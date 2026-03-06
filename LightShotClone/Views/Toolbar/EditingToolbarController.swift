import AppKit
import SwiftUI

final class EditingToolbarController {
    private var panel: NSPanel?
    let annotationVM: AnnotationViewModel
    private(set) var isFrozen: Bool
    private var onToggleFreeze: (() -> Void)?
    private var onClose: (() -> Void)?
    private var onOCR: (() -> Void)?

    init(annotationVM: AnnotationViewModel, isFrozen: Bool = false) {
        self.annotationVM = annotationVM
        self.isFrozen = isFrozen
    }

    func show(
        near selectionRect: NSRect,
        onToggleFreeze: @escaping () -> Void = {},
        onOCR: @escaping () -> Void = {},
        onClose: @escaping () -> Void
    ) {
        self.onToggleFreeze = onToggleFreeze
        self.onOCR = onOCR
        self.onClose = onClose

        let toolbarWidth: CGFloat = 50
        let toolbarHeight: CGFloat = 440
        let margin: CGFloat = 8

        // Find the screen containing the selection to constrain toolbar positioning
        let selectionCenter = CGPoint(x: selectionRect.midX, y: selectionRect.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(selectionCenter) } ?? NSScreen.main ?? NSScreen.screens[0]

        var x = selectionRect.maxX + margin
        let y = selectionRect.maxY - toolbarHeight

        if x + toolbarWidth > screen.frame.maxX {
            x = selectionRect.minX - toolbarWidth - margin
        }

        let frame = NSRect(x: x, y: max(y, screen.frame.minY), width: toolbarWidth, height: toolbarHeight)

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
        panel.isReleasedWhenClosed = false

        panel.contentView = NSHostingView(rootView: makeView())

        panel.orderFront(nil)
        self.panel = panel
    }

    func setFrozen(_ frozen: Bool) {
        isFrozen = frozen
        updateView()
    }

    func dismiss() {
        panel?.close()
        panel = nil
    }

    func reposition(near selectionRect: NSRect) {
        guard let panel = panel else { return }
        let margin: CGFloat = 8
        let x = selectionRect.maxX + margin
        let y = selectionRect.maxY - panel.frame.height
        panel.setFrameOrigin(NSPoint(x: x, y: max(y, 0)))
    }

    private func makeView() -> EditingToolbarView {
        EditingToolbarView(
            annotationVM: annotationVM,
            isFrozen: isFrozen,
            onToggleFreeze: { [weak self] in self?.onToggleFreeze?() },
            onOCR: { [weak self] in self?.onOCR?() },
            onClose: { [weak self] in self?.onClose?() }
        )
    }

    private func updateView() {
        guard let panel = panel else { return }
        panel.contentView = NSHostingView(rootView: makeView())
    }
}
