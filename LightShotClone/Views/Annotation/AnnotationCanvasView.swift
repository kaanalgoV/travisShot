import AppKit
import Combine
import SwiftUI

/// Pure AppKit drawing canvas. Handles rendering AND mouse input natively.
/// Covers the FULL SCREEN so the user can draw anywhere (useful for webinars).
final class DrawingCanvasNSView: NSView {
    let viewModel: AnnotationViewModel
    /// Frozen screenshot used for blur annotation preview
    var screenCapture: CGImage?
    private let ciContext = CIContext()
    private var textField: NSTextField?
    private var cancellables = Set<AnyCancellable>()
    private var sizeIndicatorPanel: NSPanel?
    private var sizeIndicatorTimer: Timer?

    /// True when user is typing into an inline text field — key monitor must ignore tool shortcuts
    var isTextFieldActive: Bool { textField != nil }

    /// Drag state for the select tool
    private var isDraggingSelection = false
    private var dragStartPoint: CGPoint = .zero
    private var didPushUndoForDrag = false

    /// Drag state for moving text with the text tool
    private var isDraggingText = false
    private var draggingTextIndex: Int? = nil

    /// When true, the canvas defers cursor/mouse to the OCR overlay
    var isOCRActive = false

    /// Tracking area for cursor changes
    private var cursorTrackingArea: NSTrackingArea?

    // MARK: - Editable Selection Rect

    /// The editable selection rectangle (in canvas flipped coords)
    var editableSelectionRect: CGRect? {
        didSet { needsDisplay = true }
    }
    var onSelectionChanged: ((CGRect) -> Void)?

    private var isResizingSelRect = false
    private var isMovingSelRect = false
    private var activeSelHandle: SelHandle? = nil
    private var selDragStart: CGPoint = .zero
    private let selHandleSize: CGFloat = 8

