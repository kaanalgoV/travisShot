import SwiftUI

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

            // Gesture layer for drawing
            Color.clear
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
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }
}
