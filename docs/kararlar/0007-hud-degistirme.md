# 0007 — Sistem HUD'unu değiştirme

- **Tarih:** 2026-11-02
- **Durum:** Kabul

## Karar
- Ses değişimini **her zaman** CoreAudio dinleyicisiyle görürüz (izin yok) → çentikte gösterilir. Ama macOS'un kendi HUD'u da görünür.
- "Sistem HUD'unu değiştir" açılırsa: `CGEventTap` ile `NX_SYSDEFINED` medya tuşları (ses +/−/sessiz, parlaklık +/−)
  yakalanır, sistem HUD'u hiç tetiklenmez, değeri biz ayarlarız. Erişilebilirlik izni gerekir → **varsayılan kapalı**.
- Parlaklık: özel `DisplayServices` `dlopen` ile; bulunamazsa parlaklık tuşları sisteme bırakılır (`return false`).
- Option+Shift ile ¼ adım (macOS davranışıyla aynı).

## Riskler ve önlemler
- Tap geri çağrısı yavaşlarsa macOS tap'i kapatır → `tapDisabledByTimeout` gelince yeniden açılır.
- Burrow çökerse tap süreçle birlikte ölür, tuşlar normale döner (kalıcı sistem değişikliği yok).
- Yalnızca bastığımız tuşun "bırakma" olayını yutarız; diğer olaylar dokunulmadan geçer.
