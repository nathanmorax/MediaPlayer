import SwiftUI

enum CatalogSidebarSelection: Hashable {
    case explore
    case favorite(URL)
}

struct CatalogSidebar: View {
    let favorites: [FavoriteSource]
    @Binding var selection: CatalogSidebarSelection?
    let removeFavorite: (URL) -> Void

    var body: some View {
        List(selection: $selection) {
            Label("Explorar", systemImage: "rectangle.grid.2x2")
                .tag(CatalogSidebarSelection.explore)

            Section("Favoritos") {
                if favorites.isEmpty {
                    Text("Guarda una URL con la estrella.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(favorites) { favorite in
                    Label(favorite.title, systemImage: "star")
                        .lineLimit(1)
                        .tag(CatalogSidebarSelection.favorite(favorite.url))
                        .help(favorite.url.absoluteString)
                        .contextMenu {
                            Button("Quitar de favoritos", role: .destructive) {
                                removeFavorite(favorite.url)
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 175, ideal: 220, max: 310)
    }
}
