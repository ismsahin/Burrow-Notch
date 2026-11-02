import SQLite3
import XCTest
@testable import Burrow

final class ClipboardLogicTests: XCTestCase {
    private func item(_ text: String?, kind: ClipboardItem.Kind = .text, starred: Bool = false, image: String? = nil) -> ClipboardItem {
        ClipboardItem(id: UUID(), kind: kind, text: text, imageFile: image, date: Date(), sourceApp: nil, isStarred: starred)
    }

    func test_classify_linksAndText() {
        XCTAssertEqual(ClipboardLogic.classify("https://youtube.com/watch?v=1"), .link)
        XCTAssertEqual(ClipboardLogic.classify("  http://a.com  "), .link)
        XCTAssertEqual(ClipboardLogic.classify("bak şuna https://a.com"), .text)
        XCTAssertEqual(ClipboardLogic.classify("ftp://a.com"), .text)
        XCTAssertEqual(ClipboardLogic.classify("merhaba"), .text)
        XCTAssertEqual(ClipboardLogic.classify("https://a.com\nhttps://b.com"), .text)
    }

    func test_adding_dedupesAndKeepsStar() {
        let starred = item("aynı", starred: true)
        let other = item("başka")
        let result = ClipboardLogic.adding(item("aynı"), to: [other, starred])
        XCTAssertEqual(result.items.map(\.text), ["aynı", "başka"])
        XCTAssertTrue(result.items[0].isStarred, "Tekrar kopyalanınca yıldız korunur")
        XCTAssertTrue(result.removed.isEmpty)
    }

    func test_adding_dropsOldestUnstarred_neverStarred() {
        var items = (0..<ClipboardLogic.maxItems).map { item("x\($0)") }
        items[items.count - 1] = item("eski-yildizli", starred: true)
        let result = ClipboardLogic.adding(item("yeni"), to: items)
        XCTAssertEqual(result.items.count, ClipboardLogic.maxItems)
        XCTAssertTrue(result.items.contains { $0.text == "eski-yildizli" })
        XCTAssertEqual(result.removed.map(\.text), ["x198"])
    }

    func test_adding_capsStarredToo() {
        let starred = (0..<ClipboardLogic.maxTotalItems).map { item("y\($0)", starred: true) }
        let result = ClipboardLogic.adding(item("yeni", starred: true), to: starred)
        XCTAssertEqual(result.items.count, ClipboardLogic.maxTotalItems)
        XCTAssertEqual(result.removed.map(\.text), ["y\(ClipboardLogic.maxTotalItems - 1)"])
    }

    func test_filter_byKindStarAndQuery() {
        let items = [item("https://a.com", kind: .link), item("Toplantı notu", starred: true), item(nil, kind: .media, image: "a.png")]
        XCTAssertEqual(ClipboardLogic.filtered(items, by: .kind(.link), query: "").count, 1)
        XCTAssertEqual(ClipboardLogic.filtered(items, by: .starred, query: "").map(\.text), ["Toplantı notu"])
        XCTAssertEqual(ClipboardLogic.filtered(items, by: .all, query: "toplantı").count, 1)
        XCTAssertEqual(ClipboardLogic.filtered(items, by: .all, query: "").count, 3)
    }

