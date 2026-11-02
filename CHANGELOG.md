# Değişiklik Günlüğü

Biçim: [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/). Sürümler `1.0.<CI çalıştırma no>` olarak otomatik verilir.

## [Yayınlanmamış]

### Eklendi (v1.0.5)
- **Çoklu canlı etkinlik**: müzik, indirme, yaklaşan takvim etkinliği ve zamanlayıcı aynı anda; kapalı çentikte iki
  parmakla sağa/sola (fare tekerleğiyle yukarı/aşağı) kaydırarak geçiş, sayfa noktaları.
- **Öncelikli etkinlik seçimi**: Otomatik (en son başlayan) ya da müzik / indirme / takvim / zamanlayıcı.
- **İndirmeler**: Safari ve Chrome indirmelerinin ilerlemesi (yüzde + halka), bitince "İndirildi" bildirimi.
- **Yaklaşan takvim etkinliği**: başlamadan 5–60 dk önce geri sayım.
- **Kulaklık/cihaz pili**: AirPods sol/sağ/kutu, diğer cihazlarda tek düzey; bağlanınca ve açık çentikte.
- **Zamanlayıcı**: "Süre" sekmesi, hazır süreler (1–45 dk) + özel süre, +1 dk, bitince ses.
- **Dynamic Island (hap) biçimi** çentiksiz ekranlar için (isteğe bağlı); **çentik dış çizgisi**.
- **Büyük HUD** biçimi ve HUD'da yay aşma efekti.

### Eklendi (v1.0.4)
- **Yaklaşınca büyü** (Alcove efekti): imleç çentiğe yaklaştıkça çentik yumuşakça kabarır. Ayarlardan kapatılabilir.
- **Açılma biçimi**: "Üzerinde bekleyince" (bekleme süresi 0–1,5 sn ayarlanabilir) veya "Tıklayınca".
- **Ekran seçimi**: Çentikli ekran (MacBook) / Ana ekran / Tüm ekranlar.
- Uygulamaya tekrar tıklayınca (Uygulamalar'dan) ayarlar açılır.

### Düzeltildi (v1.0.4)
- Ayarlar penceresi diğer pencerelerin arkasında açılıyordu.

### Eklendi
- Çentik paneli: üzerine gelince/tıklayınca açılan, yay animasyonlu, çentiksiz ekranlarda sanal çentik.
- Canlı etkinlikler: çalan müzik (kapak + ekolayzer), şarj, düşük pil, ses/parlaklık HUD, Bluetooth cihaz.
- Açık çentik: oynatıcı (sürüklenebilir ilerleme, kontroller, kapak rengi ışıması), takvim, kamera aynası, pil.
- Dosya rafı: sürükle-bırak, dışarı sürükleme, AirDrop, Finder'da göster.
- Kaydırma hareketleri: yatay → şarkı değiştir, dikey → aç/kapat.
- Sistem HUD'unu değiştirme (isteğe bağlı, Erişilebilirlik izni).
- Ayarlar penceresi, menü çubuğu simgesi, girişte başlat.
- Sparkle 2 ile otomatik güncelleme; main'e push → GitHub Release.
- Tek komutla kurulum betiği (SHA-256 + kod imzası + sabitlenmiş sertifika doğrulaması).
- Sürükle-bırak kurulum diski (`Burrow.dmg`): uygulamayı Uygulamalar'a sürükle, diski çıkar.
