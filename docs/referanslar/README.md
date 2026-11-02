# Referanslar

## İlham alınan uygulamalar

### Alcove — https://tryalcove.com (kapalı kaynak, ücretli, macOS 15+)
Sitede öne çıkanlar (2026-11-02 itibarıyla): *Fluid transitions, Instant Notifications, Live Activities, Swipe gestures,
Packed with surprises, Customizable HUDs, Lock Screen Widgets, Blazing fast native app.*
Burrow'a alınanlar: akıcı yay animasyonları, canlı etkinlikler, kaydırma hareketleri, HUD, yerel hız.
Alınmayanlar: kilit ekranı widget'ları, bildirimler (bkz. karar 0001).

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
