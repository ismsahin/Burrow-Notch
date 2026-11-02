# DURUM — Burrow

> Son güncelleme: 2026-11-02 · Güncelleyen: Claude Code (Opus 5.5) · Sürüm: v1.0 (henüz yayınlanmadı)

## Özet
v1 kodu tamamlandı, derleniyor ve 36/36 birim testi geçiyor. Release derlemesi imzalanıyor ve açılıyor. Kapalı/açık çentik,
canlı etkinlikler, raf ve ayarlar dahili Retina ekranda **ekran görüntüsüyle doğrulandı** (`docs/ornekler/ekran-goruntuleri/`).
**GitHub'a henüz push edilmedi**: `gh` oturumu açık değil.

## ⏭ Sıradaki adım (kullanıcı yapacak)
```bash
gh auth login
scripts/setup-github.sh          # repo + Sparkle anahtarları + imza sertifikası + ilk push → ilk sürüm
# Actions bitince:
curl -fsSL https://raw.githubusercontent.com/<kullanıcı>/burrow/main/scripts/install.sh | bash
```
Not: Yerel `scripts/build-local.sh` derlemesinde besleme adresi boştur, otomatik güncelleme **almaz**. Günlük kullanım için
uygulamayı install.sh ile kur.

## Tamamlananlar
- [x] Çentik paneli, fare takibi, tıklama geçirgenliği (yalnızca görünen şekil tıklama alır)
- [x] Canlı etkinlikler: müzik, şarj, düşük pil, ses/parlaklık HUD, Bluetooth
- [x] Açık çentik: oynatıcı + sürüklenebilir ilerleme + kapak rengi, takvim, ayna, pil
- [x] Raf: sürükle-bırak, dışarı sürükle, AirDrop, sağ tık menüsü
- [x] Kaydırma hareketleri, dokunsal geri bildirim
- [x] Sistem HUD'unu değiştirme (CGEventTap, varsayılan kapalı)
- [x] Ayarlar penceresi (5 sekme), menü çubuğu simgesi, girişte başlat
- [x] Sparkle 2 + release.yml (test → derle → imzala → EdDSA → appcast → Release)
- [x] install.sh (SHA-256 + codesign + sabitlenmiş sertifika parmak izi)
- [x] Kod incelemesi: 10 bulgu düzeltildi (bkz. ISLEM_LOG kayıt 3)
- [x] Hafıza yapısı: AGENTS/CLAUDE/GEMINI.md, kararlar (7), referanslar, promptlar, örnekler, log

## Gerçek kullanımda doğrulanmadı (otomasyonla test edilemedi)
- Gerçek fare üzerine gelme / kaydırma / dosya sürükleme (Terminal'in Erişilebilirlik izni yok, olay gönderilemedi;
  mantık birim testli, görünüm `scripts/debug-notch.sh` ile doğrulandı)
- Müzik/Spotify çalarken uçtan uca (betikler gerçek AppleScript derleyicisinde derleniyor, ayrıştırıcı testli)
- Medya tuşu yakalama, parlaklık, kamera, takvim izin akışları
- GitHub Actions hattı (ilk push'ta çalışacak; betikler yerelde ayrı ayrı denendi)

## Bilinen sınırlar
- Tarayıcı medyası (YouTube vb.) görünmez → karar 0003
- Kilit ekranı widget'ı, uygulama bildirimleri yok → karar 0001
- Developer ID yok: tarayıcıdan zip indirilirse Gatekeeper uyarır; install.sh kullan → karar 0005

## Yol haritası (öneri)
1. Kullanıcı geri bildirimiyle fare/kaydırma ince ayarı
2. Zamanlayıcı / Pomodoro canlı etkinliği
3. Odak modu değişim etkinliği (`docs/ornekler/yeni-canli-etkinlik-ekleme.md`)
4. Tarayıcı medyası için ek kaynak araştırması
5. Homebrew cask (ikincil kurulum kanalı)