    enum SelHandle: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
    }

    init(viewModel: AnnotationViewModel, frame: NSRect) {
        self.viewModel = viewModel
        super.init(frame: frame)

        viewModel.$annotations
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.needsDisplay = true }
            .store(in: &cancellables)

        viewModel.$selectedAnnotationIndex
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.needsDisplay = true }
            .store(in: &cancellables)

        // Commit & remove text field when switching away from text tool
        viewModel.$selectedTool
            .receive(on: RunLoop.main)
            .sink { [weak self] tool in
                guard let self = self else { return }
                if tool != .text {
                    self.commitTextField()
                }
            }
            .store(in: &cancellables)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    // MARK: - Tracking Area (for cursor changes)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = cursorTrackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        cursorTrackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        // When OCR overlay is active, let it handle cursor
        if isOCRActive { return }

        let point = convert(event.locationInWindow, from: nil)

        // Selection handle cursor (highest priority)
        if let handle = hitTestSelHandle(at: point) {
            cursorForSelHandle(handle).set()
            return
        }

        // Inside selection with no tool → openHand
        if shouldMoveSelection(at: point) {
            NSCursor.openHand.set()
            return
        }

        if viewModel.selectedTool == .text {
            // Show move cursor when hovering over existing text annotation
            if let _ = textAnnotationAtPoint(point) {
                NSCursor.openHand.set()
                return
            }
            NSCursor.iBeam.set()
            return
        }

        if viewModel.selectedTool == .select {
            if let _ = viewModel.hitTestAnnotation(at: point) {
                NSCursor.openHand.set()
                return
            }
            NSCursor.arrow.set()
            return
        }

        NSCursor.crosshair.set()
    }

    /// Find the topmost text annotation at a given point
    private func textAnnotationAtPoint(_ point: CGPoint) -> Int? {
        for i in viewModel.annotations.indices.reversed() {
            let ann = viewModel.annotations[i]
            if ann.tool == .text && ann.hitTest(point: point) {
                return i
            }
        }
        return nil
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(NSColor(white: 0, alpha: 0.01).cgColor)
        ctx.fill(bounds)

        for (i, annotation) in viewModel.annotations.enumerated() {
            drawAnnotation(annotation, in: ctx)
            if i == viewModel.selectedAnnotationIndex {
                drawSelectionIndicator(for: annotation, in: ctx)
            }
        }

        if let current = viewModel.currentAnnotation {
            drawAnnotation(current, in: ctx)
        }

        drawEditableSelection(in: ctx)
    }

    private func drawAnnotation(_ annotation: Annotation, in ctx: CGContext) {
        let nsColor = NSColor(annotation.color)
        ctx.setStrokeColor(nsColor.cgColor)
        ctx.setFillColor(nsColor.cgColor)
        ctx.setLineWidth(annotation.lineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        switch annotation.tool {
        case .select:
            break

        case .pen, .marker:
            guard annotation.freehandPoints.count > 1 else { return }
            ctx.beginPath()
            ctx.move(to: annotation.freehandPoints[0])
            for point in annotation.freehandPoints.dropFirst() {
                ctx.addLine(to: point)
            }
            ctx.strokePath()

        case .line:
            ctx.beginPath()
            ctx.move(to: annotation.startPoint)
            ctx.addLine(to: annotation.endPoint)
            ctx.strokePath()

        case .arrow:
            drawArrow(from: annotation.startPoint, to: annotation.endPoint,
                      lineWidth: annotation.lineWidth, in: ctx)

        case .rectangle:
            let rect = annotation.boundingRect
            ctx.stroke(rect)

        case .text:
            let font = NSFont.systemFont(ofSize: annotation.fontSize)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: nsColor
            ]
            (annotation.text as NSString).draw(at: annotation.startPoint, withAttributes: attrs)

        case .number:
            let diameter = max(28, annotation.fontSize * 1.6)
            let radius = diameter / 2
            let circleRect = CGRect(
                x: annotation.startPoint.x - radius,
                y: annotation.startPoint.y - radius,
                width: diameter,
                height: diameter
            )
            ctx.fillEllipse(in: circleRect)

            // White border
            ctx.saveGState()
            ctx.setStrokeColor(NSColor.white.cgColor)
            ctx.setLineWidth(2)
            ctx.strokeEllipse(in: circleRect)
            ctx.restoreGState()

            // Number text centered
            let numStr = "\(annotation.numberValue)" as NSString
            let numFont = NSFont.boldSystemFont(ofSize: annotation.fontSize)
            let numAttrs: [NSAttributedString.Key: Any] = [
                .font: numFont,
                .foregroundColor: NSColor.white
            ]
            let textSize = numStr.size(withAttributes: numAttrs)
            let textPoint = CGPoint(
                x: annotation.startPoint.x - textSize.width / 2,
                y: annotation.startPoint.y - textSize.height / 2
            )
            numStr.draw(at: textPoint, withAttributes: numAttrs)

        case .blur:
            let rect = annotation.boundingRect
            guard rect.width > 1, rect.height > 1, let capture = screenCapture else {
                // Fallback: draw a crosshatch pattern
                ctx.saveGState()
                ctx.setStrokeColor(NSColor.gray.withAlphaComponent(0.5).cgColor)
                ctx.setLineWidth(1)
                ctx.setLineDash(phase: 0, lengths: [4, 4])
                ctx.stroke(rect)
                ctx.restoreGState()
                return
            }

            let scaleX = CGFloat(capture.width) / bounds.width
            let scaleY = CGFloat(capture.height) / bounds.height
            let pixelRect = CGRect(
                x: rect.minX * scaleX,
                y: rect.minY * scaleY,
                width: rect.width * scaleX,
                height: rect.height * scaleY
            )
            let imageBounds = CGRect(x: 0, y: 0, width: CGFloat(capture.width), height: CGFloat(capture.height))
            let clampedRect = pixelRect.intersection(imageBounds)
            guard !clampedRect.isEmpty, let cropped = capture.cropping(to: clampedRect) else { return }

            let ciImage = CIImage(cgImage: cropped)
            let pixelScale = max(8, min(rect.width, rect.height) * scaleX / 8)
            guard let filter = CIFilter(name: "CIPixellate") else { return }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(pixelScale as NSNumber, forKey: kCIInputScaleKey)

            guard let output = filter.outputImage,
                  let pixelated = ciContext.createCGImage(output, from: ciImage.extent) else { return }

            ctx.saveGState()
            ctx.translateBy(x: rect.minX, y: rect.maxY)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(pixelated, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
            ctx.restoreGState()
        }
    }

    private func drawSelectionIndicator(for annotation: Annotation, in ctx: CGContext) {
        let rect = annotation.selectionRect().insetBy(dx: -4, dy: -4)
        guard rect.width > 0 && rect.height > 0 else { return }

        ctx.saveGState()
        ctx.setStrokeColor(NSColor.systemBlue.cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineDash(phase: 0, lengths: [4, 4])
        ctx.stroke(rect)

        let handleSize: CGFloat = 6
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.setStrokeColor(NSColor.systemBlue.cgColor)
        ctx.setLineWidth(1)
        ctx.setLineDash(phase: 0, lengths: [])
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY),
        ]
        for corner in corners {
            let handleRect = CGRect(
                x: corner.x - handleSize / 2,
                y: corner.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )
            ctx.fillEllipse(in: handleRect)
            ctx.strokeEllipse(in: handleRect)
        }
        ctx.restoreGState()
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint,
                           lineWidth: CGFloat, in ctx: CGContext) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = max(12, lineWidth * 3.5)
        let arrowAngle: CGFloat = .pi / 9

        ctx.beginPath()
        ctx.move(to: start)
        ctx.addLine(to: end)
        ctx.strokePath()

        let tip1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let tip2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        ctx.beginPath()
        ctx.move(to: tip1)
        ctx.addLine(to: end)
        ctx.addLine(to: tip2)
        ctx.strokePath()
    }

    // MARK: - Editable Selection Drawing & Hit Testing

    private func drawEditableSelection(in ctx: CGContext) {
        guard let rect = editableSelectionRect else { return }

        // Border
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.8).cgColor)
        ctx.setLineWidth(1)
        ctx.setLineDash(phase: 0, lengths: [])
        ctx.stroke(rect)
        ctx.restoreGState()

        // Handles
        ctx.setFillColor(NSColor.white.cgColor)
        for handle in SelHandle.allCases {
            ctx.fill(selHandleRect(for: handle, in: rect))
        }

        // Dimension label
        let dimStr = "\(Int(rect.width)) x \(Int(rect.height))" as NSString
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let textSize = dimStr.size(withAttributes: attrs)
        let labelX = rect.minX + 4
        let labelY = max(rect.minY - textSize.height - 6, 2)

        ctx.saveGState()
        ctx.setFillColor(NSColor(white: 0, alpha: 0.7).cgColor)
        let bgRect = CGRect(x: labelX - 4, y: labelY - 2, width: textSize.width + 8, height: textSize.height + 4)
        ctx.addPath(CGPath(roundedRect: bgRect, cornerWidth: 3, cornerHeight: 3, transform: nil))
        ctx.fillPath()
        ctx.restoreGState()

        dimStr.draw(at: CGPoint(x: labelX, y: labelY), withAttributes: attrs)
    }

    private func selHandleRect(for handle: SelHandle, in rect: CGRect) -> CGRect {
        let hs = selHandleSize
        switch handle {
        case .topLeft:     return CGRect(x: rect.minX - hs/2, y: rect.minY - hs/2, width: hs, height: hs)
        case .topRight:    return CGRect(x: rect.maxX - hs/2, y: rect.minY - hs/2, width: hs, height: hs)
        case .bottomLeft:  return CGRect(x: rect.minX - hs/2, y: rect.maxY - hs/2, width: hs, height: hs)
        case .bottomRight: return CGRect(x: rect.maxX - hs/2, y: rect.maxY - hs/2, width: hs, height: hs)
        case .top:         return CGRect(x: rect.midX - hs/2, y: rect.minY - hs/2, width: hs, height: hs)
        case .bottom:      return CGRect(x: rect.midX - hs/2, y: rect.maxY - hs/2, width: hs, height: hs)
        case .left:        return CGRect(x: rect.minX - hs/2, y: rect.midY - hs/2, width: hs, height: hs)
        case .right:       return CGRect(x: rect.maxX - hs/2, y: rect.midY - hs/2, width: hs, height: hs)
        }
    }

    private func hitTestSelHandle(at point: CGPoint) -> SelHandle? {
        guard let rect = editableSelectionRect else { return nil }
        for handle in SelHandle.allCases {
            let hr = selHandleRect(for: handle, in: rect).insetBy(dx: -4, dy: -4)
            if hr.contains(point) { return handle }
        }
        return nil
    }

    private func updateSelResize(to point: CGPoint, handle: SelHandle) {
        guard var rect = editableSelectionRect else { return }

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
        editableSelectionRect = CGRect(
            x: min(rect.origin.x, rect.origin.x + rect.width),
            y: min(rect.origin.y, rect.origin.y + rect.height),
            width: abs(rect.width),
            height: abs(rect.height)
        )
    }

    private func cursorForSelHandle(_ handle: SelHandle) -> NSCursor {
        switch handle {
        case .topLeft, .bottomRight: return Self.nwseResizeCursor
        case .topRight, .bottomLeft: return Self.neswResizeCursor
        case .top, .bottom:          return .resizeUpDown
        case .left, .right:          return .resizeLeftRight
        }
    }

    // Custom diagonal resize cursors
    private static let nwseResizeCursor: NSCursor = makeDiagonalCursor(nwse: true)
    private static let neswResizeCursor: NSCursor = makeDiagonalCursor(nwse: false)

    private static func makeDiagonalCursor(nwse: Bool) -> NSCursor {
        let size: CGFloat = 20
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.setShouldAntialias(true)
        ctx.setLineWidth(1.5)
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setFillColor(NSColor.white.cgColor)
        let m: CGFloat = 3, al: CGFloat = 5
        if nwse {
            ctx.move(to: CGPoint(x: m, y: size - m))
            ctx.addLine(to: CGPoint(x: size - m, y: m))
            ctx.strokePath()
            ctx.move(to: CGPoint(x: m, y: size - m))
            ctx.addLine(to: CGPoint(x: m + al, y: size - m))
            ctx.addLine(to: CGPoint(x: m, y: size - m - al))
            ctx.fillPath()
            ctx.move(to: CGPoint(x: size - m, y: m))
            ctx.addLine(to: CGPoint(x: size - m - al, y: m))
            ctx.addLine(to: CGPoint(x: size - m, y: m + al))
            ctx.fillPath()
        } else {
            ctx.move(to: CGPoint(x: size - m, y: size - m))
            ctx.addLine(to: CGPoint(x: m, y: m))
            ctx.strokePath()
            ctx.move(to: CGPoint(x: size - m, y: size - m))
            ctx.addLine(to: CGPoint(x: size - m - al, y: size - m))
            ctx.addLine(to: CGPoint(x: size - m, y: size - m - al))
            ctx.fillPath()
            ctx.move(to: CGPoint(x: m, y: m))
            ctx.addLine(to: CGPoint(x: m + al, y: m))
            ctx.addLine(to: CGPoint(x: m, y: m + al))
            ctx.fillPath()
        }
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(0.5)
        if nwse {
            ctx.move(to: CGPoint(x: m, y: size - m))
            ctx.addLine(to: CGPoint(x: size - m, y: m))
        } else {
            ctx.move(to: CGPoint(x: size - m, y: size - m))
            ctx.addLine(to: CGPoint(x: m, y: m))
        }
        ctx.strokePath()
        image.unlockFocus()
        return NSCursor(image: image, hotSpot: NSPoint(x: size / 2, y: size / 2))
    }

    /// Whether a point is inside the selection but not on a handle, and no annotation tool is active
    private func shouldMoveSelection(at point: CGPoint) -> Bool {
        guard let rect = editableSelectionRect, rect.contains(point) else { return false }
        let noTool = viewModel.selectedTool == nil
        let selectNoHit = viewModel.selectedTool == .select && viewModel.hitTestAnnotation(at: point) == nil
        return noTool || selectNoHit
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        // When OCR overlay is active, don't intercept clicks
        if isOCRActive { return }

        // Force TravisShot active so events don't leak to apps below (e.g. Bookmap)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)

        let point = convert(event.locationInWindow, from: nil)

        // --- Selection resize handle (highest priority) ---
        if let handle = hitTestSelHandle(at: point) {
            isResizingSelRect = true
            isMovingSelRect = false
            activeSelHandle = handle
            selDragStart = point
            return
        }

        // --- Move selection (no tool or select-tool with no annotation hit) ---
        if shouldMoveSelection(at: point) {
            isMovingSelRect = true
            isResizingSelRect = false
            activeSelHandle = nil
            selDragStart = point
            NSCursor.closedHand.set()
            return
        }

        // --- Text tool: move existing text OR create new ---
        if viewModel.selectedTool == .text {
            // Double-click on text → edit it
            if event.clickCount == 2, let idx = textAnnotationAtPoint(point) {
                openTextEditorForAnnotation(at: idx)
                return
            }

            // Single click on existing text → start dragging to move
            if let idx = textAnnotationAtPoint(point) {
                // Commit any active text field first
                commitTextField()
                window?.makeFirstResponder(self)
                isDraggingText = true
                draggingTextIndex = idx
                dragStartPoint = point
                didPushUndoForDrag = false
                NSCursor.closedHand.set()
                needsDisplay = true
                return
            }

            // Click on empty space → new text field
            showTextField(at: point)
            return
        }

        // --- Select tool ---
        window?.makeFirstResponder(self)

        if viewModel.selectedTool == .select {
            if event.clickCount == 2 {
                if let idx = viewModel.hitTestAnnotation(at: point),
                   viewModel.annotations[idx].tool == .text {
                    openTextEditorForAnnotation(at: idx)
                    return
                }
            }

            if let idx = viewModel.hitTestAnnotation(at: point) {
                viewModel.selectAnnotation(at: idx)
                isDraggingSelection = true
                dragStartPoint = point
                didPushUndoForDrag = false
                NSCursor.closedHand.set()
            } else {
                viewModel.selectAnnotation(at: nil)
                isDraggingSelection = false
            }
            needsDisplay = true
            return
        }

        // --- All other tools ---
        guard viewModel.selectedTool != nil else { return }
        viewModel.beginStroke(at: point)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // --- Selection resize ---
        if isResizingSelRect, let handle = activeSelHandle {
            updateSelResize(to: point, handle: handle)
            return
        }

        // --- Selection move ---
        if isMovingSelRect {
            guard var rect = editableSelectionRect else { return }
            rect.origin.x += point.x - selDragStart.x
            rect.origin.y += point.y - selDragStart.y
            editableSelectionRect = rect
            selDragStart = point
            return
        }

        // Dragging text with text tool
        if isDraggingText, let idx = draggingTextIndex, viewModel.annotations.indices.contains(idx) {
            if !didPushUndoForDrag {
                viewModel.undoStack.append(viewModel.annotations)
                didPushUndoForDrag = true
            }
            let delta = CGSize(width: point.x - dragStartPoint.x, height: point.y - dragStartPoint.y)
            viewModel.annotations[idx].translate(by: delta)
            dragStartPoint = point
            needsDisplay = true
            return
        }

        // Dragging with select tool
        if viewModel.selectedTool == .select && isDraggingSelection {
            if !didPushUndoForDrag {
                viewModel.undoStack.append(viewModel.annotations)
                didPushUndoForDrag = true
            }
            let delta = CGSize(width: point.x - dragStartPoint.x, height: point.y - dragStartPoint.y)
            viewModel.moveSelectedAnnotation(by: delta)
            dragStartPoint = point
            needsDisplay = true
            return
        }

        guard let tool = viewModel.selectedTool, tool != .text, tool != .number else { return }
        viewModel.continueStroke(to: point)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if isResizingSelRect || isMovingSelRect {
            isResizingSelRect = false
            isMovingSelRect = false
            activeSelHandle = nil
            if let rect = editableSelectionRect {
                onSelectionChanged?(rect)
            }
            needsDisplay = true
            return
        }

        if isDraggingText {
            isDraggingText = false
            draggingTextIndex = nil
            NSCursor.openHand.set()
            needsDisplay = true
            return
        }

        if viewModel.selectedTool == .select && isDraggingSelection {
            isDraggingSelection = false
            NSCursor.openHand.set()
            needsDisplay = true
            return
        }

        guard let tool = viewModel.selectedTool, tool != .text, tool != .number else { return }
        let point = convert(event.locationInWindow, from: nil)
        viewModel.endStroke(at: point)
        needsDisplay = true
    }

    // MARK: - Keyboard (Delete selected)

    override func keyDown(with event: NSEvent) {
        if viewModel.selectedTool == .select,
           viewModel.selectedAnnotationIndex != nil,
           event.keyCode == 51 || event.keyCode == 117 {
            viewModel.deleteSelectedAnnotation()
            needsDisplay = true
            return
        }
        super.keyDown(with: event)
    }

    // MARK: - Scroll Wheel

    override func scrollWheel(with event: NSEvent) {
        guard event.scrollingDeltaY != 0 else { return }
        let delta: CGFloat
        if event.hasPreciseScrollingDeltas {
            delta = event.scrollingDeltaY > 0 ? 0.5 : -0.5
        } else {
            delta = event.scrollingDeltaY > 0 ? 1.0 : -1.0
        }
        viewModel.adjustSize(delta: delta)
        showSizeIndicator(at: convert(event.locationInWindow, from: nil))
    }

    private func showSizeIndicator(at localPoint: CGPoint) {
        sizeIndicatorTimer?.invalidate()
        sizeIndicatorPanel?.close()
        sizeIndicatorPanel = nil

        let isText = viewModel.selectedTool == .text || viewModel.selectedTool == .number || viewModel.isEditingText
        let value = isText ? viewModel.currentFontSize : viewModel.currentLineWidth
        let label = isText ? "Font: \(Int(value))pt" : "Width: \(String(format: "%.1f", value))px"

        let previewDiameter = isText ? min(value, 40) : min(max(value, 4), 40)

        let panelWidth: CGFloat = 80
        let panelHeight: CGFloat = previewDiameter + 32

        guard let window = self.window else { return }
        let windowPoint = convert(localPoint, to: nil)
        let screenPoint = window.convertPoint(toScreen: windowPoint)

        let panelX = screenPoint.x - panelWidth / 2
        let panelY = screenPoint.y + 16

        let panel = NSPanel(
            contentRect: NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)) + 3)
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false

        let container = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(white: 0, alpha: 0.75).cgColor
        container.layer?.cornerRadius = 8

        let dotSize = previewDiameter
        let dot = NSView(frame: NSRect(
            x: (panelWidth - dotSize) / 2,
            y: 20,
            width: dotSize,
            height: dotSize
        ))
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.white.cgColor
        dot.layer?.cornerRadius = dotSize / 2
        container.addSubview(dot)

        let textLabel = NSTextField(labelWithString: label)
        textLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        textLabel.textColor = .white
        textLabel.alignment = .center
        textLabel.frame = NSRect(x: 0, y: 2, width: panelWidth, height: 14)
        container.addSubview(textLabel)

        panel.contentView = container
        panel.orderFront(nil)
        sizeIndicatorPanel = panel

        sizeIndicatorTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            self?.sizeIndicatorPanel?.close()
            self?.sizeIndicatorPanel = nil
        }
    }

    func forceRedraw() {
        needsDisplay = true
    }

    // MARK: - Text Input

    private func configureTextFieldStyle(_ tf: NSTextField) {
        tf.drawsBackground = true
        tf.backgroundColor = NSColor(white: 1.0, alpha: 0.05)
        tf.wantsLayer = true
        tf.layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor
        tf.layer?.borderWidth = 0.5
        tf.layer?.cornerRadius = 2.0
    }

    private func showTextField(at point: CGPoint) {
        commitTextField()

        let fontSize = viewModel.currentFontSize
        let minWidth: CGFloat = 20
        let height = fontSize + 8
        let tf = NSTextField(frame: NSRect(x: point.x, y: point.y, width: minWidth, height: height))
        tf.isEditable = true
        tf.isBordered = false
        tf.font = NSFont.systemFont(ofSize: fontSize)
        tf.textColor = NSColor(viewModel.currentColor)
        tf.focusRingType = .none
        tf.delegate = self
        tf.stringValue = ""
        tf.usesSingleLineMode = true
        tf.maximumNumberOfLines = 1
        tf.autoresizingMask = []
        tf.cell?.isScrollable = false
        tf.cell?.wraps = false
        tf.cell?.lineBreakMode = .byClipping
        configureTextFieldStyle(tf)

        addSubview(tf)
        textField = tf
        tf.becomeFirstResponder()
        // Field editor installation can auto-expand — snap back on next run loop
        DispatchQueue.main.async { [weak tf] in
            tf?.frame = NSRect(x: point.x, y: point.y, width: minWidth, height: height)
        }
    }

    /// Open a text editor on an existing text annotation (for re-editing)
    private func openTextEditorForAnnotation(at index: Int) {
        let annotation = viewModel.annotations[index]
        guard annotation.tool == .text else { return }

        viewModel.undoStack.append(viewModel.annotations)
        viewModel.annotations.remove(at: index)
        viewModel.selectedAnnotationIndex = nil

        viewModel.currentColor = annotation.color
        viewModel.currentFontSize = annotation.fontSize
        viewModel.selectedTool = .text

        let font = NSFont.systemFont(ofSize: annotation.fontSize)
        let height = annotation.fontSize + 8
        let origin = annotation.startPoint

        let tf = NSTextField(frame: NSRect(x: origin.x, y: origin.y, width: 20, height: height))
        tf.isEditable = true
        tf.isBordered = false
        tf.font = font
        tf.textColor = NSColor(annotation.color)
        tf.focusRingType = .none
        tf.delegate = self
        tf.stringValue = annotation.text
        tf.usesSingleLineMode = true
        tf.maximumNumberOfLines = 1
        tf.autoresizingMask = []
        tf.cell?.isScrollable = false
        tf.cell?.wraps = false
        tf.cell?.lineBreakMode = .byClipping
        configureTextFieldStyle(tf)

        addSubview(tf)
        textField = tf
        resizeTextFieldToFit(tf)
        let fittedWidth = tf.frame.size.width
        tf.becomeFirstResponder()
        tf.currentEditor()?.selectAll(nil)
        // Field editor installation can auto-expand — snap back on next run loop
        DispatchQueue.main.async { [weak tf] in
            tf?.frame = NSRect(x: origin.x, y: origin.y, width: fittedWidth, height: height)
        }
        needsDisplay = true
    }

    func commitTextField() {
        guard let tf = textField, !tf.stringValue.isEmpty else {
            textField?.removeFromSuperview()
            textField = nil
            return
        }

        let text = tf.stringValue
        let position = tf.frame.origin
        let annotation = Annotation(
            tool: .text,
            startPoint: position,
            endPoint: position,
            color: viewModel.currentColor,
            lineWidth: 1,
            text: text,
            fontSize: viewModel.currentFontSize
        )
        viewModel.addAnnotation(annotation)

        tf.removeFromSuperview()
        textField = nil
        window?.makeFirstResponder(self)
        needsDisplay = true
    }
}

// MARK: - NSTextFieldDelegate

extension DrawingCanvasNSView: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            commitTextField()
            return true
        }
        if commandSelector == #selector(cancelOperation(_:)) {
            textField?.removeFromSuperview()
            textField = nil
            window?.makeFirstResponder(self)
            return true
        }
        return false
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let tf = textField else { return }
        resizeTextFieldToFit(tf)
    }

    private func resizeTextFieldToFit(_ tf: NSTextField) {
        let font = tf.font ?? NSFont.systemFont(ofSize: viewModel.currentFontSize)
        let text = tf.stringValue.isEmpty ? " " : tf.stringValue
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let maxWidth = bounds.width - tf.frame.origin.x - 10
        let newWidth = min(max(textSize.width + 12, 20), maxWidth)
        tf.frame.size.width = newWidth
    }
}
