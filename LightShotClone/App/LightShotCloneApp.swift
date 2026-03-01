import SwiftUI
import KeyboardShortcuts

@main
struct TravisShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("TravisShot", systemImage: "camera.viewfinder") {
            Button("Capture Region") {
                appDelegate.startRegionCapture()
            }

            Divider()

            Button("Preferences...") {
                appDelegate.openPreferences()
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit TravisShot") {
                appDelegate.userRequestedQuit = true
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        // Settings window is managed manually by AppDelegate.openPreferences()
        // to avoid SwiftUI Settings scene not connecting properly in SPM builds.
    }
}
