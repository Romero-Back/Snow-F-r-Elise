#!/bin/bash
# Один раз (или при смене оформления): раскладывает окно установщика через Finder
# и сохраняет его настройки в Resources/dmg/DS_Store. Дальше build.sh кладёт этот шаблон
# и фон в каждый .dmg — Finder для сборки уже не нужен (в том числе в GitHub Actions).
#
# Перед запуском: ./build.sh (нужен build/Für Elise.app) и swift scripts/make-dmg-background.swift.
# При первом запуске macOS спросит, можно ли Терминалу управлять Finder, — нужно разрешить.
set -euo pipefail
cd "$(dirname "$0")/.."

VOL="Für Elise"          # имя тома должно совпадать с тем, что ставит build.sh
APP="build/$VOL.app"
# Во временной папке: путь к образу попадает в .DS_Store, и в нём не должно быть имени пользователя.
WORK=$(mktemp -d /tmp/furelise-dmg.XXXXXX)
TMP="$WORK/src"
IMG="$WORK/FurElise.dmg"
mkdir -p "$TMP/.background"
cp -R "$APP" "$TMP/"
ln -s /Applications "$TMP/Applications"
cp Resources/dmg/background.tiff "$TMP/.background/background.tiff"

# Если том с таким именем уже подключён — отключаем, иначе новый получит другое имя.
[ -d "/Volumes/$VOL" ] && hdiutil detach "/Volumes/$VOL" -quiet || true
hdiutil create -volname "$VOL" -srcfolder "$TMP" -ov -format UDRW "$IMG" >/dev/null
DEV=$(hdiutil attach -readwrite -noverify -noautoopen "$IMG" | grep -E '^/dev/' | head -1 | awk '{print $1}')
MNT="/Volumes/$VOL"

osascript <<EOF
tell application "Finder"
    tell disk "$VOL"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        -- Окно 660×420 по содержимому (+28 pt заголовок).
        set the bounds of container window to {200, 120, 860, 568}
        delay 1
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 112
        set text size of opts to 13
        set background picture of opts to file ".background:background.tiff"
        set position of item "$VOL.app" of container window to {165, 205}
        set position of item "Applications" of container window to {495, 205}
        update without registering applications
        delay 2
        close
        delay 1
        -- Повторное открытие с тем же размером: Finder записывает размер окна (bwsp) при закрытии.
        open
        delay 1
        set the bounds of container window to {200, 120, 860, 568}
        delay 2
        close
        delay 2
    end tell
end tell
EOF

sync
sleep 1
cp "$MNT/.DS_Store" Resources/dmg/DS_Store
hdiutil detach "$DEV" -quiet
rm -rf "$WORK"
echo "Готово: Resources/dmg/DS_Store"
