#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=${1:-"$(cd "$(dirname "$0")/.." && pwd)"}

if [ -f "$REPO_ROOT/vcsky/sha256sums.txt" ]; then
  echo "vcsky already prepared"
  exit 0
fi
if [ -d "$REPO_ROOT/vcsky" ]; then
  echo "error: $REPO_ROOT/vcsky exists but is incomplete (missing sha256sums.txt). Delete it and re-run." >&2
  exit 1
fi

TMP=$(mktemp -d)
EXTRACT="$REPO_ROOT/.vcsky-extract-$$"
trap 'rm -rf "$TMP" "$EXTRACT"' EXIT

echo "Downloading revcdos.bin (~1.08 GB)..."
curl -L --fail --output "$TMP/revcdos.bin" https://folder.morgen.qzz.io/revcdos.bin

echo "Fetching the upstream unpacker..."
git clone --quiet https://github.com/Lolendor/reVCDOS "$TMP/reVCDOS"
git -C "$TMP/reVCDOS" checkout --quiet 95f14ef3c1d0a872ecd0881544cc7e1f55cb1946

python3 -m venv "$TMP/venv"
"$TMP/venv/bin/pip" install --quiet brotli aiofiles

echo "Extracting vcsky (~1.5 GB)..."
"$TMP/venv/bin/python" - "$TMP/revcdos.bin" "$EXTRACT" "$TMP/reVCDOS/utils" <<'PY'
import sys
sys.path.insert(0, sys.argv[3])
from packer_brotli import unpack_file
unpack_file(sys.argv[1], sys.argv[2])
PY

mv "$EXTRACT/vcsky" "$REPO_ROOT/vcsky"
echo "vcsky prepared at $REPO_ROOT/vcsky"
