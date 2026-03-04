import AppKit
import SwiftUI

enum AnnotationRenderer {
    /// Draw an annotation into a CGContext (for final image rendering).
    /// `canvasOffset` translates annotations from full-screen coords to crop-relative coords.
    /// `sourceImage`, `selectionRect`, and `imageScale` are needed for blur annotations.
    static func draw(_ annotation: Annotation, in context: CGContext, canvasSize: CGSize, canvasOffset: CGPoint = .zero, sourceImage: CGImage? = nil, selectionRect: CGRect? = nil, imageScale: CGFloat = 1.0) {
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
            context.saveGState()
            context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
            context.textPosition = CGPoint(x: annotation.startPoint.x, y: annotation.startPoint.y + annotation.fontSize)
            CTLineDraw(line, context)
            context.restoreGState()

        case .number:
            let diameter = max(28, annotation.fontSize * 1.6)
            let radius = diameter / 2
            let circleRect = CGRect(
                x: annotation.startPoint.x - radius,
                y: annotation.startPoint.y - radius,
                width: diameter,
                height: diameter
            )
            context.fillEllipse(in: circleRect)

            context.saveGState()
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(2)
            context.strokeEllipse(in: circleRect)
            context.restoreGState()

            // Draw number text centered using NSGraphicsContext for correct flipped rendering
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
            let nsCtx = NSGraphicsContext(cgContext: context, flipped: true)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsCtx
            numStr.draw(at: textPoint, withAttributes: numAttrs)
            NSGraphicsContext.restoreGraphicsState()

        case .blur:
            drawBlur(annotation, in: context, sourceImage: sourceImage, selectionRect: selectionRect, imageScale: imageScale)
        }
    }

    // MARK: - Blur Drawing

    private static func drawBlur(_ annotation: Annotation, in context: CGContext, sourceImage: CGImage?, selectionRect: CGRect?, imageScale: CGFloat) {
        let rect = annotation.boundingRect
        guard rect.width > 1, rect.height > 1,
              let source = sourceImage,
              let selection = selectionRect else { return }

        let pixelRect = CGRect(
            x: (rect.minX - selection.minX) * imageScale,
            y: (rect.minY - selection.minY) * imageScale,
            width: rect.width * imageScale,
            height: rect.height * imageScale
        )

        let imageBounds = CGRect(x: 0, y: 0, width: CGFloat(source.width), height: CGFloat(source.height))
        let clampedRect = pixelRect.intersection(imageBounds)
        guard !clampedRect.isEmpty, let cropped = source.cropping(to: clampedRect) else { return }

        let ciImage = CIImage(cgImage: cropped)
        let pixelScale = max(8, min(rect.width, rect.height) * imageScale / 8)
        guard let filter = CIFilter(name: "CIPixellate") else { return }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(pixelScale as NSNumber, forKey: kCIInputScaleKey)

        let ciContext = CIContext()
        guard let output = filter.outputImage,
              let pixelated = ciContext.createCGImage(output, from: ciImage.extent) else { return }

        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(pixelated, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        context.restoreGState()
    }

    // MARK: - Arrow Drawing Helpers

    private static func drawArrow(from start: CGPoint, to end: CGPoint,
                                   lineWidth: CGFloat, in context: CGContext) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        // Narrower arrowhead: shorter and tighter angle
        let arrowLength: CGFloat = max(12, lineWidth * 3.5)
        let arrowAngle: CGFloat = .pi / 9 // 20° instead of 30°

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
