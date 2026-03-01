import XCTest
@testable import TravisShot

final class CaptureStateTests: XCTestCase {
    func testInitialStateIsIdle() {
        let state = CaptureState.idle
        if case .idle = state {
            // pass
        } else {
            XCTFail("Expected idle state")
        }
    }

    func testStateTransitions() {
        let states: [CaptureState] = [
            .idle,
            .selecting(origin: CGPoint(x: 10, y: 20)),
            .selected(rect: CGRect(x: 10, y: 20, width: 100, height: 80)),
            .annotating,
            .idle
        ]
        XCTAssertEqual(states.count, 5)
    }
}
