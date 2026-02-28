import CoreGraphics

enum CoordinateConverter {
    /// Flip Y coordinate from AppKit (bottom-left origin) to CG (top-left origin)
    static func flipY(rect: CGRect, inScreenHeight screenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// Normalize a rect that may have negative width/height (from dragging in reverse)
    static func normalize(_ rect: CGRect) -> CGRect {
        CGRect(
            x: min(rect.origin.x, rect.origin.x + rect.width),
            y: min(rect.origin.y, rect.origin.y + rect.height),
            width: abs(rect.width),
            height: abs(rect.height)
        )
    }

    /// Scale a rect by a factor (e.g., for Retina displays)
    static func scale(_ rect: CGRect, by factor: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x * factor,
            y: rect.origin.y * factor,
            width: rect.width * factor,
            height: rect.height * factor
        )
    }
}
