import XCTest
@testable import Burrow

final class ActivityCarouselTests: XCTestCase {
    func test_auto_newestStartedIsShown() {
        let carousel = ActivityCarousel()
            .setting(.media, active: true)
            .setting(.download, active: true)
        XCTAssertEqual(carousel.selected, .download, "Müzik çalarken indirme başlarsa indirme öne gelir")
        XCTAssertEqual(carousel.count, 2)
    }

    func test_auto_fallsBackWhenSelectedEnds() {
        let carousel = ActivityCarousel()
            .setting(.media, active: true)
            .setting(.download, active: true)
            .setting(.download, active: false)
        XCTAssertEqual(carousel.selected, .media)
    }

    func test_preferred_winsWhenActive() {
        let carousel = ActivityCarousel(preferred: .media)
            .setting(.media, active: true)
            .setting(.download, active: true)
        XCTAssertEqual(carousel.selected, .media)
    }

    func test_preferred_inactive_usesNewest() {
        let carousel = ActivityCarousel(preferred: .calendar)
            .setting(.media, active: true)
            .setting(.timer, active: true)
        XCTAssertEqual(carousel.selected, .timer)
    }

    func test_step_cyclesBothWays() {
        let base = ActivityCarousel()
            .setting(.media, active: true)
            .setting(.download, active: true)
            .setting(.timer, active: true)
        XCTAssertEqual(base.selected, .timer)
        XCTAssertEqual(base.stepped(by: 1).selected, .media)
        XCTAssertEqual(base.stepped(by: -1).selected, .download)
        XCTAssertEqual(base.stepped(by: 1).stepped(by: 1).selected, .download)
    }

    func test_manualChoice_survivesNewActivity_untilItEnds() {
        let manual = ActivityCarousel()
            .setting(.media, active: true)
            .setting(.download, active: true)
            .stepped(by: 1) // → media (elle)
        XCTAssertEqual(manual.selected, .media)
        let withTimer = manual.setting(.timer, active: true)
        XCTAssertEqual(withTimer.selected, .media, "Elle seçim yeni etkinlikle bozulmaz")
        let mediaEnded = withTimer.setting(.media, active: false)
        XCTAssertFalse(mediaEnded.isManual)
        XCTAssertNotNil(mediaEnded.selected)
    }

    func test_singleActivity_stepIsNoop() {
        let carousel = ActivityCarousel().setting(.media, active: true)
        XCTAssertEqual(carousel.stepped(by: 1), carousel)
    }

    func test_empty_selectsNothing() {
        XCTAssertNil(ActivityCarousel().setting(.media, active: true).setting(.media, active: false).selected)
    }

    func test_changingPreference_reselects() {
        let carousel = ActivityCarousel().setting(.media, active: true).setting(.download, active: true)
        XCTAssertEqual(carousel.withPreferred(.media).selected, .media)
    }

    func test_switchingBackToAuto_keepsCurrentDisplay() {
        let carousel = ActivityCarousel(preferred: .media).setting(.media, active: true).setting(.download, active: true)
        XCTAssertEqual(carousel.selected, .media)
        XCTAssertEqual(carousel.withPreferred(nil).selected, .media, "Otomatik'e geçmek ekranı zıplatmaz")
    }

    func test_manualChoice_survivesPreferenceChange() {
        let manual = ActivityCarousel().setting(.media, active: true).setting(.download, active: true).stepped(by: 1)
        XCTAssertEqual(manual.withPreferred(.download).selected, .media)
    }
}

@MainActor
final class ActivityCenterTests: XCTestCase {
    func test_transientOverridesThenStepWorksAfter() {
        let center = ActivityCenter()
        center.update(.media, .media)
        center.update(.download, .download(name: "a", progress: 0.5, count: 1))
        XCTAssertEqual(center.current, .download(name: "a", progress: 0.5, count: 1))
        center.show(.hud(kind: .brightness, value: 0.3))
        XCTAssertEqual(center.current, .hud(kind: .brightness, value: 0.3))
        XCTAssertFalse(center.step(by: 1), "Geçici etkinlik varken kaydırma geçiş yapmaz")
    }

    func test_progressUpdate_doesNotChangeSelection() {
        let center = ActivityCenter()
        center.update(.download, .download(name: "a", progress: 0.1, count: 1))
        center.update(.media, .media)
        XCTAssertEqual(center.current, .media)
        center.update(.download, .download(name: "a", progress: 0.9, count: 1))
        XCTAssertEqual(center.current, .media, "İlerleme güncellemesi seçili etkinliği değiştirmez")
    }

    func test_persistentActivitiesAreNotShownAsTransient() {
        let center = ActivityCenter()
        center.show(.media)
        XCTAssertEqual(center.current, .none)
    }
}

