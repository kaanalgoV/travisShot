import AppKit
import Defaults
import UniformTypeIdentifiers

enum FileSaveService {
    @MainActor
    static func saveWithDialog(_ image: NSImage) async -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg, .bmp]
        panel.nameFieldStringValue = "Screenshot \(timestamp()).\(Defaults[.uploadFormat])"
        panel.canCreateDirectories = true

        // Use quick save directory if set, otherwise last used directory
        let quickDir = Defaults[.quickSaveDirectory]
        if !quickDir.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: quickDir)
        } else if let lastDir = Defaults[.lastSaveDirectory] {
            panel.directoryURL = URL(fileURLWithPath: lastDir)
        }

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        Defaults[.lastSaveDirectory] = url.deletingLastPathComponent().path

        let format = imageFormat(for: url)
        return save(image, to: url, format: format) ? url : nil
    }

    static func save(_ image: NSImage, to url: URL, format: NSBitmapImageRep.FileType = .png) -> Bool {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData)
        else { return false }

        var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]
        if format == .jpeg {
            properties[.compressionFactor] = Defaults[.jpegQuality]
        }

        guard let data = bitmapRep.representation(using: format, properties: properties)
        else { return false }

        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private static func timestamp() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return df.string(from: Date())
    }

    private static func imageFormat(for url: URL) -> NSBitmapImageRep.FileType {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return .jpeg
        case "bmp": return .bmp
        case "tiff", "tif": return .tiff
        default: return .png
        }
    }
}
