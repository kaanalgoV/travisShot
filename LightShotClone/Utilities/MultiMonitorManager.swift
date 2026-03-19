import AppKit

extension NSScreen {
    /// The CGDirectDisplayID for this screen
    var displayID: CGDirectDisplayID {
        guard let num = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return 0 }
        return CGDirectDisplayID(num.uint32Value)
    }
}

enum MultiMonitorManager {
    /// Get all connected screens
    static var allScreens: [NSScreen] {
        NSScreen.screens
    }

    /// Find which screen contains a given point in global coordinates
    static func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSPointInRect(point, $0.frame) }
    }

    /// Get the CGDirectDisplayID for a given NSScreen
    static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let screenNumber = screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber else { return nil }
        return CGDirectDisplayID(screenNumber.uint32Value)
    }

    /// Union of all screen frames
    static var totalFrame: NSRect {
        NSScreen.screens.reduce(.null) { $0.union($1.frame) }
    }
}
