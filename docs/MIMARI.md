# Mimari

## Kuşbakışı

```
main.swift ─► AppDelegate
                ├── AppServices (tek kopya, uygulama ömrü)
                │     ├── AppSettings          (UserDefaults, @Published)
                │     ├── ActivityCenter       (olaylar → tek LiveActivity)
                │     ├── MediaController      (AppleScript + dağıtık bildirim)
                │     ├── BatteryMonitor       (IOKit bildirimleri)
                │     ├── VolumeController     (CoreAudio dinleyicileri)
                │     ├── MediaKeyTap          (CGEventTap, isteğe bağlı)
                │     ├── BrightnessController (DisplayServices, dlopen)
                │     ├── CalendarService      (EventKit)
                │     ├── ShelfStore           (UserDefaults JSON)
                │     ├── CameraMirror         (AVCaptureSession)
                │     └── BluetoothMonitor     (IOBluetooth bildirimleri)
                ├── UpdaterController (Sparkle 2)
                ├── NotchWindowController × ekran sayısı
                │     ├── NotchPanel (NSPanel, kenarlıksız, odak çalmaz)
                │     ├── NotchViewModel (açık/kapalı, sekme, geometri)
                │     └── NotchRootView (SwiftUI)
                │           ├── CompactNotchView  (kapalı: sol | çentik | sağ)
                │           └── ExpandedNotchView (açık: başlık + HomeView/ShelfView)
                └── NSStatusItem menüsü + Ayarlar penceresi (SettingsView)
```

## Veri akışı: canlı etkinlik

1. Bir servis olay yayınlar (ör. `battery.plugEvents`, `volume.changes`).
2. `AppServices.wire()` ilgili ayar açıksa `activity.show(.charging(...))` çağırır.
3. `ActivityCenter` geçici etkinliği süresiyle tutar, `ActivityResolver.resolve` ile medyayla birleştirir → `current`.
4. Her ekrandaki `NotchRootView` `current`'ı izler; genişlik `LiveActivity.extraWidth`'ten hesaplanır, yay animasyonuyla büyür.

Öncelik: `hud (60) > lowBattery (50) > charging (40) > device (30) > media (10) > none`.
Aynı türdeki güncelleme (ses 40% → 45%) her zaman yerini alır ve süreyi yeniler.

## Fare ve tıklama

- Panel ekranın üst-ortasında **sabit boyutludur** (`NotchGeometry.windowSize`); çentik şekli içinde animasyonla büyür.
- Panel yalnızca imleç **görünen şeklin** içindeyken `ignoresMouseEvents = false` olur; ayrıca `NotchHostingView.hitTest`
  şekil dışını reddeder → şeffaf kenarlar menü çubuğunu ve alttaki pencereleri asla engellemez.
- Küresel + yerel `mouseMoved` monitörü imlecin `compactRect` içine girdiğini görünce paneli etkileşimli yapar ve
  `hoverDelay` sonra açar. İmleç `expandedRect` dışına çıkınca 0.12 sn sonra kapanır.
- Dosya sürükleme: `leftMouseDragged` + sürükleme panosunun `changeCount`'u değiştiyse ve dosya içeriyorsa,
  imleç çentiğe 40 pt yaklaşınca Raf sekmesi açılır.
- Kaydırma: yalnızca panel üzerindeyken yerel monitörle; `phase` ile tek hareket = tek komut.

## Medya

- Tetik: `com.apple.Music.playerInfo` / `com.spotify.client.PlaybackStateChanged` dağıtık bildirimleri (anlık, izin yok).
- Ayrıntı ve kontrol: `NSAppleScript`, tek seri kuyrukta, derlenmiş betik önbelleği, her betikte `with timeout of 2 seconds`.
- Yoklama: çalarken 3 sn, duraklatılmışken 8 sn, hiçbir oynatıcı açık değilken **hiç**.
- Konum arayüzde `MediaInfo.estimatedPosition(at:)` ile tahmin edilir (sürekli sorgu yok).
- Kapak: Müzik → ham veri; Spotify → https URL (yalnızca izinli CDN alan adları), 5 MB sınırı.

## Güncelleme hattı

```
git push main ─► GitHub Actions (release.yml)
   test ─► Release derle (BURROW_FEED_URL, BURROW_PUBLIC_ED_KEY enjekte)
   ─► scripts/sign-app.sh (self-signed sertifika ya da ad-hoc)
   ─► Burrow.zip + SHA256SUMS
   ─► sign_update (ed25519, SPARKLE_PRIVATE_KEY secret) ─► scripts/make-appcast.sh ─► appcast.xml
   ─► gh release create v1.0.<run_number> --latest
Kurulu uygulama ─► https://github.com/<repo>/releases/latest/download/appcast.xml (saatlik)
   ─► imza doğrula ─► indir ─► kur ─► yeniden başlat
```

Sürüm numarası: `1.0.<github.run_number>`, `CFBundleVersion = run_number` (hep artar).

## Dosya haritası

| Klasör | İçerik |
|---|---|
| `Burrow/App` | Giriş, AppDelegate, servis kapsayıcısı, etkinlik merkezi |
| `Burrow/Notch` | Panel, geometri, şekil, görünüm modeli, kapalı/açık görünümler, ortak bileşenler |
| `Burrow/Features/*` | Özellik başına servis + görünüm |
| `Burrow/Settings` | Ayarlar modeli, ayarlar penceresi, girişte başlat |
| `Burrow/Update` | Sparkle sarmalayıcı |
| `BurrowTests` | Saf mantık birim testleri |
| `scripts` | Kurulum, derleme, imzalama, appcast, simge |
| `.github/workflows` | CI (PR) ve Release (main) |
