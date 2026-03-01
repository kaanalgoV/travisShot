import Defaults
import SwiftUI

struct ActionToolbarView: View {
    var onUpload: () -> Void
    var onSearchSimilar: () -> Void
    var onPrint: () -> Void
    var onCopy: () -> Void
    var onSave: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            ActionButton(systemImage: "icloud.and.arrow.up", tooltip: "Upload (Cmd+\(Defaults[.shortcutUpload].uppercased()))", action: onUpload)
            ActionButton(systemImage: "magnifyingglass", tooltip: "Search Similar", action: onSearchSimilar)
            ActionButton(systemImage: "printer", tooltip: "Print (Cmd+\(Defaults[.shortcutPrint].uppercased()))", action: onPrint)
            ActionButton(systemImage: "doc.on.clipboard", tooltip: "Copy (Cmd+\(Defaults[.shortcutCopy].uppercased()))", action: onCopy)
            ActionButton(systemImage: "square.and.arrow.down", tooltip: "Save (Cmd+\(Defaults[.shortcutSave].uppercased()))", action: onSave)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
        )
    }
}

struct ActionButton: View {
    let systemImage: String
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
                )
                .foregroundColor(.primary)
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .customTooltip(tooltip, edge: .maxY)
    }
}
