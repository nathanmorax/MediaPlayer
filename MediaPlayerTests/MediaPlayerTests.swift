import XCTest
@testable import MediaPlayer

final class MediaPlayerTests: XCTestCase {
    func testExtractsMediaAndLeavesOrdinaryLinksOutOfTheCatalog() async throws {
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
            <video title="Resumen" poster="/cover.jpg"><source src="video.mp4" type="video/mp4"></video>
            <a href="video.mp4">Duplicado</a>
            <audio title="Entrevista" src="/audio/entrevista.mp3"></audio>
            <a href="/article">Leer artículo</a>
            <a href="https://example.com/foto.png">Foto</a>
            <img src="/cover.jpg" alt="Portada del video">
            <iframe src="https://example.com/map" title="Mapa"></iframe>
            <a href="#inicio">Ancla</a>
            <a href="http://example.com/inseguro">HTTP</a>
          </main>
        </body>
        """
        let page = try await HTMLCatalogAnalyzer().analyzeRenderedHTML(html, at: url)

        XCTAssertEqual(page.title, "Guía")
        XCTAssertEqual(page.summary, "Contenido de la guía")
        XCTAssertEqual(page.items.map(\.title), ["Resumen", "Entrevista", "Foto"])
        XCTAssertEqual(page.items.compactMap { $0.media?.kind }, [.video, .audio, .image])
        XCTAssertEqual(page.items.first?.media?.url.absoluteString, "https://example.com/guide/video.mp4")
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

        XCTAssertEqual(page.items.compactMap { $0.media?.kind }, [.video, .embedded])
        let event = try XCTUnwrap(page.items.first)
        XCTAssertTrue(event.isEvent)
        XCTAssertEqual(event.title, "Azul vs. Rojo")
        XCTAssertEqual(event.startDate, try Date.ISO8601FormatStyle().parse("2026-11-25T01:30:00Z"))
        let video = try XCTUnwrap(page.items.first { $0.title == "Resumen" })
        XCTAssertEqual(video.media?.url.absoluteString, "https://example.com/stream/hls")
        XCTAssertEqual(video.imageURL?.absoluteString, "https://example.com/resumen.jpg")
        let embedded = try XCTUnwrap(page.items.first { $0.title == "Entrevista" })
        XCTAssertEqual(embedded.media?.url.absoluteString, "https://example.com/entrevista")
    }

    func testRecognizesPlayerFramesAndImagesWithoutMain() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/"))
        let html = """
        <main><a href="#inicio">Inicio</a></main>
        <iframe src="https://player.vimeo.com/video/123" title="Grabación"></iframe>
        <img src="/gallery.jpg" alt="Fotografía">
        <img src="/icon.png" alt="Icono" width="32">
        """
        let page = try await HTMLCatalogAnalyzer().analyzeRenderedHTML(html, at: url)

        XCTAssertEqual(page.items.map(\.title), ["Grabación", "Fotografía"])
        XCTAssertEqual(page.items.compactMap { $0.media?.kind }, [.embedded, .image])
    }

    func testDirectMediaOpensAutomatically() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/live.m3u8"))
        let item = CatalogItem(title: "Video", pageURL: url, media: .init(kind: .video, url: url))
        let page = CatalogPage(title: "Video", summary: nil, sourceURL: url, items: [item])

        XCTAssertEqual(page.directItem, item)
        XCTAssertEqual(CatalogURL.mediaKind(url), .video)
        XCTAssertNil(CatalogURL.mediaKind(url, mimeType: "text/html"))
    }

    func testLinkedArtworkNavigatesToThePageAndFindsItsPlayer() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/agenda/"))
        let analyzer = HTMLCatalogAnalyzer()
        let catalog = try await analyzer.analyzeRenderedHTML("""
        <main>
          <article>
            <a href="partido"><picture><img src="/portada.jpg" alt="El partido"></picture></a>
            <h2><a href="partido">Resultado y video</a></h2>
          </article>
        </main>
        """, at: url)

        XCTAssertEqual(catalog.items.count, 1)
        let tile = try XCTUnwrap(catalog.items.first)
        let destination = try XCTUnwrap(tile.pageURL)
        XCTAssertEqual(destination.absoluteString, "https://example.com/agenda/partido")
        XCTAssertEqual(tile.imageURL?.absoluteString, "https://example.com/portada.jpg")
        XCTAssertNil(tile.media)

        let detail = try await analyzer.analyzeRenderedHTML("""
        <main>
          <iframe data-src="/player/partido" allowfullscreen title="En directo"></iframe>
          <img src="/imagen.jpg" alt="Crónica">
        </main>
        """, at: destination)
        XCTAssertEqual(detail.items.count, 2)
        XCTAssertEqual(detail.preferredMediaItem?.media?.kind, .embedded)
        XCTAssertEqual(detail.preferredMediaItem?.media?.url.absoluteString, "https://example.com/player/partido")
    }

    @MainActor
    func testFavoritesPersistAndAvoidDuplicates() async throws {
        let suite = "MediaPlayerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let url = try XCTUnwrap(URL(string: "https://example.com/agenda"))
        let store = FavoritesStore(defaults: defaults)

        store.add(url, title: "Agenda")
        store.add(url, title: "Duplicado")
        let restored = FavoritesStore(defaults: defaults)
        XCTAssertEqual(restored.sources.map(\.title), ["Agenda"])
        XCTAssertTrue(restored.contains(url))

        restored.remove(url)
        XCTAssertFalse(FavoritesStore(defaults: defaults).contains(url))
    }

    func testNormalizesHTTPSAddressesAndRejectsInvalidInput() {
        XCTAssertEqual(CatalogURL.address(" example.com/guide ")?.absoluteString,
                       "https://example.com/guide")
        XCTAssertNil(CatalogURL.address("example.com/not valid"))
        XCTAssertNil(CatalogURL.address("http://example.com"))
        XCTAssertNil(CatalogURL.address("https://user:password@example.com"))
    }
}
