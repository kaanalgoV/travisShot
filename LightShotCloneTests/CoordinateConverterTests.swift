import XCTest
@testable import LightShotClone

final class CoordinateConverterTests: XCTestCase {
    func testFlipYCoordinate() {
        let result = CoordinateConverter.flipY(
            rect: CGRect(x: 50, y: 100, width: 300, height: 200),
            inScreenHeight: 1080
        )
        XCTAssertEqual(result.origin.x, 50)
        XCTAssertEqual(result.origin.y, 780)
        XCTAssertEqual(result.width, 300)
        XCTAssertEqual(result.height, 200)
    }

    func testNormalizeRect() {
        let rect = CGRect(x: 300, y: 400, width: -200, height: -150)
        let normalized = CoordinateConverter.normalize(rect)
        XCTAssertEqual(normalized.origin.x, 100)
        XCTAssertEqual(normalized.origin.y, 250)
        XCTAssertEqual(normalized.width, 200)
        XCTAssertEqual(normalized.height, 150)
    }

    func testScaleForRetina() {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 50)
        let scaled = CoordinateConverter.scale(rect, by: 2.0)
        XCTAssertEqual(scaled.origin.x, 20)
        XCTAssertEqual(scaled.origin.y, 40)
        XCTAssertEqual(scaled.width, 200)
        XCTAssertEqual(scaled.height, 100)
    }
}
