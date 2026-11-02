import Foundation

/// Kalıcı canlı etkinlikler arasında gezinme (saf, değişmez, test edilir).
///
/// Kurallar:
/// - `preferred == nil` ("Otomatik"): yeni başlayan etkinlik öne gelir (ör. müzik çalarken indirme başlarsa indirme görünür).
/// - `preferred` seçiliyse ve etkinse her zaman o gösterilir; yoksa en son başlayana düşülür.
/// - Kullanıcı kaydırarak elle seçtiyse, o etkinlik sürdükçe seçim korunur.
struct ActivityCarousel: Equatable {
    /// Etkin kalıcı etkinlikler, başlama sırasına göre (en eski önce).
    private(set) var active: [ActivityKind] = []
    private(set) var selected: ActivityKind?
    private(set) var isManual = false
    let preferred: ActivityKind?

    init(preferred: ActivityKind? = nil) {
        self.preferred = preferred
    }

    /// Etkinlik başladı/bitti.
    func setting(_ kind: ActivityKind, active isActive: Bool) -> ActivityCarousel {
        var copy = self
        let wasActive = active.contains(kind)
        if isActive, !wasActive {
            copy.active.append(kind)
        } else if !isActive, wasActive {
            copy.active.removeAll { $0 == kind }
        }
        // Elle seçilen etkinlik bittiyse elle mod da biter.
        if copy.isManual, let manual = copy.selected, !copy.active.contains(manual) { copy.isManual = false }
        copy.selected = copy.choose(newlyStarted: isActive && !wasActive ? kind : nil)
        return copy
    }

    /// Tercih değişince elle seçim ve mevcut gösterim korunur (Otomatik'e geçmek ekranı zıplatmaz).
    func withPreferred(_ preferred: ActivityKind?) -> ActivityCarousel {
        var copy = ActivityCarousel(preferred: preferred)
        copy.active = active
        copy.selected = selected
        copy.isManual = isManual
        copy.selected = copy.choose(newlyStarted: nil)
        return copy
    }

    /// Kaydırma: +1 sonraki, -1 önceki (döngüsel).
    func stepped(by offset: Int) -> ActivityCarousel {
        guard active.count > 1, let current = selected, let index = active.firstIndex(of: current) else { return self }
        var copy = self
        let count = active.count
        copy.selected = active[((index + offset) % count + count) % count]
        copy.isManual = true
        return copy
    }

    var count: Int { active.count }
    var selectedIndex: Int? { selected.flatMap { active.firstIndex(of: $0) } }

    private func choose(newlyStarted: ActivityKind?) -> ActivityKind? {
        guard !active.isEmpty else { return nil }
        if isManual, let selected, active.contains(selected) { return selected }
        if let preferred, active.contains(preferred) { return preferred }
        if let newlyStarted { return newlyStarted }
        if let selected, active.contains(selected) { return selected }
        return active.last
    }
}
