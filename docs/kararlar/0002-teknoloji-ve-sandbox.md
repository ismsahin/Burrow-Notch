# 0002 — Teknoloji yığını ve sandbox

- **Tarih:** 2026-11-02
- **Durum:** Kabul

## Karar
- **Swift + SwiftUI + AppKit**, Swift 5 dil modu (Swift 6 katı eşzamanlılık AppKit/IOKit geri çağrılarında gereksiz sürtünme yaratıyor).
- **macOS 14+**: `SMAppService`, `requestFullAccessToEvents`, `symbolEffect`, `dropDestination` için.
- **XcodeGen** (`project.yml`): `.xcodeproj` git'e girmez. Metin tabanlı proje tanımı yapay zekâ ve insan için okunaklı,
  birleştirme çakışması üretmez.
- **App Sandbox kapalı**, Hardened Runtime açık. Sandbox içinde küresel fare monitörü, CGEventTap, diğer uygulamalara
  AppleScript ve rastgele dosya yolu saklama çalışmaz. Alcove ve Boring Notch da sandbox dışıdır.
- Tek bağımlılık: **Sparkle 2** (SPM).

## Alternatifler
- SwiftPM yürütülebilir + elle .app paketleme: Sparkle framework gömme ve imzalama adımlarını elle yapmak gerekir. Reddedildi.
- Elle yönetilen `.xcodeproj`: yapay zekâlar arası devirde bozulmaya açık. Reddedildi.
