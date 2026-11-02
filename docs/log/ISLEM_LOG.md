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

## [005] 2026-11-02 — GitHub kurulumu ve ilk sürüm
- Yapan: Claude Code (Opus 5.5) + kullanıcı (`gh auth login`, public onayı)
- Ne yapıldı: setup-github.sh iki hatası düzeltildi (`-resolvePackageDependencies` için `-scheme` eksikti; yer tutucu
  bulunamayınca `grep` + `pipefail` betiği kesiyordu). Secret'lar ve değişken yüklendi, sertifika yerel anahtar zincirine
  eklendi, install.sh'e parmak izi sabitlendi (`2146be3c…`).
- Doğrulama: Release çalıştırması 41494067895 yeşil → v1.0.3. İndirilen DMG: SHA-256 OK, `codesign --strict` OK,
  Authority=Burrow Self-Signed, SUFeedURL doğru, Applications kısayolu var. Tüm varlıklar `latest/download` ile 200.
- Not: Kullanıcının gördüğü 404, sürüm yüklenmeden önce denendiği içindi.

## [006] 2026-11-02 — Yaklaşma efekti, açılma biçimi, ekran seçimi
- Yapan: Claude Code (Opus 5.5)
- İstek: Alcove gibi imleç yaklaşınca efekt; tıklayınca mı / bekleyince mi açılsın (süre ayarlı); hangi ekranda
  (çentikli / ana / ikisi) görünsün; ayarlar nerede.
- Ne yapıldı:
  - `AppSettings`: `openMode` (.hover/.click), `proximityEffect`, `displayMode` (.notched/.primary/.all). Eski
    `hoverToExpand` / `showOnAllDisplays` anahtarları otomatik taşınıyor (kullanıcının "tüm ekranlar" seçimi korundu).
  - Saf mantık: `NotchGeometry.proximity(of:to:radius:)` ve `DisplaySelector.select` (+11 test).
    Birincil ekran `NSScreen.screens.first` (NSScreen.main odaktaki pencereye göre değişir, kullanılmaz).
  - `NotchViewModel.proximity` + `displayedCompactSize`; çentik 90 pt'den itibaren en fazla 34×7 pt kabarır,
    gölge belirir. İsabet alanı kabarmış boyutu kullanır.
  - `applicationShouldHandleReopen` → ayarlar. Ayarlar penceresi `orderFrontRegardless` ile öne alınıyor (hata düzeltmesi).
  - DEBUG kancasına `peek|half|rest`.
- Doğrulama: 47/47 test. Ekran görüntüsü: dinlenme/yarı/tam yakınlık kabarması ve yeni Genel ayarları.

## [007] 2026-11-02 — Alcove eşitliği: çoklu etkinlik, ada, kulaklık pili, indirme, zamanlayıcı
- Yapan: Claude Code (Opus 5.5)
- Araştırma: tryalcove.com ana sayfa + changelog başlıkları + SSS (JS paketinden), Medium röportajı, Seam karşılaştırması.
  Bulgular `docs/referanslar/README.md`'de.
- Ne yapıldı: `ActivityCarousel` (saf), `ActivityCenter` yeniden yazıldı (kalıcı/geçici), `DownloadMonitor` (NSProgress),
  `TimerService` + "Süre" sekmesi, `DeviceBatteryReader` (system_profiler), takvim yaklaşan etkinlik, `notice` geçici
  etkinliği, ada biçimi (menü çubuğu içinde), büyük HUD, dış çizgi, kaydırma/fare tekerleği ile geçiş, sayfa noktaları,
  ayarlar (Genel › Ekran, Etkinlikler › Birden Fazla Etkinlik, HUD › biçim). Karar 0008.
- Doğrulama: 77/77 test. Ekran görüntüleri: müzik+indirme+zamanlayıcı döngüsü ve noktalar, AirPods pili, "İndirildi",
  büyük HUD, LG'de ada (kapalı/açık). İlk denemede ada menü çubuğundan taşıyordu → menü çubuğu içine sığdırıldı.
  AirPods satırı kesiliyordu → genişletildi.
- Doğrulanmayan: gerçek AirPods pil anahtarları (şu an bağlı cihaz yok; topluluk anahtar adları kullanıldı),
  gerçek Safari/Chrome indirmesi, gerçek trackpad kaydırması.
