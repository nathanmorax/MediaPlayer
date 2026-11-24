import Foundation

nonisolated struct CatalogPage: Sendable {
    let title: String
    let summary: String?
    let sourceURL: URL
    let items: [CatalogItem]

    var directItem: CatalogItem? {
        guard items.count == 1, items.first?.media?.url == sourceURL else { return nil }
        return items.first
    }

    var preferredMediaItem: CatalogItem? {
        let playableItems = items.filter { $0.media?.isPlayable == true }
        if playableItems.count == 1 { return playableItems.first }
        guard items.count == 1, items.first?.media != nil else { return nil }
        return items.first
    }
}

nonisolated struct CatalogItem: Identifiable, Hashable, Sendable {
    let title: String
    var pageURL: URL? = nil
    var summary: String? = nil
    var imageURL: URL? = nil
    var startDate: Date? = nil
    var media: CatalogMedia? = nil
    var isEvent = false

    var id: String {
        if !isEvent, let media {
            return "\(media.kind)|\(media.url.absoluteString)"
        }
        if !isEvent, let pageURL { return "page|\(pageURL.absoluteString)" }
        return "event|\(pageURL?.absoluteString ?? "")|\(title)|\(startDate?.timeIntervalSince1970.description ?? "")"
    }
}

nonisolated struct CatalogMedia: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case video
        case audio
        case image
        case embedded
    }

    let kind: Kind
    let url: URL

    var isPlayable: Bool { kind != .image }
}
