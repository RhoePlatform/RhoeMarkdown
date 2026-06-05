#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

SDK_ID="${RHOE_MARKDOWN_WASM_SDK_ID:-swift-6.3-RELEASE_wasm}"
CONFIGURATION="${RHOE_MARKDOWN_WASM_CONFIGURATION:-release}"
SWIFTLY_TOOLCHAIN="${RHOE_MARKDOWN_WASM_SWIFTLY_TOOLCHAIN:-}"
SWIFTLY_BIN="${RHOE_MARKDOWN_SWIFTLY_BIN:-}"

if [[ -z "${SWIFTLY_BIN}" ]]; then
  if command -v swiftly >/dev/null 2>&1; then
    SWIFTLY_BIN="$(command -v swiftly)"
  elif [[ -x "/opt/homebrew/bin/swiftly" ]]; then
    SWIFTLY_BIN="/opt/homebrew/bin/swiftly"
  fi
fi

if [[ -z "${SWIFTLY_TOOLCHAIN}" ]] && swift --version 2>/dev/null | grep -q "Apple Swift"; then
  if [[ -n "${SWIFTLY_BIN}" ]]; then
    SWIFTLY_TOOLCHAIN="+6.3.0"
  fi
fi

if [[ -n "${SWIFTLY_TOOLCHAIN}" && -z "${RHOE_MARKDOWN_WASM_SWIFTLY_REEXEC:-}" ]]; then
  if [[ -z "${SWIFTLY_BIN}" ]]; then
    echo "WASM_SWIFTLY_MISSING ${SWIFTLY_TOOLCHAIN}" >&2
    echo "Install swiftly or unset RHOE_MARKDOWN_WASM_SWIFTLY_TOOLCHAIN to use the active swift binary." >&2
    exit 78
  fi

  export RHOE_MARKDOWN_WASM_SWIFTLY_REEXEC=1
  exec "${SWIFTLY_BIN}" run bash "${BASH_SOURCE[0]}" "${SWIFTLY_TOOLCHAIN}"
fi

# Foundation/CoreFoundation transitively require these WASI shim libraries.
WASI_EMULATION_FLAGS=(
  -Xcc -D_WASI_EMULATED_SIGNAL
  -Xlinker -lwasi-emulated-signal
  -Xcc -D_WASI_EMULATED_MMAN
  -Xlinker -lwasi-emulated-mman
)

if ! swift sdk list 2>/dev/null | grep -q "${SDK_ID}"; then
  echo "WASM_SDK_MISSING ${SDK_ID}" >&2
  echo "Install the Swift WebAssembly SDK, then rerun:" >&2
  echo "RHOE_MARKDOWN_WASM_SDK_ID=${SDK_ID} bash Scripts/CI/build-wasm.sh" >&2
  exit 78
fi

if ! swift build \
  --swift-sdk "${SDK_ID}" \
  -c "${CONFIGURATION}" \
  --target RhoeMarkdownWasm \
  "${WASI_EMULATION_FLAGS[@]}"; then
  echo "WASM_TOOLCHAIN_MISMATCH or source build failure for SDK ${SDK_ID}" >&2
  exit 1
fi

echo "WASM_BUILD PASS ${SDK_ID}"
