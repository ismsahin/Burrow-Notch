import AppKit
import SwiftUI
import Combine

enum NotchTab: String, CaseIterable, Identifiable {
    case home, shelf, clipboard, timer, reminders, notifications
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Ana"
        case .shelf: return "Raf"
        case .clipboard: return "Pano"
        case .timer: return "Süre"
        case .reminders: return "Anımsatıcılar"
        case .notifications: return "Bildirimler"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .shelf: return "tray.full.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .timer: return "timer"
        case .reminders: return "checklist"
        case .notifications: return "bell.fill"
        }
    }
}

/// Bir ekrandaki çentiğin arayüz durumu. Servisler paylaşılır, açık/kapalı durumu ekrana özeldir.
@MainActor
final class NotchViewModel: ObservableObject {
    @Published private(set) var geometry: NotchGeometry
    @Published private(set) var isExpanded = false
    @Published var tab: NotchTab = .home
    /// Son sekme geçişinin yönü: true = sağdaki sekmeye (içerik sola kayar), false = soldakine.
    @Published private(set) var isTabForward = true
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

    /// Sekme değiştir: önce yön ayarlanır ki çıkan sekme de doğru yöne kaysın, sonra sekme animasyonla değişir.
    func select(_ newTab: NotchTab) {
        guard newTab != tab else { return }
        isTabForward = Self.isForward(from: tab, to: newTab)
        DispatchQueue.main.async { [weak self] in
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { self?.tab = newTab }
        }
    }

    /// Saf: üst banttaki sırada sağa mı gidiliyor?
    nonisolated static func isForward(from old: NotchTab, to new: NotchTab) -> Bool {
        let order = NotchTab.allCases
        return (order.firstIndex(of: new) ?? 0) > (order.firstIndex(of: old) ?? 0)
    }

    func updateGeometry(_ geometry: NotchGeometry) {
        if geometry != self.geometry { self.geometry = geometry }
    }

    var topRadius: CGFloat { isExpanded ? Self.expandedTopRadius : Self.topRadius }
    var bottomRadius: CGFloat { isExpanded ? 28 : 10 }

    // MARK: - Ada (Dynamic Island) biçimi

    /// Çentiksiz ekranda "hap" biçimi seçiliyse true.
    var isIsland: Bool { !geometry.hasPhysicalNotch && services.settings.notchlessStyle == .island }
    /// Küçük ada: menü çubuğunun içinde dikey ortalı. Büyük ada: daha iri, menü çubuğunun biraz altına sarkan hap.
    var topInset: CGFloat {
        guard isIsland else { return 0 }
        if services.settings.islandSize == .large { return Self.largeIslandTopInset }
        return max(2, (geometry.notchSize.height - islandHeight) / 2)
    }
    var islandHeight: CGFloat {
        if services.settings.islandSize == .large { return Self.largeIslandHeight }
        return max(Self.minIslandHeight, geometry.notchSize.height - Self.islandMenuBarMargin)
    }
    static let largeIslandHeight: CGFloat = 32
    static let largeIslandTopInset: CGFloat = 6
    /// Gelen bildirim kartında çentiğin altına eklenen yükseklik.
    static let notificationCardHeight: CGFloat = 46
    static let minIslandHeight: CGFloat = 18
    static let islandMenuBarMargin: CGFloat = 5
    /// Küçük adanın ortası (kamera yok, daha dar): boşken küçük bir hap.
    static let islandCenterWidth: CGFloat = 78
    /// Köşeli ada: hap'ten biraz geniş, köşeleri çentik oranında (yükseklikle orantılı).
    static let squaredIslandCenterWidth: CGFloat = 120
    static let squaredIslandCornerRatio: CGFloat = 0.32
    var isSquaredIsland: Bool { isIsland && services.settings.islandCorners == .squared }
    /// Kapalı adanın köşe yarıçapı: hap'te yarı yükseklik, köşelide çentik oranı.
    var islandCornerRadius: CGFloat {
        isSquaredIsland ? (islandHeight * Self.squaredIslandCornerRatio).rounded() : islandHeight / 2
    }
    /// Büyük HUD'da çentiğin altına eklenen yükseklik.
    static let largeHUDExtraHeight: CGFloat = 34

    /// Ortadaki boş alan (fiziksel çentik / ada gövdesi) genişliği.
    var centerWidth: CGFloat {
        guard isIsland else { return geometry.notchSize.width }
        return isSquaredIsland ? Self.squaredIslandCenterWidth : Self.islandCenterWidth
    }
    /// Kapalı hâlin ilk satır yüksekliği (çentik ya da ada).
    var barHeight: CGFloat { isIsland ? islandHeight : geometry.notchSize.height }

    func isLargeHUD(_ activity: LiveActivity) -> Bool {
        if case .hud = activity { return services.settings.hudStyle == .large }
        return false
    }

    /// Çentiğin altına uzayan ek satırın yüksekliği (büyük HUD / bildirim kartı).
    func dropDownHeight(for activity: LiveActivity) -> CGFloat {
        if isLargeHUD(activity) { return Self.largeHUDExtraHeight }
        if case .notification = activity { return Self.notificationCardHeight }
        return 0
    }

    /// Kapalı hâlde dinlenme boyutu (çentik + canlı etkinlik payı + şekil kıvrımları). İsabet alanı bundan hesaplanır.
    func compactSize(for activity: LiveActivity) -> CGSize {
        let extra = isLargeHUD(activity) ? 120 : activity.extraWidth
        let sidePadding = isIsland ? islandHeight * 0.5 : Self.topRadius * 2
        return CGSize(
            width: centerWidth + extra + sidePadding,
            height: barHeight + dropDownHeight(for: activity)
        )
    }

    /// Ekran koordinatında, üst kenara (ve adada üst boşluğa) göre hizalı dikdörtgen.
    /// Adada üstteki boşluk da dahil edilir: imleci ekranın en tepesine itmek de adayı yakalar (Fitts yasası).
    func screenRect(size: CGSize, padding: CGFloat = 0) -> CGRect {
        var rect = geometry.topCenteredRect(size: size, padding: padding)
        rect.origin.y -= topInset
        rect.size.height += topInset
        return rect
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
            // Force Touch trackpad'de hissedilir (parmak trackpad üzerindeyken).
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        services.calendar.reload()
        services.shelf.prune()
        services.notifications.markAllRead()
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        isDropTargeted = false
        services.mirror.stop()
    }
}
