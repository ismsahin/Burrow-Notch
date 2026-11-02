import AppKit
import Combine

struct ShelfItem: Identifiable, Codable, Equatable {
    let id: UUID
    let url: URL
    let addedAt: Date

    var name: String { url.lastPathComponent }
}

/// Raf: sürüklenen dosyalar için geçici cep. Dosyalar kopyalanmaz, yalnızca yolları saklanır.
/// Saf mantık (`adding`, `removing`, `pruned`) değişmez koleksiyonlar döndürür ve test edilir.
@MainActor
final class ShelfStore: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []

    nonisolated static let maxItems = 30
    private static let storageKey = "shelfItems"
    private let defaults: UserDefaults
    private let fileExists: (URL) -> Bool

    init(defaults: UserDefaults = .standard, fileExists: @escaping (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) {
        self.defaults = defaults
        self.fileExists = fileExists
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([ShelfItem].self, from: data) {
            items = Self.pruned(decoded, fileExists: fileExists)
        }
    }

    func add(_ urls: [URL]) {
        update(Self.adding(urls.filter(\.isFileURL), to: items))
    }

    func remove(_ item: ShelfItem) {
        update(Self.removing(id: item.id, from: items))
    }

    func clear() { update([]) }

    /// Dışarıda silinen dosyaları temizle (raf her açıldığında).
    func prune() {
        let cleaned = Self.pruned(items, fileExists: fileExists)
        if cleaned != items { update(cleaned) }
    }

    func reveal(_ item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func open(_ item: ShelfItem) {
        NSWorkspace.shared.open(item.url)
    }

    func airDrop(_ items: [ShelfItem]) {
        guard let service = NSSharingService(named: .sendViaAirDrop) else { return }
        let urls = items.map(\.url)
        if service.canPerform(withItems: urls) { service.perform(withItems: urls) }
    }

    private func update(_ newItems: [ShelfItem]) {
        items = newItems
        do {
            defaults.set(try JSONEncoder().encode(newItems), forKey: Self.storageKey)
        } catch {
            NSLog("Burrow: raf kaydedilemedi: \(error.localizedDescription)")
        }
    }

    // MARK: - Saf mantık

    nonisolated static func adding(_ urls: [URL], to items: [ShelfItem], now: Date = Date()) -> [ShelfItem] {
        let existing = Set(items.map { $0.url.standardizedFileURL.path })
        var seen = existing
        var newItems: [ShelfItem] = []
        for url in urls {
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else { continue }
            seen.insert(path)
            newItems.append(ShelfItem(id: UUID(), url: url.standardizedFileURL, addedAt: now))
        }
        // En yeni başta; sınırı aşanlar (en eskiler) düşer.
        return Array((newItems.reversed() + items).prefix(maxItems))
    }

    nonisolated static func removing(id: UUID, from items: [ShelfItem]) -> [ShelfItem] {
        items.filter { $0.id != id }
    }

    nonisolated static func pruned(_ items: [ShelfItem], fileExists: (URL) -> Bool) -> [ShelfItem] {
        items.filter { fileExists($0.url) }
    }
}
