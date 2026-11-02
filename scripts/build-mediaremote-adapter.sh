#!/usr/bin/env bash
# Vendor/mediaremote-adapter kaynağından MediaRemoteAdapter.framework derler (arm64 + x86_64).
# Kullanım: scripts/build-mediaremote-adapter.sh <çıktı-klasörü>
# Xcode derleme aşamasından çağrılır; kaynak değişmediyse yeniden derlemez.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Vendor/mediaremote-adapter"
OUT="${1:?çıktı klasörü gerekli}"
FW="$OUT/MediaRemoteAdapter.framework"
BIN="$FW/Versions/A/MediaRemoteAdapter"

SOURCES=(adapter/env adapter/get adapter/globals adapter/keys adapter/now_playing adapter/repeat adapter/seek
         adapter/send adapter/shuffle adapter/speed adapter/stream adapter/test private/MediaRemote
         utility/Debounce utility/helpers)
FILES=()
for s in "${SOURCES[@]}"; do FILES+=("$SRC/src/$s.m"); done

# Kaynaklar çıktıdan yeni değilse atla
if [[ -f "$BIN" ]] && [[ -z "$(find "$SRC" "$0" -newer "$BIN" -type f -print -quit)" ]]; then
  echo "MediaRemoteAdapter güncel"
  exit 0
fi

rm -rf "$FW"
mkdir -p "$FW/Versions/A/Resources"
xcrun clang -dynamiclib -fobjc-arc -fvisibility=default -O2 -w \
  -arch arm64 -arch x86_64 -mmacosx-version-min=14.0 \
  -I "$SRC/include" -I "$SRC/src" \
  -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
  -install_name "@rpath/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter" \
  -o "$BIN" "${FILES[@]}"
cat > "$FW/Versions/A/Resources/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>MediaRemoteAdapter</string>
  <key>CFBundleIdentifier</key><string>com.ismsahin.Burrow.MediaRemoteAdapter</string>
  <key>CFBundleName</key><string>MediaRemoteAdapter</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>0.7.7</string>
  <key>CFBundleVersion</key><string>0.7.7</string>
</dict></plist>
PLIST
ln -sfn A "$FW/Versions/Current"
ln -sfn Versions/Current/MediaRemoteAdapter "$FW/MediaRemoteAdapter"
ln -sfn Versions/Current/Resources "$FW/Resources"
codesign --force --sign - "$FW" >/dev/null 2>&1
echo "Derlendi: $FW"
