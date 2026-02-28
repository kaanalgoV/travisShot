import AppKit

/// A borderless NSWindow subclass that completely prevents dragging/moving.
/// Used for the annotation canvas so mouse drags go to drawing, not window movement.
final class NonDraggableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func performDrag(with event: NSEvent) {
        // Do nothing -- prevent all window dragging
    }

    // Forward scroll events to the content view
    override func scrollWheel(with event: NSEvent) {
        contentView?.scrollWheel(with: event)
    }
}
