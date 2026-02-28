import Foundation

enum CaptureState {
    case idle
    case selecting(origin: CGPoint)
    case selected(rect: CGRect)
    case annotating
}
