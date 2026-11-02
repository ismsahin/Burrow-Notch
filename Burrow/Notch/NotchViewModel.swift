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

    let services: AppServices
    static let topRadius: CGFloat = 6
    static let expandedTopRadius: CGFloat = 14

    init(geometry: NotchGeometry, services: AppServices) {
        self.geometry = geometry
        self.services = services
    }

    func updateGeometry(_ geometry: NotchGeometry) {
        if geometry != self.geometry { self.geometry = geometry }
    }

    var topRadius: CGFloat { isExpanded ? Self.expandedTopRadius : Self.topRadius }
    var bottomRadius: CGFloat { isExpanded ? 28 : 10 }

    /// Kapalı hâlde gösterilen boyut (çentik + canlı etkinlik payı + şekil kıvrımları).
    func compactSize(for activity: LiveActivity) -> CGSize {
        CGSize(
            width: geometry.notchSize.width + activity.extraWidth + Self.topRadius * 2,
            height: geometry.notchSize.height
        )
    }

    var expandedSize: CGSize {
        CGSize(width: NotchGeometry.expandedSize.width,
               height: NotchGeometry.expandedSize.height + max(0, geometry.notchSize.height - 32))
    }

    func currentSize(for activity: LiveActivity) -> CGSize {
        isExpanded ? expandedSize : compactSize(for: activity)
    }

    func expand(tab: NotchTab? = nil) {
        if let tab { self.tab = tab }
        guard !isExpanded else { return }
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
