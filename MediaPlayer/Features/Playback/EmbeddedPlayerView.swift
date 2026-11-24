import SwiftUI
import WebKit

struct EmbeddedPlayerView: View {
    let url: URL
    @State private var page: WebPage
    @State private var isLoading = true
    @State private var failed = false

    init(url: URL) {
        self.url = url
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.deviceSensorAuthorization = .init(decision: .deny)
        _page = State(initialValue: WebPage(configuration: configuration, navigationDecider: PlayerNavigation(url: url)))
    }

    var body: some View {
        Color.black
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                if failed {
                    ContentUnavailableView("Reproductor no disponible", systemImage: "play.slash")
                } else {
                    WebView(page)
                    if isLoading { ProgressView() }
                }
            }
            .clipShape(.rect(cornerRadius: 9))
            .task(id: url) {
                defer { isLoading = false }
                do {
                    for try await event in page.load(URLRequest(url: url, timeoutInterval: 15)) {
                        if event == .finished { break }
                    }
                } catch {
                    if !Task.isCancelled { failed = true }
                }
            }
            .onDisappear {
                page.stopLoading()
                Task { await page.pauseAllMediaPlayback() }
            }
    }
}

private struct PlayerNavigation: WebPage.NavigationDeciding {
    let url: URL

    func decidePolicy(
        for action: WebPage.NavigationAction,
        preferences: inout WebPage.NavigationPreferences
    ) async -> WKNavigationActionPolicy {
        guard let target = action.target, let destination = action.request.url,
              !action.shouldPerformDownload, action.navigationType != .linkActivated else { return .cancel }
        if !target.isMainFrame {
            return destination.scheme == "https" || destination.absoluteString == "about:blank" ? .allow : .cancel
        }
        let isPlayer = destination.scheme == "https" && destination.host() == url.host()
            && destination.port == url.port && destination.path() == url.path()
        return isPlayer ? .allow : .cancel
    }

    func decidePolicy(for response: WebPage.NavigationResponse) async -> WKNavigationResponsePolicy {
        if let http = response.response as? HTTPURLResponse, !(200..<400).contains(http.statusCode) {
            return .cancel
        }
        return response.canShowMimeType ? .allow : .cancel
    }
}
