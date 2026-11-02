import Foundation

/// Kapalı (compact) çentiğin iki yanında gösterilen canlı etkinlik.
///
/// İki tür vardır:
/// - **Kalıcı** (`media`, `download`, `calendar`, `timer`): sürdükçe görünür, birden fazlası aynı anda olabilir;
///   kullanıcı kaydırarak aralarında geçer (bkz. `ActivityCarousel`).
/// - **Geçici** (`charging`, `lowBattery`, `hud`, `device`): birkaç saniye üstte görünür, sonra kalıcıya döner.
enum LiveActivity: Equatable {
    case none
    case media
    case download(name: String, progress: Double, count: Int)
    case calendar(title: String, startsAt: Date)
    case timer(endsAt: Date, total: TimeInterval)
    case charging(percent: Int, isCharging: Bool)
    case lowBattery(percent: Int)
    case hud(kind: HUDKind, value: Double)
    case device(name: String, connected: Bool, battery: DeviceBattery?)
    /// Genel kısa bildirim: zamanlayıcı bitti, indirme tamamlandı, etkinlik başlıyor…
    case notice(symbol: String, title: String, detail: String)

    var kind: ActivityKind? {
        switch self {
        case .media: return .media
        case .download: return .download
        case .calendar: return .calendar
        case .timer: return .timer
        default: return nil
        }
    }

    var isTransient: Bool { displayDuration != nil }

    /// Geçici etkinlikler arasında öncelik: yüksek olan, düşüğünün üstüne yazar.
    var priority: Int {
        switch self {
        case .none: return 0
        case .media, .download, .calendar, .timer: return 10
        case .device: return 30
        case .notice: return 35
        case .charging: return 40
        case .lowBattery: return 50
        case .hud: return 60
        }
    }

    /// Geçici etkinliğin ekranda kalma süresi (sn). Kalıcılar için nil.
    var displayDuration: TimeInterval? {
        switch self {
        case .none, .media, .download, .calendar, .timer: return nil
        case .hud: return 1.6
        case .charging: return 3
        case .lowBattery: return 5
        case .device(_, _, let battery): return battery == nil ? 3 : 4.5
        case .notice: return 3.5
        }
    }

    /// Çentiğin yanlarına eklenen genişlik (iki yan toplamı).
    var extraWidth: CGFloat {
        switch self {
        case .none: return 0
        case .media: return 84
        case .download: return 150
        case .calendar: return 210
        case .timer: return 130
        case .hud: return 170
        case .charging, .lowBattery: return 110
        case .device(_, _, let battery): return battery == nil ? 200 : 300
        case .notice: return 240
        }
    }

    func isSameKind(as other: LiveActivity) -> Bool {
        switch (self, other) {
        case (.none, .none), (.media, .media), (.download, .download), (.calendar, .calendar), (.timer, .timer),
             (.charging, .charging), (.lowBattery, .lowBattery), (.device, .device), (.notice, .notice):
            return true
        case let (.hud(a, _), .hud(b, _)):
            switch (a, b) {
            case (.volume, .volume), (.brightness, .brightness): return true
            default: return false
            }
        default:
            return false
        }
    }
}

enum HUDKind: Equatable {
    case volume(muted: Bool)
    case brightness
}

/// Kalıcı etkinlik türleri. Sıra, "Otomatik" modda eşitlik bozucudur.
enum ActivityKind: String, CaseIterable, Identifiable, Codable {
    case media, download, calendar, timer
    var id: String { rawValue }

    var title: String {
        switch self {
        case .media: return "Çalan müzik"
        case .download: return "İndirmeler"
        case .calendar: return "Yaklaşan etkinlik"
        case .timer: return "Zamanlayıcı"
        }
    }
}

/// Geçici etkinlik kararları (saf, test edilir).
struct ActivityResolver {
    /// Yeni geçici etkinlik mevcut olanın yerini almalı mı? Aynı tür güncellemeler her zaman alır.
    static func shouldReplace(current: LiveActivity?, with incoming: LiveActivity) -> Bool {
        guard let current else { return true }
        if current.isSameKind(as: incoming) { return true }
        return incoming.priority >= current.priority
    }

    /// Geçici varsa o, yoksa döngüde seçili kalıcı etkinlik.
    static func resolve(transient: LiveActivity?, persistent: LiveActivity?) -> LiveActivity {
        transient ?? persistent ?? .none
    }
}
