import AppKit

enum PrintService {
    @MainActor
    static func printImage(_ image: NSImage) {
        let imageView = NSImageView(frame: NSRect(origin: .zero, size: image.size))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyDown

        let printOperation = NSPrintOperation(view: imageView)
        printOperation.printInfo.isHorizontallyCentered = true
        printOperation.printInfo.isVerticallyCentered = true
        printOperation.runModal(for: NSWindow(), delegate: nil, didRun: nil, contextInfo: nil)
    }
}
