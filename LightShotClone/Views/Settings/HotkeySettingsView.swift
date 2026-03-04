import Defaults
import KeyboardShortcuts
import SwiftUI

struct HotkeySettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Screenshot shortcut prominently at the top
                SettingsSection(title: "Screenshot", icon: "camera.viewfinder") {
                    KeyboardShortcuts.Recorder("Capture Region:", name: .captureRegion)
                        .padding(.vertical, 2)
                }

                SettingsSection(title: "Full Screen Shortcuts", icon: "macwindow") {
                    KeyboardShortcuts.Recorder("Save Full Screen:", name: .captureFullScreen)
                    KeyboardShortcuts.Recorder("Upload Full Screen:", name: .instantUploadFullScreen)
                }

                SettingsSection(title: "Tool Shortcuts (during capture)", icon: "pencil.and.outline") {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                    ], alignment: .leading, spacing: 8) {
                        ShortcutField(label: "Select", key: .shortcutSelect)
                        ShortcutField(label: "Pen", key: .shortcutPen)
                        ShortcutField(label: "Line", key: .shortcutLine)
                        ShortcutField(label: "Arrow", key: .shortcutArrow)
                        ShortcutField(label: "Rectangle", key: .shortcutRectangle)
                        ShortcutField(label: "Text", key: .shortcutText)
                        ShortcutField(label: "Marker", key: .shortcutMarker)
                        ShortcutField(label: "Number", key: .shortcutNumber)
                        ShortcutField(label: "Freeze", key: .shortcutFreeze)
                        ShortcutField(label: "Clear All", key: .shortcutClearAll)
                    }
                }

                SettingsSection(title: "Action Shortcuts (Cmd + key)", icon: "command") {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                    ], alignment: .leading, spacing: 8) {
                        ShortcutField(label: "Copy", key: .shortcutCopy)
                        ShortcutField(label: "Save", key: .shortcutSave)
                        ShortcutField(label: "Upload", key: .shortcutUpload)
                        ShortcutField(label: "Print", key: .shortcutPrint)
                        ShortcutField(label: "Undo", key: .shortcutUndo)
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Reusable Section Header

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.primary)
            content
                .padding(.leading, 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Shortcut Field

struct ShortcutField: View {
    let label: String
    let key: Defaults.Key<String>
    @Default var value: String

    init(label: String, key: Defaults.Key<String>) {
        self.label = label
        self.key = key
        self._value = Default(key)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .frame(width: 70, alignment: .trailing)
            TextField("", text: $value)
                .frame(width: 32)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .onChange(of: value) { _, newValue in
                    if newValue.count > 1 {
                        value = String(newValue.suffix(1)).lowercased()
                    } else {
                        value = newValue.lowercased()
                    }
                }
        }
    }
}
