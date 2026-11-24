import SwiftUI

struct CatalogResultsView: View {
    let page: CatalogPage
    let openBrowser: () -> Void

    var body: some View {
        let sections = sections

        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header

                if page.items.isEmpty {
                    ContentUnavailableView(
                        "Sin elementos para mostrar",
                        systemImage: "square.dashed",
                        description: Text("Abre el sitio y analiza la página cargada para incluir contenido dinámico.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 14) {
                            if let date = section.date {
                                Text(date, format: .dateTime.weekday(.wide).day().month(.wide))
                                    .font(.title3.weight(.semibold))
                            } else if sections.count > 1 {
                                Text("Más contenido")
                                    .font(.title3.weight(.semibold))
                            }
                            grid(section.items)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: 1_600)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) {
                headerText
                Spacer(minLength: 12)
                browserButton
            }
            VStack(alignment: .leading, spacing: 14) {
                headerText
                browserButton
            }
        }
    }

    private var headerText: some View {
        HStack(alignment: .center, spacing: 20) {
            if let imageURL = page.imageURL {
                CatalogArtwork(imageURL: imageURL, symbol: "globe")
                    .frame(width: 144, height: 81)
                    .clipShape(.rect(cornerRadius: 12))
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(page.sourceURL.host() ?? page.sourceURL.absoluteString)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(page.title)
                    .font(.largeTitle.weight(.semibold))
                    .lineLimit(3)
                    .accessibilityAddTraits(.isHeader)
                if let summary = page.summary {
                    Text(summary)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
    }

    private var browserButton: some View {
        Button("Abrir sitio", systemImage: "arrow.up.right", action: openBrowser)
            .buttonStyle(.bordered)
            .controlSize(.large)
            .fixedSize()
    }

    private func grid(_ items: [CatalogItem]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
            ForEach(items) { item in
                NavigationLink(value: item) {
                    CatalogCardView(item: item)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var sections: [CatalogSection] {
        let calendar = Calendar.current
        var scheduled: [Date: [CatalogItem]] = [:]
        var undated: [CatalogItem] = []
        for item in page.items {
            if let date = item.startDate {
                scheduled[calendar.startOfDay(for: date), default: []].append(item)
            } else {
                undated.append(item)
            }
        }
        var sections = scheduled.keys.sorted().map { day in
            let items = scheduled[day, default: []].sorted {
                ($0.startDate ?? day) < ($1.startDate ?? day)
            }
            return CatalogSection(date: day, items: items)
        }
        if !undated.isEmpty { sections.append(CatalogSection(date: nil, items: undated)) }
        return sections
    }
}

private struct CatalogSection: Identifiable {
    let date: Date?
    let items: [CatalogItem]
    var id: Date? { date }
}
