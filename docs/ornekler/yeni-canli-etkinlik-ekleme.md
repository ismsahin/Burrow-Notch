# Örnek: yeni bir canlı etkinlik eklemek (ör. "Odak modu değişti")

1. **Model** — `Burrow/Notch/LiveActivity.swift`
   ```swift
   case focus(name: String, isOn: Bool)
   ```
   `priority`, `displayDuration`, `extraWidth` ve `isSameKind` içine yeni dalı ekle (derleyici eksik `switch`'i gösterir).

2. **Test** — `BurrowTests/CoreLogicTests.swift`
   ```swift
   func test_focus_isTransient() {
       XCTAssertNotNil(LiveActivity.focus(name: "İş", isOn: true).displayDuration)
   }
   ```

3. **Servis** — `Burrow/Features/Focus/FocusMonitor.swift`: olay yayınlayan `PassthroughSubject`.

4. **Bağlantı** — `AppServices.wire()`:
   ```swift
   focus.events
       .filter { [weak self] _ in self?.settings.showFocusActivity ?? false }
       .sink { [weak self] in self?.activity.show(.focus(name: $0.name, isOn: $0.isOn)) }
       .store(in: &bag)
   ```

5. **Ayar** — `AppSettings`: `Key`, `@Published` özellik, `defaultValues`, `init`. `SettingsView` → "Etkinlikler" sekmesine `Toggle`.

6. **Görünüm** — `CompactNotchView.leading` ve `.trailing` içine yeni `case`.

7. **Doğrula** — Debug derle, `scripts/debug-notch.sh` içine komut ekleyip ekran görüntüsü al.

8. **Kayıt** — `CHANGELOG.md`, `docs/log/ISLEM_LOG.md`, `DURUM.md`.
