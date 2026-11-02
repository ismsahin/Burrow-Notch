#!/usr/bin/env bash
# Burrow.app'i (gömülü Sparkle dahil) içten dışa doğru imzalar.
# Kullanım: scripts/sign-app.sh <Burrow.app yolu> [kimlik]
#   kimlik verilmezse BURROW_SIGN_IDENTITY ortam değişkeni, o da yoksa ad-hoc ("-") kullanılır.
#   Not: yerelde anahtar zincirindeki sertifikayı kullanmak macOS'ta izin penceresi açar ve betik bekler;
#   bu yüzden varsayılan ad-hoc. CI kimliği açıkça verir.
set -euo pipefail

APP="${1:?Kullanım: sign-app.sh <Burrow.app> [kimlik]}"
IDENTITY="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENTITLEMENTS="$ROOT/Burrow/Resources/Burrow.entitlements"

IDENTITY="${IDENTITY:-${BURROW_SIGN_IDENTITY:--}}"
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

MRA="$APP/Contents/Frameworks/MediaRemoteAdapter.framework"
[[ -d "$MRA" ]] && sign "$MRA"

sign --entitlements "$ENTITLEMENTS" "$APP"
codesign --verify --deep --strict --verbose=1 "$APP"
echo "İmzalandı: $APP"
