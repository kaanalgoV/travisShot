import AppKit
import SwiftUI

final class ActionToolbarController {
    private var panel: NSPanel?

    func show(near selectionRect: NSRect,
              onUpload: @escaping () -> Void,
              onSearchSimilar: @escaping () -> Void,
              onPrint: @escaping () -> Void,
              onCopy: @escaping () -> Void,
              onSave: @escaping () -> Void) {
        let toolbarWidth: CGFloat = 230
        let toolbarHeight: CGFloat = 50
        let margin: CGFloat = 8

        let x = selectionRect.maxX - toolbarWidth
        var y = selectionRect.minY - toolbarHeight - margin

        if y < 0 {
            y = selectionRect.maxY + margin
        }

        let frame = NSRect(x: max(x, 0), y: y, width: toolbarWidth, height: toolbarHeight)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)) + 2)
        panel.hasShadow = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true

        let view = ActionToolbarView(
            onUpload: onUpload,
            onSearchSimilar: onSearchSimilar,
            onPrint: onPrint,
            onCopy: onCopy,
            onSave: onSave
        )
        panel.contentView = NSHostingView(rootView: view)

        panel.orderFront(nil)
        self.panel = panel
    }

    func dismiss() {
        panel?.close()
        panel = nil
    }

    func reposition(near selectionRect: NSRect) {
        guard let panel = panel else { return }
        let margin: CGFloat = 8
        let x = selectionRect.maxX - panel.frame.width
        let y = selectionRect.minY - panel.frame.height - margin
        panel.setFrameOrigin(NSPoint(x: max(x, 0), y: y))
    }
}
