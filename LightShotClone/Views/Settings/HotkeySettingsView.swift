import SwiftUI
import KeyboardShortcuts

struct HotkeySettingsView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Capture Region:", name: .captureRegion)
            KeyboardShortcuts.Recorder("Instant Save Full Screen:", name: .captureFullScreen)
            KeyboardShortcuts.Recorder("Instant Upload Full Screen:", name: .instantUploadFullScreen)
        }
        .padding(20)
    }
}
