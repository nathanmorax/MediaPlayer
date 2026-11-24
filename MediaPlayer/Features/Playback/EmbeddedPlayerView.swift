import SwiftUI
import WebKit

struct EmbeddedPlayerView: View {
    let media: CatalogMedia
    @State private var page: WebPage
    @State private var isLoading = true
    @State private var failure: String?

    init(media: CatalogMedia) {
        self.media = media
        let url = media.sourcePageURL ?? media.url
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.deviceSensorAuthorization = .init(decision: .deny)
        _page = State(initialValue: WebPage(configuration: configuration, navigationDecider: PlayerNavigation(url: url)))
    }

    var body: some View {
        Color.black
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                WebView(page)
                if let failure {
                    Color.black.overlay {
                        ContentUnavailableView(
                            "Reproductor no disponible",
                            systemImage: "play.slash",
                            description: Text(failure)
                        )
                    }
                } else if isLoading {
                    Color.black.overlay { ProgressView("Cargando reproductor…") }
                }
            }
            .clipShape(.rect(cornerRadius: 9))
            .task { await loadPlayer() }
            .onDisappear {
                page.stopLoading()
                Task { await page.pauseAllMediaPlayback() }
            }
    }

    private func loadPlayer() async {
        let url = media.sourcePageURL ?? media.url
        isLoading = true
        failure = nil
        defer { isLoading = false }

        do {
            for try await event in page.load(URLRequest(url: url, timeoutInterval: 15)) {
                if event == .finished || (event == .committed && media.sourcePageURL != nil) { break }
            }

            if media.sourcePageURL != nil, try await !focusFrame() {
                failure = "La página ya no muestra este reproductor."
            }
        } catch {
            if !Task.isCancelled { failure = error.localizedDescription }
        }
    }

    private func focusFrame() async throws -> Bool {
        for _ in 0..<25 {
            try Task.checkCancellation()
            let focused = try await page.callJavaScript(
                Self.focusFrameScript,
                arguments: ["playerURL": media.url.absoluteString],
                contentWorld: .defaultClient
            ) as? Bool
            if focused == true { return true }
            try await Task.sleep(for: .milliseconds(200))
        }
        return false
    }

    private static let focusFrameScript = """
        const normalize = value => {
            if (!value) return null;
            try {
                const url = new URL(value, document.baseURI);
                url.hash = '';
                return url.href;
            } catch {
                return null;
            }
        };
        const target = normalize(playerURL);
        const frame = [...document.querySelectorAll('iframe[src], iframe[data-src]')].find(element =>
            [element.getAttribute('src'), element.getAttribute('data-src')]
                .some(value => normalize(value) === target)
        );
        if (!frame) return false;

        const setStyles = (element, styles) => {
            for (const [property, value] of Object.entries(styles)) {
                element.style.setProperty(property, value, 'important');
            }
        };

        // Keep the iframe in its original document so its origin and session are preserved.
        for (let child = frame; child.parentElement; child = child.parentElement) {
            const parent = child.parentElement;
            for (const sibling of parent.children) {
                if (sibling !== child) setStyles(sibling, {display: 'none'});
            }
            setStyles(parent, {
                position: 'static', display: 'block', overflow: 'visible',
                transform: 'none', filter: 'none', contain: 'none',
                'clip-path': 'none', 'content-visibility': 'visible'
            });
        }

        setStyles(document.documentElement, {background: 'black', overflow: 'hidden'});
        setStyles(frame, {
            position: 'fixed', inset: '0', width: '100vw', height: '100vh',
            'max-width': 'none', 'max-height': 'none', margin: '0', border: '0',
            display: 'block', 'z-index': '2147483647'
        });
        frame.loading = 'eager';
        return true;
        """
}

private struct PlayerNavigation: WebPage.NavigationDeciding {
    let url: URL

    func decidePolicy(
        for action: WebPage.NavigationAction,
        preferences: inout WebPage.NavigationPreferences
    ) async -> WKNavigationActionPolicy {
        guard let destination = action.request.url, !action.shouldPerformDownload else { return .cancel }

        if action.target?.isMainFrame == false {
            return destination.scheme == "https" || destination.absoluteString == "about:blank" ? .allow : .cancel
        }

        guard action.navigationType != .linkActivated else { return .cancel }
        let isPlayerDocument = destination.scheme == "https" && destination.host() == url.host()
            && destination.port == url.port && destination.path() == url.path()
        if action.target == nil {
            return isPlayerDocument && destination == url && action.navigationType == .other ? .allow : .cancel
        }
        return isPlayerDocument ? .allow : .cancel
    }

    func decidePolicy(for response: WebPage.NavigationResponse) async -> WKNavigationResponsePolicy {
        response.canShowMimeType ? .allow : .cancel
    }
}
