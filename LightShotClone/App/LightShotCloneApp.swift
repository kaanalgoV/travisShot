import SwiftUI

@main
struct LightShotCloneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("LightShot", systemImage: "camera.viewfinder") {
            Button("Capture Region") {
                appDelegate.startRegionCapture()
            }
            .keyboardShortcut("9", modifiers: [.command, .shift])

            Divider()

            Button("Quit LightShot") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Settings {
            Text("Settings placeholder")
        }
    }
}