final class DownloadSummaryTests: XCTestCase {
    func test_summarize_averagesAndNamesSlowest() {
        let snapshot = DownloadMonitor.summarize([("a.zip", 0.9), ("b.mov", 0.1)])
        XCTAssertEqual(snapshot?.count, 2)
        XCTAssertEqual(snapshot?.name, "b.mov")
        XCTAssertEqual(snapshot?.progress ?? 0, 0.5, accuracy: 0.0001)
    }

    func test_summarize_clampsInvalidValues() {
        let snapshot = DownloadMonitor.summarize([("x", .nan), ("y", 2)])
        XCTAssertEqual(snapshot?.progress ?? -1, 0.5, accuracy: 0.0001)
    }

    func test_summarize_empty_isNil() {
        XCTAssertNil(DownloadMonitor.summarize([]))
    }

    func test_cleanName_stripsBrowserSuffixes() {
        XCTAssertEqual(DownloadMonitor.cleanName("rapor.pdf.crdownload"), "rapor.pdf")
        XCTAssertEqual(DownloadMonitor.cleanName("film.mp4.download"), "film.mp4")
        XCTAssertEqual(DownloadMonitor.cleanName("arsiv.zip"), "arsiv.zip")
    }
}

final class DeviceBatteryTests: XCTestCase {
    func test_parse_airPodsAndSingleLevelDevice() throws {
        let json = """
        {"SPBluetoothDataType":[{"device_connected":[
          {"AirPods Pro":{"device_batteryLevelLeft":"80%","device_batteryLevelRight":"76%","device_batteryLevelCase":"55%"}},
          {"Magic Mouse":{"device_batteryLevelMain":"42 %"}},
          {"Hoparlör":{"device_minorType":"Speaker"}}
        ]}]}
        """.data(using: .utf8)!
        let result = DeviceBatteryReader.parse(json)
        XCTAssertEqual(result["AirPods Pro"], DeviceBattery(left: 80, right: 76, caseLevel: 55))
        XCTAssertEqual(result["Magic Mouse"]?.main, 42)
        XCTAssertNil(result["Hoparlör"], "Pil bilgisi olmayan cihaz listelenmez")
    }

    func test_parse_garbage_isEmpty() {
        XCTAssertTrue(DeviceBatteryReader.parse(Data("nope".utf8)).isEmpty)
        XCTAssertTrue(DeviceBatteryReader.parse(Data("{}".utf8)).isEmpty)
    }

    func test_percent_rejectsOutOfRange() {
        XCTAssertNil(DeviceBatteryReader.percent("150%"))
        XCTAssertEqual(DeviceBatteryReader.percent(7), 7)
        XCTAssertNil(DeviceBatteryReader.percent(nil))
    }

    func test_summary_formats() {
        XCTAssertEqual(DeviceBattery(left: 80, right: 76, caseLevel: 55).summary, "S %80 · D %76 · Kutu %55")
        XCTAssertEqual(DeviceBattery(left: 70, right: 70).summary, "%70")
        XCTAssertEqual(DeviceBattery(main: 42).summary, "%42")
        XCTAssertEqual(DeviceBattery(left: 80, right: 30, caseLevel: 5).lowest, 30)
    }
}

final class CalendarUpcomingTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 10_000)

    private func item(_ id: String, startIn minutes: Double, length: Double = 30, allDay: Bool = false) -> CalendarItem {
        let start = now.addingTimeInterval(minutes * 60)
        return CalendarItem(id: id, title: id, start: start, end: start.addingTimeInterval(length * 60), isAllDay: allDay, color: .systemBlue)
    }

    func test_picksEarliestWithinLead() {
        let items = [item("b", startIn: 12), item("a", startIn: 8), item("c", startIn: 40)]
        XCTAssertEqual(CalendarService.upcoming(in: items, now: now, leadMinutes: 15)?.id, "a")
    }

    func test_ignoresAllDayAndFarEvents() {
        let items = [item("all", startIn: 2, allDay: true), item("far", startIn: 30)]
        XCTAssertNil(CalendarService.upcoming(in: items, now: now, leadMinutes: 15))
    }

    func test_keepsShowingFiveMinutesAfterStart() {
        XCTAssertNotNil(CalendarService.upcoming(in: [item("x", startIn: -4)], now: now, leadMinutes: 15))
        XCTAssertNil(CalendarService.upcoming(in: [item("x", startIn: -6)], now: now, leadMinutes: 15))
    }

    func test_countdownText() {
        XCTAssertEqual(CalendarCountdown.text(until: now.addingTimeInterval(12 * 60 - 10), now: now), "12 dk")
        XCTAssertEqual(CalendarCountdown.text(until: now.addingTimeInterval(65 * 60), now: now), "1 sa 5 dk")
        XCTAssertEqual(CalendarCountdown.text(until: now.addingTimeInterval(120 * 60), now: now), "2 sa")
        XCTAssertEqual(CalendarCountdown.text(until: now.addingTimeInterval(-30), now: now), "Şimdi")
    }
}

