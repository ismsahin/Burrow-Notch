import XCTest
@testable import Burrow

final class NotchGeometryTests: XCTestCase {
    func test_physicalNotch_widthIsScreenMinusAuxiliaryAreas() {
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            safeAreaTop: 38, leftAuxWidth: 662, rightAuxWidth: 665, menuBarHeight: 38
        )
        XCTAssertTrue(geometry.hasPhysicalNotch)
        XCTAssertEqual(geometry.notchSize, CGSize(width: 185, height: 38))
    }

    func test_noNotch_fallsBackToVirtualNotchWithMenuBarHeight() {
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            safeAreaTop: 0, leftAuxWidth: nil, rightAuxWidth: nil, menuBarHeight: 25
        )
        XCTAssertFalse(geometry.hasPhysicalNotch)
        XCTAssertEqual(geometry.notchSize, CGSize(width: NotchGeometry.fallbackNotchWidth, height: 25))
    }

    func test_windowFrame_isTopCenteredOnSecondaryScreen() {
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 1512, y: 0, width: 1920, height: 1080),
            safeAreaTop: 0, leftAuxWidth: nil, rightAuxWidth: nil, menuBarHeight: 0
        )
        let frame = geometry.windowFrame
        XCTAssertEqual(frame.midX, 1512 + 960, accuracy: 0.001)
        XCTAssertEqual(frame.maxY, 1080, accuracy: 0.001)
        XCTAssertEqual(geometry.notchSize.height, NotchGeometry.fallbackNotchHeight)
    }

    func test_topCenteredRect_includesPaddingOnSidesAndBottomOnly() {
        let geometry = NotchGeometry.make(screenFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
                                          safeAreaTop: 0, leftAuxWidth: nil, rightAuxWidth: nil, menuBarHeight: 30)
        let rect = geometry.topCenteredRect(size: CGSize(width: 200, height: 30), padding: 5)
        XCTAssertEqual(rect, CGRect(x: 395, y: 765, width: 210, height: 35))
    }
}

final class ActivityResolverTests: XCTestCase {
    func test_noTransient_showsMediaWhenActive() {
        XCTAssertEqual(ActivityResolver.resolve(transient: nil, isMediaActive: true), .media)
        XCTAssertEqual(ActivityResolver.resolve(transient: nil, isMediaActive: false), .none)
    }

    func test_transientHUD_overridesMedia() {
        let hud = LiveActivity.hud(kind: .volume(muted: false), value: 0.5)
        XCTAssertEqual(ActivityResolver.resolve(transient: hud, isMediaActive: true), hud)
    }

    func test_sameKindUpdate_alwaysReplaces() {
        let a = LiveActivity.hud(kind: .volume(muted: false), value: 0.2)
        let b = LiveActivity.hud(kind: .volume(muted: false), value: 0.3)
        XCTAssertTrue(ActivityResolver.shouldReplace(current: a, with: b))
    }

    func test_lowerPriority_doesNotReplaceHigher() {
        let hud = LiveActivity.hud(kind: .brightness, value: 0.5)
        let device = LiveActivity.device(name: "AirPods", connected: true)
        XCTAssertFalse(ActivityResolver.shouldReplace(current: hud, with: device))
        XCTAssertTrue(ActivityResolver.shouldReplace(current: device, with: hud))
    }

    func test_volumeAndBrightness_areDifferentKinds() {
        XCTAssertFalse(LiveActivity.hud(kind: .brightness, value: 0).isSameKind(as: .hud(kind: .volume(muted: true), value: 0)))
    }

    func test_transientActivities_haveDurations_persistentDoNot() {
        XCTAssertNil(LiveActivity.media.displayDuration)
        XCTAssertNil(LiveActivity.none.displayDuration)
        XCTAssertNotNil(LiveActivity.charging(percent: 50, isCharging: true).displayDuration)
    }
}

