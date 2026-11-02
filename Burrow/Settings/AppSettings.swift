import Combine
import Foundation

/// Tüm kullanıcı tercihleri. UserDefaults'a yazılır; test için farklı suite verilebilir.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum Key {
        static let hoverToExpand = "hoverToExpand"
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
        static let showOnAllDisplays = "showOnAllDisplays"
        static let lowBatteryThreshold = "lowBatteryThreshold"
    }

    private let defaults: UserDefaults

    @Published var hoverToExpand: Bool { didSet { defaults.set(hoverToExpand, forKey: Key.hoverToExpand) } }
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
    @Published var showOnAllDisplays: Bool { didSet { defaults.set(showOnAllDisplays, forKey: Key.showOnAllDisplays) } }
    @Published var lowBatteryThreshold: Int { didSet { defaults.set(lowBatteryThreshold, forKey: Key.lowBatteryThreshold) } }

    static let defaultValues: [String: Any] = [
        Key.hoverToExpand: true,
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
        Key.showOnAllDisplays: false,
        Key.lowBatteryThreshold: 20,
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: Self.defaultValues)
        hoverToExpand = defaults.bool(forKey: Key.hoverToExpand)
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
        showOnAllDisplays = defaults.bool(forKey: Key.showOnAllDisplays)
        lowBatteryThreshold = min(50, max(5, defaults.integer(forKey: Key.lowBatteryThreshold)))
    }
}
