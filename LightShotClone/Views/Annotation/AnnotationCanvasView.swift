import AppKit
import Combine
import SwiftUI

/// Pure AppKit drawing canvas. Handles rendering AND mouse input natively.
/// Now covers the FULL SCREEN so the user can draw anywhere (useful for webinars).
final class DrawingCanvasNSView: NSView {
    let viewModel: AnnotationViewModel
    private var textField: NSTextField?
    private var cancellables = Set<AnyCancellable>()
    private var sizeIndicatorPanel: NSPanel?
    private var sizeIndicatorTimer: Timer?

    /// Drag state for the select tool
    private var isDraggingSelection = false
    private var dragStartPoint: CGPoint = .zero
    private var didPushUndoForDrag = false

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
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
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
        // Narrower arrowhead: smaller length and tighter angle
        let arrowLength: CGFloat = max(12, lineWidth * 3.5)
        let arrowAngle: CGFloat = .pi / 9 // 20° instead of 30°

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

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)

        let point = convert(event.locationInWindow, from: nil)

        // Select tool handling
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
            } else {
                viewModel.selectAnnotation(at: nil)
                isDraggingSelection = false
            }
            needsDisplay = true
            return
        }

        guard viewModel.selectedTool != nil else { return }

        if viewModel.selectedTool == .text {
            showTextField(at: point)
            return
        }

        viewModel.beginStroke(at: point)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

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

        guard viewModel.selectedTool != nil, viewModel.selectedTool != .text else { return }
        viewModel.continueStroke(to: point)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if viewModel.selectedTool == .select && isDraggingSelection {
            isDraggingSelection = false
            needsDisplay = true
            return
        }

        guard viewModel.selectedTool != nil, viewModel.selectedTool != .text else { return }
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

        let isText = viewModel.selectedTool == .text || viewModel.isEditingText
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

    private func showTextField(at point: CGPoint) {
        commitTextField()

        let maxWidth = bounds.width - point.x - 10
        let tf = NSTextField(frame: NSRect(
            x: point.x,
            y: point.y,
            width: min(300, max(100, maxWidth)),
            height: viewModel.currentFontSize + 8
        ))
        tf.isEditable = true
        tf.isBordered = false
        tf.font = NSFont.systemFont(ofSize: viewModel.currentFontSize)
        tf.textColor = NSColor(viewModel.currentColor)
        tf.focusRingType = .none
        tf.delegate = self
        tf.stringValue = ""
        tf.cell?.isScrollable = true
        tf.cell?.wraps = false
        tf.cell?.lineBreakMode = .byClipping

        // Transparent background with subtle white border
        tf.drawsBackground = true
        tf.backgroundColor = NSColor(white: 1.0, alpha: 0.08)
        tf.wantsLayer = true
        tf.layer?.borderColor = NSColor(white: 1.0, alpha: 0.4).cgColor
        tf.layer?.borderWidth = 1.0
        tf.layer?.cornerRadius = 3.0

        addSubview(tf)
        tf.becomeFirstResponder()
        textField = tf
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
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (annotation.text as NSString).size(withAttributes: attrs)

        let maxWidth = bounds.width - annotation.startPoint.x - 10
        let tf = NSTextField(frame: NSRect(
            x: annotation.startPoint.x,
            y: annotation.startPoint.y,
            width: max(min(300, max(textSize.width + 20, 100)), maxWidth > 100 ? 100 : maxWidth),
            height: annotation.fontSize + 8
        ))
        tf.isEditable = true
        tf.isBordered = false
        tf.font = font
        tf.textColor = NSColor(annotation.color)
        tf.focusRingType = .none
        tf.delegate = self
        tf.stringValue = annotation.text
        tf.cell?.isScrollable = true
        tf.cell?.wraps = false
        tf.cell?.lineBreakMode = .byClipping

        // Transparent background with subtle white border
        tf.drawsBackground = true
        tf.backgroundColor = NSColor(white: 1.0, alpha: 0.08)
        tf.wantsLayer = true
        tf.layer?.borderColor = NSColor(white: 1.0, alpha: 0.4).cgColor
        tf.layer?.borderWidth = 1.0
        tf.layer?.cornerRadius = 3.0

        addSubview(tf)
        tf.becomeFirstResponder()
        tf.currentEditor()?.selectAll(nil)
        textField = tf
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
        // Tool stays on .text — user can keep placing text without re-selecting the tool
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
}
