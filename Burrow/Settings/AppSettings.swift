import Combine
import Foundation

/// Çentiğin nasıl açılacağı.
enum OpenMode: String, CaseIterable, Identifiable {
    /// İmleç çentik üzerinde `hoverDelay` kadar bekleyince açılır.
    case hover
    /// Yalnızca tıklayınca açılır.
    case click
    var id: String { rawValue }
    var title: String { self == .hover ? "Üzerinde bekleyince" : "Tıklayınca" }
}

/// Çentiğin hangi ekranlarda görüneceği.
enum DisplayMode: String, CaseIterable, Identifiable {
    /// Fiziksel çentikli ekran (MacBook). Yoksa (kapak kapalı) ana ekran.
    case notched
    /// Menü çubuğunun bulunduğu ana ekran (Sistem Ayarları › Ekranlar'daki birincil ekran).
    case primary
    /// Bağlı tüm ekranlar.
    case all
    var id: String { rawValue }
    var title: String {
        switch self {
        case .notched: return "Çentikli ekran (MacBook)"
        case .primary: return "Ana ekran"
        case .all: return "Tüm ekranlar"
        }
    }
}

/// Tüm kullanıcı tercihleri. UserDefaults'a yazılır; test için farklı suite verilebilir.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum Key {
        static let openMode = "openMode"
        static let proximityEffect = "proximityEffect"
        static let displayMode = "displayMode"
        // Eski (v1.0.3) anahtarlar — yalnızca taşıma için okunur
        static let legacyHoverToExpand = "hoverToExpand"
        static let legacyShowOnAllDisplays = "showOnAllDisplays"
        static let hoverDelay = "hoverDelay"
        static let hapticsEnabled = "hapticsEnabled"
        static let showMediaActivity = "showMediaActivity"
        static let showBatteryActivity = "showBatteryActivity"
        static let showDeviceActivity = "showDeviceActivity"
        static let showCalendar = "showCalendar"
        static let replaceSystemHUD = "replaceSystemHUD"
        static let showVolumeChanges = "showVolumeChanges"
        static let enableShelf = "enableShelf"
        static let enableMirror = "enableMirror"
        static let swipeGestures = "swipeGestures"
        static let albumTint = "albumTint"
        static let lowBatteryThreshold = "lowBatteryThreshold"
    }

    private let defaults: UserDefaults

    @Published var openMode: OpenMode { didSet { defaults.set(openMode.rawValue, forKey: Key.openMode) } }
    @Published var proximityEffect: Bool { didSet { defaults.set(proximityEffect, forKey: Key.proximityEffect) } }
    @Published var displayMode: DisplayMode { didSet { defaults.set(displayMode.rawValue, forKey: Key.displayMode) } }
    @Published var hoverDelay: Double { didSet { defaults.set(hoverDelay, forKey: Key.hoverDelay) } }
    @Published var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: Key.hapticsEnabled) } }
    @Published var showMediaActivity: Bool { didSet { defaults.set(showMediaActivity, forKey: Key.showMediaActivity) } }
    @Published var showBatteryActivity: Bool { didSet { defaults.set(showBatteryActivity, forKey: Key.showBatteryActivity) } }
    @Published var showDeviceActivity: Bool { didSet { defaults.set(showDeviceActivity, forKey: Key.showDeviceActivity) } }
    @Published var showCalendar: Bool { didSet { defaults.set(showCalendar, forKey: Key.showCalendar) } }
    @Published var replaceSystemHUD: Bool { didSet { defaults.set(replaceSystemHUD, forKey: Key.replaceSystemHUD) } }
    @Published var showVolumeChanges: Bool { didSet { defaults.set(showVolumeChanges, forKey: Key.showVolumeChanges) } }
    @Published var enableShelf: Bool { didSet { defaults.set(enableShelf, forKey: Key.enableShelf) } }
    @Published var enableMirror: Bool { didSet { defaults.set(enableMirror, forKey: Key.enableMirror) } }
    @Published var swipeGestures: Bool { didSet { defaults.set(swipeGestures, forKey: Key.swipeGestures) } }
    @Published var albumTint: Bool { didSet { defaults.set(albumTint, forKey: Key.albumTint) } }
    @Published var lowBatteryThreshold: Int { didSet { defaults.set(lowBatteryThreshold, forKey: Key.lowBatteryThreshold) } }

    static let defaultValues: [String: Any] = [
        Key.proximityEffect: true,
        Key.hoverDelay: 0.15,
        Key.hapticsEnabled: true,
        Key.showMediaActivity: true,
        Key.showBatteryActivity: true,
        Key.showDeviceActivity: true,
        Key.showCalendar: true,
        Key.replaceSystemHUD: false,
        Key.showVolumeChanges: true,
        Key.enableShelf: true,
        Key.enableMirror: true,
        Key.swipeGestures: true,
        Key.albumTint: true,
        Key.lowBatteryThreshold: 20,
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: Self.defaultValues)
        openMode = Self.migratedOpenMode(defaults)
        proximityEffect = defaults.bool(forKey: Key.proximityEffect)
        displayMode = Self.migratedDisplayMode(defaults)
        hoverDelay = defaults.double(forKey: Key.hoverDelay)
        hapticsEnabled = defaults.bool(forKey: Key.hapticsEnabled)
        showMediaActivity = defaults.bool(forKey: Key.showMediaActivity)
        showBatteryActivity = defaults.bool(forKey: Key.showBatteryActivity)
        showDeviceActivity = defaults.bool(forKey: Key.showDeviceActivity)
        showCalendar = defaults.bool(forKey: Key.showCalendar)
        replaceSystemHUD = defaults.bool(forKey: Key.replaceSystemHUD)
        showVolumeChanges = defaults.bool(forKey: Key.showVolumeChanges)
        enableShelf = defaults.bool(forKey: Key.enableShelf)
        enableMirror = defaults.bool(forKey: Key.enableMirror)
        swipeGestures = defaults.bool(forKey: Key.swipeGestures)
        albumTint = defaults.bool(forKey: Key.albumTint)
        lowBatteryThreshold = min(50, max(5, defaults.integer(forKey: Key.lowBatteryThreshold)))
    }

    /// v1.0.3'teki "Üzerine gelince aç" anahtarı kapalıysa tıklama moduna taşınır.
    private static func migratedOpenMode(_ defaults: UserDefaults) -> OpenMode {
        if let raw = defaults.string(forKey: Key.openMode), let mode = OpenMode(rawValue: raw) { return mode }
        if defaults.object(forKey: Key.legacyHoverToExpand) != nil, !defaults.bool(forKey: Key.legacyHoverToExpand) { return .click }
        return .hover
    }

    /// v1.0.3'teki "Tüm ekranlarda göster" açıksa `.all`'a taşınır.
    private static func migratedDisplayMode(_ defaults: UserDefaults) -> DisplayMode {
        if let raw = defaults.string(forKey: Key.displayMode), let mode = DisplayMode(rawValue: raw) { return mode }
        return defaults.bool(forKey: Key.legacyShowOnAllDisplays) ? .all : .notched
    }
}
