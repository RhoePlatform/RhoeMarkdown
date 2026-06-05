# Linux CLI Readiness

`RhoeMarkdown` treats the `rhoemd` executable as the first official Linux build
target. The Linux lane is intentionally scoped to the command-line compiler
surface: Markdown parsing, Liquid preprocessing, rendering, project validation,
and source-to-output compilation from the SwiftPM product graph.

## Target

| Field | Value |
| --- | --- |
| Product | `rhoemd` |
| Native gate | `RHOE_MARKDOWN_LINUX_MODE=native bash Scripts/CI/build-linux-cli.sh` |
| Static SDK gate | `bash Scripts/CI/build-linux-cli.sh` |
| Default Swift SDK selector | `x86_64-swift-linux-musl` |
| Default static triple | `x86_64-swift-linux-musl` |
| Default configuration | `release` |

The static target follows Swift's Static Linux SDK model: install a matching
swift.org or Xcode toolchain and a Static Linux SDK artifact, then build the CLI
as a statically linked Linux executable.

## Current Scope

- Supported: `rhoemd` single-file compilation, HTML/LaTeX/Typst/DOCX/PDF/EPUB
  output selection, Liquid preprocessing through `RhoeLiquid`, project build
  helpers, and CLI version/help flows.
- Portable: parser SIMD scanning, mmap-backed file reading, and logging now guard
  Darwin, Musl, Glibc, and OSLog availability explicitly.
- Conditional: live preview/server behavior depends on the active Swift/Linux
  dependency graph and remains validated through the full `rhoemd` product build.
- Excluded from this target: the macOS-only `rhoemd-preview-menu` MenuBarExtra,
  SwiftUI/native preview applications, app-extension surfaces, DocC rendering
  itself, and Homebrew bottle publication.

## Local Verification

Run the native host/Linux gate:

```bash
RHOE_MARKDOWN_LINUX_MODE=native bash Scripts/CI/build-linux-cli.sh
```

Run the static Linux gate:

```bash
bash Scripts/CI/build-linux-cli.sh
```

Override the selected Static Linux SDK selector or target triple:

```bash
RHOE_MARKDOWN_LINUX_SDK_ID=x86_64-swift-linux-musl \
RHOE_MARKDOWN_LINUX_TRIPLE=x86_64-swift-linux-musl \
bash Scripts/CI/build-linux-cli.sh
```

Some Swift installations list the installed artifact bundle as an SDK ID such
as `swift-6.3.2-RELEASE_static-linux-0.1.0`. When the target-triple selector is
available, prefer `x86_64-swift-linux-musl`; otherwise use the concrete SDK ID
and run the build with the matching Swiftly toolchain:

```bash
RHOE_MARKDOWN_LINUX_SDK_ID=swift-6.3.2-RELEASE_static-linux-0.1.0 \
swiftly run bash Scripts/CI/build-linux-cli.sh +6.3.2
```

Enable Linux certification as part of local release readiness:

```bash
RHOE_MARKDOWN_VALIDATE_LINUX_CLI=1 bash Scripts/CI/verify-release-readiness.sh
```

If no Static Linux SDK is installed, the script exits with code `78` and prints
installation guidance. If the SDK is installed but does not match the active
Swift compiler, the script reports `STATIC_LINUX_TOOLCHAIN_MISMATCH`; install an
SDK artifact built for the exact active Swift toolchain before treating the
failure as a source regression.
