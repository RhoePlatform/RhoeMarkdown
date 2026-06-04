# RhoeMarkdown

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](Package.swift)
[![Release](https://img.shields.io/badge/release-0.1.0-green.svg)](CHANGELOG.md)

RhoeMarkdown is the public Swift compiler engine for semantic Markdown in the
RhoePlatform ecosystem. It parses author-friendly Markdown into a structured
document model and renders it to HTML, LaTeX, Typst, DOCX, PDF, EPUB, JSON API
payloads, presentation artifacts, and WebAssembly-facing projections.

This repository is staged as the Apache 2.0 public foundation release for the
compiler package. SwiftUI preview apps and premium studio applications remain
separate lanes.

## Why RhoeMarkdown?

- **Plain text in, structured documents out**: keep authoring lightweight while
  preserving a rich AST for downstream tools.
- **Projection-ready compiler core**: parse once, render to many surfaces, and
  preserve semantic metadata for editors and publishing systems.
- **Liquid preprocessing built in**: use RhoeLiquid `0.1.0` for variables,
  conditionals, and repeatable document generation before Markdown parsing.
- **Serious document formats**: generate HTML, LaTeX, Typst, DOCX, PDF, EPUB,
  JSON API payloads, slides, and project outputs from one compiler pipeline.
- **Contributor-friendly by design**: CI gates, DocC docs, examples, Homebrew
  release templates, and explicit compatibility notes live in the repo.

## Install

Add RhoeMarkdown to a Swift package:

```swift
dependencies: [
    .package(url: "https://github.com/RhoePlatform/RhoeMarkdown.git", from: "0.1.0")
]
```

Use the compiler library:

```swift
import RhoeMarkdownKit

let html = await RhoeMarkdownKit.toHTML("""
# Hello, RhoeMarkdown

This is **semantic Markdown** with a generated HTML projection.
""")
```

Build the CLI from source:

```bash
swift build -c release --product rhoemd
./.build/release/rhoemd --version
```

Build the CLI for Linux:

```bash
RHOE_MARKDOWN_LINUX_MODE=native bash Scripts/CI/build-linux-cli.sh
bash Scripts/CI/build-linux-cli.sh # Static Linux SDK build
RHOE_MARKDOWN_LINUX_SDK_ID=swift-6.3.2-RELEASE_static-linux-0.1.0 \
  swiftly run bash Scripts/CI/build-linux-cli.sh +6.3.2
```

Build the WebAssembly library target:

```bash
bash Scripts/CI/build-wasm.sh
swiftly run bash Scripts/CI/build-wasm.sh +6.3.0
```

## CLI Quick Start

Render a Markdown file to HTML:

```bash
rhoemd Examples/sources/research-note.md -o Examples/outputs/research-note.html --format html --css
```

Render to Typst:

```bash
rhoemd Examples/sources/typst-paper.md -o Examples/outputs/typst-paper.typ --format typst
```

Build all checked-in examples:

```bash
bash Examples/render-all.sh
```

## Package Surface

The first public release exposes the compiler-focused surface:

- `RhoeMarkdownKit`: public parse/render umbrella.
- `RhoeMarkdownWasm`: WebAssembly-facing parse/render API.
- `RhoeMDCore`: reusable CLI core.
- `RhoeMDServer`: preview and service support.
- `RhoeProjectKitCore`: project-build substrate required by `rhoemd`.
- `rhoemd`: command-line compiler.

Deferred to later lanes:

- SwiftUI/native preview products.
- Design-kit utilities.
- Premium studio applications.

## Documentation

- DocC catalog: `Sources/RhoeMarkdownKit/Documentation.docc`
- Contributor docs: `Documentation/`
- Examples gallery: `Examples/`
- External CommonMark/GFM conformance: `Documentation/Release/ExternalConformance.md`
- Linux CLI readiness: `Documentation/Release/LinuxCLIReadiness.md`
- WebAssembly readiness: `Documentation/Release/WebAssemblyReadiness.md`
- Release process: `RELEASING.md`
- Security policy: `SECURITY.md`

Generate the DocC static site locally:

```bash
bash Scripts/CI/build-docc-pages.sh
```

## Maintainer Gates

Run the local release-readiness checks before opening a release PR:

```bash
swift package dump-package
swift build
swift build -c release --product rhoemd
swift test
bash Scripts/CI/validate-docs.sh
bash Scripts/CI/validate-examples.sh
bash Scripts/CI/validate-external-conformance.sh
bash Scripts/CI/verify-release-readiness.sh
```

To refresh and run the pinned external CommonMark/GFM conformance lane:

```bash
bash Scripts/CI/fetch-external-conformance.sh
bash Scripts/CI/validate-external-conformance.sh
```

To include the optional Linux CLI gate locally, run:

```bash
RHOE_MARKDOWN_VALIDATE_LINUX_CLI=1 bash Scripts/CI/verify-release-readiness.sh
```

To include the optional WebAssembly gate locally, run:

```bash
RHOE_MARKDOWN_VALIDATE_WASM=1 bash Scripts/CI/verify-release-readiness.sh
```

If the active Xcode Swift toolchain does not provide WASI target support, run
the gate through the matching Swiftly toolchain shown above.

The staged repo intentionally remains non-git until the first public foundation
release candidate passes these checks.

## Homebrew

The Homebrew formula template lives in `Packaging/Homebrew/`. Publication is
deferred until the clean initial commit, `v0.1.0` tag, and release audit are
complete. Bottle publication will use the RhoePlatform tap:

```bash
brew tap RhoePlatform/rhoe
brew install rhoe-markdown
```

## License

RhoeMarkdown is released under the Apache License, Version 2.0. See `LICENSE`
and `NOTICE` for details.
