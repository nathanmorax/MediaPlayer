import SwiftUI

struct CatalogCardView: View {
    let item: CatalogItem
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color(white: 0.13)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay {
                    CatalogArtwork(url: artworkURL, symbol: symbol)
                }
                .overlay(alignment: .bottomTrailing) {
                    if item.media?.isPlayable == true || item.pageURL != nil {
                        Image(systemName: item.media?.isPlayable == true ? "play.fill" : "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 30, height: 30)
                            .background(.black.opacity(0.70), in: .circle)
                            .padding(8)
                    }
                }
                .clipShape(.rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.white.opacity(isHovered ? 0.43 : 0.10))
                }
                .accessibilityHidden(true)

            Text(item.title)
                .font(.callout.weight(.medium))
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            if let date = item.startDate {
                Text(date, style: .time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .accessibilityElement(children: .combine)
    }

    private var artworkURL: URL? {
        if let media = item.media, media.kind == .image {
            return item.imageURL ?? media.url
        }
        return item.imageURL
    }

    private var symbol: String {
        switch item.media?.kind {
        case .video, .embedded: "film"
        case .audio: "waveform"
        case .image: "photo"
        case nil: item.isEvent ? "calendar" : "play.rectangle"
        }
    }
}

private struct CatalogArtwork: View {
    let url: URL?
    let symbol: String

    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 25, weight: .light))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}
