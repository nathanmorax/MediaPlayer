import Foundation

nonisolated protocol CatalogAnalyzing: Sendable {
    func analyze(_ url: URL) async throws -> CatalogPage
}

nonisolated enum CatalogError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case unsupportedContent
    case pageTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Escribe una dirección HTTPS válida."
        case .invalidResponse:
            "El sitio devolvió una respuesta que no se pudo leer."
        case .httpStatus(let status):
            "El sitio devolvió un error HTTP (\(status))."
        case .unsupportedContent:
            "Esta dirección devuelve un formato que MediaPlayer no puede analizar."
        case .pageTooLarge:
            "La página supera el límite de 2 MB de HTML."
        }
    }
}
