import Combine
import Foundation

/// Tüm servislerden gelen olayları tek bir "şu an gösterilecek canlı etkinlik" durumuna indirger.
/// Tüm çentik pencereleri (çoklu ekran) aynı merkezi dinler.
@MainActor
final class ActivityCenter: ObservableObject {
    @Published private(set) var current: LiveActivity = .none

    private var transient: LiveActivity?
    private var transientExpiry: DispatchWorkItem?
    private var isMediaActive = false

    func setMediaActive(_ active: Bool) {
        guard active != isMediaActive else { return }
        isMediaActive = active
        recompute()
    }

    func show(_ activity: LiveActivity) {
        guard ActivityResolver.shouldReplace(current: transient, with: activity) else { return }
        transient = activity
        transientExpiry?.cancel()
        if let duration = activity.displayDuration {
            let work = DispatchWorkItem { [weak self] in
                self?.transient = nil
                self?.recompute()
            }
            transientExpiry = work
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
        }
        recompute()
    }

    private func recompute() {
        let resolved = ActivityResolver.resolve(transient: transient, isMediaActive: isMediaActive)
        if resolved != current { current = resolved }
    }
}
