#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

echo "==> public hygiene: forbidden files"
for path in .build Package.resolved .DS_Store; do
  if [[ -e "${path}" ]]; then
    echo "Forbidden staging artifact present: ${path}" >&2
    exit 1
  fi
done

if [[ "${RHOE_MARKDOWN_REQUIRE_NON_GIT_STAGING:-0}" == "1" && -e .git ]]; then
  echo "Forbidden pre-git staging artifact present: .git" >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
root_names = {path.name for path in Path(".").iterdir() if path.is_dir()}
if "scripts" in root_names:
    raise SystemExit("Forbidden lowercase duplicate script directory: scripts")
PY

echo "==> public hygiene: stale private identity"
if rg -n "RhoeMarkdownEngine|RhoeLiquidEngine|/Users/thorfuchs|0\\.0\\.0-internal|RhoeAI" . --glob '!Scripts/CI/validate-public-release.sh'; then
  echo "Forbidden private/stale identity reference found." >&2
  exit 1
fi

echo "==> public hygiene: stale public language versions"
if rg -n "v3\\.3|v3\\.1|v4\\.0|4\\.0\\.0-wasm|v0\\.51|RhoeLanguageSpec" README.md Documentation Sources .github Scripts --glob '!Sources/RhoeMarkdownRendering/Resources/**' --glob '!Scripts/CI/validate-public-release.sh' --glob '!Scripts/CI/validate-language-reference.sh'; then
  echo "Forbidden stale public language/version reference found." >&2
  exit 1
fi

echo "==> public hygiene: license drift"
if rg -n "MIT License\\. See \\[LICENSE\\]|license: MIT|License\\*\\*: MIT" README.md Documentation Package.swift .github; then
  echo "Forbidden MIT project-license drift found in public-facing files." >&2
  exit 1
fi

echo "PUBLIC_RELEASE_HYGIENE PASS"
