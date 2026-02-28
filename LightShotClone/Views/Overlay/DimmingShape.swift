import SwiftUI

/// A shape that fills the entire rect with a rectangular cutout (hole)
/// Must be rendered with eoFill for the cutout to be transparent
struct DimmingShape: Shape {
    let cutout: CGRect?

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        if let cutout = cutout {
            path.addRect(cutout)
        }
        return path
    }
}
