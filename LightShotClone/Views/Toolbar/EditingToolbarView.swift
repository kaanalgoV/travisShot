import SwiftUI

struct EditingToolbarView: View {
    @ObservedObject var annotationVM: AnnotationViewModel
    var onClose: () -> Void
    @State private var showColorPicker = false

    var body: some View {
        VStack(spacing: 4) {
            // Drawing tools
            ForEach(AnnotationTool.allCases) { tool in
                ToolButton(
                    systemImage: tool.systemImage,
                    isSelected: annotationVM.selectedTool == tool,
                    tooltip: tool.displayName
                ) {
                    annotationVM.selectTool(tool)
                }
            }

            // Color picker
            ColorButton(color: annotationVM.currentColor) {
                showColorPicker.toggle()
            }
            .popover(isPresented: $showColorPicker) {
                ColorPickerPopover(selectedColor: $annotationVM.currentColor)
            }

            Divider()
                .frame(width: 24)
                .padding(.vertical, 2)

            // Undo
            ToolButton(
                systemImage: "arrow.uturn.backward",
                isSelected: false,
                tooltip: "Undo (Cmd+Z)"
            ) {
                annotationVM.undo()
            }

            // Close
            ToolButton(
                systemImage: "xmark",
                isSelected: false,
                tooltip: "Close (Esc)"
            ) {
                onClose()
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        )
    }
}

struct ToolButton: View {
    let systemImage: String
    let isSelected: Bool
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(4)
                .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

struct ColorButton: View {
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 20, height: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                )
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help("Color")
    }
}
