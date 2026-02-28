import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            HotkeySettingsView()
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }

            FormatSettingsView()
                .tabItem {
                    Label("Formats", systemImage: "doc")
                }
        }
        .frame(width: 450, height: 300)
    }
}
