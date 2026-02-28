import AppKit
import CoreGraphics

enum PermissionManager {
    // MARK: - Screen Recording

    static var hasScreenRecordingPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    static func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    // MARK: - Accessibility

    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - System Settings URLs

    static let screenRecordingSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )

    static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )

    static func openScreenRecordingSettings() {
        if let url = screenRecordingSettingsURL {
            NSWorkspace.shared.open(url)
        }
    }

    static func openAccessibilitySettings() {
        if let url = accessibilitySettingsURL {
            NSWorkspace.shared.open(url)
        }
    }
}
