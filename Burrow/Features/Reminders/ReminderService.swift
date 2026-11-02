import AppKit
import Combine
import EventKit

struct ReminderItem: Identifiable, Equatable {
    let id: String
    let title: String
    let due: Date?
    let listID: String
    let listName: String
    let color: NSColor
    let isFlagged: Bool
}

/// Anımsatıcı listesi (kategori).
struct ReminderList: Identifiable, Equatable {
    let id: String
    let title: String
    let color: NSColor
}

/// Tamamlanmamış anımsatıcılar. İzin yalnızca sekme ilk açıldığında istenir.
@MainActor
final class ReminderService: ObservableObject {
    enum Access: Equatable { case unknown, granted, denied }

    @Published private(set) var items: [ReminderItem] = []
    @Published private(set) var lists: [ReminderList] = []
    @Published private(set) var access: Access = .unknown

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    private static let maxItems = 300
    /// Seçimde "tüm listeler".
    nonisolated static let allListsID = "__all__"

    init() {
        access = Self.currentAccess()
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    private static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess: return .granted
        case .notDetermined: return .unknown
        default: return .denied
        }
    }

    func requestAccess() {
        store.requestFullAccessToReminders { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.access = granted ? .granted : .denied
                self?.reload()
            }
        }
    }

    func reload() {
        access = Self.currentAccess()
        guard access == .granted else { items = []; lists = []; return }
        let newLists = store.calendars(for: .reminder)
            .map { ReminderList(id: $0.calendarIdentifier, title: $0.title, color: $0.color ?? .systemOrange) }
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        if newLists != lists { lists = newLists }
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        store.fetchReminders(matching: predicate) { [weak self] reminders in
            let mapped = (reminders ?? []).map { reminder in
                ReminderItem(id: reminder.calendarItemIdentifier,
                             title: reminder.title ?? "Anımsatıcı",
                             due: reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) },
                             listID: reminder.calendar?.calendarIdentifier ?? "",
                             listName: reminder.calendar?.title ?? "",
                             color: reminder.calendar?.color ?? .systemOrange,
                             isFlagged: reminder.priority == 1)
            }
            let sorted = Self.sorted(mapped)
            DispatchQueue.main.async { self?.items = Array(sorted.prefix(Self.maxItems)) }
        }
    }

    /// Tamamla (işaretle). Başarısızsa listeyi yeniden okur.
    func complete(_ item: ReminderItem) {
        items = items.filter { $0.id != item.id }
        guard let reminder = store.calendarItem(withIdentifier: item.id) as? EKReminder else { reload(); return }
        reminder.isCompleted = true
        do {
            try store.save(reminder, commit: true)
        } catch {
            NSLog("Burrow: anımsatıcı tamamlanamadı: \(error.localizedDescription)")
            reload()
        }
    }

    func openRemindersApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.reminders") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    /// Saf: kayıtlı seçimi geçerli bir listeye çözer. `nil` = tüm listeler.
    /// Boş ya da silinmiş liste → ilk liste (hepsi toplu gösterilmez).
    nonisolated static func resolvedListID(_ selected: String, lists: [ReminderList]) -> String? {
        if selected == allListsID { return nil }
        if lists.contains(where: { $0.id == selected }) { return selected }
        return lists.first?.id
    }

    /// Saf: seçili listedeki öğeler (`nil` = hepsi).
    nonisolated static func items(_ items: [ReminderItem], inList listID: String?) -> [ReminderItem] {
        guard let listID else { return items }
        return items.filter { $0.listID == listID }
    }

    /// Saf: tarihi olanlar (yakın önce), sonra tarihsizler; eşitlikte başlığa göre.
    nonisolated static func sorted(_ items: [ReminderItem]) -> [ReminderItem] {
        items.sorted { lhs, rhs in
            switch (lhs.due, rhs.due) {
            case let (l?, r?): return l == r ? lhs.title < rhs.title : l < r
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return lhs.title.localizedCompare(rhs.title) == .orderedAscending
            }
        }
    }
}
