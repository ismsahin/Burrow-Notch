# 0003 — Medya kaynağı: AppleScript + dağıtık bildirim

- **Tarih:** 2026-11-02
- **Durum:** Kabul

## Bağlam
Çentik uygulamaları genelde özel `MediaRemote.framework` kullanır. **macOS 15.4'ten itibaren Apple, yetkisiz
süreçlerin MediaRemote'tan "şu an çalan" bilgisini okumasını engelledi.** Boring Notch bunu aşmak için Apple imzalı
`/usr/bin/perl` içine çerçeve yükleyen bir adaptör kullanıyor; bu kırılgan ve güvenlik açısından tartışmalı.

## Karar
- **Müzik** ve **Spotify** desteklenir.
- Değişim tetiği: oynatıcıların yayınladığı dağıtık bildirimler (izin gerektirmez, anlık).
- Ayrıntı/kontrol: AppleScript (Otomasyon izni, ilk kullanımda macOS sorar).
- Hiçbir oynatıcı açık değilken sıfır yoklama.

## Sonuçlar
- (+) Genel, belgelenmiş mekanizmalar; macOS güncellemesiyle kırılma riski düşük.
- (−) Tarayıcıda (YouTube vb.) çalan medya görünmez. Yol haritasında: `MediaPlayer` enum'una yeni AppleScript destekli oynatıcı eklemek kolaydır
  (`docs/ornekler/yeni-oynatici-ekleme.md`).
