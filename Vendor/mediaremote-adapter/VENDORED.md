# mediaremote-adapter (vendored)

- Kaynak: https://github.com/ungive/mediaremote-adapter
- Sürüm: v0.7.7 — commit `e3ff5021eb0875858bd05f48d2e9ba2e962d1cf6`
- Lisans: BSD 3-Clause (bkz. `LICENSE`)
- Neden: macOS 15.4+ "şu an çalan" bilgisini (YouTube, tarayıcılar, her oynatıcı) yalnızca `com.apple.*` kimlikli
  süreçlere veriyor. Apple imzalı `/usr/bin/perl` bu kuralı karşıladığı için adaptör onun içinde çalışır. Bkz. karar 0009.
- Değişiklik: yok. `src/test` içinden yalnızca `NowPlayingTest.h` başlığı alındı (derleme için); test istemcisi yok, `test` komutu kullanılmaz.
- Güvenlik taraması (2026-11-02): ağ erişimi yok, dosya yazma yok; `NSTask` yalnızca kullanılmayan `test` komutunda.
- Derleme: `scripts/build-mediaremote-adapter.sh` (cmake gerektirmez; clang ile, kaynaktan). Hazır ikili dosya yok.
- Güncelleme: yeni etiketin kaynağını incele (aynı taramayı yap) → buraya kopyala → bu dosyadaki sürüm/commit'i güncelle.
