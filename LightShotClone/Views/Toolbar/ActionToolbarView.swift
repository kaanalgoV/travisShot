import SwiftUI

struct ActionToolbarView: View {
    var onUpload: () -> Void
    var onSearchSimilar: () -> Void
    var onPrint: () -> Void
    var onCopy: () -> Void
    var onSave: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            ActionButton(systemImage: "icloud.and.arrow.up", tooltip: "Upload (Cmd+D)", action: onUpload)
            ActionButton(systemImage: "magnifyingglass", tooltip: "Search Similar Images", action: onSearchSimilar)
            ActionButton(systemImage: "printer", tooltip: "Print (Cmd+P)", action: onPrint)
            ActionButton(systemImage: "doc.on.clipboard", tooltip: "Copy (Cmd+C)", action: onCopy)
            ActionButton(systemImage: "square.and.arrow.down", tooltip: "Save (Cmd+S)", action: onSave)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        )
    }
}

struct ActionButton: View {
    let systemImage: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}
