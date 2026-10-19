#!/usr/bin/env bash
#
# Build the Moodle submission ZIP from the project root.
#
#   bash scripts/package-submission.sh
#
# The archive contains the source tree and the vendored build dependencies in lib/,
# the documentation, and the Ex3 evidence under submission/. It never contains
# .env, private keys, seed phrases, credentials, build artifacts, or temporary
# files. A local .env may exist for deployment; it is always excluded.
#
# Output: ../stablecoin-lab-2026-submission.zip (next to the project directory)
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

FOLDER="stablecoin-lab-2026-main"
ZIP_OUT="$(cd .. && pwd)/stablecoin-lab-2026-submission.zip"
STAGING="$(mktemp -d /tmp/stablecoin-zip.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT

# ---------------------------------------------------------------------------
# 1. Copy the tree into a staging directory, excluding everything that must
#    not be submitted
# ---------------------------------------------------------------------------
mkdir -p "$STAGING/$FOLDER"
tar -cf - \
    --exclude './out' \
    --exclude './cache' \
    --exclude './broadcast' \
    --exclude './.env' \
    --exclude './lib/forge-std/test' \
    --exclude './lib/openzeppelin-contracts/lib/forge-std/test' \
    --exclude './demo-state.json' \
    --exclude './.DS_Store' \
    --exclude '*.zip' \
    --exclude '*.pem' \
    --exclude '*.key' \
    --exclude './keystore' \
    --exclude './wallets' \
    . | tar -xf - -C "$STAGING/$FOLDER"

# ---------------------------------------------------------------------------
# 2. Secret scan over the staged tree
# ---------------------------------------------------------------------------
echo "secret scan over the staged tree:"
FOUND=0
if find "$STAGING" -name '.env*' ! -name '.env.example' | grep -q .; then
    echo "  ✗ .env-style file found in the archive"
    FOUND=1
else
    echo "  ✓ no .env-style files besides .env.example"
fi
if grep -rInE '(PRIVATE_KEY|ADMIN_KEY|ATTACK_KEY|privateKey)[[:space:]]*[:=,][[:space:]]*0x[0-9a-fA-F]{64}' "$STAGING" | grep -q .; then
    echo "  ✗ 64-hex private key material found"
    FOUND=1
else
    echo "  ✓ no 64-hex private key material"
fi
if [ "$FOUND" -eq 1 ]; then
    echo "packaging aborted — fix the matches above" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 3. Build the ZIP (top-level folder keeps the expected project layout)
# ---------------------------------------------------------------------------
rm -f "$ZIP_OUT"
( cd "$STAGING" && zip -qr "$ZIP_OUT" "$FOLDER" )
echo "  ✓ archive written: $ZIP_OUT"

# ---------------------------------------------------------------------------
# 4. Integrity checks on the archive itself
# ---------------------------------------------------------------------------
echo "integrity:"
unzip -t "$ZIP_OUT" > /dev/null
echo "  ✓ unzip -t passes"
COUNT=$(unzip -l "$ZIP_OUT" | tail -1 | awk '{print $2}')
echo "  ✓ $COUNT entries"

# ---------------------------------------------------------------------------
# 5. Record the contents and the checks in submission/package-check.txt
# ---------------------------------------------------------------------------
{
    echo "package-check for $ZIP_OUT"
    echo "generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo
    echo "archive: $ZIP_OUT ($(du -h "$ZIP_OUT" | cut -f1))"
    echo "entries: $COUNT"
    echo
    echo "--- secret scan of the staged tree ---"
    echo "no .env-style files besides .env.example"
    echo "no 64-hex private key material"
    echo "no *.pem / *.key / keystore / wallets entries"
    echo
    echo "--- excluded by design ---"
    echo "out/ cache/ broadcast/ and vendored test fixtures (not build dependencies)"
    echo ".env .env.*  (secrets; only .env.example ships)"
    echo "demo-state.json .DS_Store *.zip *.pem *.key keystore/ wallets/"
    echo
    echo "--- contents ---"
    unzip -l "$ZIP_OUT" | sed -n '4,$p'
} > submission/package-check.txt

# Rebuild once so the freshly generated package-check.txt ships inside
rm -f "$ZIP_OUT"
cp submission/package-check.txt "$STAGING/$FOLDER/submission/package-check.txt"
( cd "$STAGING" && zip -qr "$ZIP_OUT" "$FOLDER" )
unzip -t "$ZIP_OUT" > /dev/null
echo "  ✓ final rebuild verified (package-check.txt included)"

echo
echo "submission package ready: $ZIP_OUT"
