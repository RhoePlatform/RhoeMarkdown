# WebAssembly Target

Compile the Rhoe markdown engine to WebAssembly for browser, edge, and platform-independent use.

## Overview

The `RhoeMarkdownWasm` library provides a Wasm-compatible subset of the Rhoe engine, enabling markdown parsing and multi-format rendering in any WebAssembly runtime. This includes browsers, Cloudflare Workers, Deno, Node.js (via WASI), and standalone Wasm runtimes like WasmKit and Wasmtime.

The Wasm target delivers the parsing pipeline with GFM and RhoeMarkdown extensions plus HTML, LaTeX, Typst, and RhoeJSON serialization helpers. Platform-specific features remain native-only: PDF generation, external tool invocation, archive generation, and filesystem-backed transclusion.

## Building for WebAssembly

### Prerequisites

Install Swift 6.3+ and the Wasm SDK:

```bash
swiftly install 6.3
swiftly use 6.3
swift sdk install swift-6.3-RELEASE_wasm
```

### Compilation

```bash
swift build --swift-sdk swift-6.3-RELEASE_wasm --target RhoeMarkdownWasm
```

The repo also includes a maintainer helper:

```bash
bash Scripts/CI/build-wasm.sh
```

If the helper reports `WASM_TOOLCHAIN_MISMATCH`, the SDK is installed but was
built for a different Swift compiler than the active shell. Select the matching
Swift toolchain or reinstall the Wasm SDK for the active compiler before treating
the failure as a source regression.

The compiled `.wasm` module is located at `.build/wasm32-unknown-wasip1/debug/`.

### Running with WasmKit

Swift 6.3 includes WasmKit as a built-in runtime. For executable targets that depend on `RhoeMarkdownWasm`:

```bash
swift run --swift-sdk swift-6.3-RELEASE_wasm MyWasmApp
```

## API Reference

The `RhoeMarkdownWasm` facade provides a streamlined API matching the native ``RhoeMarkdownKit`` surface:

### Parse

```swift
let result = await RhoeMarkdownWasm.parse(markdown)
let document = result.document
let diagnostics = result.diagnostics
```

### Convenience (Parse + Render)

```swift
let html = await RhoeMarkdownWasm.toHTML("# Hello from WebAssembly!")
let latex = await RhoeMarkdownWasm.toLaTeX("**Bold** and *italic*")
let typst = await RhoeMarkdownWasm.toTypst("- List item")
let json = await RhoeMarkdownWasm.toJSON("[@smith2024]")
```

### Two-Stage (Document + Render)

```swift
let result = await RhoeMarkdownWasm.parse(markdown, configuration: .default)
let html = RhoeMarkdownWasm.renderHTML(result.document)
let latex = RhoeMarkdownWasm.renderLaTeX(result.document)
let typst = RhoeMarkdownWasm.renderTypst(result.document)
let json = RhoeMarkdownWasm.renderJSON(result.document)
```

### Phase 1 Liquid Preprocessing

The Wasm target includes full Liquid template preprocessing via RhoeLiquid, enabling dynamic document generation in the browser:

```swift
// Template with variables and control flow
let html = await RhoeMarkdownWasm.toHTMLWithLiquid(
    """
    ---
    title: {{ site_name }}
    ---
    # {{ title }}

    {% for section in sections %}
    ## {{ section.heading }}
    {{ section.content }}
    {% endfor %}
    """,
    context: [
        "site_name": "My Site",
        "title": "Welcome",
        "sections": [
            ["heading": "Getting Started", "content": "Install the package."],
            ["heading": "Usage", "content": "Import and call the API."]
        ]
    ]
)
```

Available Liquid methods: `parseWithLiquid`, `toHTMLWithLiquid`, `toLaTeXWithLiquid`, `toTypstWithLiquid`, `toJSONWithLiquid`.

## Feature Matrix

