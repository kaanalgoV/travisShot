import SwiftUI
import Combine

final class CaptureViewModel: ObservableObject {
    @Published var state: CaptureState = .idle
    @Published var selectionRect: CGRect? = nil
    @Published var dragStart: CGPoint? = nil
    @Published var dragCurrent: CGPoint? = nil

    // Selection resize handles
    @Published var isResizing = false
    @Published var resizeHandle: ResizeHandle? = nil

    // Screenshot data
    @Published var capturedImage: CGImage? = nil

    // Frozen screen state
    @Published var isFrozen: Bool = false {
        didSet {
            if !isFrozen { onUnfreeze?() }
        }
    }
    @Published var frozenImage: CGImage?

    // Callbacks
    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    var onUnfreeze: (() -> Void)?

    enum ResizeHandle: CaseIterable, Hashable {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
    }

    /// Start a new selection drag
    func beginDrag(at point: CGPoint) {
        // Check if we're clicking a resize handle
        if let rect = selectionRect, let handle = hitTestHandle(at: point, in: rect) {
            isResizing = true
            resizeHandle = handle
            dragStart = point
            return
        }

        // Check if clicking inside existing selection (to move it)
        if let rect = selectionRect, rect.contains(point) {
            isResizing = true
            resizeHandle = nil // nil = moving
            dragStart = point
            return
        }

        // New selection
        dragStart = point
        dragCurrent = point
        selectionRect = nil
        state = .selecting(origin: point)
    }

    /// Update during drag
    func updateDrag(to point: CGPoint) {
        if isResizing {
            updateResize(to: point)
            return
        }

        dragCurrent = point
        if let start = dragStart {
            selectionRect = CGRect(
                x: min(start.x, point.x),
                y: min(start.y, point.y),
                width: abs(point.x - start.x),
                height: abs(point.y - start.y)
            )
        }
    }

    /// End drag
    func endDrag(at point: CGPoint) {
        if isResizing {
            isResizing = false
            resizeHandle = nil
            dragStart = nil
            return
        }

        updateDrag(to: point)
        dragStart = nil
        dragCurrent = nil

        if let rect = selectionRect, rect.width > 5, rect.height > 5 {
            state = .selected(rect: rect)
            onSelectionComplete?(rect)
        }
    }

    /// Cancel the capture
    func cancel() {
        state = .idle
        selectionRect = nil
        dragStart = nil
        dragCurrent = nil
        onCancel?()
    }

    /// Move selection with arrow keys (pixel-perfect adjustment)
    func nudgeSelection(dx: CGFloat, dy: CGFloat) {
        guard var rect = selectionRect else { return }
        rect.origin.x += dx
        rect.origin.y += dy
        selectionRect = rect
    }

    // MARK: - Resize Handles

    let handleSize: CGFloat = 8

    func handleRect(for handle: ResizeHandle, in selectionRect: CGRect) -> CGRect {
        let hs = handleSize
        let r = selectionRect
        switch handle {
        case .topLeft:     return CGRect(x: r.minX - hs/2, y: r.minY - hs/2, width: hs, height: hs)
        case .topRight:    return CGRect(x: r.maxX - hs/2, y: r.minY - hs/2, width: hs, height: hs)
        case .bottomLeft:  return CGRect(x: r.minX - hs/2, y: r.maxY - hs/2, width: hs, height: hs)
        case .bottomRight: return CGRect(x: r.maxX - hs/2, y: r.maxY - hs/2, width: hs, height: hs)
        case .top:         return CGRect(x: r.midX - hs/2, y: r.minY - hs/2, width: hs, height: hs)
        case .bottom:      return CGRect(x: r.midX - hs/2, y: r.maxY - hs/2, width: hs, height: hs)
        case .left:        return CGRect(x: r.minX - hs/2, y: r.midY - hs/2, width: hs, height: hs)
        case .right:       return CGRect(x: r.maxX - hs/2, y: r.midY - hs/2, width: hs, height: hs)
        }
    }

    private func hitTestHandle(at point: CGPoint, in rect: CGRect) -> ResizeHandle? {
        for handle in ResizeHandle.allCases {
            let hr = handleRect(for: handle, in: rect).insetBy(dx: -4, dy: -4)
            if hr.contains(point) { return handle }
        }
        return nil
    }

    private func updateResize(to point: CGPoint) {
        guard var rect = selectionRect else { return }

        guard let handle = resizeHandle else {
            // Moving the entire selection
            if let start = dragStart {
                let dx = point.x - start.x
                let dy = point.y - start.y
                selectionRect = rect.offsetBy(dx: dx, dy: dy)
                dragStart = point
            }
            return
        }

        switch handle {
        case .topLeft:
            rect = CGRect(x: point.x, y: point.y, width: rect.maxX - point.x, height: rect.maxY - point.y)
        case .topRight:
            rect = CGRect(x: rect.minX, y: point.y, width: point.x - rect.minX, height: rect.maxY - point.y)
        case .bottomLeft:
            rect = CGRect(x: point.x, y: rect.minY, width: rect.maxX - point.x, height: point.y - rect.minY)
        case .bottomRight:
            rect = CGRect(x: rect.minX, y: rect.minY, width: point.x - rect.minX, height: point.y - rect.minY)
        case .top:
            rect = CGRect(x: rect.minX, y: point.y, width: rect.width, height: rect.maxY - point.y)
        case .bottom:
            rect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: point.y - rect.minY)
        case .left:
            rect = CGRect(x: point.x, y: rect.minY, width: rect.maxX - point.x, height: rect.height)
        case .right:
            rect = CGRect(x: rect.minX, y: rect.minY, width: point.x - rect.minX, height: rect.height)
        }

        // Normalize to prevent negative sizes
        selectionRect = CGRect(
            x: min(rect.origin.x, rect.origin.x + rect.width),
            y: min(rect.origin.y, rect.origin.y + rect.height),
            width: abs(rect.width),
            height: abs(rect.height)
        )
    }
}
