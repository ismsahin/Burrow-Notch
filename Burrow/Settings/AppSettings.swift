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

/// Çentiksiz ekranlarda (harici monitör vb.) görünüm.
enum NotchlessStyle: String, CaseIterable, Identifiable {
    /// Menü çubuğuna yapışık sanal çentik.
    case notch
    /// iPhone'daki gibi tepeden biraz aşağıda yüzen hap (Dynamic Island).
    case island
    var id: String { rawValue }
    var title: String { self == .notch ? "Sanal çentik" : "Dynamic Island (hap)" }
}

/// Ada (hap) boyutu.
enum IslandSize: String, CaseIterable, Identifiable {
    /// Menü çubuğunun içine sığan ince hap.
    case compact
    /// Daha iri, menü çubuğunun biraz altına sarkan hap (iPhone Dynamic Island hissi).
    case large
    var id: String { rawValue }
    var title: String { self == .compact ? "Küçük (menü çubuğunda)" : "Büyük" }
}

/// Adanın köşe biçimi.
enum IslandCorners: String, CaseIterable, Identifiable {
    /// Tam yuvarlak hap (dar).
    case rounded
    /// Çentik gibi hafif yuvarlak köşeli, biraz daha geniş.
    case squared
    var id: String { rawValue }
    var title: String { self == .rounded ? "Yuvarlak (hap)" : "Köşeli (çentik gibi)" }
}

/// Açık çentikte ana sekmede gösterilebilecek parçalar.
enum HomeWidget: String, CaseIterable, Identifiable {
    case media, calendar, reminders, mirror
    var id: String { rawValue }
    var title: String {
        switch self {
        case .media: return "Müzik çalar"
        case .calendar: return "Takvim"
        case .reminders: return "Anımsatıcılar"
        case .mirror: return "Kamera aynası"
        }
    }
    var symbol: String {
        switch self {
        case .media: return "music.note"
        case .calendar: return "calendar"
        case .reminders: return "checklist"
        case .mirror: return "person.crop.square"
        }
    }
    static let defaultLayout: [HomeWidget] = [.media, .calendar, .mirror]

    /// Kayıtlı ham değerlerden sıralı, tekrarsız düzen.
    static func parse(_ raw: [String]) -> [HomeWidget] {
        var seen = Set<HomeWidget>()
        return raw.compactMap(HomeWidget.init(rawValue:)).filter { seen.insert($0).inserted }
    }

    /// Açılan parça sona eklenir, kapatılan çıkarılır.
    static func toggled(_ layout: [HomeWidget], _ widget: HomeWidget, isOn: Bool) -> [HomeWidget] {
        let without = layout.filter { $0 != widget }
        return isOn ? without + [widget] : without
    }

    /// Parçayı `offset` kadar kaydırır (sınırlarda olduğu yerde kalır).
    static func moved(_ layout: [HomeWidget], _ widget: HomeWidget, by offset: Int) -> [HomeWidget] {
        guard let index = layout.firstIndex(of: widget) else { return layout }
        let target = index + offset
        guard layout.indices.contains(target) else { return layout }
        var result = layout
        result.swapAt(index, target)
        return result
    }
}

/// Ses/parlaklık göstergesinin biçimi.
enum HUDStyle: String, CaseIterable, Identifiable {
    /// Çentiğin iki yanında ince çubuk.
    case compact
    /// Çentik aşağı uzar: simge + kalın çubuk + yüzde.
    case large
    var id: String { rawValue }
    var title: String { self == .compact ? "Kompakt" : "Büyük" }
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
        static let notchlessStyle = "notchlessStyle"
        static let notchOutline = "notchOutline"
        static let hudStyle = "hudStyle"
        static let preferredActivity = "preferredActivity"
        static let showDownloadActivity = "showDownloadActivity"
        static let showCalendarActivity = "showCalendarActivity"
        static let calendarLeadMinutes = "calendarLeadMinutes"
        static let showDeviceBattery = "showDeviceBattery"
        static let islandSize = "islandSize"
        static let enableClipboard = "enableClipboard"
        static let enableNotifications = "enableNotifications"
        static let enableReminders = "enableReminders"
        static let islandCorners = "islandCorners"
        static let homeLayout = "homeLayout"
        static let reminderListID = "reminderListID"
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
    @Published var replaceSystemHUD: Bool { didSet { defaults.set(replaceSystemHUD, forKey: Key.replaceSystemHUD) } }
    @Published var showVolumeChanges: Bool { didSet { defaults.set(showVolumeChanges, forKey: Key.showVolumeChanges) } }
    @Published var enableShelf: Bool { didSet { defaults.set(enableShelf, forKey: Key.enableShelf) } }
    @Published var swipeGestures: Bool { didSet { defaults.set(swipeGestures, forKey: Key.swipeGestures) } }
    @Published var albumTint: Bool { didSet { defaults.set(albumTint, forKey: Key.albumTint) } }
    @Published var lowBatteryThreshold: Int { didSet { defaults.set(lowBatteryThreshold, forKey: Key.lowBatteryThreshold) } }
    @Published var notchlessStyle: NotchlessStyle { didSet { defaults.set(notchlessStyle.rawValue, forKey: Key.notchlessStyle) } }
    @Published var notchOutline: Bool { didSet { defaults.set(notchOutline, forKey: Key.notchOutline) } }
    @Published var hudStyle: HUDStyle { didSet { defaults.set(hudStyle.rawValue, forKey: Key.hudStyle) } }
    /// Birden fazla etkinlik varken varsayılan olarak gösterilecek. `nil` = Otomatik (en son başlayan).
    @Published var preferredActivity: ActivityKind? {
        didSet { defaults.set(preferredActivity?.rawValue ?? "auto", forKey: Key.preferredActivity) }
    }
    @Published var showDownloadActivity: Bool { didSet { defaults.set(showDownloadActivity, forKey: Key.showDownloadActivity) } }
    @Published var showCalendarActivity: Bool { didSet { defaults.set(showCalendarActivity, forKey: Key.showCalendarActivity) } }
    @Published var calendarLeadMinutes: Int { didSet { defaults.set(calendarLeadMinutes, forKey: Key.calendarLeadMinutes) } }
    @Published var showDeviceBattery: Bool { didSet { defaults.set(showDeviceBattery, forKey: Key.showDeviceBattery) } }
    @Published var islandSize: IslandSize { didSet { defaults.set(islandSize.rawValue, forKey: Key.islandSize) } }
    @Published var enableClipboard: Bool { didSet { defaults.set(enableClipboard, forKey: Key.enableClipboard) } }
    /// Tam Disk Erişimi gerektirir; izin yoksa sekmede yönlendirme gösterilir.
    @Published var enableNotifications: Bool { didSet { defaults.set(enableNotifications, forKey: Key.enableNotifications) } }
    @Published var enableReminders: Bool { didSet { defaults.set(enableReminders, forKey: Key.enableReminders) } }
    @Published var islandCorners: IslandCorners { didSet { defaults.set(islandCorners.rawValue, forKey: Key.islandCorners) } }
    /// Ana sekmedeki parçalar, gösterim sırasıyla. Listede olmayan gizlidir.
    @Published var homeLayout: [HomeWidget] { didSet { defaults.set(homeLayout.map(\.rawValue), forKey: Key.homeLayout) } }
    /// Anımsatıcılar sekmesinde seçili liste. Boş = ilk liste, `ReminderService.allListsID` = tümü.
    @Published var reminderListID: String { didSet { defaults.set(reminderListID, forKey: Key.reminderListID) } }

