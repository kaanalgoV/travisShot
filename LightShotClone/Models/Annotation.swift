import SwiftUI

struct Annotation: Identifiable {
    let id = UUID()
    var tool: AnnotationTool
    var startPoint: CGPoint
    var endPoint: CGPoint
    var color: Color
    var lineWidth: CGFloat
    var text: String = ""
    var fontSize: CGFloat = 16
    var freehandPoints: [CGPoint] = []
    var numberValue: Int = 0

    /// The normalized bounding rect of this annotation
    var boundingRect: CGRect {
        CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )
    }

    /// Hit test: returns true if the given point is close enough to this annotation
    func hitTest(point: CGPoint, threshold: CGFloat = 8) -> Bool {
        switch tool {
        case .select:
            return false

        case .pen, .marker:
            for p in freehandPoints {
                if hypot(p.x - point.x, p.y - point.y) < threshold + lineWidth / 2 {
                    return true
                }
            }
            return false

        case .line:
            return distanceToLineSegment(point: point, from: startPoint, to: endPoint) < threshold + lineWidth / 2

        case .arrow:
            return distanceToLineSegment(point: point, from: startPoint, to: endPoint) < threshold + lineWidth / 2

        case .rectangle:
            let rect = boundingRect.insetBy(dx: -(threshold + lineWidth / 2), dy: -(threshold + lineWidth / 2))
            let inner = boundingRect.insetBy(dx: threshold + lineWidth / 2, dy: threshold + lineWidth / 2)
            return rect.contains(point) && !inner.contains(point)

        case .text:
            let font = NSFont.systemFont(ofSize: fontSize)
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let textSize = (text as NSString).size(withAttributes: attrs)
            let textRect = CGRect(origin: startPoint, size: textSize)
            return textRect.insetBy(dx: -threshold, dy: -threshold).contains(point)

        case .number:
            let diameter = max(28, fontSize * 1.6)
            let radius = diameter / 2
            return hypot(point.x - startPoint.x, point.y - startPoint.y) < radius + threshold

        case .blur:
            return boundingRect.insetBy(dx: -threshold, dy: -threshold).contains(point)
        }
    }

    /// Translate all points by a delta
    mutating func translate(by delta: CGSize) {
        startPoint.x += delta.width
        startPoint.y += delta.height
        endPoint.x += delta.width
        endPoint.y += delta.height
        freehandPoints = freehandPoints.map { CGPoint(x: $0.x + delta.width, y: $0.y + delta.height) }
    }

    /// Selection bounding rect (for drawing selection handles)
    func selectionRect() -> CGRect {
        switch tool {
        case .pen, .marker:
            guard !freehandPoints.isEmpty else { return .zero }
            let xs = freehandPoints.map(\.x)
            let ys = freehandPoints.map(\.y)
            return CGRect(
                x: xs.min()! - lineWidth / 2,
                y: ys.min()! - lineWidth / 2,
                width: (xs.max()! - xs.min()!) + lineWidth,
                height: (ys.max()! - ys.min()!) + lineWidth
            )
        case .text:
            let font = NSFont.systemFont(ofSize: fontSize)
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let textSize = (text as NSString).size(withAttributes: attrs)
            return CGRect(origin: startPoint, size: textSize)
        case .line, .arrow:
            let minX = min(startPoint.x, endPoint.x) - lineWidth / 2
            let minY = min(startPoint.y, endPoint.y) - lineWidth / 2
            let maxX = max(startPoint.x, endPoint.x) + lineWidth / 2
            let maxY = max(startPoint.y, endPoint.y) + lineWidth / 2
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        case .rectangle:
            return boundingRect
        case .number:
            let diameter = max(28, fontSize * 1.6)
            return CGRect(
                x: startPoint.x - diameter / 2,
                y: startPoint.y - diameter / 2,
                width: diameter,
                height: diameter
            )
        case .blur:
            return boundingRect
        case .select:
            return .zero
        }
    }

    // MARK: - Geometry Helpers

    private func distanceToLineSegment(point: CGPoint, from a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSq = dx * dx + dy * dy

        if lengthSq == 0 {
            return hypot(point.x - a.x, point.y - a.y)
        }

        var t = ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSq
        t = max(0, min(1, t))

        let projX = a.x + t * dx
        let projY = a.y + t * dy
        return hypot(point.x - projX, point.y - projY)
    }
}
