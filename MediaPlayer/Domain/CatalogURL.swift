import Foundation

nonisolated enum CatalogURL {
    static func address(_ input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return nil
        }

        let address = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        return resolve(address)
    }

    static func resolve(_ input: String, relativeTo base: URL? = nil) -> URL? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              let url = URL(string: value, relativeTo: base)?.absoluteURL,
              url.scheme?.lowercased() == "https",
              let host = url.host(), !host.isEmpty,
              url.user() == nil, url.password() == nil else { return nil }

        return url
    }

    static func isDirectVideo(_ url: URL, mimeType: String? = nil) -> Bool {
        switch mimeType?.lowercased() {
        case "application/vnd.apple.mpegurl", "application/x-mpegurl", "audio/mpegurl",
             "audio/x-mpegurl", "video/mp4", "video/quicktime", "video/x-m4v":
            return true
        case nil, "application/octet-stream", "binary/octet-stream":
            return ["m3u8", "mp4", "m4v", "mov"].contains(url.pathExtension.lowercased())
        default:
            return false
        }
    }
}
