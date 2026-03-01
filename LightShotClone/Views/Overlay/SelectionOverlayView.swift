import SwiftUI

struct SelectionOverlayView: View {
    @ObservedObject var viewModel: CaptureViewModel
    let screenFrame: CGRect

    var body: some View {
        ZStack {
            // Frozen screenshot is rendered by AppKit NSImageView behind this view.

            // Dimming overlay with cutout
            DimmingShape(cutout: viewModel.selectionRect)
                .fill(Color.black.opacity(0.4), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)

            // Selection border and resize handles
            if let rect = viewModel.selectionRect {
                // Selection border
                Rectangle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)

                // Resize handles (8 handles)
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

            // Unfreeze is now handled by the editing toolbar button
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .local)
                .onChanged { value in
                    if viewModel.dragStart == nil {
                        viewModel.beginDrag(at: value.startLocation)
                    }
                    viewModel.updateDrag(to: value.location)
                }
                .onEnded { value in
                    viewModel.endDrag(at: value.location)
                }
        )
    }
}
