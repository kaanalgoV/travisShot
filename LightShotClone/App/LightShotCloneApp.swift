import SwiftUI
import KeyboardShortcuts

@main
struct LightShotCloneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("LightShot", systemImage: "camera.viewfinder") {
            Button("Capture Region") {
                appDelegate.startRegionCapture()
            }

            Divider()

            Button("Preferences...") {
                if #available(macOS 14, *) {
                    NSApp.activate()
                }
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit LightShot") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Settings {
            Text("Settings coming in Task 11")
                .frame(width: 400, height: 200)
        }
    }
}
