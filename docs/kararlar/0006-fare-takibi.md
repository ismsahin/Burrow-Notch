# 0006 — Fare takibi ve tıklama geçirgenliği

- **Tarih:** 2026-11-02
- **Durum:** Kabul

## Bağlam
Çentik açılınca büyür. Pencereyi animasyonla yeniden boyutlandırmak SwiftUI yay animasyonuyla çakışır, titreme yapar.
Pencere hep büyük olursa menü çubuğunun ortasına tıklanamaz.

## Karar
- Panel sabit boyutlu (760×300), şekil SwiftUI içinde animasyonlanır.
- Kapalı ve imleç dışarıdayken `ignoresMouseEvents = true`.
- İmleç konumu `NSEvent` küresel + yerel `mouseMoved` monitörüyle izlenir (fare monitörü izin gerektirmez).
- İsabet alanları ekran koordinatında `NotchGeometry.topCenteredRect` ile hesaplanır.

## Sonuçlar
- (+) Akıcı animasyon, menü çubuğu kullanılabilir kalır.
- (−) Açıkken panelin şeffaf kenarları tıklamayı yakalar; imleç dışarı çıkınca 0.12 sn içinde kapandığı için pratikte sorun değil.
