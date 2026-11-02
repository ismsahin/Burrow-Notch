import AppKit
import Combine

enum NotchTab: String, CaseIterable, Identifiable {
    case home, shelf
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Ana"
        case .shelf: return "Raf"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .shelf: return "tray.full.fill"
        }
    }
}

/// Bir ekrandaki çentiğin arayüz durumu. Servisler paylaşılır, açık/kapalı durumu ekrana özeldir.
@MainActor
final class NotchViewModel: ObservableObject {
    @Published private(set) var geometry: NotchGeometry
    @Published private(set) var isExpanded = false
    @Published var tab: NotchTab = .home
    @Published var isDropTargeted = false
    /// İmlecin kapalı çentiğe yakınlığı (0…1). Alcove tarzı "yaklaşınca kabarma" efekti için.
    @Published private(set) var proximity: Double = 0

    let services: AppServices
    static let topRadius: CGFloat = 6
    static let expandedTopRadius: CGFloat = 14

    init(geometry: NotchGeometry, services: AppServices) {
        self.geometry = geometry
        self.services = services
    }

    /// Yakınlıkta en fazla bu kadar büyür (genişlik / yükseklik, pt).
    static let proximityGrowth = CGSize(width: 34, height: 7)
    /// İmleç bu mesafeden itibaren etki başlar (pt).
    static let proximityRadius: CGFloat = 90

    /// Küçük titreşimleri yayınlama (gereksiz yeniden çizim olmasın).
    func setProximity(_ value: Double) {
        let clamped = min(1, max(0, value))
        let snapped = clamped < 0.02 ? 0 : clamped
        if abs(snapped - proximity) > 0.025 || (snapped == 0) != (proximity == 0) || (snapped == 1) != (proximity == 1) {
            proximity = snapped
        }
    }

    func updateGeometry(_ geometry: NotchGeometry) {
        if geometry != self.geometry { self.geometry = geometry }
    }

    var topRadius: CGFloat { isExpanded ? Self.expandedTopRadius : Self.topRadius }
    var bottomRadius: CGFloat { isExpanded ? 28 : 10 }

    /// Kapalı hâlde dinlenme boyutu (çentik + canlı etkinlik payı + şekil kıvrımları). İsabet alanı bundan hesaplanır.
    func compactSize(for activity: LiveActivity) -> CGSize {
        CGSize(
            width: geometry.notchSize.width + activity.extraWidth + Self.topRadius * 2,
            height: geometry.notchSize.height
        )
    }

    /// Çizilen boyut: dinlenme boyutu + yakınlık kabarması.
    func displayedCompactSize(for activity: LiveActivity) -> CGSize {
        let base = compactSize(for: activity)
        let p = CGFloat(services.settings.proximityEffect ? proximity : 0)
        return CGSize(width: base.width + Self.proximityGrowth.width * p,
                      height: base.height + Self.proximityGrowth.height * p)
    }

    var expandedSize: CGSize {
        CGSize(width: NotchGeometry.expandedSize.width,
               height: NotchGeometry.expandedSize.height + max(0, geometry.notchSize.height - 32))
    }

    func currentSize(for activity: LiveActivity) -> CGSize {
        isExpanded ? expandedSize : displayedCompactSize(for: activity)
    }

    func expand(tab: NotchTab? = nil) {
        if let tab { self.tab = tab }
        guard !isExpanded else { return }
        proximity = 0
        isExpanded = true
        if services.settings.hapticsEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        services.calendar.reload()
        services.shelf.prune()
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        isDropTargeted = false
        services.mirror.stop()
    }
}
