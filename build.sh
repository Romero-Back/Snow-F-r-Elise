#!/bin/bash
# Собирает универсальное (Apple Silicon + Intel) приложение и архивы для раздачи:
#   build/Für Elise.app, build/FurElise.zip, build/FurElise.dmg
# Требуется только Command Line Tools (xcode-select --install), Xcode не нужен.
set -euo pipefail
cd "$(dirname "$0")"

NAME="Für Elise"   # как подписал Бетховен
EXEC=FurElise      # имя бинарника и архивов — без умляута и пробела, чтобы не ломались ссылки
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)}"
APP="build/$NAME.app"

bins=()
for arch in arm64 x86_64; do
    echo "→ Сборка $arch"
    swift build -c release --triple "$arch-apple-macosx13.0" --scratch-path ".build/$arch"
    bins+=("$(swift build -c release --triple "$arch-apple-macosx13.0" --scratch-path ".build/$arch" --show-bin-path)/$EXEC")
done

echo "→ Упаковка $APP ($VERSION)"
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "${bins[@]}" -output "$APP/Contents/MacOS/$EXEC"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"

# Подпись. Если есть локальный сертификат (scripts/setup-signing.sh) — подписываем им:
# тогда «Универсальный доступ» не слетает после пересборки. Иначе — ad-hoc (например, в CI).
# Для раздачи без предупреждений Gatekeeper нужна подпись Developer ID и нотаризация — см. README.
KC="$PWD/.signing/dev.keychain-db"
if [ -f "$KC" ]; then
    security unlock-keychain -p furelise "$KC"
    codesign --force --options runtime --keychain "$KC" --sign "Fur Elise Local Signing" "$APP"
    echo "→ Подписано локальным сертификатом"
else
    codesign --force --options runtime --sign - "$APP"
    echo "→ Ad-hoc подпись (нет .signing/, см. scripts/setup-signing.sh)"
fi

echo "→ Архивы"
ditto -c -k --keepParent "$APP" "build/$EXEC.zip"
DMG_DIR=build/dmg
mkdir -p "$DMG_DIR"
cp -R "$APP" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"
hdiutil create -volname "$NAME" -srcfolder "$DMG_DIR" -ov -format UDZO "build/$EXEC.dmg" >/dev/null
rm -rf "$DMG_DIR"

echo "Готово:"
ls -lh "build/$EXEC.zip" "build/$EXEC.dmg"
lipo -archs "$APP/Contents/MacOS/$EXEC"
