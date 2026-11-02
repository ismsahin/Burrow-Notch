#!/usr/bin/env bash
# Sürükle-bırak kurulum diski üretir: Burrow.app → Uygulamalar.
# Kullanım: scripts/make-dmg.sh <Burrow.app> <çıktı.dmg> [imza-kimliği]
set -euo pipefail
APP="${1:?Kullanım: make-dmg.sh <Burrow.app> <çıktı.dmg> [kimlik]}"
OUT="${2:?çıktı .dmg yolu gerekli}"
IDENTITY="${3:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/stage" "$WORK/bg"
ditto "$APP" "$WORK/stage/Burrow.app"
swift "$ROOT/scripts/make-dmg-background.swift" "$WORK/bg" >/dev/null
# Retina için tek TIFF içinde @1x + @2x
tiffutil -cathidpicheck "$WORK/bg/dmg-background.png" "$WORK/bg/dmg-background@2x.png" -out "$WORK/bg/background.tiff" >/dev/null

rm -f "$OUT"
mkdir -p "$(dirname "$OUT")"

if command -v create-dmg >/dev/null; then
  # Finder ile pencere düzeni (simge konumları, arka plan). Başarısız olursa düz diske düşeriz.
  if create-dmg \
      --volname "Burrow" \
      --volicon "$WORK/stage/Burrow.app/Contents/Resources/AppIcon.icns" \
      --background "$WORK/bg/background.tiff" \
      --window-pos 200 120 --window-size 600 400 \
      --icon-size 112 --text-size 13 \
      --icon "Burrow.app" 150 190 --hide-extension "Burrow.app" \
      --app-drop-link 450 190 \
      --no-internet-enable \
      "$OUT" "$WORK/stage" >"$WORK/create-dmg.log" 2>&1; then
    echo "Düzenli DMG üretildi"
  else
    echo "! create-dmg başarısız, düz DMG'ye düşülüyor:"; tail -5 "$WORK/create-dmg.log"
    rm -f "$OUT"
  fi
fi

if [[ ! -f "$OUT" ]]; then
  ln -s /Applications "$WORK/stage/Applications"
  hdiutil create -volname "Burrow" -srcfolder "$WORK/stage" -ov -format UDZO -fs HFS+ "$OUT" >/dev/null
fi

if [[ -n "$IDENTITY" ]]; then
  codesign --force --sign "$IDENTITY" --timestamp=none "$OUT"
fi
hdiutil verify "$OUT" >/dev/null
echo "DMG: $OUT ($(du -h "$OUT" | cut -f1))"
