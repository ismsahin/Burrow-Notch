import AppKit
import Combine
import EventKit

struct CalendarItem: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: NSColor
}

/// Yaklaşan etkinlikleri EventKit'ten okur. İzin yalnızca özellik açıkken ve ilk gerektiğinde istenir.
@MainActor
final class CalendarService: ObservableObject {
    enum Access: Equatable { case unknown, granted, denied }

    @Published private(set) var items: [CalendarItem] = []
    @Published private(set) var access: Access = .unknown

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    private var lastLoad = Date.distantPast
    private static let maxItems = 4
    private static let refreshInterval: TimeInterval = 60

    init() {
        access = Self.currentAccess()
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reload(force: true) }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    private static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized: return .granted
        case .notDetermined: return .unknown
        default: return .denied
        }
    }

    func requestAccess() {
        store.requestFullAccessToEvents { [weak self] granted, _ in
            Task { @MainActor in
                self?.access = granted ? .granted : .denied
                self?.reload(force: true)
            }
        }
    }

    /// Çentik açıldığında çağrılır; dakikada bir kereden sık okumaz.
    func reload(force: Bool = false) {
        access = Self.currentAccess()
        guard access == .granted else { items = []; return }
        guard force || Date().timeIntervalSince(lastLoad) > Self.refreshInterval else { return }
        lastLoad = Date()

        let now = Date()
        guard let end = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: now)) else { return }
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { $0.endDate > now && $0.status != .canceled }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return !lhs.isAllDay }
                return lhs.startDate < rhs.startDate
            }
            .prefix(Self.maxItems)
        items = events.map {
            CalendarItem(id: $0.calendarItemIdentifier + "\($0.startDate.timeIntervalSince1970)",
                         title: $0.title ?? "Etkinlik", start: $0.startDate, end: $0.endDate,
                         isAllDay: $0.isAllDay, color: $0.calendar?.color ?? .systemBlue)
        }
    }

    /// Saf: yaklaşan (tüm gün olmayan) ilk etkinlik — başlamasına `lead` dakika kalmışsa ya da 5 dakikadan az önce başladıysa.
    nonisolated static func upcoming(in items: [CalendarItem], now: Date, leadMinutes: Int) -> CalendarItem? {
        let window = TimeInterval(leadMinutes * 60)
        let grace: TimeInterval = 5 * 60
        return items
            .filter { !$0.isAllDay && $0.end > now }
            .filter { $0.start.timeIntervalSince(now) <= window && now.timeIntervalSince($0.start) <= grace }
            .min { $0.start < $1.start }
    }

    func openCalendarApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}
