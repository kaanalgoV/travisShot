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

    // MARK: - Select Tool Tests

    func testSelectToolToggle() {
        let vm = AnnotationViewModel()
        vm.selectTool(.select)
        XCTAssertEqual(vm.selectedTool, .select)

        // Toggle off
        vm.selectTool(.select)
        XCTAssertNil(vm.selectedTool)
    }

    func testSelectToolClearsSelectionOnToolSwitch() {
        let vm = AnnotationViewModel()
        // Add an annotation
        vm.selectedTool = .line
        vm.beginStroke(at: CGPoint(x: 0, y: 0))
        vm.endStroke(at: CGPoint(x: 100, y: 0))

        // Select it
        vm.selectTool(.select)
        vm.selectAnnotation(at: 0)
        XCTAssertEqual(vm.selectedAnnotationIndex, 0)

        // Switch to another tool → selection should clear
        vm.selectTool(.pen)
        XCTAssertNil(vm.selectedAnnotationIndex)
    }

    func testHitTestAnnotation() {
        let vm = AnnotationViewModel()
        vm.selectedTool = .line
        vm.beginStroke(at: CGPoint(x: 0, y: 0))
        vm.endStroke(at: CGPoint(x: 100, y: 0))

        // Hit directly on line
        let idx = vm.hitTestAnnotation(at: CGPoint(x: 50, y: 0))
        XCTAssertEqual(idx, 0)

        // Miss
        let miss = vm.hitTestAnnotation(at: CGPoint(x: 50, y: 50))
        XCTAssertNil(miss)
    }

    func testHitTestReturnsTopmostAnnotation() {
        let vm = AnnotationViewModel()
        vm.selectedTool = .line

        // First line: horizontal at y=50
        vm.beginStroke(at: CGPoint(x: 0, y: 50))
        vm.endStroke(at: CGPoint(x: 200, y: 50))

        // Second line: vertical at x=100 crossing the first
        vm.beginStroke(at: CGPoint(x: 100, y: 0))
        vm.endStroke(at: CGPoint(x: 100, y: 200))

        // At intersection, should return the second (topmost) annotation
        let idx = vm.hitTestAnnotation(at: CGPoint(x: 100, y: 50))
        XCTAssertEqual(idx, 1)
    }

    func testMoveSelectedAnnotation() {
        let vm = AnnotationViewModel()
        vm.selectedTool = .line
        vm.beginStroke(at: CGPoint(x: 10, y: 20))
        vm.endStroke(at: CGPoint(x: 110, y: 120))

        vm.selectAnnotation(at: 0)
        vm.moveSelectedAnnotation(by: CGSize(width: 5, height: -10))

        XCTAssertEqual(vm.annotations[0].startPoint.x, 15)
        XCTAssertEqual(vm.annotations[0].startPoint.y, 10)
        XCTAssertEqual(vm.annotations[0].endPoint.x, 115)
        XCTAssertEqual(vm.annotations[0].endPoint.y, 110)
    }

    func testMoveSelectedAnnotationWithNoSelectionDoesNothing() {
        let vm = AnnotationViewModel()
        vm.selectedTool = .line
        vm.beginStroke(at: CGPoint(x: 10, y: 20))
        vm.endStroke(at: CGPoint(x: 110, y: 120))

        // No selection
        vm.moveSelectedAnnotation(by: CGSize(width: 50, height: 50))

        // Should remain unchanged
        XCTAssertEqual(vm.annotations[0].startPoint.x, 10)
        XCTAssertEqual(vm.annotations[0].startPoint.y, 20)
    }

    func testDeleteSelectedAnnotation() {
        let vm = AnnotationViewModel()
        vm.selectedTool = .line
        vm.beginStroke(at: CGPoint(x: 0, y: 0))
        vm.endStroke(at: CGPoint(x: 100, y: 100))
        vm.beginStroke(at: CGPoint(x: 50, y: 50))
        vm.endStroke(at: CGPoint(x: 150, y: 150))
        XCTAssertEqual(vm.annotations.count, 2)

        vm.selectAnnotation(at: 0)
        vm.deleteSelectedAnnotation()

        XCTAssertEqual(vm.annotations.count, 1)
        XCTAssertNil(vm.selectedAnnotationIndex)
    }

    func testDeleteSelectedAnnotationUndoable() {
        let vm = AnnotationViewModel()
        vm.selectedTool = .line
        vm.beginStroke(at: CGPoint(x: 0, y: 0))
        vm.endStroke(at: CGPoint(x: 100, y: 100))

        vm.selectAnnotation(at: 0)
        vm.deleteSelectedAnnotation()
        XCTAssertEqual(vm.annotations.count, 0)

        vm.undo()
        XCTAssertEqual(vm.annotations.count, 1)
    }

    func testUndoClearsSelection() {
        let vm = AnnotationViewModel()
        vm.selectedTool = .line
        vm.beginStroke(at: CGPoint(x: 0, y: 0))
        vm.endStroke(at: CGPoint(x: 100, y: 100))

        vm.selectAnnotation(at: 0)
        XCTAssertEqual(vm.selectedAnnotationIndex, 0)

        vm.undo()
        XCTAssertNil(vm.selectedAnnotationIndex)
    }

    func testSelectAnnotationNil() {
        let vm = AnnotationViewModel()
        vm.selectAnnotation(at: 0)
        // Out of bounds — moveSelectedAnnotation should not crash
        vm.moveSelectedAnnotation(by: CGSize(width: 10, height: 10))
        // No crash = pass
    }
}
