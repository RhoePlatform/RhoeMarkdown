#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

bash Scripts/CI/validate-public-release.sh
bash Scripts/CI/validate-docs.sh
bash Scripts/CI/validate-language-reference.sh
bash Scripts/CI/validate-homebrew-template.sh
swift package dump-package > /dev/null
swift build
if [[ "$(uname -s)" == "Darwin" ]]; then
    swift build --product rhoemd-preview-menu
else
    echo "PREVIEW_MENU_BUILD SKIP macOS-only MenuBarExtra target"
fi
swift build -c release --product rhoemd
swift test
bash Scripts/CI/validate-examples.sh
bash Scripts/CI/validate-external-conformance.sh

if [[ "${RHOE_MARKDOWN_VALIDATE_LINUX_CLI:-0}" == "1" ]]; then
    bash Scripts/CI/build-linux-cli.sh
else
    echo "LINUX_CLI_BUILD SKIP set RHOE_MARKDOWN_VALIDATE_LINUX_CLI=1 to run"
fi

if [[ "${RHOE_MARKDOWN_VALIDATE_WASM:-0}" == "1" ]]; then
    bash Scripts/CI/build-wasm.sh
else
    echo "WASM_BUILD SKIP set RHOE_MARKDOWN_VALIDATE_WASM=1 to run"
fi

echo "RELEASE_READINESS PASS"
