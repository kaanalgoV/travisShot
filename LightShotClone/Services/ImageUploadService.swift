import AppKit
import Defaults
import Foundation

struct ImgurResponse: Codable {
    let data: ImgurImageData
    let success: Bool
    let status: Int
}

struct ImgurImageData: Codable {
    let id: String
    let link: String
    let deletehash: String?
}

enum ImageUploadError: LocalizedError {
    case imageConversionFailed
    case uploadFailed(String)
    case invalidResponse
    case noApiKey

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed: return "Failed to convert image for upload"
        case .uploadFailed(let msg): return "Upload failed: \(msg)"
        case .invalidResponse: return "Invalid server response"
        case .noApiKey: return "No Imgur Client-ID configured. Set it in Preferences > Upload."
        }
    }
}

enum ImageUploadService {
    static func uploadToImgur(_ image: NSImage) async throws -> String {
        let clientID = Defaults[.imgurClientID].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty else {
            throw ImageUploadError.noApiKey
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:])
        else {
            throw ImageUploadError.imageConversionFailed
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "https://api.imgur.com/3/image")!)
        request.httpMethod = "POST"
        request.setValue("Client-ID \(clientID)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"screenshot.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(pngData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ImageUploadError.uploadFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let decoded = try JSONDecoder().decode(ImgurResponse.self, from: data)
        guard decoded.success else {
            throw ImageUploadError.uploadFailed("API returned failure")
        }

        return decoded.data.link
    }

    static func searchSimilarImages(imageURL: String) {
        let encoded = imageURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? imageURL
        let searchURL = "https://www.google.com/searchbyimage?image_url=\(encoded)"
        if let url = URL(string: searchURL) {
            NSWorkspace.shared.open(url)
        }
    }

    static func searchSimilarImages(image: NSImage) async {
        if let link = try? await uploadToImgur(image) {
            searchSimilarImages(imageURL: link)
        }
    }
}
