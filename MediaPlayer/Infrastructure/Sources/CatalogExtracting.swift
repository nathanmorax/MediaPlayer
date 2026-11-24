import Foundation
import SwiftSoup

nonisolated protocol CatalogExtracting: Sendable {
    func items(in document: Document, sourceURL: URL) throws -> [CatalogItem]
}
