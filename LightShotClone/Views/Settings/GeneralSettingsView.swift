import SwiftUI
import Defaults
import LaunchAtLogin

struct GeneralSettingsView: View {
    @Default(.autoCopyLinkAfterUpload) var autoCopyLink
    @Default(.showNotifications) var showNotifications
    @Default(.keepSelectionPosition) var keepSelection
    @Default(.captureCursor) var captureCursor

    var body: some View {
        Form {
            Toggle("Automatically copy link after uploading", isOn: $autoCopyLink)
            Toggle("Show notifications about copying/saving", isOn: $showNotifications)
            Toggle("Keep selected area position", isOn: $keepSelection)
            Toggle("Capture cursor on screenshot", isOn: $captureCursor)

            Divider()

            LaunchAtLogin.Toggle("Launch at login")
        }
        .padding(20)
    }
}
