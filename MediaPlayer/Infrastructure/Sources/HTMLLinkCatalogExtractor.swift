import Foundation
import SwiftSoup

nonisolated struct HTMLLinkCatalogExtractor: CatalogExtracting {
    func items(in document: Document, sourceURL: URL) throws -> [CatalogItem] {
        let primary = try links(
            in: document.select("main a[href], article a[href], [role=main] a[href]"),
            sourceURL: sourceURL
        )
        if !primary.isEmpty { return primary }

        return try links(in: document.select("body a[href]"), sourceURL: sourceURL)
    }

    private func links(in elements: Elements, sourceURL: URL) throws -> [CatalogItem] {
        var items: [CatalogItem] = []
        var seen: Set<URL> = []

        for link in elements {
            let href = try link.attr("href").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !href.isEmpty, !href.hasPrefix("#"),
                  let url = CatalogURL.resolve(try link.absUrl("href")),
                  url != sourceURL else { continue }

            let image = try link.select("img").first()
            let labels = try [link.text(), link.attr("aria-label"), image?.attr("alt") ?? ""]
            guard let title = labels.lazy.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                .first(where: { !$0.isEmpty }),
                seen.insert(url).inserted else { continue }

            let imageURL = try image.flatMap { image in
                try CatalogURL.resolve(image.absUrl("data-src"))
                    ?? CatalogURL.resolve(image.absUrl("src"))
            }
            let playbackURL = CatalogURL.isDirectVideo(url) ? url : nil
            items.append(CatalogItem(
                title: title,
                pageURL: url,
                kind: playbackURL == nil ? .link : .video,
                imageURL: imageURL,
                playbackURL: playbackURL
            ))
            if items.count == 30 { break }
        }
        return items
    }
}
