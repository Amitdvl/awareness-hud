import AppKit
import AwarenessCore

final class HUDContentView: NSView {
    private let label = NSTextField(labelWithString: "Starting up")
    private let accentColor = NSColor(red: 0.62, green: 0.60, blue: 1.0, alpha: 1.0)
    private let bodyColor = NSColor.white.withAlphaComponent(0.82)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.88).cgColor
        layer?.cornerRadius = 16
        layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        layer?.borderWidth = 1

        label.alignment = .left
        label.isSelectable = false
        label.isEditable = false
        label.refusesFirstResponder = true
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    func update(with narrative: NarrativeContent, isCompact: Bool) -> NSSize {
        let attributed = isCompact ? compactText(for: narrative) : expandedText(for: narrative)
        let maximumWidth: CGFloat = isCompact ? 230 : 440
        let minimumWidth: CGFloat = isCompact ? 112 : 280
        let horizontalPadding: CGFloat = 28

        label.maximumNumberOfLines = isCompact ? 1 : 2
        label.lineBreakMode = isCompact ? .byTruncatingTail : .byWordWrapping
        label.attributedStringValue = attributed

        let naturalWidth = ceil(attributed.size().width)
        let width = min(maximumWidth, max(minimumWidth, naturalWidth + horizontalPadding))
        let textRect = attributed.boundingRect(
            with: NSSize(width: width - horizontalPadding, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let lineHeight = ceil(NSFont.systemFont(ofSize: 14).boundingRectForFont.height)
        let height = isCompact
            ? max(34, lineHeight + 16)
            : min(62, max(38, ceil(textRect.height) + 16))
        return NSSize(width: width, height: height)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        self
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    private func compactText(for narrative: NarrativeContent) -> NSAttributedString {
        let timerFont = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        let contextFont = NSFont.systemFont(ofSize: 14, weight: .medium)
        let result = NSMutableAttributedString(
            string: narrative.duration,
            attributes: [.font: timerFont, .foregroundColor: accentColor]
        )
        result.append(NSAttributedString(
            string: "  ·  \(narrative.firstAccent)",
            attributes: [.font: contextFont, .foregroundColor: bodyColor]
        ))
        return result
    }

    private func expandedText(for narrative: NarrativeContent) -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: 14, weight: .medium)
        let bodyAttributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: bodyColor]
        let accentAttributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: accentColor]
        let attributed = NSMutableAttributedString(string: narrative.prefix, attributes: bodyAttributes)
        attributed.append(NSAttributedString(string: narrative.firstAccent, attributes: accentAttributes))
        attributed.append(NSAttributedString(string: narrative.middle, attributes: bodyAttributes))
        attributed.append(NSAttributedString(string: narrative.secondAccent, attributes: accentAttributes))
        attributed.append(NSAttributedString(string: narrative.suffix, attributes: bodyAttributes))
        return attributed
    }
}
