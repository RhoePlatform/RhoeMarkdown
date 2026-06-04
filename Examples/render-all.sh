#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "${REPO_ROOT}"

OUTPUT_DIR="${RHOEMD_EXAMPLE_OUTPUT_DIR:-Examples/outputs}"
mkdir -p "$OUTPUT_DIR"

scripts=(
  "render-research-note.sh"
  "render-project-brief.sh"
  "render-slides-outline.sh"
  "render-typst-paper.sh"
  "render-release-note.sh"
  "render-language-showcase.sh"
  "render-architecture-rfc.sh"
  "render-data-report.sh"
  "render-onboarding-guide.sh"
  "render-component-playbook.sh"
)

for script in "${scripts[@]}"; do
  bash "Examples/$script"
done

echo
echo "Rendered RhoeMarkdown example gallery into $OUTPUT_DIR"
