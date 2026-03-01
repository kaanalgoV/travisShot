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
        .frame(minWidth: 480, idealWidth: 520, maxWidth: 700,
               minHeight: 350, idealHeight: 500, maxHeight: 800)
    }
}
