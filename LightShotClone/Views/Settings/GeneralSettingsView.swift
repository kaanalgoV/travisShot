import Defaults
import LaunchAtLogin
import SwiftUI

struct GeneralSettingsView: View {
    @Default(.autoCopyLinkAfterUpload) var autoCopyLink
    @Default(.showNotifications) var showNotifications
    @Default(.keepSelectionPosition) var keepSelection
    @Default(.captureCursor) var captureCursor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                SettingsSection(title: "Behavior", icon: "cursorarrow.click") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Automatically copy link after uploading", isOn: $autoCopyLink)
                        Toggle("Show notifications about copying/saving", isOn: $showNotifications)
                        Toggle("Keep selected area position", isOn: $keepSelection)
                        Toggle("Capture cursor on screenshot", isOn: $captureCursor)
                    }
                }

                SettingsSection(title: "System", icon: "laptopcomputer") {
                    LaunchAtLogin.Toggle("Launch at login")
                }
            }
            .padding(20)
        }
    }
}
