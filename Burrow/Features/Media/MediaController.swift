import AppKit
import Combine
import CoreImage

/// Çalan medyayı izler ve kontrol eder.
///
/// Birincil kaynak: sistem geneli MediaRemote (`MediaRemoteSource`): YouTube/Chrome/Safari dahil her şey.
/// Yedek: Müzik ve Spotify için AppleScript + dağıtık bildirim (adaptör yoksa veya çalışmazsa).
@MainActor
final class MediaController: ObservableObject {
    @Published private(set) var info: MediaInfo?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var artworkColor: NSColor = .white

    private let bridge: AppleScriptBridge
    private let remote: MediaRemoteSource
    private var usingRemote = false
    private var appleScriptStarted = false
    private var timer: Timer?
    private var artworkTrackID: String?
    private var remoteArtworkLoaded = false
    private var lastRefresh: [MediaPlayer: MediaInfo] = [:]
    private var observers: [NSObjectProtocol] = []
    private var bag = Set<AnyCancellable>()

    private static let playingPollInterval: TimeInterval = 3
    private static let idlePollInterval: TimeInterval = 8
    private static let artworkHosts: Set<String> = ["i.scdn.co", "mosaic.scdn.co", "image-cdn-ak.spotifycdn.com", "image-cdn-fa.spotifycdn.com"]

    init(bridge: AppleScriptBridge = .shared, remote: MediaRemoteSource? = nil) {
        self.bridge = bridge
        self.remote = remote ?? MediaRemoteSource()
        if self.remote.isAvailable {
            startRemote()
        } else {
            startAppleScript()
        }
    }

    deinit {
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        timer?.invalidate()
    }

    var isPlaying: Bool { info?.isPlaying ?? false }

    /// Uygulama kapanırken arka plan akışını durdur.
    func shutdown() { remote.stop() }
    /// Kaynak: "Sistem geneli" ya da "Müzik ve Spotify".
    var sourceDescription: String { usingRemote ? "Sistem geneli (YouTube, tarayıcılar, tüm oynatıcılar)" : "Müzik ve Spotify" }

    // MARK: - Kontroller

    func playPause() {
        guard let info else { return }
        // Anında geri bildirim; gerçek durum akış/yoklama ile düzeltilir.
        self.info = info.with(position: info.estimatedPosition(), isPlaying: !info.isPlaying)
        if usingRemote { remote.send(.togglePlayPause) } else { sendScript(.playPause) }
    }

    func next() { usingRemote ? remote.send(.next) : sendScript(.next) }
    func previous() { usingRemote ? remote.send(.previous) : sendScript(.previous) }

    func seek(to seconds: TimeInterval) {
        guard let info else { return }
        self.info = info.with(position: seconds, isPlaying: info.isPlaying)
        if usingRemote {
            remote.seek(to: seconds)
        } else if let player = info.player {
            bridge.run(PlayerScripts.command(.seek(seconds), for: player), cacheable: false) { [weak self] _ in
                self?.refresh(player)
            }
        }
    }

    func openPlayerApp() {
        guard let bundleID = info?.appBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: - Sistem geneli kaynak

    private func startRemote() {
        usingRemote = true
        remote.$nowPlaying
            .sink { [weak self] in self?.applyRemote($0) }
            .store(in: &bag)
        remote.$status
            .filter { $0 == .failed }
            .sink { [weak self] _ in
                guard let self, self.usingRemote else { return }
                self.usingRemote = false
                self.apply(nil)
                self.startAppleScript()
            }
            .store(in: &bag)
        remote.start()
    }

    private func applyRemote(_ nowPlaying: RemoteNowPlaying?) {
        guard usingRemote else { return }
        guard let np = nowPlaying else { apply(nil); return }
        let newInfo = MediaInfo(player: MediaPlayer(rawValue: np.bundleID), appBundleID: np.bundleID, trackID: np.trackID,
                                title: np.title, artist: np.artist, album: np.album, duration: np.duration,
                                position: np.duration > 0 ? min(np.elapsed, np.duration) : np.elapsed,
                                isPlaying: np.isPlaying, capturedAt: np.timestamp)
        if newInfo != info { info = newInfo }
        if np.trackID != artworkTrackID {
            artworkTrackID = np.trackID
            remoteArtworkLoaded = false
            setArtwork(nil, trackID: np.trackID)
        }
        // Kapak verisi genelde birkaç saniye sonra gelir.
        if !remoteArtworkLoaded, let data = np.artworkData, let image = NSImage(data: data) {
            remoteArtworkLoaded = true
            setArtwork(image, trackID: np.trackID)
        }
    }

    // MARK: - AppleScript yedeği (Müzik, Spotify)

    private func startAppleScript() {
        guard !appleScriptStarted else { return }
        appleScriptStarted = true
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

    private func sendScript(_ command: PlayerScripts.Command) {
        guard let player = info?.player, player.isRunning else { return }
        bridge.run(PlayerScripts.command(command, for: player)) { [weak self] _ in
            self?.refresh(player)
        }
    }

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
        guard !usingRemote else { return }
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
        if newInfo.trackID != artworkTrackID, let player = newInfo.player {
            artworkTrackID = newInfo.trackID
            loadArtwork(for: newInfo, player: player)
        }
    }

    // MARK: - Kapak

    private func loadArtwork(for info: MediaInfo, player: MediaPlayer) {
        bridge.run(PlayerScripts.artwork(for: player)) { [weak self] descriptor in
            guard let self, self.artworkTrackID == info.trackID, let descriptor else { return }
            switch player {
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
