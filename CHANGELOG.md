# Değişiklik Günlüğü

Biçim: [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/). Sürümler `1.0.<CI çalıştırma no>` olarak otomatik verilir.

## [Yayınlanmamış]

### Eklendi / Değişti (v1.0.9)
- **Ada köşeleri** ayarı: Yuvarlak (hap, 78 pt) ya da Köşeli (çentik gibi, 120 pt; 185'ten daraltıldı).
  Seçilmemişse büyük adada köşeli, küçük adada hap.
- **Anımsatıcı kategorileri**: üstte liste çipleri (renk + sayı); varsayılan ilk liste, "Tümü" isteğe bağlı. Seçim hatırlanır.
- **Ana ekranı özelleştir** (Ayarlar › Etkinlikler › Ana Ekran): Müzik, Takvim, Anımsatıcılar, Kamera aynası; aç/kapa + sırala.
- **Ayna düğmesi küçüldü** (44 pt, yalnızca simge); tıklayınca yine büyür. Ana ekrandan kaldırılırsa kamera kapanır.

### Değişti (v1.0.8)
- **Büyük ada** artık ilk sanal çentik kadar geniş (185 pt) ve köşeleri çentik oranında (11 pt), tam hap değil.
  Küçük ada hap olarak kaldı. Şarj yüzdesi dar alanda iki satıra kaymıyor.

### Eklendi (v1.0.7)
- **YouTube ve tarayıcı medyası**: Chrome, Safari, Arc vb. ve sistemdeki her oynatıcı (podcast, VLC…) kapak, ilerleme ve
  kontrollerle çentikte. macOS 15.4+ kısıtı mediaremote-adapter (BSD-3) ile aşıldı; yoksa Müzik/Spotify yoluna düşer.

### Eklendi (v1.0.6)
- **Bildirimler** (Tam Disk Erişimi ile): yeni bildirim önce büyük kart, sonra kapalı çentikte uygulama simgesi +
  okunmamış sayısı; "Bildirimler" sekmesinde son bildirimler, tıkla → uygulamayı aç.
- **Pano geçmişi**: Yazı / Bağlantı / Medya kategorileri, yıldızlama, yıldızlı filtresi, arama, tıkla → tekrar kopyala.
  Parola yöneticilerinin kopyaladıkları kaydedilmez.
- **Alarm**: saat alarmları (bir kez / her gün), Süre sekmesinde "Geri sayım | Alarm".
- **Anımsatıcılar** sekmesi: tamamlanmamışlar, tarih/gecikme, tıkla → tamamlandı.
- **Büyük ayna**: aynaya basınca takvimin yerini kaplar (müzik yarıda, ayna yarıda), ✕ ile küçülür.
- **Ada boyutu**: Küçük (menü çubuğunda) / Büyük.
- Sekmeler simgeye dönüştü (altı sekme), bildirim sekmesinde kırmızı sayaç.

### Değişti (v1.0.6)
- Yaklaşınca daha belirgin siyah hale, bulanıklıktan netleşen açılış, daha yaylı açılış, açılışta daha belirgin titreşim.

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
