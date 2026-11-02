import XCTest
@testable import Burrow

final class ShelfLogicTests: XCTestCase {
    private func url(_ name: String) -> URL { URL(fileURLWithPath: "/tmp/burrow-tests/\(name)") }

    func test_adding_dedupesAndPutsNewestFirst() {
        let first = ShelfStore.adding([url("a.txt"), url("b.txt")], to: [])
        XCTAssertEqual(first.map(\.name), ["b.txt", "a.txt"])

        let second = ShelfStore.adding([url("a.txt"), url("c.txt")], to: first)
        XCTAssertEqual(second.map(\.name), ["c.txt", "b.txt", "a.txt"])
    }

    func test_adding_dedupesWithinSameBatch_andStandardizesPaths() {
        let items = ShelfStore.adding([url("a.txt"), URL(fileURLWithPath: "/tmp/burrow-tests/./a.txt")], to: [])
        XCTAssertEqual(items.count, 1)
    }

    func test_adding_respectsMaxItems() {
        let many = (0..<(ShelfStore.maxItems + 5)).map { url("f\($0)") }
        XCTAssertEqual(ShelfStore.adding(many, to: []).count, ShelfStore.maxItems)
    }

    func test_removing_doesNotMutateOriginal() {
        let items = ShelfStore.adding([url("a"), url("b")], to: [])
        let removed = ShelfStore.removing(id: items[0].id, from: items)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(removed.count, 1)
    }

    func test_pruned_dropsMissingFiles() {
        let items = ShelfStore.adding([url("keep"), url("gone")], to: [])
        let pruned = ShelfStore.pruned(items) { $0.lastPathComponent == "keep" }
        XCTAssertEqual(pruned.map(\.name), ["keep"])
    }

    @MainActor
    func test_store_persistsAcrossInstances() {
        let suite = "BurrowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = ShelfStore(defaults: defaults, fileExists: { _ in true })
        store.add([url("x.pdf")])
        let reloaded = ShelfStore(defaults: defaults, fileExists: { _ in true })
        XCTAssertEqual(reloaded.items.map(\.name), ["x.pdf"])

        let pruning = ShelfStore(defaults: defaults, fileExists: { _ in false })
        XCTAssertTrue(pruning.items.isEmpty)
    }

    @MainActor
    func test_store_ignoresNonFileURLs() {
        let suite = "BurrowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShelfStore(defaults: defaults, fileExists: { _ in true })
        store.add([URL(string: "https://example.com/a.png")!])
        XCTAssertTrue(store.items.isEmpty)
    }
}

final class AppSettingsTests: XCTestCase {
    func test_defaults_andPersistence() {
        let suite = "BurrowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.openMode, .hover)
        XCTAssertTrue(settings.proximityEffect)
        XCTAssertEqual(settings.displayMode, .notched)
        XCTAssertFalse(settings.replaceSystemHUD, "Erişilebilirlik isteyen özellik varsayılan kapalı olmalı")
        XCTAssertEqual(settings.lowBatteryThreshold, 20)

        settings.enableMirror = false
        XCTAssertFalse(AppSettings(defaults: defaults).enableMirror)
    }

    func test_legacySettings_areMigrated() {
        let suite = "BurrowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: AppSettings.Key.legacyHoverToExpand)
        defaults.set(true, forKey: AppSettings.Key.legacyShowOnAllDisplays)
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.openMode, .click)
        XCTAssertEqual(settings.displayMode, .all)
    }

    func test_newModes_persist() {
        let suite = "BurrowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.openMode = .click
        settings.displayMode = .primary
        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.openMode, .click)
        XCTAssertEqual(reloaded.displayMode, .primary)
    }

    func test_lowBatteryThreshold_isClamped() {
        let suite = "BurrowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(99, forKey: AppSettings.Key.lowBatteryThreshold)
        XCTAssertEqual(AppSettings(defaults: defaults).lowBatteryThreshold, 50)
    }
}

final class PlayerScriptsTests: XCTestCase {
    func test_seekCommand_usesDotDecimalRegardlessOfLocale() {
        let script = PlayerScripts.command(.seek(12.5), for: .music)
        XCTAssertTrue(script.contains("set player position to 12.50"))
        XCTAssertTrue(script.contains("com.apple.Music"))
    }

    func test_negativeSeek_isClampedToZero() {
        XCTAssertTrue(PlayerScripts.command(.seek(-4), for: .spotify).contains("to 0.00"))
    }

    func test_allScripts_haveTimeout() {
        for player in MediaPlayer.allCases {
            XCTAssertTrue(PlayerScripts.status(for: player).contains("with timeout"))
            XCTAssertTrue(PlayerScripts.artwork(for: player).contains("with timeout"))
            XCTAssertTrue(PlayerScripts.command(.next, for: player).contains("with timeout"))
        }
    }

    /// Regresyon: `st` gibi ayrılmış sözcükler betiği sessizce bozuyordu. Müzik her Mac'te kurulu olduğundan
    /// betikleri gerçekten derleriz (Spotify CI'da kurulu olmayabilir, o yüzden yalnızca Müzik).
    func test_musicScripts_compile() {
        let scripts = [PlayerScripts.status(for: .music), PlayerScripts.artwork(for: .music),
                       PlayerScripts.command(.playPause, for: .music), PlayerScripts.command(.seek(12.5), for: .music)]
        for source in scripts {
            var error: NSDictionary?
            NSAppleScript(source: source)?.compileAndReturnError(&error)
            XCTAssertNil(error, "Derlenemedi:\n\(source)")
        }
    }

    func test_allScripts_neverLaunchClosedPlayer() {
        for player in MediaPlayer.allCases {
            let guardLine = "if application id \"\(player.bundleID)\" is running then"
            XCTAssertTrue(PlayerScripts.status(for: player).hasPrefix(guardLine))
            XCTAssertTrue(PlayerScripts.artwork(for: player).hasPrefix(guardLine))
            XCTAssertTrue(PlayerScripts.command(.playPause, for: player).hasPrefix(guardLine))
        }
    }
}
