import AppKit
import SwiftUI

final class EditingToolbarController {
    private var panel: NSPanel?
    let annotationVM: AnnotationViewModel
    private(set) var isFrozen: Bool
    private var onToggleFreeze: (() -> Void)?
    private var onClose: (() -> Void)?

    init(annotationVM: AnnotationViewModel, isFrozen: Bool = false) {
        self.annotationVM = annotationVM
        self.isFrozen = isFrozen
    }

    func show(near selectionRect: NSRect, onToggleFreeze: @escaping () -> Void = {}, onClose: @escaping () -> Void) {
        self.onToggleFreeze = onToggleFreeze
        self.onClose = onClose

        let toolbarWidth: CGFloat = 50
        let toolbarHeight: CGFloat = 400
        let margin: CGFloat = 8

        var x = selectionRect.maxX + margin
        let y = selectionRect.maxY - toolbarHeight

        let screenMaxX = NSScreen.main?.frame.maxX ?? 1920
        if x + toolbarWidth > screenMaxX {
            x = selectionRect.minX - toolbarWidth - margin
        }

        let frame = NSRect(x: x, y: max(y, 0), width: toolbarWidth, height: toolbarHeight)

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
            onClose: { [weak self] in self?.onClose?() }
        )
    }

    private func updateView() {
        guard let panel = panel else { return }
        panel.contentView = NSHostingView(rootView: makeView())
    }
}
