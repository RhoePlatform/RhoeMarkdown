#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

COMMONMARK_FIXTURES="Tests/ExternalConformance/commonmark/spec.json"
GFM_FIXTURES="Tests/ExternalConformance/gfm/spec.json"
REPORT_ROOT="${RHOE_MARKDOWN_EXTERNAL_CONFORMANCE_REPORT_ROOT:-.build/reports/external-conformance}"
FAILURE_BUDGET="${RHOE_MARKDOWN_EXTERNAL_CONFORMANCE_FAILURE_BUDGET:-0}"
NORMALIZATION="${RHOE_MARKDOWN_EXTERNAL_CONFORMANCE_NORMALIZATION:-semantic}"

if [[ ! -f "${COMMONMARK_FIXTURES}" || ! -f "${GFM_FIXTURES}" ]]; then
  echo "External conformance fixtures are missing." >&2
  echo "Run: bash Scripts/CI/fetch-external-conformance.sh" >&2
  exit 1
fi

swift build --product rhoemd

BIN=".build/debug/rhoemd"
if [[ ! -x "${BIN}" ]]; then
  echo "rhoemd binary missing after build: ${BIN}" >&2
  exit 1
fi

python3 Scripts/CI/run-external-conformance.py \
  --suite commonmark \
  --fixtures "${COMMONMARK_FIXTURES}" \
  --binary "${BIN}" \
  --flavor strict \
  --normalization "${NORMALIZATION}" \
  --failure-budget "${FAILURE_BUDGET}" \
  --report "${REPORT_ROOT}/commonmark.json"

python3 Scripts/CI/run-external-conformance.py \
  --suite gfm \
  --fixtures "${GFM_FIXTURES}" \
  --binary "${BIN}" \
  --flavor github \
  --normalization "${NORMALIZATION}" \
  --failure-budget "${FAILURE_BUDGET}" \
  --report "${REPORT_ROOT}/gfm.json"

echo "EXTERNAL_CONFORMANCE PASS"
