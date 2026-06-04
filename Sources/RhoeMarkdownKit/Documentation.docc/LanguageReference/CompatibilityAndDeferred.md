# Compatibility And Deferred Features

Release-status notes for RhoeMarkdown `0.1.0`.

## Overview

RhoeMarkdown is deliberately larger than plain Markdown, but public release quality depends on clarity: supported syntax should be easy to find, platform-specific behavior should be named, and deferred features should not look accidentally promised.

## Compatibility Posture

| Surface | Status | Notes |
| --- | --- | --- |
| CommonMark block and inline basics | Supported | Paragraphs, headings, lists, quotes, code, links, images, and thematic breaks. |
| GitHub Flavored Markdown | Supported | Tables, task lists, and strikethrough are part of the public compiler surface. |
| Pandoc-style attributes | Supported | Parsed into `Attributes(id:classes:keyValues:)`; exact renderer behavior varies by output. |
| Liquid preprocessing | Supported | Backed by public `RhoeLiquid 0.1.1`. |
| Semantic blocks | Supported | `!!!` admonitions, formal blocks, contracts, and semantic components. |
| Visual/layout blocks | Supported | `:::` containers, visual blocks, grids, columns, widgets, tabs, and modules. |
| Math | Supported | Inline/display math are preserved and rendered by format-specific writers. |
| Citations and cross-references | Supported | Parsed and normalized; bibliography formatting depends on available metadata. |
| Presentations | Supported | Slide boundaries and presentation AST surfaces are included in the compiler package. |
| Native CLI | Supported | `rhoemd` builds and renders from SwiftPM. |
| Linux CLI | Supported gate | Native Linux CI builds `rhoemd`; static Linux builds require a matching Swift Static Linux SDK. |
| WebAssembly | Supported subset | Parse/render API is present for browser and WASI-style integrations. |

## Native-Only In `0.1.0`

The following features depend on platform services or external tools and are not part of the current Wasm subset:

- PDF generation through platform or external typesetting pipelines.
- DOCX and EPUB archive generation.
- External diagram rendering through Mermaid, Graphviz, PlantUML, or D2 command-line tools.
- File-based transclusion.
- Bundle-backed icon and emoji asset loading.
- Instruments signpost profiling.

## Deferred Or Reserved

The following areas are intentionally not part of the first public guarantee:

- SwiftUI/native preview applications.
- Premium studio applications.
- Full source-preserving block-editor round trip.
- Online collaboration semantics.
- Package-manager publication of bottles before the release tag and checksum audit.
- JSON as a `rhoemd --format` CLI option; JSON serialization is available through API/Wasm surfaces instead.

## See Also

- <doc:LanguageOverview>
- <doc:SyntaxReference>
- <doc:WebAssemblyTarget>
- <doc:ProjectConfiguration>
