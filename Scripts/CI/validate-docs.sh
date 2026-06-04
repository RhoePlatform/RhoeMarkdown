#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

required=(
  README.md
  CHANGELOG.md
  GOVERNANCE.md
  SECURITY.md
  RELEASING.md
  Documentation/README.md
  Documentation/Architecture.md
  Documentation/CLI/README.md
  Documentation/LanguageReference/README.md
  Documentation/LanguageReference/rhoemarkdown-language-surface.json
  Documentation/Release/ExternalConformance.md
  Sources/RhoeMarkdownKit/Documentation.docc/RhoeMarkdownKit.md
  Sources/RhoeMarkdownKit/Documentation.docc/LanguageReference/LanguageOverview.md
  Sources/RhoeMarkdownKit/Documentation.docc/LanguageReference/SyntaxReference.md
  Sources/RhoeMarkdownKit/Documentation.docc/LanguageReference/Block.md
  Sources/RhoeMarkdownKit/Documentation.docc/LanguageReference/Inline.md
  Sources/RhoeMarkdownKit/Documentation.docc/LanguageReference/CompatibilityAndDeferred.md
)

for file in "${required[@]}"; do
  if [[ ! -s "${file}" ]]; then
    echo "Missing required documentation file: ${file}" >&2
    exit 1
  fi
done

if rg -n "RhoeSwiftUIKit|RhoePreview|RhoeDesignKit" README.md Documentation Sources/RhoeMarkdownKit/Documentation.docc; then
  echo "Deferred UI/app lane referenced from public docs." >&2
  exit 1
fi

echo "DOCS_VALIDATION PASS"
