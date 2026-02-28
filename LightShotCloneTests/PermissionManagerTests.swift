import XCTest
@testable import LightShotClone

final class PermissionManagerTests: XCTestCase {
    func testScreenRecordingPermissionCheckDoesNotCrash() {
        let _ = PermissionManager.hasScreenRecordingPermission
    }

    func testAccessibilityPermissionCheckDoesNotCrash() {
        let _ = PermissionManager.hasAccessibilityPermission
    }

    func testSystemSettingsURLsAreValid() {
        XCTAssertNotNil(PermissionManager.screenRecordingSettingsURL)
        XCTAssertNotNil(PermissionManager.accessibilitySettingsURL)
    }
}
