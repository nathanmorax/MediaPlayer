import SwiftUI

struct CatalogCardView: View {
    let item: CatalogItem
    @State private var isHovered = false

    var body: some View {
        Color.clear
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                CatalogArtwork(imageURL: item.imageURL, symbol: item.kind.symbol)
                    .accessibilityHidden(true)
            }
            .overlay {
                LinearGradient(
                    stops: [.init(color: .clear, location: 0.2), .init(color: .black.opacity(0.85), location: 1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    if let date = item.startDate {
                        Text(date, style: .time)
                            .font(.caption.weight(.medium).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                .padding(16)
            }
            .clipShape(.rect(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .strokeBorder(.white.opacity(isHovered ? 0.56 : 0.12))
            }
            .contentShape(.rect(cornerRadius: 15))
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

struct CatalogArtwork: View {
    let imageURL: URL?
    let symbol: String

    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: imageURL) { phase in
                if let image = phase.image {
                    image.resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.20, green: 0.32, blue: 0.40), .init(red: 0.10, green: 0.15, blue: 0.21)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(alignment: .topLeading) {
                        Image(systemName: symbol)
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(.white.opacity(0.68))
                            .padding(16)
                    }
                }
            }
        }
    }
}

extension CatalogItem.Kind {
    var symbol: String {
        switch self {
        case .link: "doc.text"
        case .event: "sportscourt"
        case .video: "play.rectangle"
        }
    }
}