| Capability | Wasm | Native |
|-----------|------|--------|
| GFM parsing (tables, task lists, strikethrough) | Yes | Yes |
| Rhoe extensions (admonitions, citations, cross-refs) | Yes | Yes |
| Semantic blocks (!!!) and visual blocks (:::) | Yes | Yes |
| Composition directives (include, schema, annotations) | Yes | Yes |
| Phase 2 semantic transforms ({@ @}) | Yes | Yes |
| Section hierarchy normalization | Yes | Yes |
| Six-bucket attribute model | Yes | Yes |
| All 52 canonical node kinds | Yes | Yes |
| 10-stage processing pipeline | Stages 0-9 (except diagrams) | All 10 |
| HTML rendering (complete with CSS) | Yes | Yes |
| LaTeX string output | Yes | Yes |
| Typst string output | Yes | Yes |
| RhoeJSON serialization | Yes | Yes |
| PDF generation (WebKit / Typst / LaTeX) | No | Yes |
| EPUB generation | No | Yes |
| DOCX generation | No | Yes |
| Diagram rendering (Mermaid, Graphviz, D2) | No | Yes |
| Phase 1 Liquid preprocessing | Yes (via RhoeLiquid) | Yes |
| File-based transclusion | No | Yes |
| Icon/emoji SVG bundle loading | No | Yes |
| Instruments signpost profiling | No | Yes |

## Architecture

### Module Dependencies

```
RhoeMarkdownWasm
  |-- RhoeMarkdownModel       (AST, visitor protocols, attributes)
  |-- RhoeMarkdownParsing     (lexer, parser, 40 extension files)
  |-- RhoeMarkdownRendering   (HTML, LaTeX, Typst, JSON writers)
  |-- RhoeLiquid              (Liquid template engine for Phase 1)
```

The Wasm target depends on the three core modules plus RhoeLiquid for Phase 1 Liquid preprocessing. It does not depend on `RhoeMarkdownKit` (which additionally pulls in `RhoeMarkdownPresentation` and `RhoeDSLParsing`), keeping the Wasm binary focused.

### Platform Compilation Guards

Platform-specific code is guarded using standard Swift conditional compilation:

```swift
// Dispatch-dependent code (threading, queues)
#if canImport(Dispatch)
private let queue = DispatchQueue(label: "profiler")
#endif

// Apple-only instrumentation
#if canImport(os)
import os.signpost
#endif

// File I/O and process execution
#if !os(WASI)
import Darwin
// ... FileHandle, Process, mmap usage ...
#endif

// SwiftUI (UI framework)
#if canImport(SwiftUI)
import SwiftUI
#endif
```

When Wasm detects these guards, it compiles the `#else` branch which either provides a no-op stub or omits the feature entirely. The core parsing and rendering paths contain no platform-specific code.

### Why Not Full Feature Parity?

Three categories of features cannot compile to Wasm:

1. **External process execution** — PDF generation shells out to `typst`, `pdflatex`, or WebKit. EPUB and DOCX use `/usr/bin/zip`. Diagram rendering invokes `mmdc`, `dot`, etc. Wasm cannot launch subprocesses.

2. **Platform frameworks** — WebKit (`WKWebView`) is macOS/iOS only. `os.signpost` requires Apple's Instruments infrastructure. These have no Wasm equivalent.

3. **Resource bundles** — Icon and emoji SVG assets load from `Bundle.module` at runtime. Wasm has no bundle mechanism (future: embedded resources or fetch from URL).

## Adding New Features

When adding new features to the engine, follow these guidelines for Wasm compatibility:

1. **Default to Wasm-safe code.** Use Foundation types that work everywhere (`String`, `Data`, `Date`, `UUID`, `JSONSerialization`).

2. **Guard platform APIs.** If you must use `Process`, `DispatchQueue`, `NSLock`, `Bundle.module`, `WKWebView`, or `os.signpost`, wrap in `#if !os(WASI)` or `#if canImport(...)`.

3. **Provide fallbacks.** For guarded code, provide a Wasm-safe alternative in the `#else` branch (no-op, direct inline, or feature-disabled stub).

4. **Test both targets.** After changes, verify with:
   ```bash
   swift build                                                          # Native
   swift build --swift-sdk swift-6.3-RELEASE_wasm --target RhoeMarkdownWasm  # Wasm
   swift test                                                           # Native tests
   ```

5. **Prefer `Date().timeIntervalSinceReferenceDate`** over `CFAbsoluteTimeGetCurrent()` for timing (the latter is Darwin-only).
