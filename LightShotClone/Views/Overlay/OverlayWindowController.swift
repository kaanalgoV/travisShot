import AppKit
import SwiftUI

final class OverlayWindowController {
    private var windows: [NSWindow] = []
    private var frozenImageViewsByDisplay: [CGDirectDisplayID: NSImageView] = [:]
    private let viewModel = CaptureViewModel()
    private var totalFrame: CGRect = .zero
    private var keyMonitor: Any?
    var onSelectionComplete: ((CGRect, NSScreen) -> Void)?
    var onCancel: (() -> Void)?

    /// The selection rect in the unified (multi-screen) coordinate space
    var unifiedSelectionRect: CGRect? { viewModel.selectionRect }

    func showOverlays(frozenImages: [CGDirectDisplayID: CGImage] = [:]) {
        totalFrame = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }

        // Debug: dump screen configuration to file
        var dbg = "=== TravisShot Overlay Debug ===\n"
        for screen in NSScreen.screens {
            dbg += "Screen displayID=\(screen.displayID) frame=\(screen.frame) scale=\(screen.backingScaleFactor)\n"
        }
        dbg += "totalFrame=\(totalFrame)\n"
        for (displayID, img) in frozenImages {
            dbg += "frozenImage displayID=\(displayID) pixels=\(img.width)x\(img.height)\n"
        }

        viewModel.isFrozen = !frozenImages.isEmpty

        viewModel.onUnfreeze = { [weak self] in
            self?.frozenImageViewsByDisplay.values.forEach { $0.isHidden = true }
        }

        viewModel.onCancel = { [weak self] in
            self?.dismissOverlays()
            self?.onCancel?()
        }

        // One window per screen: each contains frozen image + selection overlay
        // This avoids mixed-DPI issues from a single spanning window
        for screen in NSScreen.screens {
            let displayID = screen.displayID
            let screenSize = screen.frame.size

            let window = NonDraggableWindow(
                contentRect: NSRect(origin: .zero, size: screenSize),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.setFrame(screen.frame, display: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true
            window.isMovable = false
            window.isMovableByWindowBackground = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isReleasedWhenClosed = false
            window.hidesOnDeactivate = false

            let container = NSView(frame: NSRect(origin: .zero, size: screenSize))

            // Frozen image layer
            if let frozenImage = frozenImages[displayID] {
                let imageView = makeImageView(for: frozenImage, screenSize: screenSize)
                imageView.frame = NSRect(origin: .zero, size: screenSize)
                container.addSubview(imageView)
                frozenImageViewsByDisplay[displayID] = imageView
            }

            // Selection overlay on top (SwiftUI)
            let unifiedOffset = CGPoint(
                x: screen.frame.origin.x - totalFrame.origin.x,
                y: totalFrame.maxY - screen.frame.maxY
            )

            let overlayView = SelectionOverlayView(
                viewModel: viewModel,
                screenFrame: CGRect(origin: .zero, size: screenSize),
                unifiedOffset: unifiedOffset
            ).frame(width: screenSize.width, height: screenSize.height)

            let hostingView = FirstMouseHostingView(rootView: overlayView)
            hostingView.frame = NSRect(origin: .zero, size: screenSize)
            hostingView.autoresizingMask = [.width, .height]
            container.addSubview(hostingView)

            window.contentView = container
            window.makeKeyAndOrderFront(nil)
            windows.append(window)

            dbg += "window[\(displayID)] frame=\(window.frame) actualFrame=\(screen.frame)\n"
        }

        dbg += "windows created: \(windows.count)\n"
        try? dbg.write(toFile: "/tmp/travisshot_overlay.log", atomically: true, encoding: .utf8)

        NSCursor.crosshair.push()
        installKeyMonitor()

        viewModel.onSelectionComplete = { [weak self] rect in
            guard let self = self else { return }
            self.removeKeyMonitor()

            // rect is in unified SwiftUI coords (top-left origin)
            let centerX = self.totalFrame.origin.x + rect.midX
            let centerY = self.totalFrame.maxY - rect.midY
            let globalCenter = CGPoint(x: centerX, y: centerY)
            let screen = NSScreen.screens.first { $0.frame.contains(globalCenter) }
                ?? NSScreen.main ?? NSScreen.screens[0]

            let screenOffsetX = screen.frame.origin.x - self.totalFrame.origin.x
            let screenOffsetY = self.totalFrame.maxY - screen.frame.maxY
            let screenLocalRect = CGRect(
                x: rect.origin.x - screenOffsetX,
                y: rect.origin.y - screenOffsetY,
                width: rect.width,
                height: rect.height
            )

            self.onSelectionComplete?(screenLocalRect, screen)
        }
    }

    /// Restore a previously saved selection rectangle (in unified coords) and immediately confirm
    func restoreSelection(_ rect: CGRect) {
        viewModel.selectionRect = rect
        viewModel.confirmSelection()
    }

    /// Update the dimming cutout from canvas coordinates (screen-local, top-left origin)
    func updateSelectionFromCanvas(_ canvasRect: CGRect, screen: NSScreen) {
        let unifiedX = canvasRect.origin.x + (screen.frame.origin.x - totalFrame.origin.x)
        let unifiedY = canvasRect.origin.y + (totalFrame.maxY - screen.frame.maxY)
        let unifiedRect = CGRect(x: unifiedX, y: unifiedY, width: canvasRect.width, height: canvasRect.height)
        viewModel.selectionRect = unifiedRect
    }

    /// Make overlay windows pass-through for mouse events (keeps dimming visible)
    func makePassthrough() {
        NSCursor.pop()
        windows.forEach { $0.ignoresMouseEvents = true }
    }

    /// Hide the frozen screenshot but keep the dimming overlay visible
    func unfreeze() {
        frozenImageViewsByDisplay.values.forEach { $0.isHidden = true }
        viewModel.isFrozen = false
    }

    /// Freeze with new per-display screenshots
    func freeze(newImages: [CGDirectDisplayID: CGImage]) {
        for (displayID, image) in newImages {
            if let existingView = frozenImageViewsByDisplay[displayID] {
                let screen = NSScreen.screens.first { $0.displayID == displayID }
                let screenSize = screen?.frame.size ?? NSSize(width: CGFloat(image.width), height: CGFloat(image.height))
                let rep = NSBitmapImageRep(cgImage: image)
                rep.size = screenSize
                let nsImage = NSImage(size: screenSize)
                nsImage.addRepresentation(rep)
                existingView.image = nsImage
                existingView.isHidden = false
            }
        }
        viewModel.isFrozen = true
    }

    func dismissOverlays() {
        removeKeyMonitor()
        NSCursor.pop()
        frozenImageViewsByDisplay.removeAll()
        windows.forEach { $0.close() }
        windows.removeAll()
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            if event.keyCode == 53 { // Escape
                self.viewModel.cancel()
                return nil
            }

            if event.keyCode == 36 || event.keyCode == 76 { // Enter or numpad Enter
                self.viewModel.confirmSelection()
                return nil
            }

            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // MARK: - Helpers

    private func makeImageView(for image: CGImage, screenSize: NSSize) -> NSImageView {
        let rep = NSBitmapImageRep(cgImage: image)
        rep.size = screenSize
        let nsImage = NSImage(size: screenSize)
        nsImage.addRepresentation(rep)

        let imageView = NSImageView(frame: NSRect(origin: .zero, size: screenSize))
        imageView.image = nsImage
        imageView.imageScaling = .scaleAxesIndependently
        imageView.autoresizingMask = [.width, .height]
        return imageView
    }
}
