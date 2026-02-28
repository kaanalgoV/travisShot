import SwiftUI
import AppKit

struct AnnotationCanvasView: View {
    @ObservedObject var viewModel: AnnotationViewModel
    let canvasSize: CGSize

    var body: some View {
        ZStack {
            // Canvas for rendering completed + in-progress annotations
            Canvas { context, size in
                for annotation in viewModel.annotations {
                    AnnotationRenderer.draw(annotation, in: &context)
                }
                if let current = viewModel.currentAnnotation {
                    AnnotationRenderer.draw(current, in: &context)
                }
            }
            .allowsHitTesting(false)

            // Gesture layer for drawing + scroll wheel
            ScrollWheelCaptureView(onScroll: { delta in
                viewModel.adjustSize(delta: delta)
            })
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .local)
                    .onChanged { value in
                        if viewModel.currentAnnotation == nil {
                            viewModel.beginStroke(at: value.startLocation)
                        }
                        viewModel.continueStroke(to: value.location)
                    }
                    .onEnded { value in
                        viewModel.endStroke(at: value.location)
                    }
            )

            // Text editing field
            if viewModel.isEditingText {
                TextField("", text: $viewModel.textEditContent)
                    .textFieldStyle(.plain)
                    .font(.system(size: viewModel.currentFontSize))
                    .foregroundColor(viewModel.currentColor)
                    .frame(minWidth: 100, maxWidth: 300)
                    .position(viewModel.textEditPosition)
                    .onSubmit {
                        viewModel.commitTextIfNeeded()
                    }
            }

            // Line width indicator (shows briefly when scrolling)
            if viewModel.selectedTool != nil && viewModel.selectedTool != .text {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Thickness: \(Int(viewModel.currentLineWidth))px")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                            .padding(8)
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }
}

// MARK: - Scroll Wheel Capture via NSViewRepresentable

struct ScrollWheelCaptureView: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScroll = onScroll
    }
}

final class ScrollWheelNSView: NSView {
    var onScroll: ((CGFloat) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func scrollWheel(with event: NSEvent) {
        let delta: CGFloat
        if event.hasPreciseScrollingDeltas {
            // Trackpad: use smaller increments
            delta = event.scrollingDeltaY > 0 ? 0.5 : -0.5
        } else {
            // Mouse wheel: use larger increments
            delta = event.scrollingDeltaY > 0 ? 1.0 : -1.0
        }
        if event.scrollingDeltaY != 0 {
            onScroll?(delta)
        }
    }
}
