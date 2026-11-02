# İşlem Günlüğü

Her oturum sonunda en alta yeni kayıt ekle. **Eski kayıtları silme veya değiştirme.**

```
## [NNN] YYYY-AA-GG — Başlık
- Yapan: <araç / model>
- Ne yapıldı:
- Değişen dosyalar:
- Doğrulama: (test sonucu, ekran görüntüsü, komut çıktısı)
- Sorunlar / açık uçlar:
- Sıradaki:
```

---

## [001] 2026-11-02 — Proje iskeleti ve v1 kodu
- Yapan: Claude Code (Opus 5.5)
- Ne yapıldı: Alcove ve Boring Notch siteleri incelendi (`docs/referanslar`). İsim "Burrow" seçildi (karar 0001).
  XcodeGen + SwiftUI/AppKit yığını kuruldu. Tüm servisler, görünümler, ayarlar, Sparkle sarmalayıcısı ve simge üretici yazıldı.
  CI (`ci.yml`) ve yayın (`release.yml`) hattı ile `install.sh`, `setup-github.sh`, `sign-app.sh`, `make-appcast.sh` eklendi.
- Doğrulama: İlk derleme başarılı.
- Sorunlar:
  - Sparkle binary indirmesi bir kez takıldı → süreç durdurulup yeniden denendi; sürüm 2.10.1'e sabitlendi.
  - Testler "runner never began": Debug'da hardened runtime test paketini engelliyordu → Debug'da kapatıldı.
  - Release açılışta çöktü ("different Team IDs") → `disable-library-validation` yetkisi (karar 0005).
  - Debug'da arayüz kurulmuyordu: `NSClassFromString("XCTestCase")` Debug'da da dolu → ortam değişkeniyle tespit.

## [002] 2026-11-02 — Görsel doğrulama
- Yapan: Claude Code (Opus 5.5)
- Ne yapıldı: Yalnızca DEBUG'da çalışan `scripts/debug-notch.sh` kancası eklendi (Terminal olay gönderemediği için).
  Kapalı, açık, raf, ayarlar ve 3 canlı etkinlik ekran görüntüsüyle doğrulandı. Açık çentik 210 → 180 pt kısaltıldı.
- Doğrulama: `docs/ornekler/ekran-goruntuleri/*.png`

## [003] 2026-11-02 — Kod incelemesi düzeltmeleri + açılış donması
- Yapan: Claude Code (Opus 5.5) + code-reviewer alt ajanı
- Düzeltilenler:
  1. Şeffaf panel alanı tıklama yutuyordu → `NotchHostingView.hitTest` + etkileşim yalnızca görünen şekil içinde.
  2. Kamera izni penceresi sırasında çentik kapanırsa kamera açık kalıyordu → izin geri çağrısında durum denetimi.
  3. Sürükleme oturumu mouseUp'ı yutunca çentik hiç kapanmıyordu → `NSEvent.pressedMouseButtons` ile düzeltme.
  4. Panel `acceptsMouseMovedEvents` almıyordu; başka ekrana geçince etkileşim kapanmıyordu.
  5. CI, doğrulanmamış indirilen Sparkle aracına özel anahtarı veriyordu → SPM'in checksum'lı artifact'ı kullanılıyor.
  6. install.sh yalnızca bütünlük doğruluyordu → sertifika SHA-256 parmak izi sabitlemesi; gereksiz `xattr` kaldırıldı.
  7. Yazılımsal ses denetimi olmayan aygıtta (HDMI) ses tuşları yutuluyordu → başarısızsa sisteme bırakılıyor.
  8. AppleScript yoklaması kapatılan oynatıcıyı yeniden açabiliyordu → her betik `if application id … is running`.
  9. appcast'te Türkçe commit mesajı UTF-8 ortasından kesiliyordu → `iconv -c` + `LC_ALL=C`.
  10. Bluetooth geç açılınca bağlı cihazlar için sahte "bağlandı" patlaması → kayıt anında süre sıfırlama.
- Ek bulunanlar (ben):
  - **AppleScript `st` değişkeni ayrılmış sözcüktü → durum betikleri hiç derlenmiyordu.** `playerState` yapıldı;
    gerçek derleme testi eklendi (`test_musicScripts_compile`).
  - **`IOBluetoothDevice.register` izin penceresi yanıtlanana kadar ana iş parçacığını kilitliyordu** (taze açılışta
    çentik görünmüyordu). İzin artık CoreBluetooth ile eşzamansız isteniyor.
- Doğrulama: 36/36 test, Release imzalı ve açılıyor, taze açılışta çentik görünür.
- Sıradaki: Kullanıcı `gh auth login && scripts/setup-github.sh`.

## [004] 2026-11-02 — Klasör adı, GitHub, DMG kurulumu
- Yapan: Claude Code (Opus 5.5)
- Ne yapıldı:
  - Proje klasörü `adsız klasör` → `~/Desktop/Yazılım/Burrow`; IsmWiki eşlemesi "Burrow" yapıldı.
  - Kullanıcı kodu `ismsahin/Burrow-Notch` deposuna push'ladı (depo private, `gh` oturumu yok → secret'lar eksik).
  - `scripts/make-dmg.sh` + `make-dmg-background.swift`: create-dmg ile sürükle-bırak penceresi, yoksa hdiutil'e düşer.
    Koyu arka planda Finder etiketleri okunmuyordu → açık zemine geçildi.
  - release.yml: DMG üretip Release'e ekliyor, SHA256SUMS'a giriyor.
  - setup-github.sh: depo adını origin'den alıyor; private ise onay sorup public yapıyor (Sparkle için şart).
  - README: DMG adımları + Gatekeeper "Yine de Aç" açıklaması; yer tutucular `ismsahin/Burrow-Notch` ile dolduruldu.
- Doğrulama: DMG açıldı, ekran görüntüsü (`docs/ornekler/ekran-goruntuleri/dmg-kurulum.png`); DMG'den kopyalanan uygulama
  imza doğrulamasını geçti ve açıldı; disk çıkarıldı. sign_update stdin + appcast zinciri geçici ed25519 anahtarla denendi.
  36/36 test, iş akışı YAML geçerli.
- Sıradaki: kullanıcı `gh auth login && scripts/setup-github.sh`.
