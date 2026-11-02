import AppKit
import Combine
import EventKit

struct ReminderItem: Identifiable, Equatable {
    let id: String
    let title: String
    let due: Date?
    let listName: String
    let color: NSColor
    let isFlagged: Bool
}

/// Tamamlanmamış anımsatıcılar. İzin yalnızca sekme ilk açıldığında istenir.
@MainActor
final class ReminderService: ObservableObject {
    enum Access: Equatable { case unknown, granted, denied }

    @Published private(set) var items: [ReminderItem] = []
    @Published private(set) var access: Access = .unknown

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    private static let maxItems = 30

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
        guard access == .granted else { items = []; return }
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        store.fetchReminders(matching: predicate) { [weak self] reminders in
            let mapped = (reminders ?? []).map { reminder in
                ReminderItem(id: reminder.calendarItemIdentifier,
                             title: reminder.title ?? "Anımsatıcı",
                             due: reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) },
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
