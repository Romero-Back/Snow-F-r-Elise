#!/bin/bash
# Для CI: восстанавливает .signing/dev.keychain-db из секрета SIGNING_P12_BASE64
# (это .signing/cert.p12 в base64, пароль furelise). Тогда build.sh подпишет релиз
# тем же сертификатом, что и локальные сборки, — и у пользователей не слетит доступ к Dock.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -z "${SIGNING_P12_BASE64:-}" ]; then
    echo "SIGNING_P12_BASE64 не задан — релиз будет с ad-hoc подписью"
    exit 0
fi
KC="$PWD/.signing/dev.keychain-db"
mkdir -p .signing
echo "$SIGNING_P12_BASE64" | base64 --decode > .signing/cert.p12
security create-keychain -p furelise "$KC"
security set-keychain-settings "$KC"
security unlock-keychain -p furelise "$KC"
security import .signing/cert.p12 -k "$KC" -P furelise -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple: -s -k furelise "$KC" >/dev/null
# На раннере codesign ищет ключ только в связках из списка поиска — добавляем свою.
security list-keychains -d user -s "$KC" $(security list-keychains -d user | tr -d '"')
security find-identity -p codesigning "$KC"
echo "Сертификат подписи импортирован"
