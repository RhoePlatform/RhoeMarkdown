#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

SDK_ID="${RHOE_MARKDOWN_WASM_SDK_ID:-swift-6.3-RELEASE_wasm}"
CONFIGURATION="${RHOE_MARKDOWN_WASM_CONFIGURATION:-release}"
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
