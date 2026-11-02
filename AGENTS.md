# AGENTS.md — Burrow için yapay zekâ çalışma kılavuzu

> Bu dosya **tek doğruluk kaynağıdır**. Claude (`CLAUDE.md`), Gemini (`GEMINI.md`), Codex/Cursor/Copilot
> bu dosyayı okur. Yeni bir yapay zekâya geçince ona yalnızca şunu söyle:
> **"AGENTS.md, DURUM.md ve docs/log/ISLEM_LOG.md dosyalarını oku, kaldığımız yerden devam et."**

## 1. Proje nedir?

**Burrow**: MacBook çentiğini (notch) canlı bir "Dynamic Island"a çeviren yerel macOS uygulaması.
- Temel: [Alcove](https://tryalcove.com) (akıcı geçişler, canlı etkinlikler, kaydırma hareketleri, HUD)
- Ek: [Boring Notch](https://boringnotch.com) özellikleri (dosya rafı, kamera aynası, takvim, kapak rengi ışıması)
- İsim: *Alcove* = duvardaki oyuk/niş, *boring* = oymak/delmek → oyulmuş küçük yuva = **Burrow**.

Kod sıfırdan yazılmıştır; iki uygulamanın kodu kopyalanmamıştır (Boring Notch GPL-3, Alcove kapalı kaynak).

## 2. Oturuma başlarken (zorunlu sıra)

1. `DURUM.md` → şu an ne durumda, sıradaki iş ne.
2. `docs/log/ISLEM_LOG.md` → en son yapılanlar (en alttaki kayıtlar en yeni).
3. `docs/kararlar/` → neden böyle yapıldı. **Bir karara aykırı iş yapmadan önce kullanıcıya sor.**
4. `docs/MIMARI.md` → kod haritası.

## 3. Oturumu bitirirken (zorunlu)

1. `docs/log/ISLEM_LOG.md` sonuna kayıt ekle (şablon dosyanın başında).
2. `DURUM.md` güncelle (tamamlananlar, sıradaki adım, bilinen sorunlar).
3. Mimari karar aldıysan `docs/kararlar/NNNN-baslik.md` aç ve `docs/kararlar/README.md` dizinine ekle.
4. Kullanıcı davranışı değiştiren her şey için `CHANGELOG.md` "Yayınlanmamış" bölümüne satır ekle.

## 4. Komutlar

| İş | Komut |
|---|---|
| Xcode projesini üret | `xcodegen generate` (proje dosyası git'te değil, `project.yml`'den üretilir) |
| Testler | `xcodebuild test -project Burrow.xcodeproj -scheme Burrow -destination 'platform=macOS'` |
| Yerel kur & aç | `scripts/build-local.sh` |
| Simgeyi yeniden üret | `swift scripts/make-icon.swift Burrow/Resources/Assets.xcassets/AppIcon.appiconset` |
| GitHub + güncelleme kurulumu (tek sefer) | `gh auth login && scripts/setup-github.sh` |
| Yeni sürüm yayınla | `main`'e kod push'la → `.github/workflows/release.yml` otomatik yayınlar |

## 5. Kurallar

- **Dil:** Arayüz metinleri, yorumlar ve dokümanlar Türkçe. Kod tanımlayıcıları İngilizce.
- **Swift 5 dil modu**, macOS 14+ hedef, SwiftUI + AppKit. Sandbox **yok** (çentik uygulamaları için gerekli, bkz. karar 0002).
- **Saf mantık ayrı tutulur ve test edilir:** `NotchGeometry`, `ActivityResolver`, `MediaInfoParser`, `ShelfStore.adding/removing/pruned`, `BatteryState.parse`, `TimeFormatting`. Yeni mantık eklerken önce test yaz.
- **Değişmezlik:** Değer tipleri (`struct`) kullan. Yeni durum üret, eskisini değiştirme.
- **Dosya boyutu:** dosya başına 400 satırı geçme; özellik başına klasör (`Burrow/Features/<Özellik>/`).
- **İzin isteyen her özellik** ayarlardan kapatılabilir olmalı ve izin yoksa çökmeden sessizce devre dışı kalmalı.
- **Erişilebilirlik izni** isteyen özellik (sistem HUD'unu değiştirme) varsayılan **kapalı**.
- **Özel API** yalnızca `dlopen`/`dlsym` ile, bulunamazsa özellik kapanacak şekilde (bkz. `BrightnessController`).
- **Güvenlik:** gizli anahtar asla repoya girmez; GitHub Secrets kullanılır. Ağdan veri yalnızca https + izinli alan adları
  (bkz. `MediaController.artworkHosts`). GitHub Actions'ta kullanıcı kontrollü metin (`commit message` vb.)
  `${{ }}` ile doğrudan `run:` içine **yazılmaz**, `env:` ile geçirilir.
- **Commit biçimi:** `feat: …`, `fix: …`, `docs: …`, `refactor: …`, `test: …`, `chore: …`

## 6. Dikkat — kolay bozulan yerler

- `NotchWindowController`: fare takibi küresel monitörle yapılır, panel kapalıyken `ignoresMouseEvents = true`.
  Bunu bozarsan menü çubuğuna tıklanamaz hâle gelir.
- `MediaKeyTap`: geri çağrı hızlı dönmeli; aksi hâlde macOS tap'i kapatır (yeniden açma kodu var).
- `Info.plist`, `Burrow.entitlements` ve `Burrow.xcodeproj` **xcodegen tarafından üretilir**. Değişikliği `project.yml`'ye yap.
- Sparkle genel anahtarı ve besleme adresi derleme ayarıyla CI'da enjekte edilir (`BURROW_PUBLIC_ED_KEY`, `BURROW_FEED_URL`).
  Yerel derlemede boştur → güncelleyici bilerek kapalıdır.
