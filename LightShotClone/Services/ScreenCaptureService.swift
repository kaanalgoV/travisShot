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
        // Match SCDisplay to NSScreen by displayID to get correct backing scale.
        // Width-based matching fails for rotated/portrait displays.
        let matchingScreen = NSScreen.screens.first { $0.displayID == display.displayID }
        if let screen = matchingScreen {
            let scale = screen.backingScaleFactor
            config.width = Int(screen.frame.width * scale)
            config.height = Int(screen.frame.height * scale)
        } else {
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

    /// Capture all connected displays, returning a mapping of display ID to CGImage
    static func captureAllDisplays(showCursor: Bool = false) async throws -> [CGDirectDisplayID: CGImage] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard !content.displays.isEmpty else { throw ScreenCaptureError.noDisplayFound }

        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let excludedApps = content.applications.filter { $0.bundleIdentifier == bundleID }

        var captures: [CGDirectDisplayID: CGImage] = [:]
        for display in content.displays {
            let filter = SCContentFilter(
                display: display,
                excludingApplications: excludedApps,
                exceptingWindows: []
            )
            let config = SCStreamConfiguration()
            let matchingScreen = NSScreen.screens.first { $0.displayID == display.displayID }
            if let screen = matchingScreen {
                let scale = screen.backingScaleFactor
                config.width = Int(screen.frame.width * scale)
                config.height = Int(screen.frame.height * scale)
            } else {
                config.width = display.width
                config.height = display.height
            }
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = showCursor

            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            captures[display.displayID] = image
        }
        return captures
    }

    /// Get all available displays as SCDisplay objects
    static func availableDisplays() async throws -> [SCDisplay] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return content.displays
    }

    /// Find the SCDisplay for the screen containing the given point (e.g. mouse location)
    static func displayForPoint(_ point: CGPoint) async throws -> SCDisplay {
        let displays = try await availableDisplays()
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main ?? NSScreen.screens[0]
        let displayID = screen.displayID
        return displays.first { $0.displayID == displayID } ?? displays[0]
    }

    /// Crop a CGImage to a given rect
    static func crop(_ image: CGImage, to rect: CGRect) -> CGImage? {
        image.cropping(to: rect)
    }
}
