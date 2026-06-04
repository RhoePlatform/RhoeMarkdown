#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

COMMONMARK_VERSION="0.31.2"
COMMONMARK_REF="9103e341a973013013bb1a80e13567007c5cef6f"
COMMONMARK_SHA256="257c41ad946f7a1414a499aca402a1aa8fdac3678532266611348c1cf54f4b80"
COMMONMARK_URL="https://raw.githubusercontent.com/commonmark/commonmark-spec/${COMMONMARK_REF}/spec.txt"

GFM_VERSION="0.29.0.gfm.13"
GFM_REF="587a12bb54d95ac37241377e6ddc93ea0e45439b"
GFM_SHA256="7d8e5814befec287ac116786d81ff14e0adc9b13295b4494649e995408fd871c"
GFM_URL="https://raw.githubusercontent.com/github/cmark-gfm/${GFM_REF}/test/spec.txt"

TMP_ROOT="${TMPDIR:-/tmp}/rhoemarkdown-external-conformance"
mkdir -p "${TMP_ROOT}"

download_and_verify() {
  local label="$1"
  local url="$2"
  local expected_sha="$3"
  local output="$4"

  curl -fsSL "${url}" -o "${output}"
  local actual_sha
  actual_sha="$(shasum -a 256 "${output}" | awk '{print $1}')"
  if [[ "${actual_sha}" != "${expected_sha}" ]]; then
    echo "${label}: SHA-256 mismatch" >&2
    echo "expected: ${expected_sha}" >&2
    echo "actual:   ${actual_sha}" >&2
    exit 1
  fi
}

COMMONMARK_SPEC="${TMP_ROOT}/commonmark-${COMMONMARK_VERSION}-spec.txt"
GFM_SPEC="${TMP_ROOT}/gfm-${GFM_VERSION}-spec.txt"

download_and_verify "CommonMark ${COMMONMARK_VERSION}" "${COMMONMARK_URL}" "${COMMONMARK_SHA256}" "${COMMONMARK_SPEC}"
download_and_verify "GitHub Flavored Markdown ${GFM_VERSION}" "${GFM_URL}" "${GFM_SHA256}" "${GFM_SPEC}"

python3 Scripts/CI/extract-markdown-spec-tests.py \
  --input "${COMMONMARK_SPEC}" \
  --output Tests/ExternalConformance/commonmark/spec.json \
  --suite commonmark \
  --suite-version "${COMMONMARK_VERSION}" \
  --upstream-ref "${COMMONMARK_REF}" \
  --upstream-url "${COMMONMARK_URL}"

python3 Scripts/CI/extract-markdown-spec-tests.py \
  --input "${GFM_SPEC}" \
  --output Tests/ExternalConformance/gfm/spec.json \
  --suite gfm \
  --suite-version "${GFM_VERSION}" \
  --upstream-ref "${GFM_REF}" \
  --upstream-url "${GFM_URL}"

cat > Tests/ExternalConformance/README.md <<'README'
# External Markdown Conformance Fixtures

This directory contains generated JSON fixtures extracted from pinned upstream
CommonMark and GitHub Flavored Markdown specifications.

Regenerate them with:

```bash
bash Scripts/CI/fetch-external-conformance.sh
```

The fetch script verifies immutable upstream refs and SHA-256 checksums before
rewriting the generated JSON files. License and attribution notes live in
`THIRD_PARTY_NOTICES.md`.
README

echo "EXTERNAL_CONFORMANCE_FETCH PASS"
