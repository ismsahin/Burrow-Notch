# 0005 — Kod imzalama: kendinden imzalı sertifika

- **Tarih:** 2026-11-02
- **Durum:** Kabul

## Bağlam
Apple Developer ID (yıllık 99 $) yok → noter onayı yok. Ad-hoc imzada "designated requirement" her derlemede değişir;
macOS TCC (Erişilebilirlik, Otomasyon, Takvim, Kamera izinleri) her güncellemede izinleri **sıfırlar**. Bu kötü bir deneyim.

## Karar
`setup-github.sh` 10 yıllık, yalnızca `codeSigning` amaçlı kendinden imzalı bir sertifika ("Burrow Self-Signed") üretir,
GitHub Secret olarak saklar. CI geçici anahtar zincirine yükler, tüm sürümler aynı kimlikle imzalanır → izinler güncellemeler
arasında korunur. Sertifika yoksa ad-hoc'a düşer ve uyarı basar.

## Library validation
Hardened runtime, süreçle aynı Team ID'ye sahip olmayan kütüphaneleri reddeder. Ad-hoc ve kendinden imzalı
sertifikalarda Team ID yoktur → gömülü `Sparkle.framework` yüklenemez ("different Team IDs", açılışta çöküş).
Bu yüzden `com.apple.security.cs.disable-library-validation` yetkisi verildi. `allow-dyld-environment-variables`
verilmedi; yani `DYLD_INSERT_LIBRARIES` ile enjeksiyon hâlâ engelli. Developer ID alınınca bu yetki kaldırılmalı.

## Sonuçlar
- Gatekeeper yine "tanımlanamayan geliştirici" der; `install.sh` curl ile indirdiği için karantina bayrağı olmaz,
  ayrıca SHA-256 ve `codesign --verify` ile doğrular.
- İleride Developer ID alınırsa: `sign-app.sh`'e kimlik + `notarytool` adımı eklenir; Sparkle EdDSA anahtarı aynı kalır.
  **Dikkat:** imza kimliği değişince TCC izinleri bir kez sıfırlanır.
