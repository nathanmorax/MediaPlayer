import AVKit
import SwiftUI

struct CatalogAVPlayerView: View {
    let media: CatalogMedia
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if media.kind == .audio {
                playbackContent
                    .padding(20)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(.white.opacity(0.05), in: .rect(cornerRadius: 9))
            } else {
                Color.black
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay { playbackContent }
                    .clipShape(.rect(cornerRadius: 9))
            }
        }
        .task(id: media.url) {
            let player = AVPlayer(url: media.url)
            self.player = player
            player.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    @ViewBuilder
    private var playbackContent: some View {
        if let player {
            if player.currentItem?.status == .failed {
                ContentUnavailableView("No se pudo reproducir el contenido", systemImage: "play.slash")
            } else if media.kind == .audio {
                AudioTransportView(player: player)
            } else {
                VideoPlayer(player: player)
            }
        } else {
            ProgressView()
        }
    }
}

private struct AudioTransportView: View {
    let player: AVPlayer

    var body: some View {
        let isPlaying = player.timeControlStatus != .paused

        HStack(spacing: 16) {
            Button(isPlaying ? "Pausar" : "Reproducir", systemImage: isPlaying ? "pause.fill" : "play.fill") {
                if isPlaying { player.pause() } else { player.play() }
            }
            .labelStyle(.iconOnly)
            .controlSize(.large)

            if let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0 {
                TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    Slider(value: Binding {
                        let seconds = player.currentTime().seconds
                        return seconds.isFinite ? min(max(seconds, 0), duration) : 0
                    } set: { value in
                        player.seek(to: CMTime(seconds: value, preferredTimescale: 600))
                    }, in: 0...duration) {
                        Text("Posición")
                    }
                    .labelsHidden()
                }
            } else if player.currentItem?.status == .unknown {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
