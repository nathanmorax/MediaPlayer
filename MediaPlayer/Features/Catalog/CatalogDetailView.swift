import SwiftUI

struct CatalogDetailView: View {
    let item: CatalogItem
    let analyzer: any CatalogAnalyzing

    @State private var linkedContent: LinkedContent = .loading

    private enum LinkedContent {
        case loading
        case loaded(CatalogPage)
        case failed(String)
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.075))
            .navigationTitle(item.title)
            .task(id: item.pageURL) {
                guard item.media == nil, let url = item.pageURL else { return }
                linkedContent = .loading
                do {
                    let page = try await analyzer.analyze(url)
                    try Task.checkCancellation()
                    linkedContent = .loaded(page)
                } catch {
                    if !Task.isCancelled { linkedContent = .failed(error.localizedDescription) }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let media = item.media {
            detail(media: media, summary: item.summary)
        } else if item.pageURL == nil {
            detail(summary: item.summary, message: "Este evento todavía no tiene multimedia disponible.")
        } else {
            switch linkedContent {
            case .loading:
                ProgressView("Cargando contenido…")
            case .loaded(let page):
                if let media = page.preferredMediaItem?.media {
                    detail(media: media, summary: item.summary ?? page.summary)
                } else if page.items.isEmpty {
                    detail(summary: item.summary ?? page.summary, message: "No se encontró multimedia compatible.")
                } else {
                    CatalogResultsView(page: page)
                }
            case .failed(let message):
                detail(summary: item.summary, message: message)
            }
        }
    }

    private func detail(media: CatalogMedia? = nil, summary: String?, message: String? = nil) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)

                    if let date = item.startDate {
                        Text(date.formatted(date: .complete, time: .shortened))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                if let media {
                    mediaView(media)
                } else if let imageURL = item.imageURL {
                    CatalogImageView(url: imageURL)
                }

                if let message {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if let summary {
                    Text(summary)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(24)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func mediaView(_ media: CatalogMedia) -> some View {
        switch media.kind {
        case .video, .audio:
            CatalogAVPlayerView(media: media)
        case .image:
            CatalogImageView(url: media.url)
        case .embedded:
            EmbeddedPlayerView(media: media)
                .id(media)
        }
    }
}

private struct CatalogImageView: View {
    let url: URL

    var body: some View {
        Color.black
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .scaledToFit()
                            .accessibilityLabel("Imagen")
                    } else if phase.error != nil {
                        ContentUnavailableView("No se pudo cargar la imagen", systemImage: "photo")
                    } else {
                        ProgressView()
                    }
                }
            }
            .clipShape(.rect(cornerRadius: 9))
    }
}
