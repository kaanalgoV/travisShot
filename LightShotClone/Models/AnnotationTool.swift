import Foundation

enum AnnotationTool: String, CaseIterable, Identifiable {
    case pen
    case line
    case arrow
    case rectangle
    case text
    case marker

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pen: return "Pen"
        case .line: return "Line"
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .text: return "Text"
        case .marker: return "Marker"
        }
    }

    var systemImage: String {
        switch self {
        case .pen: return "pencil.tip"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .text: return "textformat"
        case .marker: return "highlighter"
        }
    }
}