- Not: Ekran görüntüsü için `notchlessStyle/hudStyle/displayMode` geçici yazıldı, sonra silinerek eski hâline döndürüldü.
- Kod incelemesi (code-reviewer alt ajanı) 6 bulgu, hepsi düzeltildi (+3 test → 80/80):
  1. `Progress.addSubscriber` işleyicileri ana iş parçacığı dışında gelebilir → `assumeIsolated` çökebilirdi; ana kuyruğa geçiş.
  2. Trackpad atalet (momentum) olayları tek kaydırmada iki adım atlatıyordu → momentum yok sayılıyor.
  3. Adada ekranın en üst 2–3 pt'si isabet alanı dışındaydı → `screenRect` tepeye kadar uzatıldı.
  4. Zamanlayıcı Mac uykudayken duruyordu (monoton saat) → `wallDeadline`.
  5. Tercihi "Otomatik"e çevirmek ekranı zıplatıyordu → mevcut/elle seçim korunuyor.
  6. "+1 dk" zamanlayıcıyı bitip yeniden başlamış gibi gösteriyordu → `endsAt` hiç nil olmadan uzatılıyor.

## [008] 2026-11-02 — Bildirimler, pano, alarm, anımsatıcılar, büyük ayna, akıcılık
- Yapan: Claude Code (Opus 5.5)
- İstek: YouTube/tarayıcı müziği; kopyalama geçmişi (kategori, yıldız, filtre); geri sayım + alarm; anımsatıcılar;
  aynaya basınca büyüsün; Alcove gibi yaklaşma/gölge/titreşim; Tam Disk Erişimiyle tüm bildirimler (büyük → küçük + sayı);
  ada için "büyük" seçeneği (eski, daha iri ve biraz aşağıda).
- Yapılanlar: `ClipboardStore/Item/View`, `AlarmService/View` + `TimeToolsView`, `ReminderService/View`,
  `NotificationReader` (SQLite salt okunur) + `NotificationCenterService` + `NotificationsView`, `.notification` /
  `.notifications` etkinlikleri, simge sekmeler, büyük ayna, `IslandSize`, `blurFade` geçişi, hale gölgesi,
  `.levelChange` titreşim. Açık çentik 180 → 196 pt (alarm formu sığsın). Karar 0009.
- **Tarayıcı medyası yapılmadı:** mediaremote-adapter'ı (BSD-3) Vendor'a alıp derleyip çalıştırma adımı Claude Code'un
  otomatik güvenlik denetimince durduruldu ("Code from External"). Kullanıcı onayı bekleniyor; hiçbir dosya eklenmedi.
