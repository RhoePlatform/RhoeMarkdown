#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

OUTPUT_DIR="${RHOE_MARKDOWN_DOCC_OUTPUT:-.build/docc-pages}"
HOSTING_BASE_PATH="${RHOE_MARKDOWN_DOCC_BASE_PATH:-RhoeMarkdown}"

rm -rf "${OUTPUT_DIR}"
swift package --allow-writing-to-directory "${OUTPUT_DIR}" \
  generate-documentation \
  --target RhoeMarkdownKit \
  --disable-indexing \
  --transform-for-static-hosting \
  --hosting-base-path "${HOSTING_BASE_PATH}" \
  --output-path "${OUTPUT_DIR}"

if [[ ! -s "${OUTPUT_DIR}/index.html" ]]; then
  echo "DocC static site did not produce ${OUTPUT_DIR}/index.html" >&2
  exit 1
fi

echo "DOCC_PAGES_BUILD PASS ${OUTPUT_DIR}"