@MainActor
final class TimerServiceTests: XCTestCase {
    func test_remainingText_roundsUp() {
        let now = Date(timeIntervalSinceReferenceDate: 0)
        XCTAssertEqual(TimerService.remainingText(until: now.addingTimeInterval(299.2), now: now), "5:00")
        XCTAssertEqual(TimerService.remainingText(until: now.addingTimeInterval(-3), now: now), "0:00")
    }

    func test_extend_neverClearsEndDate() {
        let timer = TimerService()
        timer.start(minutes: 1)
        var sawNil = false
        let token = timer.$endsAt.dropFirst().sink { if $0 == nil { sawNil = true } }
        let before = timer.endsAt!
        timer.extend(by: 60)
        XCTAssertFalse(sawNil, "+1 dk zamanlayıcıyı bitip yeniden başlamış gibi göstermez")
        XCTAssertEqual(timer.endsAt!.timeIntervalSince(before), 60, accuracy: 0.5)
        XCTAssertEqual(timer.total, 120)
        token.cancel()
        timer.cancel()
    }

    func test_startAndCancel() {
        let timer = TimerService()
        timer.start(minutes: 5)
        XCTAssertTrue(timer.isRunning)
        XCTAssertEqual(timer.total, 300)
        timer.cancel()
        XCTAssertFalse(timer.isRunning)
    }

    func test_finishFiresEvent() {
        let timer = TimerService()
        let done = expectation(description: "bitti")
        let token = timer.finished.sink { total in
            XCTAssertEqual(total, 0.2, accuracy: 0.001)
            done.fulfill()
        }
        timer.start(seconds: 0.2)
        wait(for: [done], timeout: 2)
        XCTAssertFalse(timer.isRunning)
        token.cancel()
    }
}

@MainActor
final class NotchSizingTests: XCTestCase {
    private func makeViewModel(notch: Bool, style: NotchlessStyle, hud: HUDStyle = .compact) -> (NotchViewModel, () -> Void) {
        let suite = "BurrowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let settings = AppSettings(defaults: defaults)
        settings.notchlessStyle = style
        settings.hudStyle = hud
        let geometry = NotchGeometry.make(screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                          safeAreaTop: notch ? 38 : 0, leftAuxWidth: notch ? 662 : nil,
                                          rightAuxWidth: notch ? 665 : nil, menuBarHeight: 25)
        let vm = NotchViewModel(geometry: geometry, services: AppServices(settings: settings))
        return (vm, { defaults.removePersistentDomain(forName: suite) })
    }

    func test_islandOnlyAppliesToNotchlessScreens() {
        let (physical, clean1) = makeViewModel(notch: true, style: .island)
        defer { clean1() }
        XCTAssertFalse(physical.isIsland, "Fiziksel çentikte ada biçimi kullanılmaz")
        let (external, clean2) = makeViewModel(notch: false, style: .island)
        defer { clean2() }
        XCTAssertTrue(external.isIsland)
        // Menü çubuğu 25 pt → hap 20 pt, üstten 2.5 pt: menü çubuğunun içinde kalır
        XCTAssertEqual(external.islandHeight, 20)
        XCTAssertEqual(external.topInset, 2.5, accuracy: 0.001)
        XCTAssertLessThanOrEqual(external.topInset + external.compactSize(for: .none).height, 25)
    }

    func test_screenRect_isShiftedDownForIsland() {
        let (external, clean) = makeViewModel(notch: false, style: .island)
        defer { clean() }
        let rect = external.screenRect(size: CGSize(width: 100, height: 30))
        XCTAssertEqual(rect.maxY, 982, accuracy: 0.001, "Ekranın en tepesi de isabet alanında")
        XCTAssertEqual(rect.minY, 982 - external.topInset - 30, accuracy: 0.001)
    }

    func test_largeHUD_addsHeight() {
        let (vm, clean) = makeViewModel(notch: true, style: .notch, hud: .large)
        defer { clean() }
        let hud = LiveActivity.hud(kind: .volume(muted: false), value: 0.5)
        XCTAssertEqual(vm.compactSize(for: hud).height, 38 + NotchViewModel.largeHUDExtraHeight)
        XCTAssertEqual(vm.compactSize(for: .media).height, 38)
    }
}
