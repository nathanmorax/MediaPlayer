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
            items.append(try item(media, from: element, title: title, imageURL: poster))
        }

        for element in try document.select("iframe[src], iframe[data-src]") {
            guard let url = try CatalogURL.resolve(element.absUrl("src")) ?? CatalogURL.resolve(element.absUrl("data-src")),
                  url != sourceURL else { continue }
            let permissions = try element.attr("allow").lowercased()
            let isDeclaredPlayer = try element.attr("itemprop") == "embedUrl"
                || permissions.split(separator: ";").contains { $0.trimmingCharacters(in: .whitespaces) == "encrypted-media" }
            let hasPlayerControls = element.hasAttr("allowfullscreen") && url.path().split(separator: "/")
                .contains { ["embed", "player", "watch"].contains($0.lowercased()) }
            guard isDeclaredPlayer || hasPlayerControls || CatalogURL.isEmbeddedPlayer(url) else { continue }
            let media = CatalogMedia(kind: .embedded, url: url, sourcePageURL: sourceURL)
            items.append(try item(media, from: element, title: title))
        }

        for (property, type) in [("og:video", "og:video:type"), ("og:audio", "og:audio:type")] {
            let meta = try document.select("meta[property=\(property)], meta[property=\(property):url], meta[property=\(property):secure_url]")
            let mimeType = try document.select("meta[property=\(type)]").first()?.attr("content")
            for element in meta {
                guard let url = try CatalogURL.resolve(element.absUrl("content")) else { continue }
                guard let kind = CatalogURL.mediaKind(url, mimeType: mimeType)
                    ?? (CatalogURL.isEmbeddedPlayer(url) ? .embedded : nil) else { continue }
                items.append(try item(.init(kind: kind, url: url), from: element, title: title))
            }
        }

        for link in try document.select("a[href]") {
            guard let url = try CatalogURL.resolve(link.absUrl("href")), url != sourceURL,
                  let kind = CatalogURL.mediaKind(url) ?? (CatalogURL.isEmbeddedPlayer(url) ? .embedded : nil) else {
                continue
            }
            let thumbnail = try link.select("img").first()
            let text = try link.text()
            let label = text.isEmpty ? try thumbnail?.attr("alt") ?? "" : text
            let artwork = try thumbnail.flatMap { try imageURL(of: $0) }
            items.append(try item(.init(kind: kind, url: url), from: link, title: label, imageURL: artwork))
        }

        for link in try document.select("main a[href], article a[href], [role=main] a[href]") {
            guard let target = try pageURL(of: link, from: sourceURL),
                  CatalogURL.isMediaPage(target),
                  CatalogURL.mediaKind(target) == nil, !CatalogURL.isEmbeddedPlayer(target) else { continue }
            let card = sequence(first: link, next: { $0.parent() }).dropFirst().prefix(4).first {
                $0.hasClass("card") || $0.tagName() == "article"
            }
            let heading = try card?.select("h2, h3, h4").first()?.text()
            let title = try itemTitle(from: link, fallback: heading ?? link.text(), url: target)
            let thumbnail = try card?.select("img").first() ?? link.select("img").first()
            let artwork = try thumbnail.flatMap { try imageURL(of: $0) }
            let summary = try card?.select("p").first()?.text()
            items.append(CatalogItem(title: title, pageURL: target, summary: summary, imageURL: artwork))
        }

        let mainImages = try document.select("main img, article img, figure img, [role=main] img")
        let images = mainImages.isEmpty() ? try document.select("body img") : mainImages
        for image in images {
            let alt = try image.attr("alt")
            let width = try Int(image.attr("width"))
            let height = try Int(image.attr("height"))
            guard width.map({ $0 >= 100 }) ?? true,
                  height.map({ $0 >= 100 }) ?? true,
                  let url = try imageURL(of: image),
                  url != sourceURL else { continue }

            let ancestorLink = sequence(first: image, next: { $0.parent() })
                .dropFirst()
                .first { $0.tagName() == "a" }
            if let ancestorLink, let target = try pageURL(of: ancestorLink, from: sourceURL) {
                // The link pass already added targets that resolve directly to multimedia.
                guard CatalogURL.mediaKind(target) == nil, !CatalogURL.isEmbeddedPlayer(target) else { continue }
                let linkTitle = try ancestorLink.text()
                let name = try itemTitle(from: ancestorLink, fallback: linkTitle.isEmpty ? alt : linkTitle, url: target)
                items.append(CatalogItem(title: name, pageURL: target, imageURL: url))
            } else if !image.hasAttr("alt") || !alt.isEmpty {
                items.append(try item(.init(kind: .image, url: url), from: image, title: alt))
            }
        }

        for link in try document.select("main h2 a[href], main h3 a[href], article h2 a[href], article h3 a[href]") {
            guard let url = try pageURL(of: link, from: sourceURL),
                  CatalogURL.mediaKind(url) == nil, !CatalogURL.isEmbeddedPlayer(url) else { continue }
            let label = try link.text()
            guard !label.isEmpty else { continue }
            let title = try itemTitle(from: link, fallback: label, url: url)
            items.append(CatalogItem(title: title, pageURL: url))
        }
        return items
    }

    private func imageURL(of element: Element) throws -> URL? {
        try CatalogURL.resolve(element.absUrl("data-src")) ?? CatalogURL.resolve(element.absUrl("src"))
    }

    private func pageURL(of link: Element, from source: URL) throws -> URL? {
        let href = try link.attr("href").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !href.isEmpty, !href.hasPrefix("#"),
              let url = try CatalogURL.resolve(link.absUrl("href")), url != source else { return nil }
        return url
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
        _ media: CatalogMedia, from element: Element, title: String, imageURL: URL? = nil
    ) throws -> CatalogItem {
        let name = try itemTitle(from: element, fallback: title, url: media.url)
        return CatalogItem(title: name, imageURL: imageURL, media: media)
    }

    private func itemTitle(from element: Element, fallback: String, url: URL) throws -> String {
        let labels = try [element.attr("title"), element.attr("aria-label"), fallback,
                          url.deletingPathExtension().lastPathComponent]
        return labels.lazy.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "Multimedia"
    }
}
