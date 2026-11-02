import Combine
import Foundation

/// Tüm servislerden gelen olayları tek bir "şu an gösterilecek canlı etkinlik" durumuna indirger.
/// Tüm çentik pencereleri (çoklu ekran) aynı merkezi dinler.
@MainActor
final class ActivityCenter: ObservableObject {
    @Published private(set) var current: LiveActivity = .none
    /// Döngü durumu (sayfa noktaları için).
    @Published private(set) var carousel = ActivityCarousel()

    private var persistent: [ActivityKind: LiveActivity] = [:]
    private var transient: LiveActivity?
    private var transientExpiry: DispatchWorkItem?

    // MARK: - Kalıcı etkinlikler

    /// Kalıcı etkinliği günceller; `nil` bitti demektir.
    func update(_ kind: ActivityKind, _ activity: LiveActivity?) {
        let wasActive = persistent[kind] != nil
        persistent[kind] = activity
        let isActive = activity != nil
        if wasActive != isActive { carousel = carousel.setting(kind, active: isActive) }
        recompute()
    }

    func setPreferred(_ kind: ActivityKind?) {
        carousel = carousel.withPreferred(kind)
        recompute()
    }

    /// Kaydırma ile etkinlikler arasında geçiş. Geçiş olduysa true.
    @discardableResult
    func step(by offset: Int) -> Bool {
        guard transient == nil, carousel.count > 1 else { return false }
        carousel = carousel.stepped(by: offset)
        recompute()
        return true
    }

    // MARK: - Geçici etkinlikler

    func show(_ activity: LiveActivity) {
        guard activity.isTransient, ActivityResolver.shouldReplace(current: transient, with: activity) else { return }
        transient = activity
        transientExpiry?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.transient = nil
            self?.recompute()
        }
        transientExpiry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (activity.displayDuration ?? 2), execute: work)
        recompute()
    }

    private func recompute() {
        let selected = carousel.selected.flatMap { persistent[$0] }
        let resolved = ActivityResolver.resolve(transient: transient, persistent: selected)
        if resolved != current { current = resolved }
    }
}
