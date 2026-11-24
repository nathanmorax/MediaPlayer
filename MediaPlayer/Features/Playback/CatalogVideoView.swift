import AVKit
import SwiftUI

struct CatalogVideoView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        Color.black
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                if let player {
                    if player.currentItem?.status == .failed {
                        ContentUnavailableView("No se pudo reproducir el video", systemImage: "play.slash")
                    } else {
                        VideoPlayer(player: player)
                    }
                } else {
                    ProgressView()
                }
            }
            .task(id: url) {
                player = AVPlayer(url: url)
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
}
