#!/usr/bin/env bash
set -euo pipefail

IDENTITY="${CODESIGN_IDENTITY:-Graker Local Development}"
KEYCHAIN="${CODESIGN_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"

if [[ "$IDENTITY" == "-" ]]; then
  printf '%s\n' "$IDENTITY"
  exit 0
fi

if security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -F "\"$IDENTITY\"" >/dev/null; then
  printf '%s\n' "$IDENTITY"
  exit 0
fi

WORK="$(mktemp -d /tmp/graker-codesign.XXXXXX)"
PKCS12_PASSWORD="$(uuidgen)"
cleanup() {
  rm -rf "$WORK"
}
trap cleanup EXIT

cat > "$WORK/openssl.cnf" <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = codesign
prompt = no

[req_distinguished_name]
CN = $IDENTITY

[codesign]
keyUsage = critical,digitalSignature
extendedKeyUsage = codeSigning
basicConstraints = critical,CA:false
EOF

openssl req \
  -newkey rsa:2048 \
  -nodes \
  -keyout "$WORK/key.pem" \
  -x509 \
  -days 3650 \
  -out "$WORK/cert.pem" \
  -config "$WORK/openssl.cnf" \
  -extensions codesign >/dev/null 2>&1

openssl pkcs12 \
  -export \
  -legacy \
  -out "$WORK/identity.p12" \
  -inkey "$WORK/key.pem" \
  -in "$WORK/cert.pem" \
  -passout "pass:$PKCS12_PASSWORD" >/dev/null 2>&1

security import "$WORK/identity.p12" \
  -k "$KEYCHAIN" \
  -P "$PKCS12_PASSWORD" \
  -T /usr/bin/codesign >/dev/null

security add-trusted-cert \
  -d \
  -r trustRoot \
  -p codeSign \
  -k "$KEYCHAIN" \
  "$WORK/cert.pem" >/dev/null

if ! security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -F "\"$IDENTITY\"" >/dev/null; then
  echo "Could not create a valid code signing identity named '$IDENTITY'." >&2
  exit 1
fi

printf '%s\n' "$IDENTITY"
