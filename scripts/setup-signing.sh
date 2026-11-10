#!/bin/bash
# Создаёт постоянный самоподписанный сертификат для подписи приложения при локальной сборке.
# Зачем: macOS привязывает разрешение «Универсальный доступ» к подписи. С ad-hoc подписью
# каждая пересборка — «новое приложение», и доступ слетает. С постоянным сертификатом — нет.
# Сертификат лежит в отдельной связке ключей .signing/ (в .gitignore), основную не трогает.
set -euo pipefail
cd "$(dirname "$0")/.."
DIR=.signing
KC="$PWD/$DIR/dev.keychain-db"
PASS=furelise
NAME="Fur Elise Local Signing"
mkdir -p "$DIR"
if [ -f "$KC" ]; then echo "Уже настроено: $KC"; exit 0; fi

cat > "$DIR/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$DIR/cert.cnf" \
    -keyout "$DIR/key.pem" -out "$DIR/cert.pem" 2>/dev/null
openssl pkcs12 -export -legacy -inkey "$DIR/key.pem" -in "$DIR/cert.pem" -out "$DIR/cert.p12" -passout pass:$PASS 2>/dev/null \
  || openssl pkcs12 -export -inkey "$DIR/key.pem" -in "$DIR/cert.pem" -out "$DIR/cert.p12" -passout pass:$PASS

security create-keychain -p $PASS "$KC"
security set-keychain-settings "$KC"            # без автоблокировки
security unlock-keychain -p $PASS "$KC"
security import "$DIR/cert.p12" -k "$KC" -P $PASS -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple: -s -k $PASS "$KC" >/dev/null
rm -f "$DIR/key.pem" "$DIR/cert.p12" "$DIR/cert.cnf"
echo "Готово: $NAME в $KC"