final class MediaInfoParserTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 1000)

    func test_parsesMusicFields() throws {
        let info = try XCTUnwrap(MediaInfoParser.parse(
            fields: ["playing", "Emagination", "Miami Horror", "Illumination", "245,5", "12,25", "ABC"],
            player: .music, durationIsMilliseconds: false, now: now))
        XCTAssertEqual(info.title, "Emagination")
        XCTAssertEqual(info.duration, 245.5, accuracy: 0.001)
        XCTAssertEqual(info.position, 12.25, accuracy: 0.001)
        XCTAssertTrue(info.isPlaying)
        XCTAssertEqual(info.trackID, "ABC")
    }

    func test_spotifyDurationMilliseconds_isConverted() throws {
        let info = try XCTUnwrap(MediaInfoParser.parse(
            fields: ["paused", "Song", "Artist", "Album", "180000", "30.0", "spotify:track:1"],
            player: .spotify, durationIsMilliseconds: true, now: now))
        XCTAssertEqual(info.duration, 180, accuracy: 0.001)
        XCTAssertFalse(info.isPlaying)
    }

    func test_stoppedOrEmpty_returnsNil() {
        XCTAssertNil(MediaInfoParser.parse(fields: ["stopped", "", "", "", "0", "0", ""], player: .music, durationIsMilliseconds: false))
        XCTAssertNil(MediaInfoParser.parse(fields: ["playing", "  ", "a", "b", "1", "0", "x"], player: .music, durationIsMilliseconds: false))
        XCTAssertNil(MediaInfoParser.parse(fields: ["playing"], player: .music, durationIsMilliseconds: false))
    }

    func test_positionIsClampedToDuration() throws {
        let info = try XCTUnwrap(MediaInfoParser.parse(
            fields: ["playing", "S", "A", "B", "100", "150", "id"], player: .music, durationIsMilliseconds: false, now: now))
        XCTAssertEqual(info.position, 100)
    }

    func test_estimatedPosition_advancesOnlyWhilePlaying() throws {
        let playing = try XCTUnwrap(MediaInfoParser.parse(
            fields: ["playing", "S", "A", "B", "100", "10", "id"], player: .music, durationIsMilliseconds: false, now: now))
        XCTAssertEqual(playing.estimatedPosition(at: now.addingTimeInterval(5)), 15, accuracy: 0.001)
        XCTAssertEqual(playing.estimatedPosition(at: now.addingTimeInterval(500)), 100, accuracy: 0.001)

        let paused = try XCTUnwrap(MediaInfoParser.parse(
            fields: ["paused", "S", "A", "B", "100", "10", "id"], player: .music, durationIsMilliseconds: false, now: now))
        XCTAssertEqual(paused.estimatedPosition(at: now.addingTimeInterval(5)), 10, accuracy: 0.001)
    }

    func test_missingTrackID_fallsBackToTitleArtist() throws {
        let info = try XCTUnwrap(MediaInfoParser.parse(
            fields: ["playing", "S", "A", "B", "100", "10", ""], player: .music, durationIsMilliseconds: false))
        XCTAssertEqual(info.trackID, "S-A")
    }
}

final class TimeFormattingTests: XCTestCase {
    func test_clockFormats() {
        XCTAssertEqual(TimeFormatting.clock(0), "0:00")
        XCTAssertEqual(TimeFormatting.clock(75), "1:15")
        XCTAssertEqual(TimeFormatting.clock(3725), "1:02:05")
        XCTAssertEqual(TimeFormatting.clock(.nan), "-:--")
        XCTAssertEqual(TimeFormatting.clock(-1), "-:--")
    }
}

final class BatteryStateTests: XCTestCase {
    func test_parsesInternalBattery() {
        let state = BatteryState.parse([
            "Type": "InternalBattery", "Current Capacity": 54, "Max Capacity": 100,
            "Is Charging": true, "Power Source State": "AC Power",
        ])
        XCTAssertEqual(state, BatteryState(percent: 54, isCharging: true, isPluggedIn: true, hasBattery: true))
    }

    func test_nonBatterySource_isUnknown() {
        XCTAssertEqual(BatteryState.parse(["Type": "UPS"]), .unknown)
        XCTAssertEqual(BatteryState.parse(nil), .unknown)
    }

    func test_percentIsClamped() {
        let state = BatteryState.parse(["Type": "InternalBattery", "Current Capacity": 120, "Max Capacity": 100])
        XCTAssertEqual(state.percent, 100)
    }
}

final class HUDSymbolTests: XCTestCase {
    func test_volumeSymbols() {
        XCTAssertEqual(HUDSymbol.name(for: .volume(muted: true), value: 0.8), "speaker.slash.fill")
        XCTAssertEqual(HUDSymbol.name(for: .volume(muted: false), value: 0.1), "speaker.wave.1.fill")
        XCTAssertEqual(HUDSymbol.name(for: .volume(muted: false), value: 0.9), "speaker.wave.3.fill")
    }

    func test_deviceSymbols() {
        XCTAssertEqual(DeviceSymbol.name(for: "İsmail's AirPods Pro"), "airpodspro")
        XCTAssertEqual(DeviceSymbol.name(for: "Magic Keyboard"), "keyboard")
        XCTAssertEqual(DeviceSymbol.name(for: "Bilinmeyen"), "dot.radiowaves.left.and.right")
    }
}
