import AppKit

enum ClipboardService {
    static func copy(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Get CGImage directly to avoid creating a large intermediate TIFF
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            log("copy: failed to get CGImage, falling back to writeObjects")
            pasteboard.writeObjects([image])
            return
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        bitmapRep.size = image.size // preserve point size for DPI metadata

        // Use PNG as primary format — compressed, reliable for large images.
        // Uncompressed TIFF for very large captures (e.g. 3780×6720 portrait @ 2x ≈ 97 MB)
        // can exceed pasteboard IPC transfer limits.
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            log("copy: failed to create PNG data, falling back to writeObjects")
            pasteboard.writeObjects([image])
            return
        }

        let item = NSPasteboardItem()
        item.setData(pngData, forType: .png)

        // Also provide TIFF for apps that specifically require it, but only if reasonably sized
        let tiffProperties: [NSBitmapImageRep.PropertyKey: Any] = [
            .compressionMethod: NSNumber(value: NSBitmapImageRep.TIFFCompression.lzw.rawValue)
        ]
        if let tiffData = bitmapRep.representation(using: .tiff, properties: tiffProperties),
           tiffData.count < 80_000_000 {
            item.setData(tiffData, forType: .tiff)
            log("copy: PNG \(pngData.count) bytes + TIFF \(tiffData.count) bytes for \(cgImage.width)×\(cgImage.height)")
        } else {
            log("copy: PNG only \(pngData.count) bytes for \(cgImage.width)×\(cgImage.height) (TIFF too large or failed)")
        }

        let success = pasteboard.writeObjects([item])
        log("copy: writeObjects result = \(success)")
    }

    static func copy(_ cgImage: CGImage) {
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        copy(nsImage)
    }

    static func copyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static func log(_ msg: String) {
        let line = "[\(Date())] ClipboardService: \(msg)\n"
        guard let data = line.data(using: .utf8) else { return }
        let path = "/tmp/travisshot_debug.log"
        if let fh = FileHandle(forWritingAtPath: path) {
            fh.seekToEndOfFile()
            fh.write(data)
            fh.closeFile()
        } else {
            FileManager.default.createFile(atPath: path, contents: data)
        }
    }
}
