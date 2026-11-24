import Foundation
import Observation

@MainActor @Observable
final class CatalogViewModel {
    enum State {
        case idle
        case loading
        case loaded(CatalogPage)
        case failed(String)
    }

    var address = ""
    private(set) var state: State = .idle
    private(set) var loadedURL: URL?
    private let analyzer: any CatalogAnalyzing
    private var activeRequest: UUID?

    init(analyzer: any CatalogAnalyzing) {
        self.analyzer = analyzer
    }

    func load(_ input: String) async -> CatalogItem? {
        guard !Task.isCancelled else { return nil }
        let request = UUID()
        activeRequest = request
        loadedURL = nil
        guard let url = CatalogURL.address(input) else {
            state = .failed(CatalogError.invalidURL.localizedDescription)
            return nil
        }

        address = url.absoluteString
        state = .loading
        do {
            let page = try await analyzer.analyze(url)
            try Task.checkCancellation()
            guard activeRequest == request else { return nil }
            loadedURL = url
            state = .loaded(page)
            return page.directItem
        } catch {
            guard activeRequest == request else { return nil }
            if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                state = .idle
            } else {
                state = .failed(error.localizedDescription)
            }
        }
        return nil
    }

    func reset() {
        activeRequest = nil
        loadedURL = nil
        address = ""
        state = .idle
    }
}
