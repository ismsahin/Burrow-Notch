import AppKit
import Combine

/// Gelen bildirimleri izler: önce büyük kart (geçici), sonra kapalı çentikte uygulama simgesi + okunmamış sayısı.
@MainActor
final class NotificationCenterService: ObservableObject {
    enum Status: Equatable { case off, needsAccess, active }

    @Published private(set) var status: Status = .off
    @Published private(set) var recent: [NotificationEntry] = []
    @Published private(set) var unread = 0
    @Published private(set) var latestAppID: String?
    let incoming = PassthroughSubject<NotificationEntry, Never>()

    private var lastID: Int64?
    private var timer: Timer?
    private var lastModified: Date?
    private let queue = DispatchQueue(label: "com.ismsahin.Burrow.notifications", qos: .utility)
    private static let pollInterval: TimeInterval = 1.5
    private static let maxRecent = 40

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        status = .off
        lastID = nil
        lastModified = nil
        clear() // kapatınca eski sayaç/rozet çentikte kalmasın
    }

    /// Kullanıcı çentiği açtı / bildirimleri gördü.
    func markAllRead() {
        unread = 0
    }

    func open(_ entry: NotificationEntry) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: entry.appID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    func clear() {
        recent = []
        unread = 0
        latestAppID = nil
    }

    /// Sistem Ayarları › Gizlilik › Tam Disk Erişimi sayfası.
    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Yoklama

    /// Yalnızca veritabanı (veya WAL) dosyası değiştiyse sorgular: boştayken maliyet bir `stat` çağrısı.
    private func tick() {
        let dbURL = NotificationReader.databaseURL
        let walPath = dbURL.path + "-wal"
        let modified = [dbURL.path, walPath]
            .compactMap { try? FileManager.default.attributesOfItem(atPath: $0)[.modificationDate] as? Date }
            .max()
        if status == .active, let modified, modified == lastModified { return }
        lastModified = modified

        let after = lastID
        let ownID = Bundle.main.bundleIdentifier
        queue.async {
            let result = NotificationReader.read(after: after)
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated { self?.handle(result, ownID: ownID) }
            }
        }
    }

    private func handle(_ result: Result<(entries: [NotificationEntry], lastID: Int64), NotificationReader.ReadError>, ownID: String?) {
        guard timer != nil else { return } // durdurulduktan sonra gelen geç sonuç
        switch result {
        case .failure(.noAccess), .failure(.missing):
            status = .needsAccess
        case .failure(.query(let message)):
            // Geçici kilit (usernoted yazıyor): durumu bozma, sonraki turda yeniden dene.
            NSLog("Burrow: bildirim veritabanı sorgusu başarısız: \(message)")
            lastModified = nil
        case .success(let (entries, newLast)):
            status = .active
            if entries.count >= NotificationReader.pageSize { lastModified = nil } // kalanları bir sonraki turda al
            let isFirstRead = lastID == nil
            lastID = newLast
            guard !isFirstRead else { return } // açılıştaki eski bildirimleri gösterme
            let fresh = entries.filter { $0.appID != ownID }
            guard !fresh.isEmpty else { return }
            recent = Array((fresh.reversed() + recent).prefix(Self.maxRecent))
            unread += fresh.count
            latestAppID = fresh.last?.appID
            fresh.forEach { incoming.send($0) }
        }
    }
}

/// Uygulama simgesi önbelleği (bundle kimliğinden).
@MainActor
enum AppIconCache {
    private static var cache: [String: NSImage] = [:]

    static func icon(for bundleID: String) -> NSImage? {
        if let cached = cache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache[bundleID] = icon
        return icon
    }

    static func name(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}
