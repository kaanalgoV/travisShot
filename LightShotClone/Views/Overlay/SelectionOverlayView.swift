import SwiftUI

struct SelectionOverlayView: View {
    @ObservedObject var viewModel: CaptureViewModel
    let screenFrame: CGRect
    /// Offset from this screen's local coords to unified (multi-screen) coords
    var unifiedOffset: CGPoint = .zero

    /// Convert unified selection rect to this screen's local coords for rendering
    private var localSelectionRect: CGRect? {
        guard let rect = viewModel.selectionRect else { return nil }
        return CGRect(
            x: rect.origin.x - unifiedOffset.x,
            y: rect.origin.y - unifiedOffset.y,
            width: rect.width,
            height: rect.height
        )
    }

    var body: some View {
        ZStack {
            // Frozen screenshot is rendered by AppKit NSImageView behind this view.

            // Dimming overlay with cutout
            DimmingShape(cutout: localSelectionRect)
                .fill(Color.black.opacity(0.4), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)

            // Selection border and dimension label
            if let rect = localSelectionRect {
                Rectangle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)

                // Resize handles (visual only — interaction is on the annotation canvas)
                ForEach(CaptureViewModel.ResizeHandle.allCases, id: \.self) { handle in
                    let hr = viewModel.handleRect(for: handle, in: rect)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: hr.width, height: hr.height)
                        .position(x: hr.midX, y: hr.midY)
                        .allowsHitTesting(false)
                }

                // Dimension label (above selection, left-aligned)
                Text("\(Int(rect.width)) x \(Int(rect.height))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(3)
                    .position(
                        x: rect.minX + 40,
                        y: max(rect.minY - 14, 14)
                    )
                    .allowsHitTesting(false)
            }
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .local)
                .onChanged { value in
                    // Translate local coords to unified coords
                    let unifiedStart = CGPoint(
                        x: value.startLocation.x + unifiedOffset.x,
                        y: value.startLocation.y + unifiedOffset.y
                    )
                    let unifiedCurrent = CGPoint(
                        x: value.location.x + unifiedOffset.x,
                        y: value.location.y + unifiedOffset.y
                    )
                    if viewModel.dragStart == nil {
                        viewModel.beginDrag(at: unifiedStart)
                    }
                    viewModel.updateDrag(to: unifiedCurrent)
                }
                .onEnded { value in
                    let unifiedEnd = CGPoint(
                        x: value.location.x + unifiedOffset.x,
                        y: value.location.y + unifiedOffset.y
                    )
                    viewModel.endDrag(at: unifiedEnd)
                }
        )
    }
}
