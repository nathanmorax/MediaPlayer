import Foundation
import SwiftSoup

nonisolated struct JSONLDCatalogExtractor: CatalogExtracting {
    func items(in document: Document, sourceURL: URL) throws -> [CatalogItem] {
        var items: [CatalogItem] = []
        for script in try document.select("script[type=application/ld+json]") {
            let data = Data(script.data().utf8)
            guard let root = try? JSONSerialization.jsonObject(with: data) else { continue }
            collect(root, sourceURL: sourceURL, into: &items)
        }
        return items
    }

    private func collect(_ value: Any, sourceURL: URL, into items: inout [CatalogItem]) {
        if let array = value as? [Any] {
            for entry in array { collect(entry, sourceURL: sourceURL, into: &items) }
            return
        }
        guard let object = value as? [String: Any] else { return }

        let types = object["@type"] as? [String] ?? [object["@type"] as? String ?? ""]
        let names = types.map { $0.split(whereSeparator: { $0 == "/" || $0 == ":" }).last }
        if names.contains("SportsEvent"), let event = event(from: object, at: sourceURL) {
            items.append(event)
        }
        if names.contains("VideoObject"), let video = video(from: object, at: sourceURL) {
            items.append(video)
        }
        if names.contains("AudioObject"), let audio = audio(from: object, at: sourceURL) {
            items.append(audio)
        }
        for key in ["@graph", "itemListElement", "item", "mainEntity", "video"] {
            if let child = object[key] { collect(child, sourceURL: sourceURL, into: &items) }
        }
    }

    private func event(from object: [String: Any], at base: URL) -> CatalogItem? {
        let home = text((object["homeTeam"] as? [String: Any])?["name"])
        let away = text((object["awayTeam"] as? [String: Any])?["name"])
        let teams = [home, away].compactMap { $0 }
        guard let title = text(object["name"]) ?? (teams.isEmpty ? nil : teams.joined(separator: " vs. ")) else {
            return nil
        }

        return CatalogItem(
            title: title,
            pageURL: linkedURL(object["url"], from: base),
            summary: text(object["description"]),
            imageURL: url(object["image"], relativeTo: base),
            startDate: date(object["startDate"]),
            media: (object["video"] as? [String: Any]).flatMap { videoMedia(from: $0, at: base) },
            isEvent: true
        )
    }

    private func video(from object: [String: Any], at base: URL) -> CatalogItem? {
        let media = videoMedia(from: object, at: base)
        let pageURL = linkedURL(object["url"], from: base)
        guard media != nil || pageURL != nil else { return nil }
        return CatalogItem(
            title: text(object["name"]) ?? "Video",
            pageURL: pageURL,
            summary: text(object["description"]),
            imageURL: url(object["thumbnailUrl"], relativeTo: base) ?? url(object["image"], relativeTo: base),
            media: media
        )
    }

    private func videoMedia(from object: [String: Any], at base: URL) -> CatalogMedia? {
        if let contentURL = url(object["contentUrl"], relativeTo: base),
           CatalogURL.mediaKind(contentURL, mimeType: text(object["encodingFormat"])) == .video {
            return CatalogMedia(kind: .video, url: contentURL)
        }
        if let embedURL = url(object["embedUrl"], relativeTo: base) {
            return CatalogMedia(kind: .embedded, url: embedURL)
        }
        return nil
    }

    private func audio(from object: [String: Any], at base: URL) -> CatalogItem? {
        guard let contentURL = url(object["contentUrl"], relativeTo: base),
              CatalogURL.mediaKind(contentURL, mimeType: text(object["encodingFormat"])) == .audio else {
            return nil
        }
        return CatalogItem(
            title: text(object["name"]) ?? "Audio",
            summary: text(object["description"]),
            imageURL: url(object["image"], relativeTo: base),
            media: CatalogMedia(kind: .audio, url: contentURL)
        )
    }

    private func linkedURL(_ value: Any?, from base: URL) -> URL? {
        guard let link = url(value, relativeTo: base), link != base else { return nil }
        return link
    }

    private func text(_ value: Any?) -> String? {
        guard let string = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty else { return nil }
        return string
    }

    private func url(_ value: Any?, relativeTo base: URL) -> URL? {
        if let string = text(value) { return CatalogURL.resolve(string, relativeTo: base) }
        if let array = value as? [Any] {
            return array.lazy.compactMap { url($0, relativeTo: base) }.first
        }
        if let object = value as? [String: Any] {
            return url(object["url"] ?? object["contentUrl"] ?? object["@id"], relativeTo: base)
        }
        return nil
    }

    private func date(_ value: Any?) -> Date? {
        guard let value = text(value) else { return nil }
        if let date = try? Date.ISO8601FormatStyle().parse(value) { return date }
        return try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value)
    }
}
