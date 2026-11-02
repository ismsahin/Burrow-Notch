#!/usr/bin/env bash
# Tek öğelik Sparkle appcast.xml üretir (stdout).
# Kullanım: make-appcast.sh <sürüm> <derleme> <zip-url> '<sign_update çıktısı>' '<notlar>'
set -euo pipefail
VERSION="$1"; BUILD="$2"; URL="$3"; SIG_ATTRS="$4"; NOTES="${5:-}"

# sign_update çıktısı: sparkle:edSignature="..." length="..."  → yalnızca bu iki özniteliğe izin ver
if ! [[ "$SIG_ATTRS" =~ ^sparkle:edSignature=\"[A-Za-z0-9+/=]+\"\ length=\"[0-9]+\"$ ]]; then
  echo "Geçersiz imza çıktısı: $SIG_ATTRS" >&2
  exit 1
fi

# Bayt düzeyinde işle (Türkçe karakterlerde "illegal byte sequence" olmasın)
export LC_ALL=C
xml_escape() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'; }
TITLE="$(printf 'Burrow %s' "$VERSION" | xml_escape)"
# head bayt keser; yarım kalan UTF-8 dizisini iconv -c atar → appcast her zaman geçerli UTF-8
DESC="$(printf '%s' "$NOTES" | head -c 2000 | iconv -c -f UTF-8 -t UTF-8 | sed 's/]]>/]] >/g' | xml_escape)"
DATE="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"

cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Burrow</title>
    <item>
      <title>$TITLE</title>
      <pubDate>$DATE</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[<pre>$DESC</pre>]]></description>
      <enclosure url="$URL" type="application/octet-stream" $SIG_ATTRS />
    </item>
  </channel>
</rss>
EOF
