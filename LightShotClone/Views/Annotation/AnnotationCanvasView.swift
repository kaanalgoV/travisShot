import AppKit
import Combine
import SwiftUI

/// Pure AppKit drawing canvas. Handles rendering AND mouse input natively.
final class DrawingCanvasNSView: NSView {
    let viewModel: AnnotationViewModel
    private var textField: NSTextField?
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: AnnotationViewModel, frame: NSRect) {
        self.viewModel = viewModel
        super.init(frame: frame)

        // Observe annotation changes from external sources (e.g. undo via toolbar)
        viewModel.$annotations
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.needsDisplay = true }
            .store(in: &cancellables)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    /// Accept the very first mouse click even when the window isn't key.
    /// Without this, clicking after using the toolbar only re-focuses the window.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // Draw a nearly-invisible background so macOS delivers mouse events to this window.
        // Fully transparent borderless windows pass mouse events through to windows below.
        ctx.setFillColor(NSColor(white: 0, alpha: 0.01).cgColor)
        ctx.fill(bounds)

        // Draw completed annotations
        for annotation in viewModel.annotations {
            drawAnnotation(annotation, in: ctx)
        }

        // Draw in-progress annotation
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

    private func drawArrow(from start: CGPoint, to end: CGPoint,
                           lineWidth: CGFloat, in ctx: CGContext) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = max(15, lineWidth * 5)
        let arrowAngle: CGFloat = .pi / 6

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
        // Always reclaim key window + first responder on click
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)

        guard viewModel.selectedTool != nil else { return }
        let point = convert(event.locationInWindow, from: nil)

        if viewModel.selectedTool == .text {
            showTextField(at: point)
            return
        }

        viewModel.beginStroke(at: point)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard viewModel.selectedTool != nil, viewModel.selectedTool != .text else { return }
        let point = convert(event.locationInWindow, from: nil)
        viewModel.continueStroke(to: point)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard viewModel.selectedTool != nil, viewModel.selectedTool != .text else { return }
        let point = convert(event.locationInWindow, from: nil)
        viewModel.endStroke(at: point)
        needsDisplay = true
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
    }

    /// Force redraw (called externally when tool changes via toolbar)
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
        tf.drawsBackground = false
        tf.font = NSFont.systemFont(ofSize: viewModel.currentFontSize)
        tf.textColor = NSColor(viewModel.currentColor)
        tf.focusRingType = .none
        tf.delegate = self
        tf.stringValue = ""
        tf.cell?.isScrollable = true
        tf.cell?.wraps = false
        tf.cell?.lineBreakMode = .byClipping
        addSubview(tf)
        tf.becomeFirstResponder()
        textField = tf
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
}
