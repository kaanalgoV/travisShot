import XCTest
@testable import TravisShot

final class AnnotationViewModelTests: XCTestCase {
    func testUndoStackCappedAt50() {
        let vm = AnnotationViewModel()
        vm.selectedTool = .pen
        for i in 0..<60 {
            vm.beginStroke(at: CGPoint(x: CGFloat(i), y: 0))
            vm.endStroke(at: CGPoint(x: CGFloat(i) + 10, y: 10))
        }
        XCTAssertEqual(vm.annotations.count, 60)
        XCTAssertLessThanOrEqual(vm.undoStack.count, 50)
    }

    func testUndoRestoresPreviousState() {
        let vm = AnnotationViewModel()
        vm.selectedTool = .pen
        vm.beginStroke(at: CGPoint(x: 0, y: 0))
        vm.endStroke(at: CGPoint(x: 10, y: 10))
        XCTAssertEqual(vm.annotations.count, 1)
        vm.undo()
        XCTAssertEqual(vm.annotations.count, 0)
    }
}
