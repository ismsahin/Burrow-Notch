import XCTest
@testable import Burrow

final class NowPlayingPayloadTests: XCTestCase {
    /// Gerçek adaptör çıktısından (Chrome'da YouTube) alınmış örnek.
    private let youtube: [String: Any] = [
        "artist": "mabelmatiz", "timestamp": "2026-11-02T19:06:06Z",
        "contentItemIdentifier": "BD3AF8BB-CFB9-4DA9-B0A1-032520119803", "title": "Mabel Matiz - Umrumdışı",
        "elapsedTime": 20.47494, "bundleIdentifier": "com.google.Chrome", "playing": false,
        "duration": 240.021, "playbackRate": 0, "album": "",
    ]

    func test_parse_youtubeInChrome() throws {
        let np = try XCTUnwrap(NowPlayingPayload.parse(youtube))
        XCTAssertEqual(np.bundleID, "com.google.Chrome")
        XCTAssertEqual(np.title, "Mabel Matiz - Umrumdışı")
        XCTAssertEqual(np.trackID, "BD3AF8BB-CFB9-4DA9-B0A1-032520119803")
        XCTAssertEqual(np.duration, 240.021, accuracy: 0.001)
        XCTAssertEqual(np.elapsed, 20.47494, accuracy: 0.0001)
        XCTAssertFalse(np.isPlaying)
        XCTAssertEqual(np.timestamp, ISO8601DateFormatter().date(from: "2026-11-02T19:06:06Z"))
        XCTAssertNil(np.artworkData)
        XCTAssertNil(MediaPlayer(rawValue: np.bundleID), "Chrome AppleScript oynatıcısı değil")
    }

    func test_parse_prefersParentBundle_andDecodesArtwork() throws {
        var state = youtube
        state["parentApplicationBundleIdentifier"] = "com.apple.Safari"
        state["artworkData"] = Data([1, 2, 3]).base64EncodedString()
        let np = try XCTUnwrap(NowPlayingPayload.parse(state))
        XCTAssertEqual(np.bundleID, "com.apple.Safari")
        XCTAssertEqual(np.artworkData, Data([1, 2, 3]))
    }

    func test_parse_missingTitle_isNil() {
        var state = youtube
        state["title"] = "  "
        XCTAssertNil(NowPlayingPayload.parse(state))
        XCTAssertNil(NowPlayingPayload.parse([:]))
    }

    func test_merge_diffUpdatesAndRemovesKeys() {
        let merged = NowPlayingPayload.merged(youtube, with: ["playing": true, "album": NSNull()], isDiff: true)
        XCTAssertEqual(merged["playing"] as? Bool, true)
        XCTAssertNil(merged["album"])
        XCTAssertEqual(merged["title"] as? String, "Mabel Matiz - Umrumdışı")
    }

    func test_merge_nonDiffReplacesState() {
        let merged = NowPlayingPayload.merged(youtube, with: ["title": "Yeni", "bundleIdentifier": "com.spotify.client"], isDiff: false)
        XCTAssertEqual(merged.count, 2)
        XCTAssertNil(merged["artist"])
    }

    func test_mediaInfo_withKeepsIdentity() {
        let info = MediaInfo(player: nil, appBundleID: "com.google.Chrome", trackID: "t", title: "a", artist: "b", album: "",
                             duration: 100, position: 10, isPlaying: true, capturedAt: Date())
        let paused = info.with(position: 42, isPlaying: false)
        XCTAssertEqual(paused.appBundleID, "com.google.Chrome")
        XCTAssertEqual(paused.trackID, "t")
        XCTAssertEqual(paused.position, 42)
        XCTAssertFalse(paused.isPlaying)
    }

    @MainActor
    func test_remoteSource_isDisabledUnderTests() {
        XCTAssertFalse(MediaRemoteSource().isAvailable, "Testlerde arka plan perl süreci başlatılmaz")
    }
}
