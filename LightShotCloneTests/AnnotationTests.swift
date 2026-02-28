import XCTest
@testable import LightShotClone

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
}
