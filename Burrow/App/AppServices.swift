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
    let downloads = DownloadMonitor()
    let timer = TimerService()
    let alarms = AlarmService()
    let clipboard = ClipboardStore()
    let reminders = ReminderService()
    let notifications = NotificationCenterService()

    /// Bağlı Bluetooth cihazlarının pil düzeyleri (ad → pil).
    @Published private(set) var deviceBatteries: [String: DeviceBattery] = [:]

    /// HUD değiştirme açık ama erişilebilirlik izni yoksa ayarlarda uyarı gösterilir.
    @Published private(set) var keyTapActive = false

    private lazy var keyTap = MediaKeyTap { [weak self] key, fine in
        MainActor.assumeIsolated { self?.handleMediaKey(key, fine: fine) ?? false }
    }
    private var bag = Set<AnyCancellable>()
    private var permissionPoll: Timer?
    private var calendarTicker: Timer?
    private var batteryTicker: Timer?
    private static let calendarTickInterval: TimeInterval = 30
    private static let batteryRefreshInterval: TimeInterval = 300
    /// AirPods pil bilgisi bağlantıdan birkaç saniye sonra hazır olur.
    private static let batteryReadDelay: TimeInterval = 2.5

    init(settings: AppSettings = .shared) {
        self.settings = settings
        wire()
        refreshDeviceBatteries() // açılışta zaten bağlı cihazlar
    }

    private func wire() {
        wirePersistentActivities()

        settings.$preferredActivity
            .removeDuplicates()
            .sink { [weak self] in self?.activity.setPreferred($0) }
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
            .sink { [weak self] event in self?.handleDevice(event) }
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

    // MARK: - Kalıcı etkinlikler (döngü)

    private func wirePersistentActivities() {
        media.$info
            .combineLatest(settings.$showMediaActivity)
            .map { info, enabled in enabled && (info?.isPlaying ?? false) }
            .removeDuplicates()
            .sink { [weak self] in self?.activity.update(.media, $0 ? .media : nil) }
            .store(in: &bag)

        downloads.$snapshot
            .combineLatest(settings.$showDownloadActivity)
            .map { snapshot, enabled in enabled ? snapshot : nil }
            .removeDuplicates()
            .sink { [weak self] snapshot in
                self?.activity.update(.download, snapshot.map { .download(name: $0.name, progress: $0.progress, count: $0.count) })
            }
            .store(in: &bag)

        settings.$showDownloadActivity
            .removeDuplicates()
            .sink { [weak self] enabled in enabled ? self?.downloads.start() : self?.downloads.stop() }
            .store(in: &bag)

        timer.$endsAt
            .sink { [weak self] end in
                guard let self else { return }
                self.activity.update(.timer, end.map { .timer(endsAt: $0, total: self.timer.total) })
            }
            .store(in: &bag)

        alarms.fired
            .sink { [weak self] alarm in
                self?.activity.show(.notice(symbol: "alarm.fill", title: alarm.label, detail: alarm.timeText))
            }
            .store(in: &bag)

        settings.$enableClipboard
            .removeDuplicates()
            .sink { [weak self] enabled in enabled ? self?.clipboard.start() : self?.clipboard.stop() }
            .store(in: &bag)

        settings.$enableNotifications
            .removeDuplicates()
            .sink { [weak self] enabled in enabled ? self?.notifications.start() : self?.notifications.stop() }
            .store(in: &bag)

        notifications.incoming
            .sink { [weak self] entry in self?.activity.show(.notification(entry)) }
            .store(in: &bag)

        notifications.$unread
            .combineLatest(notifications.$latestAppID)
            .map { unread, app -> LiveActivity? in
                guard unread > 0, let app else { return nil }
                return .notifications(appID: app, count: unread)
            }
            .removeDuplicates()
            .sink { [weak self] in self?.activity.update(.notifications, $0) }
            .store(in: &bag)

        timer.finished
            .sink { [weak self] total in
                self?.activity.show(.notice(symbol: "timer", title: "Süre doldu", detail: TimeFormatting.clock(total)))
            }
            .store(in: &bag)

        downloads.completed
            .filter { [weak self] _ in self?.settings.showDownloadActivity ?? false }
            .sink { [weak self] name in
                self?.activity.show(.notice(symbol: "checkmark.circle.fill", title: "İndirildi", detail: name))
            }
            .store(in: &bag)

        settings.$showCalendarActivity
            .combineLatest(settings.$calendarLeadMinutes)
            .sink { [weak self] enabled, _ in self?.configureCalendarTicker(enabled: enabled) }
            .store(in: &bag)
    }

    private func configureCalendarTicker(enabled: Bool) {
        calendarTicker?.invalidate()
        calendarTicker = nil
        guard enabled else {
            activity.update(.calendar, nil)
            return
        }
        refreshCalendarActivity()
        let ticker = Timer(timeInterval: Self.calendarTickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshCalendarActivity() }
        }
        ticker.tolerance = 5
        RunLoop.main.add(ticker, forMode: .common)
        calendarTicker = ticker
    }

    private func refreshCalendarActivity() {
        calendar.reload()
        let event = CalendarService.upcoming(in: calendar.items, now: Date(), leadMinutes: settings.calendarLeadMinutes)
        activity.update(.calendar, event.map { .calendar(title: $0.title, startsAt: $0.start) })
    }

    // MARK: - Bluetooth cihazları

    private func handleDevice(_ event: BluetoothMonitor.Event) {
        guard event.connected, settings.showDeviceBattery else {
            if !event.connected { deviceBatteries.removeValue(forKey: event.name) }
            activity.show(.device(name: event.name, connected: event.connected, battery: nil))
            updateBatteryTicker()
            return
        }
        // Önce hemen "bağlandı" göster, pil bilgisi gelince aynı etkinliği pil ile güncelle.
        activity.show(.device(name: event.name, connected: true, battery: nil))
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.batteryReadDelay) { [weak self] in
            self?.refreshDeviceBatteries { batteries in
                guard let battery = batteries[event.name] else { return }
                self?.activity.show(.device(name: event.name, connected: true, battery: battery))
            }
        }
    }

    func refreshDeviceBatteries(then completion: (([String: DeviceBattery]) -> Void)? = nil) {
        guard settings.showDeviceBattery else { return }
        DeviceBatteryReader.read { [weak self] batteries in
            self?.deviceBatteries = batteries
            self?.updateBatteryTicker()
            completion?(batteries)
        }
    }

    private func updateBatteryTicker() {
        let needed = settings.showDeviceBattery && !deviceBatteries.isEmpty
        if needed, batteryTicker == nil {
            let ticker = Timer(timeInterval: Self.batteryRefreshInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshDeviceBatteries() }
            }
            ticker.tolerance = 30
            RunLoop.main.add(ticker, forMode: .common)
            batteryTicker = ticker
        } else if !needed {
            batteryTicker?.invalidate()
            batteryTicker = nil
        }
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
