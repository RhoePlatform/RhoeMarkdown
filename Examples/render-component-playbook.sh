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

"$BIN" Examples/sources/component-playbook.md \
  -o "$OUTPUT_DIR/component-playbook.html" \
  --format html \
  --css \
  --pretty
