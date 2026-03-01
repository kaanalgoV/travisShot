import AppKit

/// Manages a floating tooltip window at a high window level (above toolbar panels)
final class TooltipPanel {
    static let shared = TooltipPanel()
    private var window: NSWindow?

    func show(_ text: String, anchorScreenRect: NSRect, edge: NSRectEdge) {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .white
        label.backgroundColor = .clear
        label.isBezeled = false

        let hPad: CGFloat = 8
        let vPad: CGFloat = 4
        let size = NSSize(
            width: label.fittingSize.width + hPad * 2,
            height: label.fittingSize.height + vPad * 2
        )
        label.frame.origin = NSPoint(x: hPad, y: vPad)

        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.cornerRadius = 4
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        container.addSubview(label)

        if window == nil {
            let w = NSWindow(
                contentRect: .zero,
                styleMask: [.borderless],
                backing: .buffered,
                defer: true
            )
            w.isOpaque = false
            w.backgroundColor = .clear
            w.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)) + 10)
            w.hasShadow = false
            w.ignoresMouseEvents = true
            w.isReleasedWhenClosed = false
            window = w
        }

        let origin: NSPoint
        switch edge {
        case .minX: // Left of anchor
            origin = NSPoint(x: anchorScreenRect.minX - size.width - 4,
                             y: anchorScreenRect.midY - size.height / 2)
        case .maxY: // Above anchor
            origin = NSPoint(x: anchorScreenRect.midX - size.width / 2,
                             y: anchorScreenRect.maxY + 4)
        default:
            origin = NSPoint(x: anchorScreenRect.maxX + 4,
                             y: anchorScreenRect.midY - size.height / 2)
        }

        window?.contentView = container
        window?.setFrame(NSRect(origin: origin, size: size), display: true)
        window?.orderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }
}
