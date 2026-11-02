import SwiftUI

/// Açık çentikteki oynatıcı: kapak, bilgi, ilerleme çubuğu, kontroller.
struct MediaPlayerView: View {
    @ObservedObject var media: MediaController

    var body: some View {
        if let info = media.info {
            player(info)
        } else {
            emptyState
        }
    }

    private func player(_ info: MediaInfo) -> some View {
        HStack(spacing: 14) {
            Button { media.openPlayerApp() } label: {
                ArtworkView(image: media.artwork, size: 84, cornerRadius: 14)
                    .shadow(color: Color(nsColor: media.artworkColor).opacity(0.45), radius: 12, y: 4)
                    .scaleEffect(info.isPlaying ? 1 : 0.92)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: info.isPlaying)
            }
            .buttonStyle(.plain)
            .help("\(AppIconCache.name(for: info.appBundleID)) uygulamasını aç")

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Text(info.artist.isEmpty ? info.album : info.artist)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    EqualizerView(isPlaying: info.isPlaying, color: Color(nsColor: media.artworkColor))
                        .frame(width: 22, height: 16)
                }
                ProgressScrubber(info: info, tint: Color(nsColor: media.artworkColor)) { media.seek(to: $0) }
                controls(info)
            }
        }
    }

    private func controls(_ info: MediaInfo) -> some View {
        HStack(spacing: 22) {
            Spacer(minLength: 0)
            IconButton(symbol: "backward.fill", size: 15, help: "Önceki") { media.previous() }
            IconButton(symbol: info.isPlaying ? "pause.fill" : "play.fill", size: 20, help: "Oynat/Duraklat") { media.playPause() }
                .contentTransition(.symbolEffect(.replace))
            IconButton(symbol: "forward.fill", size: 15, help: "Sonraki") { media.next() }
            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 14) {
            ArtworkView(image: nil, size: 84, cornerRadius: 14)
            VStack(alignment: .leading, spacing: 4) {
                Text("Şu an çalan yok")
                    .font(.system(size: 14, weight: .semibold))
                Text("Müzik veya Spotify'da bir şey çal; burada görünür.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Sürüklenebilir ilerleme çubuğu. Konumu saniyede bir tahmin ederek akıtır (oynatıcıyı sürekli sorgulamaz).
struct ProgressScrubber: View {
    let info: MediaInfo
    let tint: Color
    let onSeek: (TimeInterval) -> Void
    @State private var dragProgress: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let position = info.estimatedPosition(at: context.date)
            let progress = dragProgress ?? (info.duration > 0 ? position / info.duration : 0)
            VStack(spacing: 3) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18))
                        Capsule().fill(tint)
                            .frame(width: proxy.size.width * CGFloat(min(1, max(0, progress))))
                    }
                    .frame(height: dragProgress == nil ? 5 : 7)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragProgress = min(1, max(0, value.location.x / max(1, proxy.size.width)))
                        }
                        .onEnded { _ in
                            if let p = dragProgress, info.duration > 0 { onSeek(p * info.duration) }
                            dragProgress = nil
                        })
                }
                .frame(height: 10)
                .animation(.easeOut(duration: 0.15), value: dragProgress == nil)

                HStack {
                    Text(TimeFormatting.clock(dragProgress.map { $0 * info.duration } ?? position))
                    Spacer()
                    Text(info.duration > 0 ? "-" + TimeFormatting.clock(max(0, info.duration - position)) : "")
                }
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}
