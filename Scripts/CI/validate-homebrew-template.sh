#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

formula="Packaging/Homebrew/rhoe-markdown.rb.template"

if [[ ! -s "${formula}" ]]; then
  echo "Missing Homebrew formula template: ${formula}" >&2
  exit 1
fi

required=(
  "class RhoeMarkdown < Formula"
  "version \"0.1.0\""
  "license \"Apache-2.0\""
  "rhoemd"
  "__ARM64_TAHOE_SHA256__"
  "__X86_64_LINUX_SHA256__"
)

for needle in "${required[@]}"; do
  if ! grep -Fq "${needle}" "${formula}"; then
    echo "Homebrew formula template missing: ${needle}" >&2
    exit 1
  fi
done

echo "HOMEBREW_TEMPLATE_VALIDATION PASS"
