import Foundation
import WebKit

@MainActor
final class WebCatalogAnalyzer: CatalogAnalyzing {
    private let htmlAnalyzer = HTMLCatalogAnalyzer()

    func analyze(_ url: URL) async throws -> CatalogPage {
        let original = try await htmlAnalyzer.analyze(url)
        guard original.directItem == nil, await !containsPlayableMedia(original) else { return original }

        do {
            let rendered = try await render(original.sourceURL)
            let expanded = try await htmlAnalyzer.analyzeRenderedHTML(rendered.html, at: rendered.url)
            if await containsPlayableMedia(expanded) || expanded.items.count > original.items.count {
                return expanded
            }
        } catch {
            try Task.checkCancellation()
        }
        return original
    }

    private func containsPlayableMedia(_ catalog: CatalogPage) -> Bool {
        catalog.items.contains { item in
            guard let media = item.media else { return false }
            return media.kind != .image
        }
    }

    private func render(_ url: URL) async throws -> (html: String, url: URL) {
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.deviceSensorAuthorization = .init(decision: .deny)
        let page = WebPage(configuration: configuration)
        let deadline = Task {
            try await Task.sleep(for: .seconds(6))
            page.stopLoading()
        }
        defer {
            deadline.cancel()
            page.stopLoading()
        }

        return try await withTaskCancellationHandler {
            await page.setAllMediaPlaybackSuspended(true)
            for try await event in page.load(URLRequest(url: url, timeoutInterval: 6)) {
                if event == .finished { break }
            }

            try await Task.sleep(for: .milliseconds(350))
            let result = try await page.callJavaScript(
                """
                const html = document.documentElement?.outerHTML;
                return html?.length <= 2000000 ? html : null;
                """,
                contentWorld: .defaultClient
            )
            guard let html = result as? String, let finalURL = page.url else {
                throw CatalogError.invalidResponse
            }
            return (html, finalURL)
        } onCancel: {
            Task { @MainActor in page.stopLoading() }
        }
    }
}
