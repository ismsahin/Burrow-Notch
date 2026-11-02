# Fikirler — sonra yapılacak (2026-11-03, kullanıcı İsmail)

> Henüz başlanmadı. Sırayla değil; hepsi kullanıcının istekleri. Yaparken her biri için ADR (`docs/kararlar/`) aç.

## 1. Sürükle-bırak ile panoya alma (Pano / "Kopyalananlar" sekmesi)
- Bağlantı veya fotoğraf (ya da metin) çentiğin üzerine sürüklenip bırakılınca **Pano** sekmesine eklensin.
- Bırakınca çentik **açılıp Pano sekmesinde açık kalsın**; kullanıcı öğeyi oradan alıp (sürükleyip) kullansın.
- Kapanma: çentik dışına (boşluğa) tıklayınca **ya da** belli süre dokunulmazsa (süre ayarlanabilir olsun).
- Not: şu an çentiğe bırakılan dosyalar **Raf**'a gidiyor (`NotchRootView.dropDestination(for: URL.self)`); URL/görsel/metin
  türüne göre Pano'ya yönlendirme ve `ClipboardStore`'a ekleme gerekecek. Dosya ↔ link ayrımı kararı verilmeli.

## 2. Dosya sürüklerken eylem bölgeleri: Kopyala / Kes / AirDrop
- Dosya sürüklemeye **başlayınca** çentik kendiliğinden açılsın ve bölgeler çıksın: **Kopyala**, **Kes (taşı)**, **AirDrop**.
- Hangisinin üzerine bırakılırsa o işlem başlar:
  - Kopyala / Kes → dosya çentikte (raf benzeri) **tutulur**. Bu ekran **kapanmaz**; kullanıcı başka masaüstüne/uygulamaya/klasöre
    geçer, oradan çentikteki dosyayı tutup hedefe sürükler → kopyalama ya da taşıma o anda yapılır.
  - AirDrop → AirDrop paylaşım penceresi açılır (`NSSharingService(named: .sendViaAirDrop)`), oradan paylaşılır.
- Teknik notlar: sistem genelinde sürükleme başlangıcını yakalamak için `NSPasteboard(name: .drag)` changeCount izleme +
  global `leftMouseDragged` (Boring Notch / Alcove benzeri). Kes = hedefe bırakınca kaynağı sil (`NSDragOperation.move`);
  izinler ve geri alma (çöpe taşıma yerine gerçek silme yapma!) dikkatle tasarlanmalı.

## 3. Ücretli satış / lisans anahtarı (karar verilmedi)
- Kullanıcı ileride parayla satmayı ya da lisans anahtarıyla dağıtmayı düşünüyor. Konuşulan seçenekler ve dikkat noktaları:
  - Depo şu an **public** → kod açık; lisans kontrolü derleyen biri tarafından kolayca kaldırılır. Satışa geçilecekse
    depo private yapılmalı; Sparkle güncellemeleri için indirmeler public bir yerde kalmalı (ayrı public "releases" deposu ya da site).
  - Ödeme + lisans: Merchant-of-record hizmeti (Lemon Squeezy, Paddle; KDV/vergiyi onlar halleder, lisans anahtarı API'si var) ya da Gumroad.
  - Ücretli kullanıcı için **Apple Developer ID (yıllık 99 $) + notarization** şart: kendinden imzalı sertifikada Gatekeeper uyarısı çıkar.
  - Lisanslar: Sparkle (MIT), mediaremote-adapter (BSD-3) ticari kullanıma izin veriyor; uygulamada lisans metinleri gösterilmeli.
  - Model önerisi: ücretsiz deneme (ör. 14 gün) + tek seferlik lisans; anahtar çevrimdışı doğrulanabilir imzalı (Ed25519) olsun,
    periyodik çevrimiçi kontrol isteğe bağlı. Sırlar (API anahtarı) koda yazılmaz.
