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

    /// Index of the currently selected annotation (for select tool)
    @Published var selectedAnnotationIndex: Int? = nil

    var undoStack: [[Annotation]] = []
    private let maxUndoSteps = 50

    private func pushUndo() {
        undoStack.append(annotations)
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst(undoStack.count - maxUndoSteps)
        }
    }

    func addAnnotation(_ annotation: Annotation) {
        pushUndo()
        annotations.append(annotation)
    }

    // MARK: - Tool Selection

    func selectTool(_ tool: AnnotationTool) {
        if selectedTool == tool {
            selectedTool = nil
        } else {
            selectedTool = tool
        }
        if tool != .select {
            selectedAnnotationIndex = nil
        }
        commitTextIfNeeded()
    }

    // MARK: - Selection

    /// Hit-test annotations in reverse order (topmost first) and return the index
    func hitTestAnnotation(at point: CGPoint) -> Int? {
        for i in annotations.indices.reversed() {
            if annotations[i].hitTest(point: point) {
                return i
            }
        }
        return nil
    }

    func selectAnnotation(at index: Int?) {
        selectedAnnotationIndex = index
    }

    func moveSelectedAnnotation(by delta: CGSize) {
        guard let idx = selectedAnnotationIndex, annotations.indices.contains(idx) else { return }
        annotations[idx].translate(by: delta)
    }

    func commitMove() {
        // Push undo before the move series started — handled by beginMove
    }

    func deleteSelectedAnnotation() {
        guard let idx = selectedAnnotationIndex, annotations.indices.contains(idx) else { return }
        pushUndo()
        annotations.remove(at: idx)
        selectedAnnotationIndex = nil
    }

    // MARK: - Drawing

    private func log(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
        if let data = line.data(using: .utf8) {
            if let fh = FileHandle(forWritingAtPath: "/tmp/travisshot_debug.log") {
                fh.seekToEndOfFile()
                fh.write(data)
                fh.closeFile()
            }
        }
    }

    func beginStroke(at point: CGPoint) {
        guard let tool = selectedTool else {
            log("beginStroke: no tool selected")
            return
        }
        log("beginStroke: tool=\(tool), point=\(point)")

        if tool == .text {
            commitTextIfNeeded()
            isEditingText = true
            textEditPosition = point
            textEditContent = ""
            return
        }

        if tool == .number {
            let nextNum = (annotations.filter { $0.tool == .number }.map(\.numberValue).max() ?? 0) + 1
            log("number tool: placing #\(nextNum) at \(point), color=\(currentColor), fontSize=\(currentFontSize)")
            let annotation = Annotation(
                tool: .number,
                startPoint: point,
                endPoint: point,
                color: currentColor,
                lineWidth: currentLineWidth,
                fontSize: currentFontSize,
                numberValue: nextNum
            )
            pushUndo()
            annotations.append(annotation)
            log("number tool: annotations count = \(annotations.count)")
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

        pushUndo()
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

        pushUndo()
        annotations.append(annotation)
        isEditingText = false
        textEditContent = ""
    }

    // MARK: - Line Width / Font Size (scroll wheel)

    func adjustSize(delta: CGFloat) {
        if selectedTool == .text || selectedTool == .number || isEditingText {
            currentFontSize = max(8, min(72, currentFontSize + delta))
        } else {
            currentLineWidth = max(1, min(20, currentLineWidth + delta))
        }
    }

    // MARK: - Undo

    func undo() {
        if let previous = undoStack.popLast() {
            annotations = previous
            selectedAnnotationIndex = nil
        }
    }

    // MARK: - Clear All

    func clearAll() {
        guard !annotations.isEmpty else { return }
        pushUndo()
        annotations = []
        selectedAnnotationIndex = nil
        currentAnnotation = nil
    }

    /// Render all annotations onto a CGImage and return the composited result.
    /// Annotations are in full-screen coordinates; selectionRect.origin is the offset to crop-relative coords.
    func renderAnnotations(onto image: CGImage, selectionRect: CGRect, scale: CGFloat = 2.0) -> CGImage? {
        let pixelWidth = image.width
        let pixelHeight = image.height

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        context.translateBy(x: 0, y: CGFloat(pixelHeight))
        context.scaleBy(x: scale, y: -scale)

        // Offset: annotations are in full-screen coords, image is cropped to selectionRect
        context.translateBy(x: -selectionRect.origin.x, y: -selectionRect.origin.y)

        for annotation in annotations {
            AnnotationRenderer.draw(annotation, in: context, canvasSize: selectionRect.size)
        }

        return context.makeImage()
    }
}
