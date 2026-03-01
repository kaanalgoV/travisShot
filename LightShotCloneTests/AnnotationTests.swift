import XCTest
@testable import TravisShot

final class AnnotationTests: XCTestCase {
    func testAnnotationCreation() {
        let annotation = Annotation(
            tool: .arrow,
            startPoint: CGPoint(x: 10, y: 20),
            endPoint: CGPoint(x: 100, y: 200),
            color: .red,
            lineWidth: 2
        )
        XCTAssertEqual(annotation.tool, .arrow)
        XCTAssertEqual(annotation.startPoint, CGPoint(x: 10, y: 20))
        XCTAssertEqual(annotation.endPoint, CGPoint(x: 100, y: 200))
    }

    func testAnnotationBoundingRect() {
        let annotation = Annotation(
            tool: .rectangle,
            startPoint: CGPoint(x: 100, y: 50),
            endPoint: CGPoint(x: 50, y: 150),
            color: .red,
            lineWidth: 2
        )
        let bounds = annotation.boundingRect
        XCTAssertEqual(bounds.origin.x, 50)
        XCTAssertEqual(bounds.origin.y, 50)
        XCTAssertEqual(bounds.width, 50)
        XCTAssertEqual(bounds.height, 100)
    }

    func testFreehandAnnotation() {
        var annotation = Annotation(
            tool: .pen,
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: 0),
            color: .red,
            lineWidth: 2
        )
        annotation.freehandPoints = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 10),
            CGPoint(x: 20, y: 5)
        ]
        XCTAssertEqual(annotation.freehandPoints.count, 3)
    }

    // MARK: - Hit Test

    func testHitTestLine() {
        let annotation = Annotation(
            tool: .line,
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 100, y: 0),
            color: .red,
            lineWidth: 2
        )
        // Point on the line
        XCTAssertTrue(annotation.hitTest(point: CGPoint(x: 50, y: 0)))
        // Point near the line (within threshold)
        XCTAssertTrue(annotation.hitTest(point: CGPoint(x: 50, y: 5)))
        // Point far from the line
        XCTAssertFalse(annotation.hitTest(point: CGPoint(x: 50, y: 30)))
    }

    func testHitTestArrow() {
        let annotation = Annotation(
            tool: .arrow,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 110, y: 10),
            color: .blue,
            lineWidth: 2
        )
        XCTAssertTrue(annotation.hitTest(point: CGPoint(x: 60, y: 10)))
        XCTAssertFalse(annotation.hitTest(point: CGPoint(x: 60, y: 50)))
    }

    func testHitTestRectangle() {
        let annotation = Annotation(
            tool: .rectangle,
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 110, y: 110),
            color: .green,
            lineWidth: 2
        )
        // Point on the edge
        XCTAssertTrue(annotation.hitTest(point: CGPoint(x: 10, y: 50)))
        // Point inside (not on edge)
        XCTAssertFalse(annotation.hitTest(point: CGPoint(x: 60, y: 60)))
        // Point outside
        XCTAssertFalse(annotation.hitTest(point: CGPoint(x: 200, y: 200)))
    }

    func testHitTestText() {
        let annotation = Annotation(
            tool: .text,
            startPoint: CGPoint(x: 50, y: 50),
            endPoint: CGPoint(x: 50, y: 50),
            color: .red,
            lineWidth: 1,
            text: "Hello World",
            fontSize: 16
        )
        // Point inside text area
        XCTAssertTrue(annotation.hitTest(point: CGPoint(x: 80, y: 58)))
        // Point far away
        XCTAssertFalse(annotation.hitTest(point: CGPoint(x: 300, y: 300)))
    }

    func testHitTestPen() {
        var annotation = Annotation(
            tool: .pen,
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 50, y: 50),
            color: .red,
            lineWidth: 4
        )
        annotation.freehandPoints = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 25, y: 25),
            CGPoint(x: 50, y: 50)
        ]
        // Point near a freehand point
        XCTAssertTrue(annotation.hitTest(point: CGPoint(x: 26, y: 26)))
        // Point far from any freehand point
        XCTAssertFalse(annotation.hitTest(point: CGPoint(x: 100, y: 100)))
    }

    func testHitTestSelectToolReturnsFalse() {
        let annotation = Annotation(
            tool: .select,
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 100, y: 100),
            color: .red,
            lineWidth: 2
        )
        XCTAssertFalse(annotation.hitTest(point: CGPoint(x: 50, y: 50)))
    }

    // MARK: - Translate

    func testTranslateLine() {
        var annotation = Annotation(
            tool: .line,
            startPoint: CGPoint(x: 10, y: 20),
            endPoint: CGPoint(x: 100, y: 200),
            color: .red,
            lineWidth: 2
        )
        annotation.translate(by: CGSize(width: 5, height: -10))
        XCTAssertEqual(annotation.startPoint.x, 15)
        XCTAssertEqual(annotation.startPoint.y, 10)
        XCTAssertEqual(annotation.endPoint.x, 105)
        XCTAssertEqual(annotation.endPoint.y, 190)
    }

    func testTranslateFreehand() {
        var annotation = Annotation(
            tool: .pen,
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 50, y: 50),
            color: .red,
            lineWidth: 2,
            freehandPoints: [CGPoint(x: 0, y: 0), CGPoint(x: 25, y: 25), CGPoint(x: 50, y: 50)]
        )
        annotation.translate(by: CGSize(width: 10, height: 20))
        XCTAssertEqual(annotation.freehandPoints[0], CGPoint(x: 10, y: 20))
        XCTAssertEqual(annotation.freehandPoints[1], CGPoint(x: 35, y: 45))
        XCTAssertEqual(annotation.freehandPoints[2], CGPoint(x: 60, y: 70))
    }

    // MARK: - Selection Rect

    func testSelectionRectLine() {
        let annotation = Annotation(
            tool: .line,
            startPoint: CGPoint(x: 10, y: 20),
            endPoint: CGPoint(x: 100, y: 200),
            color: .red,
            lineWidth: 4
        )
        let rect = annotation.selectionRect()
        XCTAssertEqual(rect.minX, 8)   // 10 - 4/2
        XCTAssertEqual(rect.minY, 18)  // 20 - 4/2
        XCTAssertEqual(rect.maxX, 102) // 100 + 4/2
        XCTAssertEqual(rect.maxY, 202) // 200 + 4/2
    }

    func testSelectionRectPen() {
        let annotation = Annotation(
            tool: .pen,
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 50, y: 50),
            color: .red,
            lineWidth: 2,
            freehandPoints: [CGPoint(x: 10, y: 20), CGPoint(x: 30, y: 40), CGPoint(x: 50, y: 10)]
        )
        let rect = annotation.selectionRect()
        XCTAssertEqual(rect.minX, 9)   // 10 - 2/2
        XCTAssertEqual(rect.minY, 9)   // 10 - 2/2
        XCTAssertEqual(rect.maxX, 51)  // 50 + 2/2
        XCTAssertEqual(rect.maxY, 41)  // 40 + 2/2
    }
}
