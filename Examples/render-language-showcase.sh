#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${RHOEMD_BIN:-${ROOT_DIR}/.build/debug/rhoemd}"
OUTPUT_DIR="${RHOEMD_EXAMPLE_OUTPUT_DIR:-Examples/outputs}"

cd "$ROOT_DIR"

if [[ ! -x "$BIN" ]]; then
  swift build --product rhoemd
fi

mkdir -p "$OUTPUT_DIR"

"$BIN" Examples/sources/language-showcase.md \
  -o "$OUTPUT_DIR/language-showcase.html" \
  --format html \
  --css \
  --pretty
