//
//  MediaPlayerApp.swift
//  MediaPlayer
//
//  Created by Satori Tech 341 on 23/11/26.
//

import AVFoundation
import SwiftUI

@main
struct MediaPlayerApp: App {
    private let analyzer = WebCatalogAnalyzer()
    @State private var favorites = FavoritesStore()

    init() {
        AVPlayer.isObservationEnabled = true
    }

    var body: some Scene {
        WindowGroup("MediaPlayer") {
            ContentView(analyzer: analyzer, favorites: favorites)
                .preferredColorScheme(.dark)
        }
        #if os(macOS)
        .defaultSize(width: 1080, height: 740)
        #endif
    }
}
