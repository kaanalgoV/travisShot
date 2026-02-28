import AppKit
import SwiftUI

enum AnnotationRenderer {
    /// Draw an annotation into a CGContext (for final image rendering)
    static func draw(_ annotation: Annotation, in context: CGContext, canvasSize: CGSize) {
        let nsColor = NSColor(annotation.color)
        context.setStrokeColor(nsColor.cgColor)
        context.setFillColor(nsColor.cgColor)
        context.setLineWidth(annotation.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch annotation.tool {
        case .pen, .marker:
            guard annotation.freehandPoints.count > 1 else { return }
            context.beginPath()
            context.move(to: annotation.freehandPoints[0])
            for point in annotation.freehandPoints.dropFirst() {
                context.addLine(to: point)
            }
            context.strokePath()

        case .line:
            context.beginPath()
            context.move(to: annotation.startPoint)
            context.addLine(to: annotation.endPoint)
            context.strokePath()

        case .arrow:
            drawArrow(from: annotation.startPoint, to: annotation.endPoint,
                      lineWidth: annotation.lineWidth, in: context)

        case .rectangle:
            let rect = annotation.boundingRect
            context.stroke(rect)

        case .text:
            let font = NSFont.systemFont(ofSize: annotation.fontSize)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: nsColor
            ]
            let string = NSAttributedString(string: annotation.text, attributes: attributes)
            let line = CTLineCreateWithAttributedString(string)
            context.textPosition = annotation.startPoint
            CTLineDraw(line, context)
        }
    }

    /// Draw an annotation into a SwiftUI GraphicsContext (for live preview)
    static func draw(_ annotation: Annotation, in context: inout GraphicsContext) {
        switch annotation.tool {
        case .pen, .marker:
            guard annotation.freehandPoints.count > 1 else { return }
            var path = Path()
            path.move(to: annotation.freehandPoints[0])
            for point in annotation.freehandPoints.dropFirst() {
                path.addLine(to: point)
            }
            context.stroke(
                path,
                with: .color(annotation.color),
                style: StrokeStyle(lineWidth: annotation.lineWidth, lineCap: .round, lineJoin: .round)
            )

        case .line:
            var path = Path()
            path.move(to: annotation.startPoint)
            path.addLine(to: annotation.endPoint)
            context.stroke(path, with: .color(annotation.color),
                           style: StrokeStyle(lineWidth: annotation.lineWidth, lineCap: .round))

        case .arrow:
            drawArrowSwiftUI(from: annotation.startPoint, to: annotation.endPoint,
                             color: annotation.color, lineWidth: annotation.lineWidth, in: &context)

        case .rectangle:
            let rect = annotation.boundingRect
            context.stroke(Path(rect), with: .color(annotation.color),
                           style: StrokeStyle(lineWidth: annotation.lineWidth))

        case .text:
            let text = Text(annotation.text)
                .font(.system(size: annotation.fontSize))
                .foregroundColor(annotation.color)
            context.draw(context.resolve(text), at: annotation.startPoint, anchor: .topLeading)
        }
    }

    // MARK: - Arrow Drawing Helpers

    private static func drawArrow(from start: CGPoint, to end: CGPoint,
                                   lineWidth: CGFloat, in context: CGContext) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = max(15, lineWidth * 5)
        let arrowAngle: CGFloat = .pi / 6

        // Shaft
        context.beginPath()
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        // Arrowhead
        let tip1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let tip2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )

        context.beginPath()
        context.move(to: tip1)
        context.addLine(to: end)
        context.addLine(to: tip2)
        context.strokePath()
    }

    private static func drawArrowSwiftUI(from start: CGPoint, to end: CGPoint,
                                          color: Color, lineWidth: CGFloat,
                                          in context: inout GraphicsContext) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = max(15, lineWidth * 5)
        let arrowAngle: CGFloat = .pi / 6

        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        path.move(to: CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        ))
        path.addLine(to: end)
        path.addLine(to: CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        ))

        context.stroke(path, with: .color(color),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
}
