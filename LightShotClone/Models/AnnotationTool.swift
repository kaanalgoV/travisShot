import Foundation

enum AnnotationTool: String, CaseIterable, Identifiable {
    case select
    case pen
    case line
    case arrow
    case rectangle
    case text
    case marker
    case number

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .select: return "Select"
        case .pen: return "Pen"
        case .line: return "Line"
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .text: return "Text"
        case .marker: return "Marker"
        case .number: return "Number"
        }
    }

    var systemImage: String {
        switch self {
        case .select: return "cursorarrow"
        case .pen: return "pencil.tip"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .text: return "textformat"
        case .marker: return "highlighter"
        case .number: return "1.circle"
        }
    }
}
