import AppKit
import SwiftUI

/// NSView that tracks its screen frame and shows/hides a tooltip via TooltipPanel
final class TooltipAnchorNSView: NSView {
    var tooltipText: String = ""
    var tooltipEdge: NSRectEdge = .minX

    func showTooltip() {
        guard let window = window else { return }
        let frameInWindow = convert(bounds, to: nil)
        let screenFrame = window.convertToScreen(frameInWindow)
        TooltipPanel.shared.show(tooltipText, anchorScreenRect: screenFrame, edge: tooltipEdge)
    }

    func hideTooltip() {
        TooltipPanel.shared.hide()
    }
}

/// NSViewRepresentable bridge for tooltip anchor tracking
struct TooltipAnchor: NSViewRepresentable {
    let text: String
    let edge: NSRectEdge
    let isHovered: Bool

    func makeNSView(context: Context) -> TooltipAnchorNSView {
        TooltipAnchorNSView()
    }

    func updateNSView(_ nsView: TooltipAnchorNSView, context: Context) {
        nsView.tooltipText = text
        nsView.tooltipEdge = edge
        if isHovered {
            nsView.showTooltip()
        } else {
            nsView.hideTooltip()
        }
    }
}

/// SwiftUI view modifier that shows a custom tooltip at a high window level
struct CustomTooltipModifier: ViewModifier {
    let text: String
    let edge: NSRectEdge
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                TooltipAnchor(text: text, edge: edge, isHovered: isHovered)
            )
            .onHover { hovering in
                isHovered = hovering
                if !hovering {
                    TooltipPanel.shared.hide()
                }
            }
    }
}

extension View {
    /// Shows a custom tooltip that works above high-level panels
    func customTooltip(_ text: String, edge: NSRectEdge = .minX) -> some View {
        modifier(CustomTooltipModifier(text: text, edge: edge))
    }
}
