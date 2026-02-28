import SwiftUI
import Defaults

struct FormatSettingsView: View {
    @Default(.uploadFormat) var uploadFormat
    @Default(.jpegQuality) var jpegQuality

    var body: some View {
        Form {
            Picker("Upload format:", selection: $uploadFormat) {
                Text("PNG").tag("png")
                Text("JPEG").tag("jpeg")
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            if uploadFormat == "jpeg" {
                HStack {
                    Text("JPEG Quality:")
                    Slider(value: $jpegQuality, in: 0.5...1.0, step: 0.1)
                    Text("\(Int(jpegQuality * 100))%")
                        .monospacedDigit()
                        .frame(width: 40)
                }
            }
        }
        .padding(20)
    }
}
