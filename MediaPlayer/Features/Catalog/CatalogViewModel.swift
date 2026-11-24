import Foundation
import Observation

@MainActor @Observable
final class CatalogViewModel {
    enum State {
        case idle
        case loading
        case loaded(CatalogPage)
        case failed(String, URL?)
    }

    var address = ""
    private(set) var state: State = .idle
    private let analyzer: any CatalogAnalyzing

    init(analyzer: any CatalogAnalyzing) {
        self.analyzer = analyzer
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    func load() async {
        guard !isLoading else { return }
        guard let url = CatalogURL.address(address) else {
            state = .failed(CatalogError.invalidURL.localizedDescription, nil)
            return
        }

        address = url.absoluteString
        state = .loading
        do {
            let page = try await analyzer.analyze(url)
            try Task.checkCancellation()
            state = .loaded(page)
        } catch let error as URLError where error.code == .cancelled {
            state = .idle
        } catch {
            state = Task.isCancelled ? .idle : .failed(error.localizedDescription, url)
        }
    }

    func loadRenderedHTML(_ html: String, at url: URL) async throws {
        let page = try await analyzer.analyzeRenderedHTML(html, at: url)
        try Task.checkCancellation()
        address = page.sourceURL.absoluteString
        state = .loaded(page)
    }
}
