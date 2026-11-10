#!/bin/bash
# Делает build/appcast.xml — ленту обновлений Sparkle для свежесобранного build/FurElise.zip.
# Лента прикрепляется к релизу, а приложение читает её по ссылке
#   https://github.com/<repo>/releases/latest/download/appcast.xml
#
# Использование: SPARKLE_PRIVATE_KEY=... scripts/make-appcast.sh <версия> [файл-с-описанием]
# Ключ берётся из переменной SPARKLE_PRIVATE_KEY или из .signing/sparkle_private.key.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$1"
NOTES_FILE="${2:-}"
REPO="${GITHUB_REPOSITORY:-Romero-Back/Snow-F-r-Elise}"
ZIP=build/FurElise.zip
SIGN_UPDATE=$(find .build/arm64/artifacts -path "*Sparkle/bin/sign_update" | head -1)

if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
    ENCLOSURE_SIG=$(echo "$SPARKLE_PRIVATE_KEY" | "$SIGN_UPDATE" --ed-key-file - "$ZIP")
else
    ENCLOSURE_SIG=$("$SIGN_UPDATE" --ed-key-file .signing/sparkle_private.key "$ZIP")
fi

NOTES=""
if [ -n "$NOTES_FILE" ] && [ -s "$NOTES_FILE" ]; then
    # Каждая непустая строка — пункт списка.
    NOTES="<ul>$(sed -e '/^[[:space:]]*$/d' -e 's/^[-*•][[:space:]]*//' -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' \
        -e 's/.*/<li>&<\/li>/' "$NOTES_FILE" | tr -d '\n')</ul>"
fi
PUB_DATE=$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")

cat > build/appcast.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Für Elise</title>
    <item>
      <title>Für Elise $VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <description><![CDATA[$NOTES]]></description>
      <enclosure url="https://github.com/$REPO/releases/download/v$VERSION/FurElise.zip"
                 $ENCLOSURE_SIG
                 type="application/octet-stream"/>
    </item>
  </channel>
</rss>
XML
echo "Готово: build/appcast.xml"
