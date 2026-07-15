#!/bin/sh
# Ensures a stable local code-signing identity exists in the login keychain.
#
# macOS ties Accessibility/notification permissions to an app's code-signing
# identity. Ad-hoc signing (`codesign -s -`) has no fixed identity, so every
# rebuild looks like a different app and silently revokes permissions granted
# on the previous run. Signing with a real (if self-signed) certificate keeps
# the identity stable across rebuilds, so granted permissions persist.
#
# Idempotent: does nothing if an identity with $IDENTITY_NAME already exists.
set -eu

IDENTITY_NAME="${1:-Agent Dev}"

if security find-certificate -c "$IDENTITY_NAME" login.keychain-db >/dev/null 2>&1 \
    || security find-certificate -c "$IDENTITY_NAME" login.keychain >/dev/null 2>&1; then
    exit 0
fi

echo "No local code-signing identity named \"$IDENTITY_NAME\" found — creating one..." >&2

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

cat > "$WORKDIR/codesign.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no

[dn]
CN = $IDENTITY_NAME

[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -keyout "$WORKDIR/key.pem" -out "$WORKDIR/cert.pem" \
    -days 3650 -nodes -config "$WORKDIR/codesign.cnf" -extensions ext

openssl pkcs12 -export -out "$WORKDIR/cert.p12" \
    -inkey "$WORKDIR/key.pem" -in "$WORKDIR/cert.pem" -passout pass:

security import "$WORKDIR/cert.p12" -k login.keychain-db -P "" \
    -T /usr/bin/codesign -T /usr/bin/security

# Trust the cert for code signing within the login keychain only (no sudo,
# no system-wide trust store changes) — equivalent to clicking "Always
# Trust" in Keychain Access.
security add-trusted-cert -r trustRoot -p codeSign -k login.keychain-db "$WORKDIR/cert.pem"

echo "created local code-signing identity: $IDENTITY_NAME" >&2
