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

grep -Fq "markdown --version" README.md || {
  echo "README must document the markdown Homebrew alias." >&2
  exit 1
}

grep -Fq "Homebrew also" Documentation/CLI/README.md || {
  echo "CLI docs must document the markdown Homebrew alias." >&2
  exit 1
}

grep -Fq "Live Preview Daemon" Documentation/CLI/README.md || {
  echo "CLI docs must document the live preview daemon." >&2
  exit 1
}

grep -Fq "rhoemd preview" README.md || {
  echo "README must document the preview command." >&2
  exit 1
}

grep -Fq "Preview Daemon" Documentation/Architecture.md || {
  echo "Architecture docs must document the preview daemon." >&2
  exit 1
}

grep -Fq "rhoemd-preview-menu" README.md || {
  echo "README must document the macOS preview menu extra." >&2
  exit 1
}

grep -Fq "RHOEMD_PREVIEW_MENU=0" Documentation/CLI/README.md || {
  echo "CLI docs must document the preview menu opt-out environment variable." >&2
  exit 1
}

grep -Fq "Scripts/Packaging/build-preview-menu-app.sh" Documentation/Release/Homebrew.md || {
  echo "Homebrew docs must document the preview menu app bundle script." >&2
  exit 1
}

grep -Fq 'macOS-only `rhoemd-preview-menu`' Documentation/Release/LinuxCLIReadiness.md || {
  echo "Linux readiness docs must exclude the macOS preview menu extra." >&2
  exit 1
}

echo "DOCS_VALIDATION PASS"
