import AppKit

/// Desteklenen oynatıcılar. AppleScript ile kontrol edilir (bkz. docs/kararlar/0003-medya-kaynagi.md).
enum MediaPlayer: String, CaseIterable, Codable {
    case music = "com.apple.Music"
    case spotify = "com.spotify.client"

    var bundleID: String { rawValue }

    var displayName: String {
        switch self {
        case .music: return "Müzik"
        case .spotify: return "Spotify"
        }
    }

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    /// Oynatıcının yayınladığı "çalan değişti" dağıtık bildirimi (izin gerektirmez).
    var changeNotification: Notification.Name {
        switch self {
        case .music: return Notification.Name("com.apple.Music.playerInfo")
        case .spotify: return Notification.Name("com.spotify.client.PlaybackStateChanged")
        }
    }
}

/// Çalan parça anlık görüntüsü. Değer tipi, değişmez.
struct MediaInfo: Equatable {
    /// AppleScript ile kontrol edilebilen oynatıcı (Müzik/Spotify); tarayıcı vb. için nil.
    let player: MediaPlayer?
    /// Çalan uygulamanın kimliği (ör. com.google.Chrome).
    let appBundleID: String
    let trackID: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let position: TimeInterval
    let isPlaying: Bool
    /// `position` değerinin okunduğu an; arayüz bu andan ileri doğru tahmin yürütür.
    let capturedAt: Date

    func estimatedPosition(at date: Date = Date()) -> TimeInterval {
        guard isPlaying else { return position }
        let elapsed = max(0, date.timeIntervalSince(capturedAt))
        return duration > 0 ? min(duration, position + elapsed) : position + elapsed
    }

    /// Yeni konum/durumla kopya (değişmez güncelleme).
    func with(position: TimeInterval, isPlaying: Bool, at date: Date = Date()) -> MediaInfo {
        MediaInfo(player: player, appBundleID: appBundleID, trackID: trackID, title: title, artist: artist, album: album,
                  duration: duration, position: position, isPlaying: isPlaying, capturedAt: date)
    }

    var progress: Double {
        duration > 0 ? min(1, max(0, position / duration)) : 0
    }
}

/// AppleScript çıktısını `MediaInfo`'ya çeviren saf ayrıştırıcı.
///
/// Beklenen sıra: [durum, ad, sanatçı, albüm, süre(sn), konum(sn), kimlik]
/// Spotify süreyi milisaniye döndürür; `durationIsMilliseconds` ile düzeltilir.
enum MediaInfoParser {
    static func parse(
        fields: [String],
        player: MediaPlayer,
        durationIsMilliseconds: Bool,
        now: Date = Date()
    ) -> MediaInfo? {
        guard fields.count >= 7 else { return nil }
        let state = fields[0].lowercased()
        guard state == "playing" || state == "paused" else { return nil }
        let title = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        let rawDuration = parseNumber(fields[4]) ?? 0
        let duration = durationIsMilliseconds ? rawDuration / 1000 : rawDuration
        let position = max(0, parseNumber(fields[5]) ?? 0)

        return MediaInfo(
            player: player,
            appBundleID: player.bundleID,
            trackID: fields[6].isEmpty ? "\(title)-\(fields[2])" : fields[6],
            title: title,
            artist: fields[2],
            album: fields[3],
            duration: max(0, duration),
            position: duration > 0 ? min(position, duration) : position,
            isPlaying: state == "playing",
            capturedAt: now
        )
    }

    /// AppleScript sayıları yerel ayara göre virgüllü dönebilir ("12,5").
    static func parseNumber(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}

enum TimeFormatting {
    /// 75 -> "1:15", 3725 -> "1:02:05"
    static func clock(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "-:--" }
        let total = Int(seconds.rounded(.down))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
