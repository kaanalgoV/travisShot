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
        // Determine correct pixel dimensions for capture.
        // SCDisplay.width/height may be in points or pixels depending on macOS version.
        // Match against NSScreen to detect which and compute native pixel resolution.
        let matchingScreen = NSScreen.screens.first { abs(Int($0.frame.width) - display.width) < 2 }
        if let screen = matchingScreen {
            // display.width matches screen point width → multiply by scale
            let scale = screen.backingScaleFactor
            config.width = Int(screen.frame.width * scale)
            config.height = Int(screen.frame.height * scale)
        } else {
            // display.width is already in native pixels → use as-is
            config.width = display.width
            config.height = display.height
        }
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