- Doğrulama: 98/98 test (bildirim okuyucu macOS şemasıyla geçici SQLite'ta test edildi). Ekran görüntüleri: bildirim kartı,
  kırmızı sayaç, Pano, Süre, Anımsatıcılar ve Bildirimler sekmeleri.
- Doğrulanmayan: gerçek bildirim veritabanı (Tam Disk Erişimi kullanıcı verince), büyük ayna (kamera izni), alarm
  formunun yerleşimi (segment tıklanamadı), gerçek trackpad titreşimi.
- Not: Test için panoya iki metin kopyalandı (kullanıcının panosundaki son öğenin yerine geçti); geçmiş dosyasından silindi.
- Kod incelemesi (code-reviewer): kritik/yüksek yok; 8 bulgu düzeltildi:
  pano küçük resimleri önbellekli (üzerine gelince takılma yok), resim çözme/yazma arka planda, metin resimden önce
  (Office önizlemesi), yıldızlılar dahil 500 sınırı; alarm uyanışta kaçırılmıyor (wake observer kaldırıldı, saat değişimi
  izleniyor), çalmayı durdurma bekleyen tekrarları iptal ediyor; bildirimler kapatılınca sayaç temizleniyor, durdurma
  sonrası geç sonuç yok sayılıyor, 50'den fazla yığın sonraki turda okunuyor, geçici SQLite kilidi "izin yok" göstermiyor.

## [009] 2026-11-02 — Otomatik güncelleme doğrulandı
- v1.0.6 yayınlandı (Actions yeşil). Kullanıcının kurulu Burrow'u Sparkle ile kendiliğinden 1.0.3 → 1.0.5'e geçmiş
  (SULastCheckTime 18:23 UTC). Uçtan uca güncelleme hattı ilk kez gerçek kullanımda doğrulandı.

## [010] 2026-11-02 — YouTube / tarayıcı medyası (mediaremote-adapter)
- Yapan: Claude Code (Opus 5.5), kullanıcı onayıyla ("evet ekle")
- Ne yapıldı: mediaremote-adapter v0.7.7 (BSD-3, commit e3ff502) kaynağı tarandı ve `Vendor/`'a alındı; clang ile
  kaynaktan derleyen `scripts/build-mediaremote-adapter.sh`; Xcode postCompile aşaması framework + perl betiğini
  uygulamaya koyuyor; `sign-app.sh` imzalıyor. `MediaRemoteSource` (stream JSON, diff birleştirme, komutlar, seek),
  `MediaController` iki kaynaklı (sistem geneli → AppleScript yedeği), `MediaInfo.player` opsiyonel + `appBundleID`.
- Bulunan/düzeltilen: `pkill`/SIGTERM'de kapanış kodu çalışmadığı için perl süreci sahipsiz kalıyordu → sinyal
  yakalama + açılışta artık temizliği. Yerel imzada anahtar zinciri izin penceresi betiği bekletiyordu → yerelde
  varsayılan ad-hoc (`BURROW_SIGN_IDENTITY` ile değiştirilebilir); yarıda kesilen imza Sparkle'ı bozmuştu, yeniden imzalandı.
- Doğrulama: Chrome'da YouTube "Mabel Matiz - Umrumdışı" kapak, sanatçı ve ilerlemeyle açık çentikte (ekran görüntüsü).
  106/106 test; testler sonrası artık süreç yok; Release imzası geçerli, imzalı adaptör çalışıyor.
- Doğrulanmayan: oynat/duraklat/ileri/geri ve atlama komutlarının tarayıcıda gerçek etkisi (kullanıcının Mac'inde ses
  çalmamak için denenmedi).

## [011] 2026-11-02 — Büyük ada: daha geniş, çentik köşeli
- İstek: "ilk denemelerdeki gibi, daha geniş, köşeleri orijinal çentik oranında". YouTube medyası kullanıcıda çalıştı (doğrulandı).
- Yapılan: `NotchViewModel.largeIslandCenterWidth` = `NotchGeometry.fallbackNotchWidth` (185), `largeIslandCornerRadius` 11,
  `isLargeIsland`; `NotchRootView` büyük adada sabit köşe yarıçapı. Şarj yüzdesi `.lineLimit(1).fixedSize()` (önceden "%7/6" kayıyordu).
- Doğrulama: 107/107 test; LG ekranda Debug derlemesiyle boş/şarj/müzik/açık hâl ekran görüntüleri.

## [012] 2026-11-03 — Ada köşe ayarı, anımsatıcı kategorileri, özelleştirilebilir ana ekran
- İstek: 185 pt fazla geniş → daralt; eski hap da ayarda kalsın; anımsatıcılarda kategori seçimi; ana ekran özelleştirme; ayna düğmesi küçük.
- Yapılan: `IslandCorners` (.rounded 78 pt / .squared 120 pt, yarıçap = yükseklik × 0.32); `HomeWidget` + `homeLayout`
  (sıralı; eski showCalendar/enableMirror anahtarlarından taşınır, artık hesaplanan özellik); `ReminderList`, `ReminderItem.listID`,
  `ReminderService.resolvedListID` (boş → ilk liste, `__all__` → tümü), çipler + `HomeRemindersView`; `MirrorView.smallSize` 44.
- Kod incelemesi: küçük ada kullanıcılarının görünümü değişmesin diye köşe varsayılanı boyuta bağlandı; liste aynıysa yayınlanmıyor;
  ayna ana ekrandan kalkınca kamera durduruluyor.
- Doğrulama: 111/111 test; LG ekranda köşeli ada (120 pt) ve yeni ana ekran (küçük ayna) ekran görüntüsü.
- Not: Bu sırada XProtect %355 CPU ile yeni ikilileri taradığı için test çalıştırıcı ve `swift` betiği takıldı; tarama bitince geçti.
  `debug-notch.sh` yerine `osascript -l JavaScript` ile dağıtık bildirim gönderilebilir.
- Doğrulanmayan: anımsatıcı çipleri gerçek listelerle (Debug derlemesinin anımsatıcı izni yok).

## [013] 2026-11-03 — Ana ekran taşma hatası
- Kullanıcı: uygulamayı yeniden açınca ana sekmede içerik genişlikten taşıyor, başka sekmeye geçince düzeliyor.
- Neden: 4 parçanın (müzik + takvim 160 + ayna + anımsatıcılar 170 + boşluklar) en küçük toplamı 620 pt açık çentiğe sığmıyordu;
  taşan HStack üst bandı da genişletti.
- Düzeltme: `HomeView.sideColumnWidth` (iki yan sütun varsa 118, tekse 160, müzik yoksa esnek), müzik en az 180 pt;
  `ExpandedNotchView` içeriği `minWidth: 0` + `.clipped()`. Not: `layoutPriority` denendi, takvimi sıfıra ezdiği için bırakıldı.
- Doğrulama: yeniden başlatıp ilk açılışta ekran görüntüsü (dört parça sığıyor, sekmeler/ayar görünür); testler.
