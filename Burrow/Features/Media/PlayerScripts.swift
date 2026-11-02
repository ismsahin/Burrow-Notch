import Foundation

/// Oynatıcı başına AppleScript kaynakları.
/// Her betik `if application id … is running` ile korunur: kullanıcı oynatıcıyı kapattıktan sonra
/// kuyrukta bekleyen bir yoklama onu **yeniden açmaz**. Ayrıca 2 sn zaman aşımı vardır.
enum PlayerScripts {
    /// Gövdeyi "uygulama açıksa" ve zaman aşımı korumasıyla sarar. Kapalıysa boş liste döner.
    static func guarded(_ player: MediaPlayer, _ body: String) -> String {
        """
        if application id "\(player.bundleID)" is running then
            with timeout of 2 seconds
                tell application id "\(player.bundleID)"
        \(body)
                end tell
            end timeout
        end if
        return {}
        """
    }

    static func status(for player: MediaPlayer) -> String {
        let idProperty = player == .music ? "persistent ID of t" : "id of t"
        return guarded(player, """
                    set playerState to player state as text
                    if playerState is "stopped" then return {"stopped", "", "", "", "0", "0", ""}
                    set t to current track
                    return {playerState, name of t, artist of t, album of t, (duration of t) as text, (player position) as text, \(idProperty)}
        """)
    }

    static func artwork(for player: MediaPlayer) -> String {
        switch player {
        case .music:
            return guarded(player, """
                    try
                        return raw data of artwork 1 of current track
                    on error
                        return ""
                    end try
            """)
        case .spotify:
            return guarded(player, "            return artwork url of current track")
        }
    }

    enum Command {
        case playPause, next, previous
        case seek(TimeInterval)
    }

    static func command(_ command: Command, for player: MediaPlayer) -> String {
        let body: String
        switch command {
        case .playPause: body = "playpause"
        case .next: body = "next track"
        case .previous: body = "previous track"
        case .seek(let seconds):
            // Yerel ayardan bağımsız nokta ayraçlı sayı
            body = "set player position to \(String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), max(0, seconds)))"
        }
        return guarded(player, "            \(body)")
    }
}
