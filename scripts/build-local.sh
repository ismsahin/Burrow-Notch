#!/usr/bin/env bash
# Yerelde Release derler, imzalar, /Applications'a kurar ve açar.
# Kullanım: scripts/build-local.sh [--no-install]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

command -v xcodegen >/dev/null || { echo "xcodegen gerekli: brew install xcodegen"; exit 1; }
xcodegen generate --quiet

xcodebuild -project Burrow.xcodeproj -scheme Burrow -configuration Release \
  -derivedDataPath build/DerivedData -destination 'platform=macOS' build -quiet

APP="build/DerivedData/Build/Products/Release/Burrow.app"
scripts/sign-app.sh "$APP"

if [[ "${1:-}" == "--no-install" ]]; then
  echo "Derlendi: $APP"
  exit 0
fi

DEST="/Applications"
[[ -w "$DEST" ]] || DEST="$HOME/Applications"
mkdir -p "$DEST"
pkill -x Burrow 2>/dev/null || true
sleep 0.5
rm -rf "$DEST/Burrow.app"
ditto "$APP" "$DEST/Burrow.app"
open "$DEST/Burrow.app"
echo "Kuruldu ve açıldı: $DEST/Burrow.app"
