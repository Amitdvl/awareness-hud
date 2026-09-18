import AppKit
import AwarenessCore

@MainActor
final class CodexCommandsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private var commands: [CodexSlashCommand] = []
    private let tableView = NSTableView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Commands"
        window.center()
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        super.init(window: window)
        configureWindow(window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showCommands() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        refresh()
    }

    private func configureWindow(_ window: NSWindow) {
        guard let content = window.contentView else { return }

        let heading = NSTextField(labelWithString: "Personal slash commands")
        heading.font = .systemFont(ofSize: 17, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "Use these in Codex. Copy a command to get started.")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor

        refreshButton.target = self
        refreshButton.action = #selector(refresh)
        refreshButton.bezelStyle = .rounded

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("command"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 60
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(copySelectedCommand)

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = "Loading commands…"

        for view in [heading, subtitle, refreshButton, scrollView, statusLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            heading.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            refreshButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            refreshButton.centerYAnchor.constraint(equalTo: heading.centerYAnchor),
            subtitle.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            scrollView.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 14),
            statusLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            statusLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 9),
            statusLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
        ])
    }

    @objc private func refresh() {
        refreshButton.isEnabled = false
        statusLabel.stringValue = "Loading commands…"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try CodexCommandCatalogLoader.load() }
            DispatchQueue.main.async { [weak self] in
                self?.finishLoading(result)
            }
        }
    }

    private func finishLoading(_ result: Result<[CodexSlashCommand], Error>) {
        refreshButton.isEnabled = true
        switch result {
        case .success(let commands):
            self.commands = commands
            tableView.reloadData()
            statusLabel.stringValue = commands.isEmpty
                ? "No personal commands are installed."
                : "\(commands.count) commands available"
        case .failure(let error):
            statusLabel.stringValue = error.localizedDescription
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { commands.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let command = commands[row]
        let cell = NSView()
        let name = NSTextField(labelWithString: command.invocation)
        name.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)

        let summary = NSTextField(labelWithString: command.description)
        summary.font = .systemFont(ofSize: 11)
        summary.textColor = .secondaryLabelColor
        summary.lineBreakMode = .byTruncatingTail
        summary.toolTip = command.description

        let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyCommand(_:)))
        copyButton.bezelStyle = .rounded
        copyButton.tag = row

        for view in [name, summary, copyButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(view)
        }
        NSLayoutConstraint.activate([
            name.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
            name.trailingAnchor.constraint(lessThanOrEqualTo: copyButton.leadingAnchor, constant: -10),
            name.topAnchor.constraint(equalTo: cell.topAnchor, constant: 8),
            summary.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            summary.trailingAnchor.constraint(equalTo: copyButton.leadingAnchor, constant: -10),
            summary.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 5),
            summary.bottomAnchor.constraint(lessThanOrEqualTo: cell.bottomAnchor, constant: -6),
            copyButton.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
            copyButton.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            copyButton.widthAnchor.constraint(equalToConstant: 58)
        ])
        return cell
    }

    @objc private func copyCommand(_ sender: NSButton) {
        copyCommand(at: sender.tag)
    }

    @objc private func copySelectedCommand() {
        copyCommand(at: tableView.clickedRow)
    }

    private func copyCommand(at row: Int) {
        guard commands.indices.contains(row) else { return }
        let invocation = commands[row].invocation
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(invocation, forType: .string)
        statusLabel.stringValue = "Copied \(invocation)"
    }
}
