import AppKit
import SwiftUI

final class OverlayWindowController {
    private var windows: [NSWindow] = []
    private let viewModel = CaptureViewModel()
    var onSelectionComplete: ((CGRect, NSScreen) -> Void)?
    var onCancel: (() -> Void)?

    func showOverlays() {
        viewModel.onCancel = { [weak self] in
            self?.dismissOverlays()
            self?.onCancel?()
        }

        for screen in NSScreen.screens {
            let window = NSWindow(
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
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let overlayView = SelectionOverlayView(
                viewModel: viewModel,
                screenFrame: screen.frame
            ).frame(width: screen.frame.width, height: screen.frame.height)

            window.contentView = NSHostingView(rootView: overlayView)
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }

        // Set cursor to crosshair
        NSCursor.crosshair.push()

        // Listen for selection completion
        viewModel.onSelectionComplete = { [weak self] rect in
            guard let self = self else { return }
            let screen = NSScreen.screens.first { $0.frame.intersects(rect) } ?? NSScreen.main ?? NSScreen.screens[0]
            self.onSelectionComplete?(rect, screen)
        }
    }

    func dismissOverlays() {
        NSCursor.pop()
        windows.forEach { $0.close() }
        windows.removeAll()
    }
}
