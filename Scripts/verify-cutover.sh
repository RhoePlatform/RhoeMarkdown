#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cleanup_generated_artifacts() {
  if [[ "${RHOE_MARKDOWN_KEEP_BUILD_ARTIFACTS:-0}" == "1" ]]; then
    return 0
  fi

  rm -rf "${REPO_ROOT}/.build"
  rm -f "${REPO_ROOT}/Package.resolved"
  rm -f "${REPO_ROOT}/.DS_Store"
}

cd "${REPO_ROOT}"

echo "==> preflight cleanup"
cleanup_generated_artifacts

echo
echo "==> public release hygiene"
bash Scripts/CI/validate-public-release.sh

echo
echo "==> release readiness"
bash Scripts/CI/verify-release-readiness.sh

echo
echo "==> source-only cleanup"
cleanup_generated_artifacts
bash Scripts/CI/validate-public-release.sh

echo
echo "RhoeMarkdown cutover verification passed."
