import Foundation
import SwiftSoup

nonisolated struct HTMLMediaCatalogExtractor: CatalogExtracting {
    func items(in document: Document, sourceURL: URL) throws -> [CatalogItem] {
        let title = try document.title()
        var items: [CatalogItem] = []

        for element in try document.select("video, audio") {
            let kind: CatalogMedia.Kind = element.tagName() == "video" ? .video : .audio
            guard let media = try mediaSource(of: element, kind: kind) else { continue }
            let poster = try CatalogURL.resolve(element.absUrl("poster"))
            items.append(try item(media, from: element, title: title, imageURL: poster, sourceURL: sourceURL))
        }

        for element in try document.select("iframe[src]") {
            guard let url = try CatalogURL.resolve(element.absUrl("src")), url != sourceURL else { continue }
            let permissions = try element.attr("allow").lowercased()
            let isDeclaredPlayer = try element.attr("itemprop") == "embedUrl"
                || permissions.split(separator: ";").contains { $0.trimmingCharacters(in: .whitespaces) == "encrypted-media" }
            guard isDeclaredPlayer || CatalogURL.isEmbeddedPlayer(url) else { continue }
            let media = CatalogMedia(kind: .embedded, url: url)
            items.append(try item(media, from: element, title: title, sourceURL: sourceURL))
        }

        for (property, type) in [("og:video", "og:video:type"), ("og:audio", "og:audio:type")] {
            let meta = try document.select("meta[property=\(property)], meta[property=\(property):url], meta[property=\(property):secure_url]")
            let mimeType = try document.select("meta[property=\(type)]").first()?.attr("content")
            for element in meta {
                guard let url = try CatalogURL.resolve(element.absUrl("content")) else { continue }
                guard let kind = CatalogURL.mediaKind(url, mimeType: mimeType)
                    ?? (CatalogURL.isEmbeddedPlayer(url) ? .embedded : nil) else { continue }
                items.append(try item(.init(kind: kind, url: url), from: element, title: title, sourceURL: sourceURL))
            }
        }

        for link in try document.select("a[href]") {
            guard let url = try CatalogURL.resolve(link.absUrl("href")), url != sourceURL,
                  let kind = CatalogURL.mediaKind(url) ?? (CatalogURL.isEmbeddedPlayer(url) ? .embedded : nil) else {
                continue
            }
            let label = try link.text()
            items.append(try item(.init(kind: kind, url: url), from: link, title: label, sourceURL: sourceURL))
        }

        let mainImages = try document.select("main img, article img, figure img, [role=main] img")
        let images = mainImages.isEmpty() ? try document.select("body img") : mainImages
        for image in images {
            let alt = try image.attr("alt")
            let width = try Int(image.attr("width"))
            let height = try Int(image.attr("height"))
            guard !image.hasAttr("alt") || !alt.isEmpty,
                  width.map({ $0 >= 100 }) ?? true,
                  height.map({ $0 >= 100 }) ?? true,
                  let url = try CatalogURL.resolve(image.absUrl("data-src")) ?? CatalogURL.resolve(image.absUrl("src")),
                  url != sourceURL else { continue }
            items.append(try item(.init(kind: .image, url: url), from: image, title: alt, sourceURL: sourceURL))
        }
        return items
    }

    private func mediaSource(of element: Element, kind: CatalogMedia.Kind) throws -> CatalogMedia? {
        let sources = try [element] + element.select("source[src]").array()
        for source in sources {
            guard let url = try CatalogURL.resolve(source.absUrl("src")) else { continue }
            let type = try source.attr("type")
            let detectedKind = CatalogURL.mediaKind(url, mimeType: type.isEmpty ? nil : type)
            if detectedKind == kind || (type.isEmpty && url.pathExtension.isEmpty) {
                return CatalogMedia(kind: kind, url: url)
            }
        }
        return nil
    }

    private func item(
        _ media: CatalogMedia, from element: Element, title: String, imageURL: URL? = nil, sourceURL: URL
    ) throws -> CatalogItem {
        let labels = try [element.attr("title"), element.attr("aria-label"), title,
                          media.url.deletingPathExtension().lastPathComponent]
        let name = labels.lazy.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "Multimedia"
        return CatalogItem(title: name, pageURL: sourceURL, imageURL: imageURL, media: media)
    }
}
