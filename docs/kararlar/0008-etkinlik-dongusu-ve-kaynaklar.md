# 0008 — Çoklu canlı etkinlik döngüsü ve yeni kaynaklar

- **Tarih:** 2026-11-02
- **Durum:** Kabul

## Bağlam
Kullanıcı: "Hem müzik çalıyor hem bir şey iniyorsa kaydırınca aralarında geçsin; boştayken ne görüneceğini seçebileyim;
kulaklık şarjını göreyim; çentiksiz ekranda Dynamic Island olsun." Alcove 1.5'te "multiple live activities", 1.7'de
"pill shape for notchless displays" ekledi.

## Karar
- **İki katman:** kalıcı etkinlikler (`media`, `download`, `calendar`, `timer`) `ActivityCarousel` içinde; geçiciler
  (`hud`, `charging`, `lowBattery`, `device`, `notice`) birkaç saniye üstte.
- **Seçim kuralı (saf, testli):** tercih edilen etkinse o → yoksa en son başlayan. Elle kaydırılan seçim o etkinlik
  sürdükçe korunur. Geçici varken kaydırma geçiş yapmaz.
- **Kaydırma:** kapalı çentikte trackpad/Magic Mouse yatay = etkinlik değiştir (tek etkinlik müzikse şarkı değiştir);
  klasik fare tekerleği dikey = etkinlik değiştir. Açık çentikte yatay = şarkı.
- **İndirmeler:** `Progress.addSubscriber(forFileURL: ~/Downloads)`. Safari/Chrome'un Finder'a yayınladığı ilerlemeyi
  dinler; dosya okumaz, izin istemez. Firefox yayınlamadığı için görünmez.
- **Kulaklık pili:** genel API yok → Apple'ın `system_profiler SPBluetoothDataType -json` aracı, yalnızca bağlantıda
  (+2,5 sn) ve bağlıyken 5 dakikada bir, arka planda, 8 sn zaman aşımıyla. Özel API kullanılmadı.
- **Takvim etkinliği:** başlamadan N dk (5–60, varsayılan 15) önce, başladıktan 5 dk sonrasına kadar.
- **Ada (hap) biçimi:** yalnızca çentiksiz ekranlarda, isteğe bağlı (varsayılan sanal çentik). Menü çubuğu içinde dikey
  ortalı (menü çubuğu − 5 pt), altındaki pencerelerin üstüne taşmaz.
- **Büyük HUD:** çentik aşağı uzar (simge + kalın çubuk + yüzde), HUD'da hafif aşma (overshoot) yayı.

## Yapılmayanlar (bilerek)
- **Kilit ekranı widget'ları:** Alcove'un geliştiricisi bunun için belgelenmemiş sistem API'leri kullandığını ve
  geliştirirken Mac'ine 4 kez giriş yapamadığını yazıyor. Kullanıcıyı Mac'inden kilitleme riski → yok.
- **Diğer uygulamaların bildirimleri:** okumak Tam Disk Erişimi + özel bildirim veritabanı gerektirir → yok.
- **Odak modu:** genel API yok (veritabanı Tam Disk Erişimi ister) → ileride araştırılacak.
- **Hava durumu:** WeatherKit ücretli geliştirici hesabı, alternatifler konum izni + üçüncü taraf API ister → ileride.