    func test_passwordManagerTypes_areIgnored() {
        XCTAssertTrue(ClipboardLogic.shouldIgnore(types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"]))
        XCTAssertFalse(ClipboardLogic.shouldIgnore(types: ["public.utf8-plain-text"]))
    }

    @MainActor
    func test_store_persistsAndClearKeepsStarred() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("BurrowClip-\(UUID())")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ClipboardStore(directory: dir)
        store.copy(item("bir"))
        store.copy(item("iki"))
        let first = try XCTUnwrap(store.items.first { $0.text == "bir" })
        store.toggleStar(first)
        let reloaded = ClipboardStore(directory: dir)
        XCTAssertEqual(reloaded.items.count, 2)
        reloaded.clearUnstarred()
        XCTAssertEqual(ClipboardStore(directory: dir).items.map(\.text), ["bir"])
    }
}

final class AlarmTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    private func date(_ h: Int, _ m: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: h, minute: m))!
    }

    private func alarm(_ h: Int, _ m: Int, enabled: Bool = true) -> Alarm {
        Alarm(id: UUID(), hour: h, minute: m, label: "a", isEnabled: enabled, repeatsDaily: false)
    }

    func test_next_picksSoonestToday() {
        let next = AlarmService.next(in: [alarm(22, 0), alarm(21, 30)], after: date(21, 0), calendar: calendar)
        XCTAssertEqual(next?.date, date(21, 30))
    }

    func test_next_rollsToTomorrowWhenPassed() {
        let next = AlarmService.next(in: [alarm(7, 0)], after: date(21, 0), calendar: calendar)
        XCTAssertEqual(next?.date, calendar.date(byAdding: .day, value: 1, to: date(7, 0)))
    }

    func test_next_ignoresDisabled() {
        XCTAssertNil(AlarmService.next(in: [alarm(22, 0, enabled: false)], after: date(21, 0), calendar: calendar))
    }

    @MainActor
    func test_service_persistsSorted() {
        let suite = "BurrowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = AlarmService(defaults: defaults)
        service.add(hour: 9, minute: 0, label: "", repeatsDaily: true)
        service.add(hour: 7, minute: 30, label: "Kalk", repeatsDaily: false)
        let reloaded = AlarmService(defaults: defaults)
        XCTAssertEqual(reloaded.alarms.map(\.timeText), ["07:30", "09:00"])
        XCTAssertEqual(reloaded.alarms.last?.label, "Alarm", "Boş etiket 'Alarm' olur")
    }
}

final class ReminderSortTests: XCTestCase {
    func test_datedFirstThenUndatedByTitle() {
        let now = Date()
        let items = [
            ReminderItem(id: "1", title: "Zeta", due: nil, listName: "", color: .red, isFlagged: false),
            ReminderItem(id: "2", title: "Geç", due: now.addingTimeInterval(3600), listName: "", color: .red, isFlagged: false),
            ReminderItem(id: "3", title: "Erken", due: now, listName: "", color: .red, isFlagged: false),
            ReminderItem(id: "4", title: "Alfa", due: nil, listName: "", color: .red, isFlagged: false),
        ]
        XCTAssertEqual(ReminderService.sorted(items).map(\.id), ["3", "2", "4", "1"])
    }
}

final class NotificationReaderTests: XCTestCase {
    private func plist(_ dict: [String: Any]) -> Data {
        try! PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
    }

    func test_parse_titleSubtitleBody() throws {
        let data = plist(["app": "com.apple.MobileSMS", "req": ["titl": "Ayşe", "subt": "", "body": "Geliyor musun?"]])
        let entry = try XCTUnwrap(NotificationRecordParser.parse(id: 7, appID: "x", data: data, deliveredDate: 100))
        XCTAssertEqual(entry.appID, "com.apple.MobileSMS")
        XCTAssertEqual(entry.title, "Ayşe")
        XCTAssertEqual(entry.body, "Geliyor musun?")
        XCTAssertEqual(entry.date, Date(timeIntervalSinceReferenceDate: 100))
    }

    func test_parse_bodyOnly_becomesTitle() throws {
        let entry = try XCTUnwrap(NotificationRecordParser.parse(id: 1, appID: "com.a", data: plist(["req": ["body": "Yalnız gövde"]]), deliveredDate: 0))
        XCTAssertEqual(entry.title, "Yalnız gövde")
        XCTAssertEqual(entry.body, "")
        XCTAssertEqual(entry.appID, "com.a")
    }

    func test_parse_emptyOrGarbage_isNil() {
        XCTAssertNil(NotificationRecordParser.parse(id: 1, appID: "a", data: plist(["req": [:]]), deliveredDate: 0))
        XCTAssertNil(NotificationRecordParser.parse(id: 1, appID: "a", data: Data("çöp".utf8), deliveredDate: 0))
    }

