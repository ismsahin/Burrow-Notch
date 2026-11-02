import AppKit
import Combine
import CoreImage

/// Çalan medyayı izler ve kontrol eder.
/// Güncelleme tetikleyicileri: oynatıcının dağıtık bildirimi (anında) + hafif periyodik yoklama (konum kayması için).
/// Hiçbir oynatıcı açık değilken yoklama yapılmaz.
@MainActor
final class MediaController: ObservableObject {
    @Published private(set) var info: MediaInfo?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var artworkColor: NSColor = .white

    private let bridge: AppleScriptBridge
    private var timer: Timer?
    private var artworkTrackID: String?
    private var lastRefresh: [MediaPlayer: MediaInfo] = [:]
    private var observers: [NSObjectProtocol] = []

    private static let playingPollInterval: TimeInterval = 3
    private static let idlePollInterval: TimeInterval = 8
    private static let artworkHosts: Set<String> = ["i.scdn.co", "mosaic.scdn.co", "image-cdn-ak.spotifycdn.com", "image-cdn-fa.spotifycdn.com"]

    init(bridge: AppleScriptBridge = .shared) {
        self.bridge = bridge
        let distributed = DistributedNotificationCenter.default()
        for player in MediaPlayer.allCases {
            observers.append(distributed.addObserver(forName: player.changeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh(player) }
            })
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.playersChanged() }
            })
        }
        playersChanged()
    }

    deinit {
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        timer?.invalidate()
    }

    var isPlaying: Bool { info?.isPlaying ?? false }

    // MARK: - Kontroller

    func playPause() { send(.playPause, optimisticToggle: true) }
    func next() { send(.next) }
    func previous() { send(.previous) }

    func seek(to seconds: TimeInterval) {
        guard let info else { return }
        bridge.run(PlayerScripts.command(.seek(seconds), for: info.player), cacheable: false) { [weak self] _ in
            self?.refresh(info.player)
        }
        self.info = MediaInfo(player: info.player, trackID: info.trackID, title: info.title, artist: info.artist,
                              album: info.album, duration: info.duration, position: seconds,
                              isPlaying: info.isPlaying, capturedAt: Date())
    }

    func openPlayerApp() {
        guard let player = info?.player,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func send(_ command: PlayerScripts.Command, optimisticToggle: Bool = false) {
        guard let info, info.player.isRunning else { return }
        if optimisticToggle {
            // Anında geri bildirim; gerçek durum bildirim/yoklama ile düzeltilir.
            self.info = MediaInfo(player: info.player, trackID: info.trackID, title: info.title, artist: info.artist,
                                  album: info.album, duration: info.duration, position: info.estimatedPosition(),
                                  isPlaying: !info.isPlaying, capturedAt: Date())
        }
        bridge.run(PlayerScripts.command(command, for: info.player)) { [weak self] _ in
            self?.refresh(info.player)
        }
    }

    // MARK: - Durum

    private func playersChanged() {
        let running = MediaPlayer.allCases.filter(\.isRunning)
        for player in MediaPlayer.allCases where !running.contains(player) {
            lastRefresh[player] = nil
        }
        if running.isEmpty {
            timer?.invalidate()
            timer = nil
            apply(nil)
            return
        }
        running.forEach(refresh)
        reschedule()
    }

    private func reschedule() {
        timer?.invalidate()
        let interval = isPlaying ? Self.playingPollInterval : Self.idlePollInterval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                MediaPlayer.allCases.filter(\.isRunning).forEach { self?.refresh($0) }
            }
        }
        timer.tolerance = interval * 0.3
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func refresh(_ player: MediaPlayer) {
        guard player.isRunning else {
            lastRefresh[player] = nil
            chooseActive()
            return
        }
        bridge.run(PlayerScripts.status(for: player)) { [weak self] descriptor in
            guard let self else { return }
            let parsed = descriptor.flatMap {
                MediaInfoParser.parse(fields: $0.stringList, player: player, durationIsMilliseconds: player == .spotify)
            }
            self.lastRefresh[player] = parsed
            self.chooseActive()
        }
    }

    /// Çalan oynatıcıyı tercih et; yoksa mevcut duraklatılmış oynatıcıda kal.
    private func chooseActive() {
        let candidates = Array(lastRefresh.values)
        let chosen = candidates.first(where: \.isPlaying)
            ?? candidates.first(where: { $0.player == info?.player })
            ?? candidates.first
        let wasPlaying = isPlaying
        apply(chosen)
        if wasPlaying != isPlaying { reschedule() }
    }

    private func apply(_ newInfo: MediaInfo?) {
        if newInfo != info { info = newInfo }
        guard let newInfo else {
            artwork = nil
            artworkTrackID = nil
            return
        }
        if newInfo.trackID != artworkTrackID {
            artworkTrackID = newInfo.trackID
            loadArtwork(for: newInfo)
        }
    }

    // MARK: - Kapak

    private func loadArtwork(for info: MediaInfo) {
        bridge.run(PlayerScripts.artwork(for: info.player)) { [weak self] descriptor in
            guard let self, self.artworkTrackID == info.trackID, let descriptor else { return }
            switch info.player {
            case .music:
                self.setArtwork(NSImage(data: descriptor.data), trackID: info.trackID)
            case .spotify:
                self.fetchRemoteArtwork(descriptor.stringValue, trackID: info.trackID)
            }
        }
    }

    private func fetchRemoteArtwork(_ urlString: String?, trackID: String) {
        // Güvenlik: yalnızca https ve bilinen Spotify CDN alan adları.
        guard let urlString, let url = URL(string: urlString), url.scheme == "https",
              let host = url.host, Self.artworkHosts.contains(host) else {
            setArtwork(nil, trackID: trackID)
            return
        }
        Task {
            let image: NSImage?
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                let ok = (response as? HTTPURLResponse)?.statusCode == 200 && data.count < 5_000_000
                image = ok ? NSImage(data: data) : nil
            } catch {
                image = nil
            }
            self.setArtwork(image, trackID: trackID)
        }
    }

    private func setArtwork(_ image: NSImage?, trackID: String) {
        guard artworkTrackID == trackID else { return }
        artwork = image
        artworkColor = image.flatMap(ArtworkColor.average) ?? .white
    }
}

enum ArtworkColor {
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    /// Kapağın ortalama rengini, okunabilir olacak kadar parlak döndürür.
    static func average(of image: NSImage) -> NSColor? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let input = CIImage(cgImage: cg)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: input,
            kCIInputExtentKey: CIVector(cgRect: input.extent),
        ]), let output = filter.outputImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        let color = NSColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255,
                            blue: CGFloat(pixel[2]) / 255, alpha: 1)
        return brighten(color)
    }

    static func brighten(_ color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.sRGB) else { return color }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(hue: h, saturation: min(s, 0.85), brightness: max(b, 0.75), alpha: 1)
    }
}
