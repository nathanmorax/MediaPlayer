import SwiftUI
import WebKit

struct BrowserSheet: View {
    let url: URL
    let onAnalyze: (String, URL) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var page = WebPage()
    @State private var loadError: String?
    @State private var analysisError: String?
    @State private var analysisRequested = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button("Cerrar", role: .close) { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Text(page.url?.host() ?? url.host() ?? url.absoluteString)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()

                Button("Analizar página cargada", systemImage: "rectangle.grid.2x2") {
                    analysisRequested = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(page.isLoading || page.url == nil || analysisRequested || loadError != nil)
            }
            .padding(16)

            if page.isLoading {
                ProgressView(value: page.estimatedProgress)
                    .progressViewStyle(.linear)
            } else {
                Divider()
            }

            if let loadError {
                ContentUnavailableView {
                    Label("No se pudo abrir la página", systemImage: "globe")
                } description: {
                    Text(loadError)
                } actions: {
                    Link("Abrir en el navegador", destination: url)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                WebView(page)
            }

            if let analysisError {
                Text(analysisError)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
        #if os(macOS)
        .frame(minWidth: 700, minHeight: 480)
        #endif
        .task {
            do {
                for try await _ in page.load(URLRequest(url: url)) {}
            } catch {
                if !Task.isCancelled { loadError = error.localizedDescription }
            }
        }
        .task(id: analysisRequested) {
            if analysisRequested { await analyzePage() }
        }
    }

    private func analyzePage() async {
        defer { analysisRequested = false }
        guard let finalURL = page.url else { return }
        analysisError = nil

        do {
            let result = try await page.callJavaScript(
                """
                const html = document.documentElement?.outerHTML;
                return html?.length <= 2000000 ? html : null;
                """,
                contentWorld: .defaultClient
            )
            guard page.url == finalURL else {
                analysisError = "La página cambió. Vuelve a analizar cuando termine de cargar."
                return
            }
            try Task.checkCancellation()
            guard let html = result as? String else { throw CatalogError.pageTooLarge }
            try await onAnalyze(html, finalURL)
        } catch {
            if !Task.isCancelled { analysisError = error.localizedDescription }
        }
    }
}
