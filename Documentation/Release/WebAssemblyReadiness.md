# WebAssembly Readiness

`RhoeMarkdownWasm` is the browser/editor-facing compilation target for the
public package. The `0.1.0` release gate validates that the target compiles with
Swift's WASI SDK; JavaScript packaging and npm publication are deferred to a
later lane.

## Target

| Field | Value |
| --- | --- |
| Target | `RhoeMarkdownWasm` |
| Gate | `bash Scripts/CI/build-wasm.sh` |
| Default Swift SDK selector | `swift-6.3-RELEASE_wasm` |
| Default configuration | `release` |

The build script passes the WASI emulation flags required by
Foundation/CoreFoundation when transitive dependencies import those modules:
`_WASI_EMULATED_SIGNAL`, `wasi-emulated-signal`, `_WASI_EMULATED_MMAN`, and
`wasi-emulated-mman`.

## Local Verification

Run the WASM gate with the active Swift toolchain:

```bash
bash Scripts/CI/build-wasm.sh
```

When using Swiftly, select the toolchain that matches the installed WASM SDK:

```bash
swiftly run bash Scripts/CI/build-wasm.sh +6.3.0
```

Enable WASM certification as part of local release readiness:

```bash
RHOE_MARKDOWN_VALIDATE_WASM=1 bash Scripts/CI/verify-release-readiness.sh
```

If the SDK is missing, the script exits with code `78` and prints installation
guidance. If the active compiler does not support the WASI target, rerun through
the matching Swiftly toolchain before treating the failure as a source
regression.
