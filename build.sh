#!/bin/bash
# Собирает универсальное (Apple Silicon + Intel) приложение и архивы для раздачи:
#   build/Für Elise.app, build/FurElise.zip, build/FurElise.dmg
# Требуется только Command Line Tools (xcode-select --install), Xcode не нужен.
# Версия: VERSION=1.2.0 ./build.sh (по умолчанию — из Resources/Info.plist).
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
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
lipo -create "${bins[@]}" -output "$APP/Contents/MacOS/$EXEC"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
# Sparkle сравнивает CFBundleVersion — держим её равной версии.
/usr/libexec/PlistBuddy -c "Set CFBundleVersion $VERSION" "$APP/Contents/Info.plist"

# Sparkle.framework (универсальный) — из скачанного SwiftPM артефакта, с сохранением симлинков.
SPARKLE_FW=$(find .build/arm64/artifacts -path "*Sparkle.xcframework/macos-*/Sparkle.framework" -maxdepth 6 | head -1)
ditto "$SPARKLE_FW" "$APP/Contents/Frameworks/Sparkle.framework"

# Подпись. Если есть сертификат (scripts/setup-signing.sh локально, scripts/import-signing.sh в CI) —
# подписываем им: тогда «Универсальный доступ» не слетает после обновлений. Иначе — ad-hoc.
# Hardened runtime не включаем: он нужен только для нотаризации, а с самоподписанным
# сертификатом не дал бы загрузить Sparkle.framework.
KC="$PWD/.signing/dev.keychain-db"
if [ -f "$KC" ]; then
    security unlock-keychain -p furelise "$KC"
    SIGN=(--keychain "$KC" --sign "Fur Elise Local Signing")
    echo "→ Подпись сертификатом"
else
    SIGN=(--sign -)
    echo "→ Ad-hoc подпись (нет .signing/)"
fi
sign() { codesign --force "${SIGN[@]}" "$@"; }
FW="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
# Порядок из документации Sparkle: изнутри наружу.
sign "$FW/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$FW/XPCServices/Downloader.xpc"
sign "$FW/Autoupdate"
sign "$FW/Updater.app"
sign "$APP/Contents/Frameworks/Sparkle.framework"
sign "$APP"
codesign --verify --deep --strict "$APP"

echo "→ Архивы"
ditto -c -k --sequesterRsrc --keepParent "$APP" "build/$EXEC.zip"
DMG_DIR=build/dmg
mkdir -p "$DMG_DIR"
cp -R "$APP" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"
hdiutil create -volname "$NAME" -srcfolder "$DMG_DIR" -ov -format UDZO "build/$EXEC.dmg" >/dev/null
rm -rf "$DMG_DIR"

echo "Готово:"
ls -lh "build/$EXEC.zip" "build/$EXEC.dmg"
lipo -archs "$APP/Contents/MacOS/$EXEC"
