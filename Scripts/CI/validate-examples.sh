#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

for file in Examples/README.md Examples/COMMANDS.md Examples/gallery-manifest.json Examples/render-all.sh; do
  if [[ ! -s "${file}" ]]; then
    echo "Missing example gallery file: ${file}" >&2
    exit 1
  fi
done

swift build --product rhoemd

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/rhoemarkdown-examples.XXXXXX")"
trap 'rm -rf "${tmp_dir}"' EXIT

RHOEMD_BIN="${REPO_ROOT}/.build/debug/rhoemd" \
RHOEMD_EXAMPLE_OUTPUT_DIR="${tmp_dir}" \
  bash Examples/render-all.sh > /dev/null

diff -qr Examples/outputs "${tmp_dir}" > /tmp/rhoemarkdown-example-diff.txt || {
  cat /tmp/rhoemarkdown-example-diff.txt >&2
  echo "Example gallery outputs drifted. Run bash Examples/render-all.sh intentionally and review outputs." >&2
  exit 1
}

echo "EXAMPLES_VALIDATION PASS"
