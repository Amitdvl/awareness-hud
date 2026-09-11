import AppKit
import AwarenessCore

final class HUDContentView: NSView {
    private let label = NSTextField(labelWithString: "Starting up")
    private let accentColor = NSColor(red: 0.62, green: 0.60, blue: 1.0, alpha: 1.0)
    private let bodyColor = NSColor.white.withAlphaComponent(0.82)
    private let horizontalPadding: CGFloat = 36
    private let verticalPadding: CGFloat = 20
    private let minimumWidth: CGFloat = 280
    private let maximumWidth: CGFloat = 720

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.88).cgColor
        layer?.cornerRadius = 16
        layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        layer?.borderWidth = 1

        label.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        label.textColor = bodyColor
        label.alignment = .left
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.isSelectable = false
        label.isEditable = false
        label.refusesFirstResponder = true
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    func update(with narrative: NarrativeContent) -> NSSize {
        let font = label.font ?? NSFont.systemFont(ofSize: 15, weight: .medium)
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: bodyColor
        ]
        let accentAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: accentColor
        ]
        let attributed = NSMutableAttributedString(string: narrative.prefix, attributes: bodyAttributes)
        attributed.append(NSAttributedString(string: narrative.firstAccent, attributes: accentAttributes))
        attributed.append(NSAttributedString(string: narrative.middle, attributes: bodyAttributes))
        attributed.append(NSAttributedString(string: narrative.secondAccent, attributes: accentAttributes))
        attributed.append(NSAttributedString(string: narrative.suffix, attributes: bodyAttributes))
        label.attributedStringValue = attributed

        let naturalWidth = ceil((attributed.string as NSString).size(withAttributes: [.font: font]).width)
        let width = min(maximumWidth, max(minimumWidth, naturalWidth + horizontalPadding))
        let textRect = attributed.boundingRect(
            with: NSSize(width: width - horizontalPadding, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let lineHeight = ceil(font.boundingRectForFont.height)
        let height = min(verticalPadding + lineHeight * 2, max(verticalPadding + lineHeight, ceil(textRect.height) + verticalPadding))
        return NSSize(width: width, height: height)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        self
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
