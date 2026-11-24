import SwiftUI

struct ContentView: View {
    @State private var model: CatalogViewModel
    @State private var path: [CatalogItem] = []
    @State private var browser: BrowserDestination?

    private let example = "https://www.iana.org/domains/reserved"

    init(analyzer: any CatalogAnalyzing) {
        _model = State(initialValue: CatalogViewModel(analyzer: analyzer))
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "link")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        TextField("Pega o escribe una URL", text: $model.address)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .accessibilityLabel("Dirección web")
                            .onSubmit(analyze)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
                    .disabled(model.isLoading)

                    Button("Analizar", action: analyze)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(model.isLoading)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 18)

                Divider()

                results
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationDestination(for: CatalogItem.self) { item in
                CatalogDetailView(item: item) { openBrowser(item.pageURL) }
            }
            .background(alignment: .topLeading) {
                CatalogBackdrop()
            }
        }
        .sheet(item: $browser) { destination in
            BrowserSheet(url: destination.url) { html, finalURL in
                try await model.loadRenderedHTML(html, at: finalURL)
                path.removeAll()
                browser = nil
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        switch model.state {
        case .idle:
            ContentUnavailableView {
                Label("Tu catálogo web", systemImage: "rectangle.grid.2x2")
            } description: {
                Text("Abre una página como una colección de tarjetas.")
            } actions: {
                Button("Probar con un ejemplo") {
                    model.address = example
                    analyze()
                }
            }
        case .loading:
            ProgressView("Analizando la página…")
        case .loaded(let page):
            CatalogResultsView(page: page) { openBrowser(page.sourceURL) }
        case .failed(let message, let url):
            ContentUnavailableView {
                Label("No se pudo analizar la página", systemImage: "exclamationmark.circle")
            } description: {
                Text(message)
            } actions: {
                if let url {
                    Button("Abrir en vista web") { openBrowser(url) }
                }
            }
        }
    }

    private func analyze() {
        Task { await model.load() }
    }

    private func openBrowser(_ url: URL) {
        browser = BrowserDestination(url: url)
    }
}

private struct BrowserDestination: Identifiable {
    let url: URL
    var id: URL { url }
}

struct CatalogBackdrop: View {
    var body: some View {
        Color(red: 0.065, green: 0.078, blue: 0.102)
            .overlay {
                RadialGradient(
                    colors: [Color(red: 0.12, green: 0.19, blue: 0.26), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 680
                )
            }
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView(analyzer: HTMLCatalogAnalyzer())
        .preferredColorScheme(.dark)
}
