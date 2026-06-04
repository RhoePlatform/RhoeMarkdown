#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

MODE="${RHOE_MARKDOWN_LINUX_MODE:-static}"
CONFIGURATION="${RHOE_MARKDOWN_LINUX_CONFIGURATION:-release}"
SDK_ID="${RHOE_MARKDOWN_LINUX_SDK_ID:-x86_64-swift-linux-musl}"
TARGET_TRIPLE="${RHOE_MARKDOWN_LINUX_TRIPLE:-x86_64-swift-linux-musl}"

if [[ "${MODE}" == "native" ]]; then
  swift build -c "${CONFIGURATION}" --product rhoemd
  ".build/${CONFIGURATION}/rhoemd" --version
  echo "LINUX_CLI_BUILD PASS native"
  exit 0
fi

if ! swift sdk list 2>/dev/null | grep -q "${SDK_ID}"; then
  echo "STATIC_LINUX_SDK_MISSING ${SDK_ID}" >&2
  echo "Install a Swift Static Linux SDK, then rerun:" >&2
  echo "RHOE_MARKDOWN_LINUX_SDK_ID=${TARGET_TRIPLE} bash Scripts/CI/build-linux-cli.sh" >&2
  exit 78
fi

if ! swift build --swift-sdk "${SDK_ID}" -c "${CONFIGURATION}" --product rhoemd; then
  echo "STATIC_LINUX_TOOLCHAIN_MISMATCH or source build failure for SDK ${SDK_ID}" >&2
  exit 1
fi

echo "LINUX_CLI_BUILD PASS ${SDK_ID}"
