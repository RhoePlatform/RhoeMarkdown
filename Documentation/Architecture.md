# Public Architecture

RhoeMarkdown is staged as a compiler-focused public package. The repository
keeps the semantic Markdown engine, command-line compiler, server support,
project-build substrate, WebAssembly surface, documentation, and release tooling
together so contributors can validate the complete foundation release locally.

## Layers

- `RhoeMarkdownModel`: document model, metadata, diagnostics, and AST types.
- `RhoeMarkdownParsing`: Markdown and Rhoe syntax parsing.
- `RhoeDSLParsing`: structured DSL conversion support.
- `RhoeMarkdownRendering`: HTML, resources, icons, emoji, and writer support.
- `RhoeMarkdownPresentation`: slide, grid, shape, and presentation projections.
- `RhoeMarkdownKit`: public parse/render umbrella.
- `RhoeMDCore`, `RhoeMDServer`, `rhoemd`: CLI and preview/service substrate.
- `RhoeMarkdownWasm`: WebAssembly-facing compiler API.

## Deferred Lanes

SwiftUI preview components, design-kit helpers, and premium studio applications
are intentionally deferred so the first public release is easy to audit,
consume, and package.
