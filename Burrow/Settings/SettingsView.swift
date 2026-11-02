import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var services: AppServices
    @ObservedObject var updater: UpdaterController
    @ObservedObject var launchAtLogin: LaunchAtLogin

    var body: some View {
        TabView {
            general.tabItem { Label("Genel", systemImage: "gearshape") }
            activities.tabItem { Label("Etkinlikler", systemImage: "sparkles") }
            hud.tabItem { Label("HUD", systemImage: "speaker.wave.2") }
            updates.tabItem { Label("Güncelleme", systemImage: "arrow.triangle.2.circlepath") }
            about.tabItem { Label("Hakkında", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 540)
    }

    private var general: some View {
        Form {
            Section("Davranış") {
                Toggle("Girişte başlat", isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.set($0) }))
                if let error = launchAtLogin.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                Picker("Çentik açılsın", selection: $settings.openMode) {
                    ForEach(OpenMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if settings.openMode == .hover {
                    LabeledContent("Bekleme süresi") {
                        HStack {
                            Slider(value: $settings.hoverDelay, in: 0...1.5, step: 0.05)
                            Text(String(format: "%.2f sn", settings.hoverDelay))
                                .monospacedDigit()
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                    Text("İmleç çentiğin üzerinde bu kadar bekleyince açılır. Tıklamak her zaman anında açar.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Çentik yalnızca tıklayınca açılır; üzerinden geçmek açmaz.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Yaklaşınca büyü (Alcove efekti)", isOn: $settings.proximityEffect)
                Text("İmleç çentiğe yaklaştıkça çentik yumuşakça kabarır, uzaklaşınca küçülür.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Kaydırma hareketleri", isOn: $settings.swipeGestures)
                Text("İki parmakla yatay kaydır: sonraki/önceki şarkı. Aşağı kaydır: aç, yukarı: kapat.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Dokunsal geri bildirim", isOn: $settings.hapticsEnabled)
            }
            Section("Ekran") {
                Picker("Çentik nerede görünsün", selection: $settings.displayMode) {
                    ForEach(DisplayMode.allCases) { Text($0.title).tag($0) }
                }
                Text(displayHint)
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Çentiksiz ekranlarda", selection: $settings.notchlessStyle) {
                    ForEach(NotchlessStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(settings.notchlessStyle == .island
                     ? "Harici monitör gibi çentiksiz ekranlarda menü çubuğunun hemen altında yüzen yuvarlak hap (iPhone Dynamic Island)."
                     : "Çentiksiz ekranlarda menü çubuğuna yapışık sanal çentik çizilir.")
                    .font(.caption).foregroundStyle(.secondary)
                if settings.notchlessStyle == .island {
                    Picker("Ada boyutu", selection: $settings.islandSize) {
                        ForEach(IslandSize.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Ada köşeleri", selection: $settings.islandCorners) {
                        ForEach(IslandCorners.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Toggle("Çentik dış çizgisi", isOn: $settings.notchOutline)
            }
        }
        .formStyle(.grouped)
    }

    private var displayHint: String {
        switch settings.displayMode {
        case .notched: return "MacBook'un çentikli ekranı. Kapak kapalıysa ana ekrana geçer."
        case .primary: return "Menü çubuğunun olduğu ekran (Sistem Ayarları › Ekranlar › Ana ekran). Çentiksizse sanal çentik çizilir."
        case .all: return "Her ekranda ayrı çentik. Çentiksiz ekranlarda sanal çentik çizilir."
        }
    }

    private var activities: some View {
        Form {
            Section("Canlı Etkinlikler") {
                Toggle("Çalan müzik", isOn: $settings.showMediaActivity)
                Toggle("Şarj ve düşük pil", isOn: $settings.showBatteryActivity)
                if settings.showBatteryActivity {
                    Stepper("Düşük pil eşiği: %\(settings.lowBatteryThreshold)", value: $settings.lowBatteryThreshold, in: 5...50, step: 5)
                }
                Toggle("İndirmeler (Safari, Chrome)", isOn: $settings.showDownloadActivity)
                Toggle("Yaklaşan takvim etkinliği", isOn: $settings.showCalendarActivity)
                if settings.showCalendarActivity {
                    Stepper("Başlamadan \(settings.calendarLeadMinutes) dk önce göster", value: $settings.calendarLeadMinutes, in: 5...60, step: 5)
                }
                Toggle("Bluetooth cihaz bağlantıları", isOn: $settings.showDeviceActivity)
                if settings.showDeviceActivity {
                    Toggle("Kulaklık / cihaz pilini göster (AirPods vb.)", isOn: $settings.showDeviceBattery)
                }
            }
            Section("Birden Fazla Etkinlik") {
                Picker("Öncelikli göster", selection: $settings.preferredActivity) {
                    Text("Otomatik (en son başlayan)").tag(ActivityKind?.none)
                    ForEach(ActivityKind.allCases) { Text($0.title).tag(ActivityKind?.some($0)) }
                }
                Text("Aynı anda örneğin müzik çalıp bir şey iniyorsa kapalı çentikte bu gösterilir. Çentiğin üzerindeyken iki parmakla sağa/sola kaydırarak (fare tekerleğiyle yukarı/aşağı) diğerlerine geçebilirsin; sağ alttaki noktalar kaç etkinlik olduğunu gösterir.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Bildirimler") {
                Toggle("Uygulama bildirimlerini çentikte göster", isOn: $settings.enableNotifications)
                Text("Yeni bildirim önce büyük kart olarak açılır, sonra kapalı çentikte uygulama simgesi ve okunmamış sayısı kalır. macOS bunun için **Tam Disk Erişimi** ister: Burrow bildirim veritabanını yalnızca okur, hiçbir yere göndermez.")
                    .font(.caption).foregroundStyle(.secondary)
                if settings.enableNotifications {
                    NotificationAccessRow(service: services.notifications)
                }
            }
            Section("Ana Ekran") {
                ForEach(homeRows) { widget in homeRow(widget) }
                Text("Açık çentiğin ilk sekmesinde görünecekler. Oklarla sırasını değiştir; aynaya tıklayınca büyür.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Açık Çentik") {
                Toggle("Pano geçmişi", isOn: $settings.enableClipboard)
                Toggle("Anımsatıcılar sekmesi", isOn: $settings.enableReminders)
                Toggle("Dosya rafı", isOn: $settings.enableShelf)
                Toggle("Kapak rengiyle ışıma", isOn: $settings.albumTint)
            }
        }
        .formStyle(.grouped)
    }

    /// Önce gösterilenler (sırasıyla), sonra gizliler.
    private var homeRows: [HomeWidget] {
        settings.homeLayout + HomeWidget.allCases.filter { !settings.homeLayout.contains($0) }
    }

    private func homeRow(_ widget: HomeWidget) -> some View {
        let isOn = settings.homeLayout.contains(widget)
        let index = settings.homeLayout.firstIndex(of: widget)
        return HStack {
            Toggle(isOn: Binding(
                get: { settings.homeLayout.contains(widget) },
                set: { settings.homeLayout = HomeWidget.toggled(settings.homeLayout, widget, isOn: $0) }
            )) {
                Label(widget.title, systemImage: widget.symbol)
            }
            if isOn {
                Button { settings.homeLayout = HomeWidget.moved(settings.homeLayout, widget, by: -1) } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(index == 0)
                Button { settings.homeLayout = HomeWidget.moved(settings.homeLayout, widget, by: 1) } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(index == settings.homeLayout.count - 1)
            }
        }
        .buttonStyle(.borderless)
    }

    private var hud: some View {
        Form {
            Section("Ses ve Parlaklık") {
                Toggle("Ses değişince çentikte göster", isOn: $settings.showVolumeChanges)
                Picker("Gösterge biçimi", selection: $settings.hudStyle) {
                    ForEach(HUDStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(settings.hudStyle == .large ? "Çentik aşağı uzar: simge, kalın çubuk ve yüzde." : "Çentiğin iki yanında ince çubuk.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Sistem HUD'unu Burrow ile değiştir", isOn: $settings.replaceSystemHUD)
                Text("Ses/parlaklık tuşlarını yakalar, macOS'un ortadaki göstergesi yerine çentikte şık bir çubuk gösterir. Erişilebilirlik izni gerekir. Burrow kapanırsa tuşlar normale döner.")
                    .font(.caption).foregroundStyle(.secondary)
                if settings.replaceSystemHUD && !services.keyTapActive {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                        Text("Erişilebilirlik izni bekleniyor.")
                        Spacer()
                        Button("Ayarları Aç") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
                if !BrightnessController.shared.isAvailable {
                    Text("Parlaklık kontrolü bu Mac'te kullanılamıyor; parlaklık tuşları sisteme bırakılır.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var updates: some View {
        Form {
            Section("Otomatik Güncelleme") {
                if updater.isConfigured {
                    Toggle("Güncellemeleri otomatik denetle", isOn: Binding(get: { updater.automaticallyChecks }, set: { updater.automaticallyChecks = $0 }))
                    Toggle("Otomatik indir ve kur", isOn: Binding(get: { updater.automaticallyDownloads }, set: { updater.automaticallyDownloads = $0 }))
                    HStack {
                        if let last = updater.lastCheck {
                            Text("Son denetim: \(last.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Şimdi Denetle") { updater.checkForUpdates() }
                            .disabled(!updater.canCheckForUpdates)
                    }
                    Text("Güncellemeler GitHub sürümlerinden gelir ve ed25519 imzasıyla doğrulanır; imzasız paket kurulmaz.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Bu derleme yerel geliştirme derlemesi; otomatik güncelleme yalnızca GitHub'dan indirilen sürümlerde çalışır.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var about: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
            Text("Burrow").font(.title.bold())
            Text("Sürüm \(Bundle.main.shortVersion) (\(Bundle.main.buildNumber))")
                .foregroundStyle(.secondary)
            Text("Çentiğin içindeki küçük yuva.\nAlcove ve Boring Notch'tan ilham alınmıştır.")
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Burrow'dan Çık") { NSApp.terminate(nil) }
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Bundle {
    var shortVersion: String { object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?" }
    var buildNumber: String { object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?" }
}

/// Tam Disk Erişimi durumu (servisi doğrudan izler, izin verilince kendiliğinden yeşile döner).
private struct NotificationAccessRow: View {
    @ObservedObject var service: NotificationCenterService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                switch service.status {
                case .active:
                    Label("Etkin", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                case .needsAccess:
                    Label("Tam Disk Erişimi gerekiyor", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                case .off:
                    Label("Kapalı", systemImage: "circle")
                }
                Spacer()
                if service.status != .active {
                    Button("Tam Disk Erişimi Ver…") { NotificationCenterService.openFullDiskAccessSettings() }
                }
            }
            .font(.callout)
            if service.status == .needsAccess {
                Text("Açılan listede **+** düğmesine bas → Uygulamalar › Burrow'u seç → anahtarı aç. Burrow birkaç saniye içinde kendiliğinden algılar.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
