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

    static func mediaKind(_ url: URL, mimeType: String? = nil) -> CatalogMedia.Kind? {
        let type = mimeType?.split(separator: ";").first?.trimmingCharacters(in: .whitespaces).lowercased()
        switch type {
        case "application/vnd.apple.mpegurl", "application/x-mpegurl", "audio/mpegurl",
             "audio/x-mpegurl", "video/mp4", "video/quicktime", "video/x-m4v":
            return .video
        case "audio/mpeg", "audio/mp4", "audio/x-m4a", "audio/aac", "audio/wav",
             "audio/x-wav", "audio/aiff", "audio/x-aiff", "audio/flac", "audio/x-flac":
            return .audio
        case "image/jpeg", "image/png", "image/webp", "image/gif", "image/avif",
             "image/heic", "image/heif", "image/tiff", "image/bmp":
            return .image
        case nil, "application/octet-stream", "binary/octet-stream":
            switch url.pathExtension.lowercased() {
            case "m3u8", "mp4", "m4v", "mov": return .video
            case "mp3", "m4a", "aac", "wav", "aiff", "aif", "flac": return .audio
            case "jpg", "jpeg", "png", "webp", "gif", "avif", "heic", "heif", "tiff", "bmp": return .image
            default: return nil
            }
        default:
            return nil
        }
    }

    static func isEmbeddedPlayer(_ url: URL) -> Bool {
        let path = url.path()
        switch url.host()?.lowercased() {
        case "www.youtube.com", "youtube.com", "www.youtube-nocookie.com", "youtube-nocookie.com":
            return path.hasPrefix("/embed/")
        case "player.vimeo.com":
            return path.hasPrefix("/video/")
        case "www.dailymotion.com", "dailymotion.com":
            return path.hasPrefix("/embed/video/")
        default:
            return false
        }
    }

    static func isMediaPage(_ url: URL) -> Bool {
        let routes = ["en-vivo", "en-directo", "directo", "live", "watch", "canal", "channel"]
        return url.path().split(separator: "/").dropLast().contains { routes.contains($0.lowercased()) }
    }
}
