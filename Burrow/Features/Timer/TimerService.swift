import AppKit
import Combine

/// Basit geri sayım (Pomodoro / çay / toplantı öncesi). Bitince ses + geçici bildirim.
@MainActor
final class TimerService: ObservableObject {
    @Published private(set) var endsAt: Date?
    @Published private(set) var total: TimeInterval = 0
    let finished = PassthroughSubject<TimeInterval, Never>()

    static let presets: [Int] = [1, 5, 10, 15, 25, 45]
    private var work: DispatchWorkItem?

    var isRunning: Bool { endsAt != nil }

    func start(minutes: Int) {
        start(seconds: TimeInterval(max(1, minutes) * 60))
    }

    func start(seconds: TimeInterval) {
        cancel()
        total = seconds
        schedule(endingAt: Date().addingTimeInterval(seconds))
    }

    /// Süreyi uzat (+1 dk vb.). `endsAt` hiç nil olmaz → döngü zamanlayıcıyı "yeni başladı" sanmaz.
    func extend(by seconds: TimeInterval) {
        guard let current = endsAt else { return }
        work?.cancel()
        let newEnd = max(Date().addingTimeInterval(1), current.addingTimeInterval(seconds))
        total += seconds
        schedule(endingAt: newEnd)
    }

    /// Duvar saatine göre zamanla: Mac uykudayken monoton saat durur, duvar saati durmaz.
    private func schedule(endingAt end: Date) {
        endsAt = end
        let work = DispatchWorkItem { [weak self] in self?.finish() }
        self.work = work
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + max(0, end.timeIntervalSinceNow), execute: work)
    }

    func cancel() {
        work?.cancel()
        work = nil
        endsAt = nil
    }

    private func finish() {
        let duration = total
        work = nil
        endsAt = nil
        NSSound(named: "Glass")?.play()
        finished.send(duration)
    }

    /// Saf: kalan süre metni ("4:59", "1:02:00")
    nonisolated static func remainingText(until end: Date, now: Date = Date()) -> String {
        TimeFormatting.clock(max(0, end.timeIntervalSince(now)).rounded(.up))
    }
}
