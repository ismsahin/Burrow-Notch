#!/usr/bin/env bash
# TEK SEFERLİK kurulum: GitHub deposu + otomatik güncelleme anahtarları + imza sertifikası.
#
# Önkoşul: `gh auth login` yapılmış olmalı.
# Kullanım: scripts/setup-github.sh [depo-adı]   (varsayılan: origin remote'undaki ad, yoksa burrow)
#
# Yaptıkları:
#  1. Herkese açık GitHub deposu oluşturur (Sparkle'ın sürümleri indirebilmesi için public olmalı).
#  2. Sparkle ed25519 anahtar çifti üretir → özel anahtar: GitHub Secret, genel anahtar: GitHub Variable.
#     Özel anahtar ayrıca macOS Anahtar Zinciri'nde saklanır (yedek). Diske düz metin bırakılmaz.
#  3. Kendinden imzalı kod imzalama sertifikası üretir → GitHub Secret. (Her güncellemede izinler sıfırlanmasın diye.)
#  4. README/install.sh içindeki __GITHUB_REPO__ yer tutucusunu doldurur, commit'ler, main'e push'lar.
#     İlk push, ilk sürümü (v1.0.N) otomatik yayınlar.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ORIGIN_NAME="$(git remote get-url origin 2>/dev/null | sed -E 's#.*/([^/]+)(\.git)?$#\1#; s#\.git$##')"
REPO_NAME="${1:-${ORIGIN_NAME:-burrow}}"
CERT_NAME="Burrow Self-Signed"

command -v gh >/dev/null || { echo "gh gerekli: brew install gh"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Önce: gh auth login"; exit 1; }

OWNER="$(gh api user --jq .login)"
FULL="$OWNER/$REPO_NAME"
echo "Depo: $FULL"

# 1) Depo
if ! gh repo view "$FULL" >/dev/null 2>&1; then
  gh repo create "$FULL" --public --description "Burrow — çentiğin içindeki küçük yuva. macOS Dynamic Island."
fi
git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$FULL.git"

# Otomatik güncelleme ve install.sh sürümleri kimlik doğrulamasız indirir → depo public olmalı.
if [[ "$(gh repo view "$FULL" --json visibility -q .visibility)" != "PUBLIC" ]]; then
  echo ""
  echo "⚠️  $FULL şu an PRIVATE. Otomatik güncelleme ve kurulum için PUBLIC olmalı (kod herkese görünür olur)."
  read -r -p "Depoyu public yapayım mı? [e/H] " ANSWER
  if [[ "$ANSWER" =~ ^[eEyY]$ ]]; then
    gh repo edit "$FULL" --visibility public --accept-visibility-change-consequences
    echo "✓ Depo public yapıldı"
  else
    echo "! Depo private kaldı: sürümler yayınlanır ama uygulamalar güncelleme indiremez."
  fi
fi

# 2) Sparkle anahtarları — araçlar SPM'in checksum ile doğruladığı sabit sürümden (project.yml) alınır
command -v xcodegen >/dev/null || { echo "xcodegen gerekli: brew install xcodegen"; exit 1; }
xcodegen generate --quiet
xcodebuild -resolvePackageDependencies -project Burrow.xcodeproj -derivedDataPath build/DerivedData -quiet
TOOLS="$ROOT/build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle"
[[ -x "$TOOLS/bin/generate_keys" ]] || { echo "Sparkle araçları bulunamadı: $TOOLS/bin"; exit 1; }
ACCOUNT="burrow-$OWNER"
"$TOOLS/bin/generate_keys" --account "$ACCOUNT" >/dev/null 2>&1 || true   # varsa yeniden üretmez
PUBLIC_KEY="$("$TOOLS/bin/generate_keys" --account "$ACCOUNT" -p)"
KEYFILE="$(mktemp)"
trap 'rm -f "$KEYFILE"' EXIT
rm -f "$KEYFILE"
"$TOOLS/bin/generate_keys" --account "$ACCOUNT" -x "$KEYFILE"
gh secret set SPARKLE_PRIVATE_KEY --repo "$FULL" < "$KEYFILE"
rm -f "$KEYFILE"
gh variable set SPARKLE_PUBLIC_KEY --repo "$FULL" --body "$PUBLIC_KEY"
echo "✓ Sparkle anahtarları ayarlandı (genel anahtar: $PUBLIC_KEY)"

# 3) Kendinden imzalı kod imzalama sertifikası
if ! gh secret list --repo "$FULL" | grep -q MACOS_CERT_P12; then
  CERT_DIR="$(mktemp -d)"
  trap 'rm -rf "$CERT_DIR"; rm -f "$KEYFILE"' EXIT
  cat > "$CERT_DIR/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $CERT_NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF
  P12_PASS="$(openssl rand -hex 24)"
  /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$CERT_DIR/key.pem" -out "$CERT_DIR/cert.pem" -config "$CERT_DIR/cert.cnf" 2>/dev/null
  /usr/bin/openssl pkcs12 -export -inkey "$CERT_DIR/key.pem" -in "$CERT_DIR/cert.pem" \
    -name "$CERT_NAME" -passout "pass:$P12_PASS" -out "$CERT_DIR/cert.p12"
  CERT_SHA256="$(/usr/bin/openssl x509 -in "$CERT_DIR/cert.pem" -outform DER | shasum -a 256 | awk '{print $1}')"
  base64 -i "$CERT_DIR/cert.p12" | gh secret set MACOS_CERT_P12 --repo "$FULL"
  printf '%s' "$P12_PASS" | gh secret set MACOS_CERT_PASSWORD --repo "$FULL"

  # Yerel derlemeler de aynı kimlikle imzalansın (izinler CI ve yerel arasında korunur)
  security import "$CERT_DIR/cert.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
    -P "$P12_PASS" -T /usr/bin/codesign >/dev/null 2>&1 && echo "✓ Sertifika yerel anahtar zincirine eklendi" \
    || echo "! Sertifika yerel anahtar zincirine eklenemedi (isteğe bağlı)"
  rm -rf "$CERT_DIR"
  echo "✓ İmza sertifikası ayarlandı"
fi

# 3b) Kurulum betiğine sertifika parmak izini sabitle (yalnızca bizim sertifikamızla imzalı uygulama kurulur)
if [[ -z "${CERT_SHA256:-}" ]] && security find-certificate -c "$CERT_NAME" >/dev/null 2>&1; then
  CERT_SHA256="$(security find-certificate -c "$CERT_NAME" -p | /usr/bin/openssl x509 -outform DER | shasum -a 256 | awk '{print $1}')"
fi
if [[ -n "${CERT_SHA256:-}" ]]; then
  sed -i '' "s#__CERT_SHA256__#$CERT_SHA256#g" scripts/install.sh
  echo "✓ install.sh sertifika parmak izi: $CERT_SHA256"
else
  echo "! Sertifika parmak izi bulunamadı; install.sh sabitleme olmadan çalışacak"
fi

# 4) Yer tutucular + push
grep -rl "__GITHUB_REPO__" README.md scripts/install.sh docs 2>/dev/null | while read -r f; do
  sed -i '' "s#__GITHUB_REPO__#$FULL#g" "$f"
done
git add -A
git commit -m "chore: configure repository $FULL" >/dev/null 2>&1 || true
git branch -M main
git push -u origin main
echo ""
echo "✓ Hazır. İlk sürüm GitHub Actions'ta derleniyor: https://github.com/$FULL/actions"
echo "  Kurulum komutu: curl -fsSL https://raw.githubusercontent.com/$FULL/main/scripts/install.sh | bash"
