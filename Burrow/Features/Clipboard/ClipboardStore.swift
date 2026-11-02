import AppKit
import Combine

/// Pano geçmişi. `NSPasteboard.changeCount` yarım saniyede bir okunur (macOS'ta pano bildirimi yoktur;
/// bu sayaç okuması çok ucuzdur). Veriler yalnızca bu Mac'te, Application Support altında tutulur.
@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private let directory: URL
    private var ownChangeCount: Int?
    private static let pollInterval: TimeInterval = 0.5
    private static let maxImageBytes = 15_000_000

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Burrow/Clipboard", isDirectory: true)
        self.directory = base
        lastChangeCount = pasteboard.changeCount
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        load()
    }

    var isRunning: Bool { timer != nil }

    func start() {
        guard timer == nil else { return }
        lastChangeCount = pasteboard.changeCount
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Eylemler

    /// Öğeyi tekrar panoya koyar (kendi yazdığımızı geçmişe yeniden eklemeyiz).
    func copy(_ item: ClipboardItem) {
        pasteboard.clearContents()
        switch item.kind {
        case .text, .link:
            pasteboard.setString(item.text ?? "", forType: .string)
        case .media:
            if let file = item.imageFile, let image = NSImage(contentsOf: directory.appendingPathComponent(file)) {
                pasteboard.writeObjects([image])
            } else if let paths = item.text {
                pasteboard.writeObjects(paths.split(separator: "\n").map { URL(fileURLWithPath: String($0)) as NSURL })
            }
        }
        ownChangeCount = pasteboard.changeCount
        lastChangeCount = pasteboard.changeCount
        apply(ClipboardLogic.adding(item, to: items))
    }

    func toggleStar(_ item: ClipboardItem) {
        items = items.map { $0.id == item.id ? $0.with(starred: !$0.isStarred) : $0 }
        save()
    }

    func remove(_ item: ClipboardItem) {
        items = items.filter { $0.id != item.id }
        deleteFiles(of: [item])
        save()
    }

    /// Yıldızlılar korunur.
    func clearUnstarred() {
        let removed = items.filter { !$0.isStarred }
        items = items.filter(\.isStarred)
        deleteFiles(of: removed)
        save()
    }

    func imageURL(for item: ClipboardItem) -> URL? {
        item.imageFile.map { directory.appendingPathComponent($0) }
    }

    // MARK: - Okuma

    private func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        if count == ownChangeCount { return }
        let types = pasteboard.types?.map(\.rawValue) ?? []
        guard !ClipboardLogic.shouldIgnore(types: types) else { return }
        let source = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard source != Bundle.main.bundleIdentifier else { return }
        if let item = readQuickItem(source: source) {
            apply(ClipboardLogic.adding(item, to: items))
            return
        }
        // Resim: ham veriyi ana iş parçacığında al, çöz/kodla/yaz işini arka planda yap (animasyonlar takılmasın).
        guard let raw = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff), raw.count <= Self.maxImageBytes else { return }
        let directory = directory
        DispatchQueue.global(qos: .utility).async {
            let file = Self.storeImage(raw, in: directory)
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, let file else { return }
                    let item = ClipboardItem(id: UUID(), kind: .media, text: nil, imageFile: file, date: Date(),
                                             sourceApp: source, isStarred: false)
                    self.apply(ClipboardLogic.adding(item, to: self.items))
                }
            }
        }
    }

    /// Dosya listesi ve metin (hızlı). Metin resimden önce gelir: Office/Numbers metinle birlikte önizleme resmi de koyar.
    private func readQuickItem(source: String?) -> ClipboardItem? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            return ClipboardItem(id: UUID(), kind: .media, text: urls.map(\.path).joined(separator: "\n"),
                                 imageFile: nil, date: Date(), sourceApp: source, isStarred: false)
        }
        if let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let clipped = String(text.prefix(ClipboardLogic.maxTextLength))
            return ClipboardItem(id: UUID(), kind: ClipboardLogic.classify(clipped), text: clipped,
                                 imageFile: nil, date: Date(), sourceApp: source, isStarred: false)
        }
        return nil
    }

    nonisolated private static func storeImage(_ data: Data, in directory: URL) -> String? {
        guard let rep = NSBitmapImageRep(data: data), let png = rep.representation(using: .png, properties: [:]) else { return nil }
        let name = UUID().uuidString + ".png"
        do {
            try png.write(to: directory.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            NSLog("Burrow: pano resmi kaydedilemedi: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Kalıcılık

    private var indexURL: URL { directory.appendingPathComponent("history.json") }

    private func apply(_ result: (items: [ClipboardItem], removed: [ClipboardItem])) {
        items = result.items
        deleteFiles(of: result.removed)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        do {
            items = try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            NSLog("Burrow: pano geçmişi okunamadı: \(error.localizedDescription)")
        }
    }

    private func save() {
        do {
            try JSONEncoder().encode(items).write(to: indexURL, options: .atomic)
        } catch {
            NSLog("Burrow: pano geçmişi kaydedilemedi: \(error.localizedDescription)")
        }
    }

    private func deleteFiles(of removed: [ClipboardItem]) {
        for file in removed.compactMap(\.imageFile) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
        }
    }
}
