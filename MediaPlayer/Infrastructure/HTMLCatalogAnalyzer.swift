import CoreFoundation
import Foundation
import SwiftSoup

actor HTMLCatalogAnalyzer: CatalogAnalyzing {
    private let session: URLSession
    private let extractors: [any CatalogExtracting]
    private let maximumHTMLSize = 2_000_000

    init(
        session: URLSession = .shared,
        extractors: [any CatalogExtracting] = [JSONLDCatalogExtractor(), HTMLMediaCatalogExtractor()]
    ) {
        self.session = session
        self.extractors = extractors
    }

    func analyze(_ url: URL) async throws -> CatalogPage {
        guard CatalogURL.resolve(url.absoluteString) != nil else { throw CatalogError.invalidURL }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(
            "text/html, application/xhtml+xml, video/*, audio/*, image/*, application/vnd.apple.mpegurl, */*;q=0.5",
            forHTTPHeaderField: "Accept"
        )
        let (bytes, response) = try await session.bytes(for: request)
        defer { bytes.task.cancel() }
        guard let response = response as? HTTPURLResponse,
              let responseURL = response.url,
              let finalURL = CatalogURL.resolve(responseURL.absoluteString) else {
            throw CatalogError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw CatalogError.httpStatus(response.statusCode)
        }

        let mimeType = response.mimeType?.lowercased()
        if let kind = CatalogURL.mediaKind(finalURL, mimeType: mimeType)
            ?? (CatalogURL.isEmbeddedPlayer(finalURL) ? .embedded : nil) {
            let filename = finalURL.deletingPathExtension().lastPathComponent
            let title = filename.isEmpty ? finalURL.host() ?? "Multimedia" : filename
            let media = CatalogMedia(kind: kind, url: finalURL)
            let item = CatalogItem(title: title, pageURL: finalURL, media: media)
            return CatalogPage(title: title, summary: nil, sourceURL: finalURL, items: [item])
        }

        guard mimeType == nil || mimeType == "text/html" || mimeType == "application/xhtml+xml" else {
            throw CatalogError.unsupportedContent
        }
        guard response.expectedContentLength <= Int64(maximumHTMLSize) else {
            throw CatalogError.pageTooLarge
        }

        var data = Data()
        for try await byte in bytes {
            guard data.count < maximumHTMLSize else {
                throw CatalogError.pageTooLarge
            }
            data.append(byte)
        }

        let encoding = response.textEncodingName.map { name in
            let identifier = CFStringConvertIANACharSetNameToEncoding(name as CFString)
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(identifier))
        } ?? .utf8
        let html = String(data: data, encoding: encoding) ?? String(decoding: data, as: UTF8.self)
        return try analyzeRenderedHTML(html, at: finalURL)
    }

    func analyzeRenderedHTML(_ html: String, at url: URL) throws -> CatalogPage {
        guard CatalogURL.resolve(url.absoluteString) != nil else { throw CatalogError.invalidURL }
        guard html.utf8.count <= maximumHTMLSize else { throw CatalogError.pageTooLarge }
        try Task.checkCancellation()

        let document = try SwiftSoup.parseHTML(html, url.absoluteString)
        let metadataTitle = try metadata("meta[property=og:title]", in: document)
        let title = try metadataTitle ?? document.title()
        let socialSummary = try metadata("meta[property=og:description]", in: document)
        let summary = try socialSummary ?? metadata("meta[name=description]", in: document)
        let image = try document.select("meta[property=og:image]").first()?.attr("abs:content")

        var items: [CatalogItem] = []
        var itemIDs: Set<CatalogItem.ID> = []
        var mediaURLs: Set<URL> = []
        for extractor in extractors {
            for item in try extractor.items(in: document, sourceURL: url) {
                guard itemIDs.insert(item.id).inserted else { continue }
                if let media = item.media, !mediaURLs.insert(media.url).inserted, !item.isEvent { continue }
                items.append(item)
            }
        }
        let posters = Set(items.compactMap { $0.media?.kind == .image ? nil : $0.imageURL })
        items.removeAll { item in
            item.media?.kind == .image && item.media.map { posters.contains($0.url) } == true
        }
        if items.count == 1, items[0].imageURL == nil, items[0].media?.kind != .image {
            items[0].imageURL = image.flatMap { CatalogURL.resolve($0) }
        }
        try Task.checkCancellation()

        return CatalogPage(
            title: title.isEmpty ? url.host() ?? url.absoluteString : title,
            summary: summary,
            sourceURL: url,
            items: Array(items.prefix(30))
        )
    }

    private func metadata(_ selector: String, in document: Document) throws -> String? {
        guard let value = try document.select(selector).first()?.attr("content")
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }

        return value
    }
}
