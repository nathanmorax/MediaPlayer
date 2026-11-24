import SwiftUI

struct CatalogDetailView: View {
    let item: CatalogItem
    let openBrowser: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let url = item.playbackURL {
                    CatalogVideoView(url: url)
                        .clipShape(.rect(cornerRadius: 16))
                } else if let imageURL = item.imageURL {
                    Color.clear
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .overlay { CatalogArtwork(imageURL: imageURL, symbol: item.kind.symbol) }
                        .clipShape(.rect(cornerRadius: 16))
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.largeTitle.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)

                    if let date = item.startDate {
                        Label(date.formatted(date: .complete, time: .shortened), systemImage: "calendar")
                            .foregroundStyle(.secondary)
                    }
                    if let summary = item.summary {
                        Text(summary)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Button("Ver página", systemImage: "arrow.up.right", action: openBrowser)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
            .padding(32)
            .frame(maxWidth: 930, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background { CatalogBackdrop() }
    }
}
