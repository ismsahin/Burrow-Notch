# 0004 — Otomatik güncelleme: Sparkle 2 + GitHub Releases

- **Tarih:** 2026-11-02
- **Durum:** Kabul

## Bağlam
İstek: "GitHub main'e push'landığında otomatik güncelleme çeksin", güvenlik açığı oluşturmadan.

## Karar
- `main`'e kod push'u (`docs/**` ve `*.md` hariç) → `release.yml` → test → derle → imzala → **ed25519 imzalı** zip → `appcast.xml`
  → `gh release create v1.0.<run_number> --latest`.
- Uygulama besleme adresi: `https://github.com/<sahip>/<repo>/releases/latest/download/appcast.xml`. Sparkle saatlik denetler,
  otomatik indirir ve kurar (`SUAutomaticallyUpdate`), kullanıcı ayarlardan kapatabilir.
- Genel anahtar ve besleme adresi derleme anında enjekte edilir; repoya sabit yazılmaz. Özel anahtar yalnızca GitHub Secret.
- `SUVerifyUpdateBeforeExtraction = true`: imza açmadan önce doğrulanır.

## Güvenlik notları
- Depo **public** olmalı (Sparkle kimlik doğrulamasız indirir).
- GitHub hesabı ele geçirilirse saldırgan secret'ı kullanarak sürüm yayınlayabilir → GitHub'da 2FA şart.
- Workflow'da kullanıcı kontrollü metin `env:` ile geçirilir (komut enjeksiyonu önlemi).
- `make-appcast.sh` imza çıktısını regex ile doğrular, XML'i kaçışlar.

## Alternatifler
- Kendi güncelleyicimiz: imza doğrulama, atomik değiştirme, yeniden başlatma → tekerleği yeniden icat. Reddedildi.
- Homebrew cask: otomatik değil, kullanıcı `brew upgrade` yapmalı. İleride ek kanal olabilir.
