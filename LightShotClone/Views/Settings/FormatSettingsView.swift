import Defaults
import SwiftUI

struct FormatSettingsView: View {
    @Default(.uploadFormat) var uploadFormat
    @Default(.jpegQuality) var jpegQuality
    @Default(.imgurClientID) var imgurClientID
    @Default(.quickSaveDirectory) var quickSaveDirectory

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                SettingsSection(title: "Save Format", icon: "photo") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Format:", selection: $uploadFormat) {
                            Text("PNG").tag("png")
                            Text("JPEG").tag("jpeg")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)

                        if uploadFormat == "jpeg" {
                            HStack {
                                Text("Quality:")
                                Slider(value: $jpegQuality, in: 0.5...1.0, step: 0.1)
                                Text("\(Int(jpegQuality * 100))%")
                                    .monospacedDigit()
                                    .frame(width: 40)
                            }
                        }
                    }
                }

                SettingsSection(title: "Save Location", icon: "folder") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Quick save folder:")
                            Text(quickSaveDirectory.isEmpty ? "Desktop (default)" : abbreviatePath(quickSaveDirectory))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("Choose...") {
                                chooseSaveDirectory()
                            }
                            if !quickSaveDirectory.isEmpty {
                                Button("Reset") {
                                    quickSaveDirectory = ""
                                }
                            }
                        }
                        Text("Screenshots saved with Cmd+S will use this folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                SettingsSection(title: "Upload", icon: "icloud.and.arrow.up") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Imgur Client-ID:")
                            TextField("Enter your Imgur Client-ID", text: $imgurClientID)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 240)
                        }
                        Text("Get a free Client-ID at api.imgur.com/oauth2/addclient")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
        }
    }

    private func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"

        if !quickSaveDirectory.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: quickSaveDirectory)
        }

        if panel.runModal() == .OK, let url = panel.url {
            quickSaveDirectory = url.path
        }
    }

    private func abbreviatePath(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}
