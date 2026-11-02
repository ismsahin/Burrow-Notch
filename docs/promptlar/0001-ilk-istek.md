# 0001 — İlk istek (2026-11-02, Claude Code / Opus 5.5)

Kullanıcının kelimesi kelimesine isteği:

> bana alcove https://tryalcove.com/ ve https://boringnotch.com/ karışımı daha çok alcove temelli ve ekstra olarak boring
> notch özelliklerininde eklenmiş hali olan güzel bi uygulama yapar mısın ismine bu programların isminden yola çıkarak sen
> özgün bir isim ver programı güvenlik açığı oluşturmadan kolay kurulumu olan github maine pushlandğında otomatik güncelleme
> çekecek şekilde yap. bütün güzel zöellikler olsun optimize olsun bug u olmasın sorun çıkarmasın güzel aynı bu attıklarım
> gibi olsun istiyorum. bunu yaparken sonradan unutmamak için hafıza dosyalarıını oluştur claude md readme md kararlar
> klasörü referanslar promptlar ornekler durum md gibi hertürlü yapılan işlemin loglandğıı ve farklı yapay zekaya geçince
> birebir sorunsuz devam edebileceğim şekilde proje dizinini kur.

## Çıkarılan gereksinimler
1. Alcove temelli + Boring Notch özellikleri → karar 0001
2. Özgün isim → **Burrow**
3. Güvenli, kolay kurulum → `scripts/install.sh` (SHA-256 + codesign doğrulama)
4. main push → otomatik güncelleme → karar 0004
5. Optimize, hatasız → olay tabanlı servisler, birim testleri
6. Yapay zekâlar arası devredilebilir hafıza → `AGENTS.md`, `DURUM.md`, `docs/**`
