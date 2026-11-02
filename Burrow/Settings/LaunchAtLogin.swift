import Combine
import ServiceManagement

/// Girişte başlat (SMAppService; ek yardımcı uygulama gerektirmez).
@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var isEnabled = SMAppService.mainApp.status == .enabled
    @Published private(set) var lastError: String?

    func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// İlk açılışta varsayılan olarak etkinleştir (kullanıcı sonra kapatabilir).
    func enableOnFirstLaunch(defaults: UserDefaults = .standard) {
        let key = "didConfigureLaunchAtLogin"
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        set(true)
    }
}
