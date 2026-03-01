import AppKit
import SwiftUI

/// NSHostingView subclass that accepts the first mouse click immediately,
/// even when the window is not key. Without this, borderless windows
/// consume the first click just to activate the window.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
