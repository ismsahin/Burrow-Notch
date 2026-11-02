import AppKit
import Combine

/// Uygulama ömrü boyunca yaşayan servisler ve aralarındaki bağlantılar.
@MainActor
final class AppServices: ObservableObject {
    let settings: AppSettings
    let activity = ActivityCenter()
    let media = MediaController()
    let battery = BatteryMonitor()
    let volume = VolumeController()
    let calendar = CalendarService()
    let shelf = ShelfStore()
    let mirror = CameraMirror()
    let bluetooth = BluetoothMonitor()

    /// HUD değiştirme açık ama erişilebilirlik izni yoksa ayarlarda uyarı gösterilir.
    @Published private(set) var keyTapActive = false

    private lazy var keyTap = MediaKeyTap { [weak self] key, fine in
        MainActor.assumeIsolated { self?.handleMediaKey(key, fine: fine) ?? false }
    }
    private var bag = Set<AnyCancellable>()
    private var permissionPoll: Timer?

    init(settings: AppSettings = .shared) {
        self.settings = settings
        wire()
    }

    private func wire() {
        media.$info
            .combineLatest(settings.$showMediaActivity)
            .map { info, enabled in enabled && (info?.isPlaying ?? false) }
            .removeDuplicates()
            .sink { [weak self] in self?.activity.setMediaActive($0) }
            .store(in: &bag)

        battery.plugEvents
            .filter { [weak self] _ in self?.settings.showBatteryActivity ?? false }
            .sink { [weak self] state in
                self?.activity.show(.charging(percent: state.percent, isCharging: state.isPluggedIn))
            }
            .store(in: &bag)

        battery.lowBatteryEvents
            .filter { [weak self] _ in self?.settings.showBatteryActivity ?? false }
            .sink { [weak self] state in self?.activity.show(.lowBattery(percent: state.percent)) }
            .store(in: &bag)

        settings.$lowBatteryThreshold
            .sink { [weak self] in self?.battery.lowThreshold = $0 }
            .store(in: &bag)

        volume.changes
            .filter { [weak self] _ in self?.settings.showVolumeChanges ?? false }
            .sink { [weak self] change in
                self?.activity.show(.hud(kind: .volume(muted: change.muted), value: change.muted ? 0 : change.volume))
            }
            .store(in: &bag)

        bluetooth.events
            .filter { [weak self] _ in self?.settings.showDeviceActivity ?? false }
            .sink { [weak self] event in self?.activity.show(.device(name: event.name, connected: event.connected)) }
            .store(in: &bag)

        settings.$showDeviceActivity
            .removeDuplicates()
            .sink { [weak self] enabled in enabled ? self?.bluetooth.start() : self?.bluetooth.stop() }
            .store(in: &bag)

        settings.$replaceSystemHUD
            .removeDuplicates()
            .sink { [weak self] in self?.updateKeyTap(enabled: $0) }
            .store(in: &bag)
    }

    // MARK: - Sistem HUD'unu değiştirme

    func updateKeyTap(enabled: Bool) {
        permissionPoll?.invalidate()
        permissionPoll = nil
        guard enabled else {
            keyTap.stop()
            keyTapActive = false
            return
        }
        if keyTap.start() {
            keyTapActive = true
            return
        }
        keyTapActive = false
        MediaKeyTap.requestPermission()
        // Kullanıcı izni Sistem Ayarları'ndan verince otomatik başlat (en fazla 2 dk bekle).
        var remaining = 60
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                remaining -= 1
                if self.keyTap.start() {
                    self.keyTapActive = true
                    timer.invalidate()
                } else if remaining <= 0 {
                    timer.invalidate()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionPoll = timer
    }

    private func handleMediaKey(_ key: MediaKeyTap.Key, fine: Bool) -> Bool {
        let volumeStep = fine ? VolumeController.step / 4 : VolumeController.step
        let brightnessStep = fine ? BrightnessController.step / 4 : BrightnessController.step
        switch key {
        case .volumeUp, .volumeDown:
            // Aygıt yazılımsal sesi desteklemiyorsa (ör. HDMI) tuşu sisteme bırak.
            guard volume.adjust(by: key == .volumeUp ? volumeStep : -volumeStep) else { return false }
            showVolume()
        case .mute:
            guard volume.toggleMute() else { return false }
            showVolume()
        case .brightnessUp, .brightnessDown:
            let brightness = BrightnessController.shared
            guard brightness.isAvailable,
                  let value = brightness.adjust(by: key == .brightnessUp ? brightnessStep : -brightnessStep) else {
                return false // Sisteme bırak
            }
            activity.show(.hud(kind: .brightness, value: Double(value)))
        }
        return true
    }

    /// Sınırda (0 veya 1) değer değişmese de geri bildirim göster.
    private func showVolume() {
        activity.show(.hud(kind: .volume(muted: volume.isMuted), value: volume.isMuted ? 0 : volume.volume))
    }
}
