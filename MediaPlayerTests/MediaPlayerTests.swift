import XCTest
@testable import MediaPlayer

final class MediaPlayerTests: XCTestCase {
    func testExtractsMainLinksAndResolvesRelativeArtwork() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/guide/"))
        let html = """
        <head>
          <title>Página</title>
          <meta property="og:title" content="Guía">
          <meta property="og:image" content="/cover.jpg">
          <meta name="description" content="Contenido de la guía">
        </head>
        <body>
          <nav><a href="/menu">Menú</a></nav>
          <main>
            <a href="primer-articulo"><img src="/cover.jpg" alt="Primer artículo"></a>
            <a href="primer-articulo">Duplicado</a>
            <a href="#inicio">Ancla</a>
            <a href="http://example.com/inseguro">HTTP</a>
          </main>
        </body>
        """
        let page = try await HTMLCatalogAnalyzer().analyzeRenderedHTML(html, at: url)

        XCTAssertEqual(page.title, "Guía")
        XCTAssertEqual(page.summary, "Contenido de la guía")
        XCTAssertEqual(page.imageURL?.absoluteString, "https://example.com/cover.jpg")
        XCTAssertEqual(page.items.map(\.title), ["Primer artículo"])
        XCTAssertEqual(page.items.first?.pageURL.absoluteString, "https://example.com/guide/primer-articulo")
        XCTAssertEqual(page.items.first?.imageURL?.absoluteString, "https://example.com/cover.jpg")
    }

    func testExtractsEventsAndDirectVideoFromStructuredData() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/agenda"))
        let html = """
        <main><a href="/menu">Menú</a></main>
        <script type="application/ld+json">invalid</script>
        <script type="application/ld+json">
        {
          "@graph": [
            {
              "@type": ["Event", "https://schema.org/SportsEvent"],
              "homeTeam": {"name": "Azul"},
              "awayTeam": {"name": "Rojo"},
              "startDate": "2026-11-24T19:30:00-06:00",
              "url": "/partido"
            },
            {
              "@type": "VideoObject",
              "name": "Resumen",
              "thumbnailUrl": ["/resumen.jpg"],
              "contentUrl": "/stream/hls",
              "encodingFormat": "application/vnd.apple.mpegurl",
              "embedUrl": "/reproductor"
            },
            {
              "@type": "VideoObject",
              "name": "Entrevista",
              "embedUrl": "/entrevista"
            }
          ]
        }
        </script>
        """
        let page = try await HTMLCatalogAnalyzer().analyzeRenderedHTML(html, at: url)

        XCTAssertEqual(page.items.map(\.kind), [.event, .video, .video])
        let event = try XCTUnwrap(page.items.first)
        XCTAssertEqual(event.title, "Azul vs. Rojo")
        XCTAssertEqual(event.startDate, try Date.ISO8601FormatStyle().parse("2026-11-25T01:30:00Z"))
        let video = try XCTUnwrap(page.items.first { $0.title == "Resumen" })
        XCTAssertEqual(video.pageURL.absoluteString, "https://example.com/reproductor")
        XCTAssertEqual(video.playbackURL?.absoluteString, "https://example.com/stream/hls")
        XCTAssertEqual(video.imageURL?.absoluteString, "https://example.com/resumen.jpg")
        let embedded = try XCTUnwrap(page.items.first { $0.title == "Entrevista" })
        XCTAssertNil(embedded.playbackURL)
        XCTAssertEqual(embedded.pageURL.absoluteString, "https://example.com/entrevista")
    }

    func testFallsBackToBodyWhenMainHasNoUsableLinks() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/"))
        let html = """
        <main><a href="#inicio">Inicio</a></main>
        <footer><a href="/about">Acerca de</a></footer>
        """
        let page = try await HTMLCatalogAnalyzer().analyzeRenderedHTML(html, at: url)

        XCTAssertEqual(page.items.map(\.title), ["Acerca de"])
    }

    func testNormalizesHTTPSAddressesAndRejectsInvalidInput() {
        XCTAssertEqual(CatalogURL.address(" example.com/guide ")?.absoluteString,
                       "https://example.com/guide")
        XCTAssertNil(CatalogURL.address("example.com/not valid"))
        XCTAssertNil(CatalogURL.address("http://example.com"))
        XCTAssertNil(CatalogURL.address("https://user:password@example.com"))
    }
}
