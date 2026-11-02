import AppKit
import Combine

/// Sistem geneli "şu an çalan" (YouTube/Chrome/Safari, Music, Spotify, podcast… hepsi).
///
/// macOS 15.4+ MediaRemote'u yalnızca `com.apple.*` süreçlere açıyor; Apple imzalı `/usr/bin/perl` içinde çalışan
/// mediaremote-adapter (BSD-3, `Vendor/`) bu bilgiyi JSON akışı olarak verir. Bkz. karar 0009.
/// Adaptör yoksa ya da çalışmazsa `isAvailable == false` olur ve Müzik/Spotify AppleScript yoluna düşülür.
@MainActor
final class MediaRemoteSource: ObservableObject {
    enum Status: Equatable { case unavailable, running, failed }

    @Published private(set) var status: Status = .unavailable
    @Published private(set) var nowPlaying: RemoteNowPlaying?

    private let scriptURL: URL?
    private let frameworkURL: URL?
    private var process: Process?
    private var buffer = Data()
    private var state: [String: Any] = [:]
    private var restarts = 0
    private let parseQueue = DispatchQueue(label: "com.ismsahin.Burrow.mediaremote")
    private static let maxRestarts = 3

    init(bundle: Bundle = .main) {
        scriptURL = bundle.url(forResource: "mediaremote-adapter", withExtension: "pl")
        frameworkURL = bundle.privateFrameworksURL?.appendingPathComponent("MediaRemoteAdapter.framework")
    }

    var isAvailable: Bool {
        // Birim testlerinde arka plan akış süreci başlatılmaz.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              ProcessInfo.processInfo.environment["XCTestBundlePath"] == nil else { return false }
        guard let scriptURL, let frameworkURL else { return false }
        return FileManager.default.fileExists(atPath: scriptURL.path) && FileManager.default.fileExists(atPath: frameworkURL.path)
    }

    func start() {
        guard process == nil, isAvailable, let scriptURL, let frameworkURL else { return }
        if restarts == 0 { Self.killOrphans(frameworkPath: frameworkURL.path) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptURL.path, frameworkURL.path, "stream", "--debounce=60"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.consume(chunk) } }
        }
        process.terminationHandler = { [weak self] finished in
            let code = finished.terminationStatus
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.terminated(code: code) } }
        }
        do {
            try process.run()
            self.process = process
            status = .running
        } catch {
            NSLog("Burrow: mediaremote-adapter başlatılamadı: \(error.localizedDescription)")
            status = .failed
        }
    }

    func stop() {
        process?.terminationHandler = nil
        (process?.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        if status == .running { status = .unavailable }
    }

    /// Önceki bir çalıştırmadan (ör. çökme) kalmış akış süreçlerini kapat. Yalnızca bizim framework yolumuzla
    /// başlatılan `stream` süreçleri eşleşir; başka hiçbir süreç etkilenmez.
    private static func killOrphans(frameworkPath: String) {
        let pkill = Process()
        pkill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        pkill.arguments = ["-U", String(getuid()), "-f", "\(frameworkPath) stream"]
        pkill.standardOutput = FileHandle.nullDevice
        pkill.standardError = FileHandle.nullDevice
        try? pkill.run()
        pkill.waitUntilExit()
    }

    // MARK: - Komutlar

    enum Command: Int {
        case togglePlayPause = 2, next = 4, previous = 5
    }

    func send(_ command: Command) { runOnce(["send", String(command.rawValue)]) }

    func seek(to seconds: TimeInterval) {
        runOnce(["seek", String(Int64(max(0, seconds) * 1_000_000))])
    }

    private func runOnce(_ arguments: [String]) {
        guard let scriptURL, let frameworkURL else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptURL.path, frameworkURL.path] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch {
            NSLog("Burrow: medya komutu gönderilemedi: \(error.localizedDescription)")
        }
    }

    // MARK: - Akış

    private func consume(_ chunk: Data) {
        buffer.append(chunk)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            guard !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let payload = object["payload"] as? [String: Any] else { continue }
            state = NowPlayingPayload.merged(state, with: payload, isDiff: object["diff"] as? Bool ?? false)
            restarts = 0
            let snapshot = state
            parseQueue.async {
                let parsed = NowPlayingPayload.parse(snapshot)
                DispatchQueue.main.async { [weak self] in
                    MainActor.assumeIsolated { if self?.nowPlaying != parsed { self?.nowPlaying = parsed } }
                }
            }
        }
        // Bozuk akışa karşı sınır
        if buffer.count > 8_000_000 { buffer.removeAll() }
    }

    private func terminated(code: Int32) {
        process = nil
        guard restarts < Self.maxRestarts, code == 0 || code == 15 else {
            NSLog("Burrow: mediaremote-adapter çıktı (kod \(code)); AppleScript yoluna geçiliyor")
            status = .failed
            nowPlaying = nil
            return
        }
        restarts += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(restarts)) { [weak self] in self?.start() }
    }
}

/// Adaptörün bildirdiği çalan medya (değer tipi).
struct RemoteNowPlaying: Equatable {
    let bundleID: String
    let trackID: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let elapsed: TimeInterval
    let isPlaying: Bool
    let timestamp: Date
    let artworkData: Data?
}

/// Saf JSON birleştirme/ayrıştırma (test edilir).
enum NowPlayingPayload {
    /// `diff == true` ise yalnızca değişen anahtarlar gelir; `NSNull` anahtarın kalktığını belirtir.
    static func merged(_ state: [String: Any], with payload: [String: Any], isDiff: Bool) -> [String: Any] {
        guard isDiff else { return payload.filter { !($0.value is NSNull) } }
        var result = state
        for (key, value) in payload {
            if value is NSNull { result.removeValue(forKey: key) } else { result[key] = value }
        }
        return result
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let isoFormatterPlain = ISO8601DateFormatter()

    static func parse(_ state: [String: Any]) -> RemoteNowPlaying? {
        guard let bundle = (state["parentApplicationBundleIdentifier"] as? String) ?? (state["bundleIdentifier"] as? String),
              let title = state["title"] as? String, !title.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let artist = state["artist"] as? String ?? ""
        let timestampText = state["timestamp"] as? String ?? ""
        let timestamp = isoFormatter.date(from: timestampText) ?? isoFormatterPlain.date(from: timestampText) ?? Date()
        let identifier = (state["contentItemIdentifier"] as? String) ?? (state["uniqueIdentifier"] as? String)
            ?? (state["uniqueIdentifier"] as? NSNumber)?.stringValue ?? "\(bundle)|\(title)|\(artist)"
        let artwork = (state["artworkData"] as? String).flatMap { Data(base64Encoded: $0, options: .ignoreUnknownCharacters) }
        return RemoteNowPlaying(
            bundleID: bundle,
            trackID: identifier,
            title: title,
            artist: artist,
            album: state["album"] as? String ?? "",
            duration: max(0, (state["duration"] as? NSNumber)?.doubleValue ?? 0),
            elapsed: max(0, (state["elapsedTime"] as? NSNumber)?.doubleValue ?? 0),
            isPlaying: (state["playing"] as? Bool) ?? false,
            timestamp: timestamp,
            artworkData: artwork
        )
    }
}
