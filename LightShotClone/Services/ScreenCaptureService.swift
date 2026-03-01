import AppKit
import ScreenCaptureKit

enum ScreenCaptureError: Error {
    case noDisplayFound
    case captureFailedWithError(Error)
    case noPermission
}

final class ScreenCaptureService {
    /// Capture the entire screen as a CGImage (excluding our own app windows)
    static func captureFullScreen(display: SCDisplay, showCursor: Bool = false) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // Exclude our own app from the capture
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let excludedApps = content.applications.filter { $0.bundleIdentifier == bundleID }

        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApps,
            exceptingWindows: []
        )

        let config = SCStreamConfiguration()
        config.width = display.width * 2  // Retina
        config.height = display.height * 2 // Retina
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = showCursor

        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
    }

    /// Get all available displays as SCDisplay objects
    static func availableDisplays() async throws -> [SCDisplay] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return content.displays
    }

    /// Crop a CGImage to a given rect
    static func crop(_ image: CGImage, to rect: CGRect) -> CGImage? {
        image.cropping(to: rect)
    }
}
