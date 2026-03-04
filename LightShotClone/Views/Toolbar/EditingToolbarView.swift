import Defaults
import SwiftUI

struct EditingToolbarView: View {
    @ObservedObject var annotationVM: AnnotationViewModel
    var isFrozen: Bool
    var onToggleFreeze: () -> Void
    var onClose: () -> Void
    @State private var showColorPicker = false

    var body: some View {
        VStack(spacing: 2) {
            // Drawing tools
            ForEach(AnnotationTool.allCases) { tool in
                ToolButton(
                    systemImage: tool.systemImage,
                    isSelected: annotationVM.selectedTool == tool,
                    tooltip: "\(tool.displayName) (\(shortcutForTool(tool).uppercased()))"
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
                .frame(width: 28)
                .padding(.vertical, 2)

            // Freeze / Unfreeze toggle
            ToolButton(
                systemImage: "snowflake",
                isSelected: isFrozen,
                tooltip: isFrozen ? "Unfreeze (\(Defaults[.shortcutFreeze].uppercased()))" : "Freeze (\(Defaults[.shortcutFreeze].uppercased()))"
            ) {
                onToggleFreeze()
            }

            // Undo
            ToolButton(
                systemImage: "arrow.uturn.backward",
                isSelected: false,
                tooltip: "Undo (Cmd+\(Defaults[.shortcutUndo].uppercased()))"
            ) {
                annotationVM.undo()
            }

            // Clear All
            ToolButton(
                systemImage: "trash",
                isSelected: false,
                tooltip: "Clear All (\(Defaults[.shortcutClearAll].uppercased()))"
            ) {
                annotationVM.clearAll()
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
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
        )
    }

    private func shortcutForTool(_ tool: AnnotationTool) -> String {
        switch tool {
        case .select: return Defaults[.shortcutSelect]
        case .pen: return Defaults[.shortcutPen]
        case .line: return Defaults[.shortcutLine]
        case .arrow: return Defaults[.shortcutArrow]
        case .rectangle: return Defaults[.shortcutRectangle]
        case .text: return Defaults[.shortcutText]
        case .marker: return Defaults[.shortcutMarker]
        case .number: return Defaults[.shortcutNumber]
        case .blur: return Defaults[.shortcutBlur]
        }
    }
}

struct ToolButton: View {
    let systemImage: String
    let isSelected: Bool
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
                        .fill(isSelected ? Color.accentColor.opacity(0.25) :
                              isHovered ? Color.primary.opacity(0.1) : Color.clear)
                )
                .foregroundColor(isSelected ? .accentColor : .primary)
                .scaleEffect(isHovered && !isSelected ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
                .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .customTooltip(tooltip, edge: .minX)
    }
}

struct ColorButton: View {
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                )
                .frame(width: 34, height: 34)
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .customTooltip("Color", edge: .minX)
    }
}
