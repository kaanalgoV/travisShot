import AppKit
import SwiftUI

final class OverlayWindowController {
    private var windows: [NSWindow] = []
    private var frozenImageViews: [NSImageView] = []
    private let viewModel = CaptureViewModel()
    var onSelectionComplete: ((CGRect, NSScreen) -> Void)?
    var onCancel: (() -> Void)?

    func showOverlays(frozenImage: CGImage? = nil) {
        viewModel.frozenImage = frozenImage
        viewModel.isFrozen = frozenImage != nil

        // When isFrozen changes, toggle the AppKit image views
        viewModel.onUnfreeze = { [weak self] in
            self?.frozenImageViews.forEach { $0.isHidden = true }
        }

        viewModel.onCancel = { [weak self] in
            self?.dismissOverlays()
            self?.onCancel?()
        }

        for screen in NSScreen.screens {
            let window = NonDraggableWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )

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

            // Container view
            let container = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))

            // Frozen screenshot as AppKit NSImageView (handles DPI correctly)
            if let frozenImage = frozenImage {
                let rep = NSBitmapImageRep(cgImage: frozenImage)
                rep.size = screen.frame.size // Map pixel data to screen point size
                let nsImage = NSImage(size: screen.frame.size)
                nsImage.addRepresentation(rep)

                let imageView = NSImageView(frame: NSRect(origin: .zero, size: screen.frame.size))
                imageView.image = nsImage
                imageView.imageScaling = .scaleAxesIndependently
                imageView.autoresizingMask = [.width, .height]
                container.addSubview(imageView)
                frozenImageViews.append(imageView)
            }

            // SwiftUI overlay on top
            let overlayView = SelectionOverlayView(
                viewModel: viewModel,
                screenFrame: screen.frame
            ).frame(width: screen.frame.width, height: screen.frame.height)

            let hostingView = FirstMouseHostingView(rootView: overlayView)
            hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
            hostingView.autoresizingMask = [.width, .height]
            container.addSubview(hostingView)

            window.contentView = container
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }

        NSCursor.crosshair.push()

        viewModel.onSelectionComplete = { [weak self] rect in
            guard let self = self else { return }
            let screen = NSScreen.screens.first { $0.frame.intersects(rect) } ?? NSScreen.main ?? NSScreen.screens[0]
            self.onSelectionComplete?(rect, screen)
        }
    }

    /// Restore a previously saved selection rectangle
    func restoreSelection(_ rect: CGRect) {
        viewModel.selectionRect = rect
    }

    /// Make overlay windows pass-through for mouse events (keeps dimming visible)
    func makePassthrough() {
        NSCursor.pop()
        windows.forEach { $0.ignoresMouseEvents = true }
    }

    /// Hide the frozen screenshot but keep the dimming overlay visible
    func unfreeze() {
        frozenImageViews.forEach { $0.isHidden = true }
        viewModel.isFrozen = false
    }

    /// Freeze with a new screenshot
    func freeze(newImage: CGImage) {
        guard let screen = NSScreen.main else { return }
        let rep = NSBitmapImageRep(cgImage: newImage)
        rep.size = screen.frame.size
        let nsImage = NSImage(size: screen.frame.size)
        nsImage.addRepresentation(rep)

        for imageView in frozenImageViews {
            imageView.image = nsImage
            imageView.isHidden = false
        }
        viewModel.frozenImage = newImage
        viewModel.isFrozen = true
    }

    func dismissOverlays() {
        NSCursor.pop()
        frozenImageViews.removeAll()
        windows.forEach { $0.close() }
        windows.removeAll()
    }
}