    /// macOS 15 şemasının özüyle geçici veritabanı: ilk okuma yalnızca son kimliği verir, sonrakiler yenileri.
    func test_read_onlyReturnsNewRecords() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("burrow-notif-\(UUID()).db")
        defer { try? FileManager.default.removeItem(at: url) }
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        func exec(_ sql: String) { XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK, sql) }
        exec("CREATE TABLE app (app_id INTEGER PRIMARY KEY, identifier VARCHAR, badge INTEGER NULL)")
        exec("CREATE TABLE record (rec_id INTEGER PRIMARY KEY, app_id INTEGER, uuid BLOB, data BLOB, request_date REAL, request_last_date REAL, delivered_date REAL, presented BOOL, style INTEGER, snooze_fire_date REAL)")
        exec("INSERT INTO app VALUES (1, 'com.tinyspeck.slackmacgap', NULL)")
        func insert(_ id: Int, _ title: String) {
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, "INSERT INTO record (rec_id, app_id, data, delivered_date) VALUES (?, 1, ?, 50)", -1, &stmt, nil)
            sqlite3_bind_int(stmt, 1, Int32(id))
            let data = plist(["req": ["titl": title, "body": "b"]])
            _ = data.withUnsafeBytes { sqlite3_bind_blob(stmt, 2, $0.baseAddress, Int32(data.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
            XCTAssertEqual(sqlite3_step(stmt), SQLITE_DONE)
            sqlite3_finalize(stmt)
        }
        insert(1, "eski")
        insert(2, "eski2")

        let first = try NotificationReader.read(after: nil, at: url).get()
        XCTAssertTrue(first.entries.isEmpty, "Açılışta eski bildirimler gösterilmez")
        XCTAssertEqual(first.lastID, 2)

        insert(3, "yeni")
        let second = try NotificationReader.read(after: first.lastID, at: url).get()
        XCTAssertEqual(second.entries.map(\.title), ["yeni"])
        XCTAssertEqual(second.entries.first?.appID, "com.tinyspeck.slackmacgap")
        XCTAssertEqual(second.lastID, 3)
        sqlite3_close(db)
    }

    func test_read_missingDatabase() {
        let url = URL(fileURLWithPath: "/tmp/burrow-yok-\(UUID()).db")
        XCTAssertEqual(NotificationReader.read(after: 0, at: url).failureValue, .missing)
    }
}

@MainActor
final class NewSizingTests: XCTestCase {
    private func viewModel(island: IslandSize) -> (NotchViewModel, () -> Void) {
        let suite = "BurrowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let settings = AppSettings(defaults: defaults)
        settings.notchlessStyle = .island
        settings.islandSize = island
        let geometry = NotchGeometry.make(screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                          safeAreaTop: 0, leftAuxWidth: nil, rightAuxWidth: nil, menuBarHeight: 25)
        return (NotchViewModel(geometry: geometry, services: AppServices(settings: settings)),
                { defaults.removePersistentDomain(forName: suite) })
    }

    func test_largeIsland_isBiggerAndLower() {
        let (small, c1) = viewModel(island: .compact)
        defer { c1() }
        let (large, c2) = viewModel(island: .large)
        defer { c2() }
        XCTAssertGreaterThan(large.islandHeight, small.islandHeight)
        XCTAssertGreaterThan(large.topInset, small.topInset)
        XCTAssertEqual(large.islandHeight, NotchViewModel.largeIslandHeight)
    }

    func test_notificationCard_addsHeight() {
        let (vm, clean) = viewModel(island: .large)
        defer { clean() }
        let entry = NotificationEntry(id: 1, appID: "a", title: "t", subtitle: "", body: "b", date: Date())
        XCTAssertEqual(vm.compactSize(for: .notification(entry)).height, vm.barHeight + NotchViewModel.notificationCardHeight)
    }
}

private extension Result {
    var failureValue: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
