import AppKit
import Combine

struct Alarm: Identifiable, Codable, Equatable {
    let id: UUID
    var hour: Int
    var minute: Int
    var label: String
    var isEnabled: Bool
    /// Her gün tekrarla; değilse bir kez çalıp kapanır.
    var repeatsDaily: Bool

    var timeText: String { String(format: "%02d:%02d", hour, minute) }
}

/// Saat alarmları. Duvar saatine göre zamanlanır (uyku/uyanma sonrası da doğru çalar).
@MainActor
final class AlarmService: ObservableObject {
    @Published private(set) var alarms: [Alarm] = []
    let fired = PassthroughSubject<Alarm, Never>()

    private let defaults: UserDefaults
    private var work: DispatchWorkItem?
    private var wakeObserver: NSObjectProtocol?
    private var sound: NSSound?
    private var ringGeneration = 0
    private static let storageKey = "alarms"
    private static let ringRepeats = 4

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([Alarm].self, from: data) {
            alarms = decoded
        }
        // Uyku: `wallDeadline` zaten duvar saatine göre çalar (uyanınca kaçırılanı geç de olsa çalar).
        // Uyanışta yeniden zamanlamak kaçırılan alarmı yarına atardı; bu yüzden yalnızca saat/saat dilimi değişince.
        wakeObserver = NotificationCenter.default.addObserver(
            forName: .NSSystemClockDidChange, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.reschedule() } }
        reschedule()
    }

    deinit {
        if let wakeObserver { NotificationCenter.default.removeObserver(wakeObserver) }
    }

    var nextAlarm: (alarm: Alarm, date: Date)? { Self.next(in: alarms, after: Date()) }

    func add(hour: Int, minute: Int, label: String, repeatsDaily: Bool) {
        let alarm = Alarm(id: UUID(), hour: hour, minute: minute,
                          label: label.trimmingCharacters(in: .whitespaces).isEmpty ? "Alarm" : label,
                          isEnabled: true, repeatsDaily: repeatsDaily)
        update(alarms + [alarm])
    }

    func toggle(_ alarm: Alarm) {
        update(alarms.map { $0.id == alarm.id ? Alarm(id: $0.id, hour: $0.hour, minute: $0.minute, label: $0.label,
                                                     isEnabled: !$0.isEnabled, repeatsDaily: $0.repeatsDaily) : $0 })
    }

    func remove(_ alarm: Alarm) { update(alarms.filter { $0.id != alarm.id }) }

    func stopRinging() {
        ringGeneration += 1 // bekleyen tekrarlar kendini iptal eder
        sound?.stop()
    }

    private func update(_ new: [Alarm]) {
        alarms = new.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        do { defaults.set(try JSONEncoder().encode(alarms), forKey: Self.storageKey) } catch {
            NSLog("Burrow: alarmlar kaydedilemedi: \(error.localizedDescription)")
        }
        reschedule()
    }

    private func reschedule() {
        work?.cancel()
        guard let next = nextAlarm else { return }
        let work = DispatchWorkItem { [weak self] in self?.ring(next.alarm) }
        self.work = work
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + max(0, next.date.timeIntervalSinceNow), execute: work)
    }

    private func ring(_ alarm: Alarm) {
        sound = NSSound(named: "Funk")
        sound?.loops = false
        ringGeneration += 1
        let generation = ringGeneration
        var count = 0
        func playAgain() {
            guard count < Self.ringRepeats, generation == ringGeneration else { return }
            count += 1
            sound?.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { playAgain() }
        }
        playAgain()
        fired.send(alarm)
        if !alarm.repeatsDaily {
            update(alarms.map { $0.id == alarm.id ? Alarm(id: $0.id, hour: $0.hour, minute: $0.minute, label: $0.label,
                                                         isEnabled: false, repeatsDaily: false) : $0 })
        } else {
            reschedule()
        }
    }

    /// Saf: etkin alarmlar içinde `after`'dan sonraki ilk çalma zamanı (bugün geçtiyse yarın).
    nonisolated static func next(in alarms: [Alarm], after now: Date, calendar: Calendar = .current) -> (alarm: Alarm, date: Date)? {
        alarms.filter(\.isEnabled).compactMap { alarm -> (Alarm, Date)? in
            var components = DateComponents()
            components.hour = alarm.hour
            components.minute = alarm.minute
            components.second = 0
            guard let date = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) else { return nil }
            return (alarm, date)
        }
        .min { $0.1 < $1.1 }
        .map { (alarm: $0.0, date: $0.1) }
    }
}
