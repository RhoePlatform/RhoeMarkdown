#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

MODE="${RHOE_MARKDOWN_LINUX_MODE:-static}"
CONFIGURATION="${RHOE_MARKDOWN_LINUX_CONFIGURATION:-release}"
SDK_ID="${RHOE_MARKDOWN_LINUX_SDK_ID:-x86_64-swift-linux-musl}"
TARGET_TRIPLE="${RHOE_MARKDOWN_LINUX_TRIPLE:-x86_64-swift-linux-musl}"
SWIFTLY_TOOLCHAIN="${RHOE_MARKDOWN_LINUX_SWIFTLY_TOOLCHAIN:-}"
SWIFTLY_BIN="${RHOE_MARKDOWN_SWIFTLY_BIN:-}"

if [[ -z "${SWIFTLY_BIN}" ]]; then
  if command -v swiftly >/dev/null 2>&1; then
    SWIFTLY_BIN="$(command -v swiftly)"
  elif [[ -x "/opt/homebrew/bin/swiftly" ]]; then
    SWIFTLY_BIN="/opt/homebrew/bin/swiftly"
  fi
fi

if [[ -n "${SWIFTLY_TOOLCHAIN}" && -z "${RHOE_MARKDOWN_LINUX_SWIFTLY_REEXEC:-}" ]]; then
  if [[ -z "${SWIFTLY_BIN}" ]]; then
    echo "STATIC_LINUX_SWIFTLY_MISSING ${SWIFTLY_TOOLCHAIN}" >&2
    echo "Install swiftly or unset RHOE_MARKDOWN_LINUX_SWIFTLY_TOOLCHAIN to use the active swift binary." >&2
    exit 78
  fi

  export RHOE_MARKDOWN_LINUX_SWIFTLY_REEXEC=1
  exec "${SWIFTLY_BIN}" run bash "${BASH_SOURCE[0]}" "${SWIFTLY_TOOLCHAIN}"
fi

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
