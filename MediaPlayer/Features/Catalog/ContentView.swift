import SwiftUI

struct ContentView: View {
    @State private var model: CatalogViewModel
    @State private var selection: CatalogSidebarSelection? = .explore
    @State private var path: [CatalogItem] = []
    @State private var request: AnalysisRequest?

    private let analyzer: any CatalogAnalyzing
    private let favorites: FavoritesStore

    init(analyzer: any CatalogAnalyzing, favorites: FavoritesStore) {
        self.analyzer = analyzer
        self.favorites = favorites
        _model = State(initialValue: CatalogViewModel(analyzer: analyzer))
    }

    var body: some View {
        NavigationSplitView {
            CatalogSidebar(
                favorites: favorites.sources,
                selection: sidebarSelection,
                removeFavorite: removeFavorite
            )
        } detail: {
            NavigationStack(path: $path) {
                catalog
                    .navigationTitle("Explorar")
                    .navigationDestination(for: CatalogItem.self) { item in
                        CatalogDetailView(item: item, analyzer: analyzer)
                            .toolbar {
                                if let url = item.pageURL ?? item.media?.sourcePageURL ?? item.media?.url {
                                    ToolbarItem {
                                        let isFavorite = favorites.contains(url)
                                        Button {
                                            toggleFavorite(url, title: item.title)
                                        } label: {
                                            Label(
                                                isFavorite ? "Quitar de favoritos" : "Guardar en favoritos",
                                                systemImage: isFavorite ? "star.fill" : "star"
                                            )
                                        }
                                    }
                                }
                            }
                    }
            }
        }
        .task(id: request) {
            guard let request else { return }
            let item = await model.load(request.address)
            guard self.request == request, !Task.isCancelled else { return }
            if let item { path.append(item) }
            self.request = nil
        }
    }

    private var sidebarSelection: Binding<CatalogSidebarSelection?> {
        Binding {
            selection
        } set: { source in
            guard let source else { return }
            let previous = selection
            selection = source
            path.removeAll()

            switch source {
            case .explore:
                if previous != .explore {
                    request = nil
                    model.reset()
                }
            case .favorite(let url):
                model.address = url.absoluteString
                request = AnalysisRequest(address: url.absoluteString)
            }
        }
    }

    private var catalog: some View {
        VStack(spacing: 0) {
            addressBar

            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
                .accessibilityHidden(true)

            results
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(white: 0.075))
    }

    private var addressBar: some View {
        @Bindable var model = model
        let url = CatalogURL.address(model.address)
        let isFavorite = url.map { favorites.contains($0) } ?? false
        let favoriteLabel = isFavorite ? "Quitar de favoritos" : "Guardar en favoritos"

        return HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Pega una URL", text: $model.address)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Dirección web")
                    .onSubmit(analyze)
            }
            .padding(.horizontal, 13)
            .frame(height: 38)
            .background(.white.opacity(0.055), in: .rect(cornerRadius: 9))
            .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.10)) }
            .disabled(request != nil)

            Button {
                if let url { toggleFavorite(url) }
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? Color.yellow : .secondary)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.055), in: .rect(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(favoriteLabel)
            .help(favoriteLabel)
            .disabled(url == nil)

            Button(action: analyze) {
                Text("Analizar")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(.white, in: .rect(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .opacity(request != nil || model.address.isEmpty ? 0.48 : 1)
            .disabled(request != nil || model.address.isEmpty)
        }
        .frame(maxWidth: 740)
        .padding(.horizontal, 28)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var results: some View {
        switch model.state {
        case .idle:
            ContentUnavailableView(
                "Tu catálogo multimedia",
                systemImage: "play.rectangle",
                description: Text("Pega una dirección web para encontrar videos, audio e imágenes.")
            )
        case .loading:
            ProgressView("Buscando multimedia…")
        case .loaded(let page):
            CatalogResultsView(page: page)
        case .failed(let message):
            ContentUnavailableView(
                "No se pudo analizar la dirección",
                systemImage: "exclamationmark.circle",
                description: Text(message)
            )
        }
    }

    private func analyze() {
        guard request == nil, !model.address.isEmpty else { return }
        if let url = CatalogURL.address(model.address), favorites.contains(url) {
            selection = .favorite(url)
        } else {
            selection = .explore
        }
        path.removeAll()
        request = AnalysisRequest(address: model.address)
    }

    private func toggleFavorite(_ url: URL, title requestedTitle: String? = nil) {
        if favorites.contains(url) {
            removeFavorite(url)
        } else {
            let title: String
            if let requestedTitle {
                title = requestedTitle
            } else if model.loadedURL == url, case .loaded(let page) = model.state {
                title = page.title
            } else {
                title = url.host() ?? url.absoluteString
            }
            favorites.add(url, title: title)
        }
    }

    private func removeFavorite(_ url: URL) {
        favorites.remove(url)
        if selection == .favorite(url) { selection = .explore }
    }
}

private struct AnalysisRequest: Equatable {
    let id = UUID()
    let address: String
}
