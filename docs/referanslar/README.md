# Referanslar

## İlham alınan uygulamalar

### Alcove — https://tryalcove.com (kapalı kaynak, ücretli, macOS 15+)
Sitede öne çıkanlar (2026-11-02 itibarıyla): *Fluid transitions, Instant Notifications, Live Activities, Swipe gestures,
Packed with surprises, Customizable HUDs, Lock Screen Widgets, Blazing fast native app.*
Burrow'a alınanlar: akıcı yay animasyonları, canlı etkinlikler, kaydırma hareketleri, HUD, yerel hız.
Alınmayanlar: kilit ekranı widget'ları, bildirimler (bkz. karar 0001, 0008).

Değişiklik günlüğü başlıkları (tryalcove.com/changelog, 2026-11-02 itibarıyla; ayrıntılar sitede JS ile katlı):
- 1.1: sistem geneli medya, odak modu, ekran seçimi, kaydırma ve bildirim kontrolleri
- 1.2: oynatma kontrolleri, podcast/canlı yayın, bağlantı kopyalama, iCloud ayar eşitleme, zengin HUD seçenekleri
- 1.3: kilit ekranı widget'ları (çalan, odak, hava, pil, bağlantı, takvim), çıkış sesi kontrolü, oynatma hızı
- 1.4: takvim canlı etkinlikleri, "çıkma vakti" bildirimi, yağış, podcast/canlı göstergesi
- 1.5: Tahoe tarzı yeniden tasarım, **çoklu canlı etkinlik**, widget özelleştirme
- 1.6: genişletilmiş takvim, **HUD aşma (overshoot)**, progressive blur, BetterDisplay sesi
- 1.7: Duo modu, **çentiksiz ekranlar için hap**, canlı dalga formu, **çentik dış çizgisi**, Spotify/AirPlay

Alcove SSS: "Alcove relies on private APIs" — uygulama özel Apple API'lerine dayanıyor.
Geliştirici röportajı (Medium, 2025-07): kilit ekranı için belgelenmemiş yöntem, geliştirirken 4 kez Mac'e girememe;
klavye izni yerine sistem değişikliklerini dinleyerek HUD.

Burrow karşılığı (v1.0.5): bkz. karar 0008 ve README özellik tablosu.

### Boring Notch — https://boringnotch.com · https://github.com/TheBoredTeam/boring.notch (GPL-3.0)
Özellikler: müzik kontrolü + kapak renk efekti, takvim, hızlı ayna, pil, dosya rafı (AirDrop), yeniden tasarlanmış HUD,
çentiksiz Mac desteği. **Lisans GPL-3 olduğu için kodundan kopya alınmadı**, yalnızca özellik listesi ilham oldu.

## Apple API'leri (kullanılanlar)

| Konu | API | Not |
|---|---|---|
| Çentik ölçüsü | `NSScreen.safeAreaInsets`, `auxiliaryTopLeftArea/RightArea` | macOS 12+ |
| Panel | `NSPanel` + `.nonactivatingPanel`, `collectionBehavior` | |
| Fare | `NSEvent.addGlobalMonitorForEvents` | Fare olayları izin istemez, klavye ister |
| Pil | `IOPSNotificationCreateRunLoopSource`, `IOPSCopyPowerSourcesInfo` | |
| Ses | CoreAudio `AudioObjectAddPropertyListenerBlock`, `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` | |
| Medya tuşları | `CGEvent.tapCreate`, `NX_SYSDEFINED` (tip 14, alt tip 8) | Erişilebilirlik izni |
| Parlaklık | `DisplayServicesGetBrightness/SetBrightness` (özel) | `dlopen` |
| Takvim | `EKEventStore.requestFullAccessToEvents` | macOS 14+ |
| Kamera | `AVCaptureSession`, `AVCaptureVideoPreviewLayer` | |
| Bluetooth | `IOBluetoothDevice.register(forConnectNotifications:)` | |
| Girişte başlat | `SMAppService.mainApp` | macOS 13+ |
| Güncelleme | Sparkle 2 — https://sparkle-project.org/documentation/ | EdDSA |

## Bilinen platform kısıtları
- macOS 15.4+: MediaRemote "şu an çalan" bilgisi yetkisiz uygulamalara kapalı → karar 0003.
- Hardened runtime + Team ID'siz imza → library validation → karar 0005.