    var showCalendar: Bool {
        get { homeLayout.contains(.calendar) }
        set { homeLayout = HomeWidget.toggled(homeLayout, .calendar, isOn: newValue) }
    }
    var enableMirror: Bool {
        get { homeLayout.contains(.mirror) }
        set { homeLayout = HomeWidget.toggled(homeLayout, .mirror, isOn: newValue) }
    }

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
        Key.notchlessStyle: NotchlessStyle.notch.rawValue,
        Key.notchOutline: false,
        Key.hudStyle: HUDStyle.compact.rawValue,
        Key.preferredActivity: "auto",
        Key.showDownloadActivity: true,
        Key.showCalendarActivity: true,
        Key.calendarLeadMinutes: 15,
        Key.showDeviceBattery: true,
        Key.islandSize: IslandSize.large.rawValue,
        Key.enableClipboard: true,
        Key.enableNotifications: true,
        Key.enableReminders: true,
        Key.reminderListID: "",
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
        replaceSystemHUD = defaults.bool(forKey: Key.replaceSystemHUD)
        showVolumeChanges = defaults.bool(forKey: Key.showVolumeChanges)
        enableShelf = defaults.bool(forKey: Key.enableShelf)
        swipeGestures = defaults.bool(forKey: Key.swipeGestures)
        albumTint = defaults.bool(forKey: Key.albumTint)
        lowBatteryThreshold = min(50, max(5, defaults.integer(forKey: Key.lowBatteryThreshold)))
        notchlessStyle = NotchlessStyle(rawValue: defaults.string(forKey: Key.notchlessStyle) ?? "") ?? .notch
        notchOutline = defaults.bool(forKey: Key.notchOutline)
        hudStyle = HUDStyle(rawValue: defaults.string(forKey: Key.hudStyle) ?? "") ?? .compact
        preferredActivity = ActivityKind(rawValue: defaults.string(forKey: Key.preferredActivity) ?? "")
        showDownloadActivity = defaults.bool(forKey: Key.showDownloadActivity)
        showCalendarActivity = defaults.bool(forKey: Key.showCalendarActivity)
        calendarLeadMinutes = min(60, max(5, defaults.integer(forKey: Key.calendarLeadMinutes)))
        showDeviceBattery = defaults.bool(forKey: Key.showDeviceBattery)
        let storedIslandSize = IslandSize(rawValue: defaults.string(forKey: Key.islandSize) ?? "") ?? .large
        islandSize = storedIslandSize
        enableClipboard = defaults.bool(forKey: Key.enableClipboard)
        enableNotifications = defaults.bool(forKey: Key.enableNotifications)
        enableReminders = defaults.bool(forKey: Key.enableReminders)
        // Seçilmemişse: büyük adada köşeli, küçük adada eskisi gibi hap.
        islandCorners = IslandCorners(rawValue: defaults.string(forKey: Key.islandCorners) ?? "")
            ?? (storedIslandSize == .large ? .squared : .rounded)
        homeLayout = Self.migratedHomeLayout(defaults)
        reminderListID = defaults.string(forKey: Key.reminderListID) ?? ""
    }

    /// v1.0.8 ve öncesindeki "Takvim" / "Kamera aynası" anahtarları ana ekran düzenine taşınır.
    private static func migratedHomeLayout(_ defaults: UserDefaults) -> [HomeWidget] {
        if let raw = defaults.stringArray(forKey: Key.homeLayout) { return HomeWidget.parse(raw) }
        return HomeWidget.defaultLayout.filter { widget in
            switch widget {
            case .calendar: return defaults.bool(forKey: Key.showCalendar)
            case .mirror: return defaults.bool(forKey: Key.enableMirror)
            default: return true
            }
        }
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
