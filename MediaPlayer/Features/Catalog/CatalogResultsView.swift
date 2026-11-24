import SwiftUI

struct CatalogResultsView: View {
    let page: CatalogPage

    var body: some View {
        let sections = sections

        if sections.isEmpty {
            ContentUnavailableView(
                "Sin multimedia disponible",
                systemImage: "play.rectangle",
                description: Text("La página no publicó ningún recurso compatible.")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 27) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(page.title)
                            .font(.system(size: 29, weight: .semibold))
                            .lineLimit(2)
                            .accessibilityAddTraits(.isHeader)
                        if let summary = page.summary {
                            Text(summary)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            if let date = section.date {
                                Text(date, format: .dateTime.weekday(.wide).day().month(.wide))
                                    .font(.headline)
                                    .accessibilityAddTraits(.isHeader)
                            }
                            grid(section.items)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 26)
                .frame(maxWidth: 1_240, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func grid(_ items: [CatalogItem]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 18)], spacing: 23) {
            ForEach(items) { item in
                NavigationLink(value: item) {
                    CatalogCardView(item: item)
                }
                .buttonStyle(.plain)
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
