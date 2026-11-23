#!/usr/bin/env bash
# Create the self-signed code-signing identity build.sh signs sketchybar with.
#
# macOS ties the "control this Mac" (Accessibility) approval to the binary's
# code signature. An ad-hoc signature changes with every build, so each rebuild
# re-prompted. Signing every build with the same local certificate keeps the
# identity stable, so the approval granted once in System Settings survives.
#
# Idempotent: does nothing if the identity already exists in the login keychain.
set -euo pipefail

name=${1:-sketchybar-local}
keychain=$HOME/Library/Keychains/login.keychain-db

if security find-identity -v -p codesigning "$keychain" 2>/dev/null | grep -q "\"$name\""; then
  echo "identity '$name' already present"
  exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
pass=$(head -c 24 /dev/urandom | base64)

cat > "$work/ext.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = $name
[v3]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
EOF

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -config "$work/ext.cnf" -keyout "$work/key.pem" -out "$work/cert.pem" 2>/dev/null
# OpenSSL 3 defaults to PBKDF2/AES/SHA-256 inside the PKCS#12, which macOS's
# importer rejects ("MAC verification failed"); use the algorithms it accepts.
openssl pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" \
  -name "$name" -passout "pass:$pass" -out "$work/identity.p12" \
  -macalg sha1 -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES

# -T lets codesign use the key; the first signing may still ask once in a
# keychain dialog, where "Always Allow" settles it.
security import "$work/identity.p12" -k "$keychain" -P "$pass" \
  -T /usr/bin/codesign -T /usr/bin/security >/dev/null

# Trust it for code signing in the user's trust domain so codesign and the
# system accept the chain. This can show a one-time authorization dialog.
security add-trusted-cert -r trustRoot -p codeSign -k "$keychain" "$work/cert.pem"

echo "created code-signing identity '$name' in the login keychain"
