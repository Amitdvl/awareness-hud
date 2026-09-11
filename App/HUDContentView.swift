import AppKit
import AwarenessCore

final class HUDContentView: NSView {
    private let label = NSTextField(labelWithString: "Starting up")
    private let accentColor = NSColor(red: 0.62, green: 0.60, blue: 1.0, alpha: 1.0)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.88).cgColor
        layer?.cornerRadius = 16
        layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        layer?.borderWidth = 1

        label.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        label.textColor = NSColor.white.withAlphaComponent(0.82)
        label.alignment = .left
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
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

    func update(with narrative: NarrativeContent) {
        let attributed = NSMutableAttributedString(string: narrative.prefix)
        attributed.append(NSAttributedString(string: narrative.firstAccent, attributes: [.foregroundColor: accentColor]))
        attributed.append(NSAttributedString(string: narrative.middle))
        attributed.append(NSAttributedString(string: narrative.secondAccent, attributes: [.foregroundColor: accentColor]))
        attributed.append(NSAttributedString(string: narrative.suffix))
        label.attributedStringValue = attributed
    }
}
