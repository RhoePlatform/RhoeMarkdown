# ``RhoeMarkdownKit``

Semantic Markdown parsing and multi-format rendering for Swift.

@Metadata {
    @TitleHeading("Welcome to")
    @PageKind(article)
    @Available(macOS, introduced: "26.0")
    @Available(iOS, introduced: "26.0")
    @Available(tvOS, introduced: "26.0")
    @Available(watchOS, introduced: "26.0")
    @Available(visionOS, introduced: "26.0")
}

## Overview

RhoeMarkdownKit turns Markdown into a structured document model and renders that
model into publication, web, project, and WebAssembly-facing projections. The
public `0.1.0` repository surface focuses on the compiler engine, `rhoemd` CLI,
server support, project-build substrate, and WebAssembly API.

```swift
import RhoeMarkdownKit

let html = await RhoeMarkdownKit.toHTML("""
# Hello, RhoeMarkdown

This is **semantic Markdown** with math, tables, admonitions, and structured
projection metadata.
""")
```

## Key Capabilities

- CommonMark/GFM-oriented parsing plus RhoeMarkdown extensions.
- HTML, LaTeX, Typst, DOCX, PDF, EPUB, and JSON API rendering surfaces.
- Slide, grid, shape, icon, math, and project-build projection support.
- Phase 1 Liquid preprocessing through public RhoeLiquid `0.1.1`.
- WebAssembly-facing compiler target for browser integrations.
- `rhoemd` command-line compiler and preview/service substrate.

## Package Layers

| Layer | Target | Role |
| --- | --- | --- |
| Model | `RhoeMarkdownModel` | AST, metadata, diagnostics, and configuration |
| Parsing | `RhoeMarkdownParsing` | Markdown lexer/parser implementation |
| DSL | `RhoeDSLParsing` | Structured syntax conversion support |
| Rendering | `RhoeMarkdownRendering` | HTML, resource, emoji, icon, and writer support |
| Presentation | `RhoeMarkdownPresentation` | Slides, grids, shapes, and presentation projections |
| Kit | `RhoeMarkdownKit` | Public parse/render umbrella |
| CLI | `RhoeMDCore`, `rhoemd` | Command-line compiler behavior |
| Server | `RhoeMDServer` | Preview/service support |
| Project | `RhoeProjectKitCore` | Project-build substrate used by the CLI |
| WebAssembly | `RhoeMarkdownWasm` | Browser-facing compiler API |

## Topics

### Getting Started

- <doc:GettingStarted>

### Language Reference

- <doc:LanguageOverview>
- <doc:SyntaxReference>
- <doc:Block>
- <doc:Inline>
- <doc:MathematicalRendering>
- <doc:IconLibraries>
- <doc:CustomExtensions>
- <doc:CompatibilityAndDeferred>

### Project Orchestration

- <doc:ProjectConfiguration>
- <doc:BuildingProjects>

### Presentations

- <doc:SlideSystem>
- <doc:GridLayouts>
- <doc:ShapeSystem>

### API

- <doc:APIReference>
- <doc:ExecutionAPI>
- <doc:ProjectAPI>

### Architecture

- <doc:LiquidPreprocessingGuide>
- <doc:SemanticTransformsGuide>
- <doc:Performance>
- <doc:Security>
- <doc:Testing>
- <doc:WebAssemblyTarget>

### Resources

- <doc:MigrationGuide>
- <doc:Troubleshooting>
