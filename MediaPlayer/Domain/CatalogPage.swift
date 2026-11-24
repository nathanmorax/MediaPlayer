import Foundation

nonisolated struct CatalogPage: Sendable {
    let title: String
    let summary: String?
    let imageURL: URL?
    let sourceURL: URL
    let items: [CatalogItem]
}

nonisolated struct CatalogItem: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case link
        case event
        case video
    }

    let title: String
    let pageURL: URL
    let kind: Kind
    var summary: String? = nil
    var imageURL: URL? = nil
    var startDate: Date? = nil
    var playbackURL: URL? = nil

    var id: String {
        switch kind {
        case .link:
            pageURL.absoluteString
        case .event:
            "event|\(pageURL.absoluteString)|\(title)|\(startDate?.timeIntervalSince1970.description ?? "")"
        case .video:
            "video|\((playbackURL ?? pageURL).absoluteString)|\(title)"
        }
    }
}
