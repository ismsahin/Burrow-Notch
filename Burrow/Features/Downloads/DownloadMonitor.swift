import Combine
import Foundation

/// İndirilenler klasörüne yazılan dosyaların ilerlemesini izler.
///
/// Safari ve Chrome indirmelerini `NSProgress` olarak yayınlar (Finder simgesindeki ilerleme çubuğu bunu kullanır).
/// `Progress.addSubscriber(forFileURL:)` ile bu yayınlara abone oluruz: dosya okumayız, izin gerekmez.
@MainActor
final class DownloadMonitor: ObservableObject {
    struct Snapshot: Equatable {
        let name: String
        let progress: Double
        let count: Int
    }

    @Published private(set) var snapshot: Snapshot?
    /// Bir indirme bitti (dosya adı).
    let completed = PassthroughSubject<String, Never>()

    private var subscriber: Any?
    private var tracked: [ObjectIdentifier: Tracked] = [:]
    private var throttle: DispatchWorkItem?
    private static let publishInterval: TimeInterval = 0.4

    private final class Tracked {
        let progress: Progress
        var observations: [NSKeyValueObservation] = []
        init(_ progress: Progress) { self.progress = progress }
    }

    func start() {
        guard subscriber == nil else { return }
        guard let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }
        // Foundation bu işleyicileri ana iş parçacığında çağırmayı garanti etmez → açıkça ana kuyruğa geç.
        subscriber = Progress.addSubscriber(forFileURL: downloads) { [weak self] progress in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.track(progress) } }
            return { [weak self] in
                let finished = progress.fractionCompleted >= 0.999
                DispatchQueue.main.async { MainActor.assumeIsolated { self?.untrack(progress, finished: finished) } }
            }
        }
    }

    func stop() {
        if let subscriber { Progress.removeSubscriber(subscriber) }
        subscriber = nil
        tracked.values.forEach { $0.observations.forEach { $0.invalidate() } }
        tracked.removeAll()
        snapshot = nil
    }

    private func track(_ progress: Progress) {
        let item = Tracked(progress)
        let schedule: () -> Void = { [weak self] in
            DispatchQueue.main.async { self?.schedulePublish() }
        }
        item.observations = [
            progress.observe(\.fractionCompleted) { _, _ in schedule() },
            progress.observe(\.isCancelled) { _, _ in schedule() },
        ]
        tracked[ObjectIdentifier(progress)] = item
        publish()
    }

    private func untrack(_ progress: Progress, finished: Bool) {
        guard let item = tracked.removeValue(forKey: ObjectIdentifier(progress)) else { return }
        item.observations.forEach { $0.invalidate() }
        if finished, !progress.isCancelled { completed.send(Self.displayName(for: progress)) }
        publish()
    }

    private func schedulePublish() {
        guard throttle == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.throttle = nil
            self?.publish()
        }
        throttle = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.publishInterval, execute: work)
    }

    private func publish() {
        let progresses = tracked.values.map(\.progress).filter { !$0.isCancelled }
        snapshot = Self.summarize(progresses.map { (Self.displayName(for: $0), $0.fractionCompleted) })
    }

    /// Saf: birden çok indirmeyi tek özete indirger (ortalama ilerleme, en az ilerlemiş dosyanın adı).
    nonisolated static func summarize(_ items: [(name: String, fraction: Double)]) -> Snapshot? {
        guard !items.isEmpty else { return nil }
        let clamped = items.map { (name: $0.name, fraction: min(1, max(0, $0.fraction.isFinite ? $0.fraction : 0))) }
        let average = clamped.map(\.fraction).reduce(0, +) / Double(clamped.count)
        let slowest = clamped.min { $0.fraction < $1.fraction }!
        return Snapshot(name: slowest.name, progress: average, count: clamped.count)
    }

    /// "rapor.pdf.crdownload" → "rapor.pdf", "film.mp4.download" → "film.mp4"
    nonisolated static func cleanName(_ raw: String) -> String {
        for suffix in [".crdownload", ".download", ".part", ".partial", ".opdownload"] where raw.lowercased().hasSuffix(suffix) {
            return String(raw.dropLast(suffix.count))
        }
        return raw
    }

    private static func displayName(for progress: Progress) -> String {
        let url = progress.userInfo[.fileURLKey] as? URL
        return cleanName(url?.lastPathComponent ?? "İndirme")
    }
}
