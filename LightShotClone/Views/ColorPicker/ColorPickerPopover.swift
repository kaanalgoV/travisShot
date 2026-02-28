import SwiftUI

struct ColorPickerPopover: View {
    @Binding var selectedColor: Color

    private let presetColors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple,
        .pink, .brown, .cyan, .mint, .indigo, .teal,
        .white, .gray, .black
    ]

    var body: some View {
        VStack(spacing: 12) {
            Text("Color")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Preset color grid
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 6), count: 6), spacing: 6) {
                ForEach(Array(presetColors.enumerated()), id: \.offset) { _, color in
                    ColorSwatch(color: color, isSelected: false) {
                        selectedColor = color
                    }
                }
            }

            Divider()

            // System color picker for custom colors
            ColorPicker("Custom Color", selection: $selectedColor, supportsOpacity: false)
        }
        .padding(12)
        .frame(width: 180)
    }
}

struct ColorSwatch: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}
