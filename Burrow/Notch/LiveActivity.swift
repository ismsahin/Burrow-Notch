import Foundation

/// Kapalı (compact) çentiğin iki yanında gösterilen canlı etkinlik.
enum LiveActivity: Equatable {
    case none
    case media
    case charging(percent: Int, isCharging: Bool)
    case lowBattery(percent: Int)
    case hud(kind: HUDKind, value: Double)
    case device(name: String, connected: Bool)

    /// Yüksek değer kazanır. Geçici (transient) etkinlikler medyanın üstüne çıkar.
    var priority: Int {
        switch self {
        case .none: return 0
        case .media: return 10
        case .device: return 30
        case .charging: return 40
        case .lowBattery: return 50
        case .hud: return 60
        }
    }

    /// Geçici etkinliğin ekranda kalma süresi (sn). Kalıcılar için nil.
    var displayDuration: TimeInterval? {
        switch self {
        case .none, .media: return nil
        case .hud: return 1.6
        case .charging: return 3
        case .lowBattery: return 5
        case .device: return 3
        }
    }

    /// Çentiğin yanlarına eklenen genişlik (her iki yan toplamı).
    var extraWidth: CGFloat {
        switch self {
        case .none: return 0
        case .media: return 84
        case .hud: return 170
        case .charging, .lowBattery: return 110
        case .device: return 200
        }
    }
}

enum HUDKind: Equatable {
    case volume(muted: Bool)
    case brightness
}

/// Geçici etkinlikleri kalıcı (medya) etkinlikle birleştiren saf karar mantığı.
struct ActivityResolver {
    /// - Parameters:
    ///   - transient: Süresi dolmamış geçici etkinlik (varsa).
    ///   - isMediaActive: Medya canlı etkinliği gösterilmeli mi?
    static func resolve(transient: LiveActivity?, isMediaActive: Bool) -> LiveActivity {
        let base: LiveActivity = isMediaActive ? .media : .none
        guard let transient else { return base }
        return transient.priority >= base.priority ? transient : base
    }

    /// Yeni geçici etkinlik mevcut olanın yerini almalı mı?
    /// Aynı türdeki güncellemeler (ör. ses seviyesi değişimi) her zaman yerini alır.
    static func shouldReplace(current: LiveActivity?, with incoming: LiveActivity) -> Bool {
        guard let current else { return true }
        if current.isSameKind(as: incoming) { return true }
        return incoming.priority >= current.priority
    }
}

extension LiveActivity {
    func isSameKind(as other: LiveActivity) -> Bool {
        switch (self, other) {
        case (.none, .none), (.media, .media): return true
        case (.charging, .charging), (.lowBattery, .lowBattery), (.device, .device): return true
        case let (.hud(a, _), .hud(b, _)):
            switch (a, b) {
            case (.volume, .volume), (.brightness, .brightness): return true
            default: return false
            }
        default: return false
        }
    }
}
