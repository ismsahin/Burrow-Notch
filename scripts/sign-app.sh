#!/usr/bin/env bash
# Burrow.app'i (gömülü Sparkle dahil) içten dışa doğru imzalar.
# Kullanım: scripts/sign-app.sh <Burrow.app yolu> [kimlik]
#   kimlik verilmezse "Burrow Self-Signed" anahtar zincirinde varsa o, yoksa ad-hoc ("-") kullanılır.
set -euo pipefail

APP="${1:?Kullanım: sign-app.sh <Burrow.app> [kimlik]}"
IDENTITY="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENTITLEMENTS="$ROOT/Burrow/Resources/Burrow.entitlements"

if [[ -z "$IDENTITY" ]]; then
  if security find-certificate -c "Burrow Self-Signed" >/dev/null 2>&1; then
    IDENTITY="Burrow Self-Signed"
  else
    IDENTITY="-"
  fi
fi
echo "İmza kimliği: $IDENTITY"

sign() { codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$@"; }

SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
if [[ -d "$SPARKLE" ]]; then
  V="$SPARKLE/Versions/B"
  [[ -d "$V/XPCServices/Installer.xpc" ]] && sign "$V/XPCServices/Installer.xpc"
  [[ -d "$V/XPCServices/Downloader.xpc" ]] && sign --preserve-metadata=entitlements "$V/XPCServices/Downloader.xpc"
  [[ -e "$V/Autoupdate" ]] && sign "$V/Autoupdate"
  [[ -d "$V/Updater.app" ]] && sign "$V/Updater.app"
  sign "$SPARKLE"
fi

sign --entitlements "$ENTITLEMENTS" "$APP"
codesign --verify --deep --strict --verbose=1 "$APP"
echo "İmzalandı: $APP"
