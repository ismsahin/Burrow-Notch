#!/usr/bin/env bash
# Burrow tek komutla kurulum:
#   curl -fsSL https://raw.githubusercontent.com/ismsahin/Burrow-Notch/main/scripts/install.sh | bash
#
# Ne yapar: GitHub'daki son sürümü indirir, SHA-256 ve kod imzasını doğrular,
# /Applications'a (yazılamıyorsa ~/Applications) kurar ve açar. Sonraki güncellemeler uygulama içinden otomatik gelir.
set -euo pipefail

REPO="${BURROW_REPO:-ismsahin/Burrow-Notch}"
# Yayın sertifikasının SHA-256 parmak izi (setup-github.sh doldurur). Zip + SHA256SUMS aynı sürümden geldiği için
# yalnızca bütünlük sağlar; asıl kimlik doğrulaması bu sabitlenmiş sertifikadır.
CERT_PIN="2146be3c6ec22f2786fb5409ef197079fa7242cc599334db8f9f41d721c7bcca"
BASE="https://github.com/$REPO/releases/latest/download"

if [[ "$(uname)" != "Darwin" ]]; then echo "Burrow yalnızca macOS içindir."; exit 1; fi
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if (( MAJOR < 14 )); then echo "Burrow macOS 14 (Sonoma) veya üstü gerektirir."; exit 1; fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "→ Son sürüm indiriliyor ($REPO)…"
curl -fsSL --proto '=https' --tlsv1.2 -o "$TMP/Burrow.zip" "$BASE/Burrow.zip"
curl -fsSL --proto '=https' --tlsv1.2 -o "$TMP/SHA256SUMS" "$BASE/SHA256SUMS"

echo "→ Bütünlük doğrulanıyor…"
EXPECTED="$(awk '/Burrow.zip/ {print $1}' "$TMP/SHA256SUMS")"
ACTUAL="$(shasum -a 256 "$TMP/Burrow.zip" | awk '{print $1}')"
if [[ -z "$EXPECTED" || "$EXPECTED" != "$ACTUAL" ]]; then
  echo "✗ SHA-256 eşleşmedi, kurulum iptal edildi."; exit 1
fi

ditto -x -k "$TMP/Burrow.zip" "$TMP/out"
APP="$TMP/out/Burrow.app"
codesign --verify --deep --strict "$APP" || { echo "✗ Kod imzası geçersiz, kurulum iptal edildi."; exit 1; }
if [[ "$CERT_PIN" != __CERT* ]]; then
  (cd "$TMP" && codesign -d --extract-certificates="$TMP/signer" "$APP" 2>/dev/null)
  SIGNER="$(shasum -a 256 "$TMP/signer0" 2>/dev/null | awk '{print $1}')"
  if [[ "$SIGNER" != "$CERT_PIN" ]]; then
    echo "✗ Uygulama beklenen Burrow sertifikasıyla imzalanmamış, kurulum iptal edildi."; exit 1
  fi
fi

DEST="/Applications"
[[ -w "$DEST" ]] || DEST="$HOME/Applications"
mkdir -p "$DEST"

echo "→ $DEST konumuna kuruluyor…"
pkill -x Burrow 2>/dev/null || true
sleep 0.5
rm -rf "$DEST/Burrow.app"
ditto "$APP" "$DEST/Burrow.app"

open "$DEST/Burrow.app"
echo "✓ Burrow kuruldu. Çentiğin üzerine gel ✨"
