# 0001 — İsim ve v1 kapsamı

- **Tarih:** 2026-11-02
- **Durum:** Kabul

## Bağlam
Kullanıcı Alcove temelli, Boring Notch özellikleri eklenmiş, özgün isimli bir çentik uygulaması istedi.

## Karar
**İsim: Burrow.** *Alcove* "duvardaki oyuk/niş" demek; *boring* "oymak, delmek" anlamına da gelir. İkisinin kesişimi:
oyularak açılmış küçük, sıcak yuva → *burrow*. Simge de bunu anlatır: koyu bir yuvanın tepesinden sızan sıcak ışık.

**v1 kapsamı**
- Alcove'dan: akıcı yay animasyonları, canlı etkinlikler (müzik, şarj, düşük pil, ses/parlaklık, Bluetooth),
  kaydırma hareketleri, özelleştirilebilir HUD, hızlı yerel uygulama.
- Boring Notch'tan: dosya rafı + AirDrop, kamera aynası, takvim, pil göstergesi, kapak rengi ışıması, çentiksiz Mac desteği.

**v1 dışında (bilerek):**
- Kilit ekranı widget'ları (özel SkyLight API'leri gerektirir, kırılgan).
- Uygulama bildirimlerini çentikte gösterme (genel API yok; bildirim veritabanını okumak Tam Disk Erişimi ister).
- Tarayıcı medya desteği (bkz. 0003).

## Sonuçlar
Kapsam dışı maddeler `DURUM.md` "Yol haritası" bölümünde.
