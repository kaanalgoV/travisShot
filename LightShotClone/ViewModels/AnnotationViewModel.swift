import SwiftUI

final class AnnotationViewModel: ObservableObject {
    @Published var annotations: [Annotation] = []
    @Published var currentAnnotation: Annotation? = nil
    @Published var selectedTool: AnnotationTool? = nil
    @Published var currentColor: Color = .red
    @Published var currentLineWidth: CGFloat = 2
    @Published var currentFontSize: CGFloat = 16
    @Published var isEditingText = false
    @Published var textEditPosition: CGPoint = .zero
    @Published var textEditContent: String = ""

    private var undoStack: [[Annotation]] = []

    // MARK: - Tool Selection

    func selectTool(_ tool: AnnotationTool) {
        if selectedTool == tool {
            selectedTool = nil // Toggle off
        } else {
            selectedTool = tool
        }
        commitTextIfNeeded()
    }

    // MARK: - Drawing

    func beginStroke(at point: CGPoint) {
        guard let tool = selectedTool else { return }

        if tool == .text {
            commitTextIfNeeded()
            isEditingText = true
            textEditPosition = point
            textEditContent = ""
            return
        }

        let color: Color = (tool == .marker) ? .yellow.opacity(0.4) : currentColor
        let lineWidth: CGFloat = (tool == .marker) ? max(currentLineWidth * 5, 20) : currentLineWidth

        var annotation = Annotation(
            tool: tool,
            startPoint: point,
            endPoint: point,
            color: color,
            lineWidth: lineWidth
        )

        if tool == .pen || tool == .marker {
            annotation.freehandPoints = [point]
        }

        currentAnnotation = annotation
    }

    func continueStroke(to point: CGPoint) {
        guard var annotation = currentAnnotation else { return }

        if annotation.tool == .pen || annotation.tool == .marker {
            annotation.freehandPoints.append(point)
        }
        annotation.endPoint = point
        currentAnnotation = annotation
    }

    func endStroke(at point: CGPoint) {
        guard var annotation = currentAnnotation else { return }

        if annotation.tool == .pen || annotation.tool == .marker {
            annotation.freehandPoints.append(point)
        }
        annotation.endPoint = point

        undoStack.append(annotations)
        annotations.append(annotation)
        currentAnnotation = nil
    }

    // MARK: - Text

    func commitTextIfNeeded() {
        guard isEditingText, !textEditContent.isEmpty else {
            isEditingText = false
            return
        }

        let annotation = Annotation(
            tool: .text,
            startPoint: textEditPosition,
            endPoint: textEditPosition,
            color: currentColor,
            lineWidth: 1,
            text: textEditContent,
            fontSize: currentFontSize
        )

        undoStack.append(annotations)
        annotations.append(annotation)
        isEditingText = false
        textEditContent = ""
    }

    // MARK: - Line Width / Font Size (scroll wheel)

    func adjustSize(delta: CGFloat) {
        if selectedTool == .text || isEditingText {
            currentFontSize = max(8, min(72, currentFontSize + delta))
        } else {
            currentLineWidth = max(1, min(20, currentLineWidth + delta))
        }
    }

    // MARK: - Undo

    func undo() {
        if let previous = undoStack.popLast() {
            annotations = previous
        }
    }

    /// Render all annotations onto a CGImage and return the composited result
    func renderAnnotations(onto image: CGImage, selectionRect: CGRect) -> CGImage? {
        let width = Int(selectionRect.width)
        let height = Int(selectionRect.height)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Draw the base image
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Draw annotations
        for annotation in annotations {
            AnnotationRenderer.draw(annotation, in: context, canvasSize: CGSize(width: width, height: height))
        }

        return context.makeImage()
    }
}
