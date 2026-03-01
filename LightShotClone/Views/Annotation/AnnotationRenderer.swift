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
        case .select:
            break

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
            // Counter-flip text so it renders right-side-up in our flipped context
            context.saveGState()
            context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
            context.textPosition = CGPoint(x: annotation.startPoint.x, y: annotation.startPoint.y + annotation.fontSize)
            CTLineDraw(line, context)
            context.restoreGState()
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

}
