# Architecture

RhoeMarkdown is organized as a compiler package with narrow internal layers and
a small public surface. The first public release keeps implementation ownership
together while deferring native preview and studio application surfaces.

## Compiler Flow

```text
Markdown source
  -> Phase 1 Liquid preprocessing
  -> lexical scanning
  -> block and inline parsing
  -> semantic normalization
  -> projection filtering
  -> renderer or project target
```

## Target Responsibilities

| Target | Responsibility |
| --- | --- |
| `RhoeMarkdownModel` | document structures, diagnostics, metadata, and configuration |
| `RhoeMarkdownParsing` | Markdown lexer/parser implementation |
| `RhoeDSLParsing` | structured DSL conversion support |
| `RhoeMarkdownRendering` | HTML renderer, resource bundles, and writers |
| `RhoeMarkdownPresentation` | slide, grid, shape, and presentation projections |
| `RhoeMarkdownKit` | public parse/render facade |
| `RhoeProjectKitCore` | project graph and build support required by `rhoemd` |
| `RhoeMDCore` | command-line option handling and compile orchestration |
| `RhoeMDServer` | preview/service substrate |
| `RhoeMarkdownWasm` | browser-facing compiler API |

## Dependency Boundary

RhoeMarkdown depends on public RhoeLiquid `0.1.0` for Phase 1 template
preprocessing. The dependency is intentionally public and versioned so the
compiler package can be consumed independently from private platform repos.

## Deferred Surface

Native preview UI, design-kit utilities, and premium studio applications are not
part of this first public compiler package. They may become separate public or
premium lanes after the compiler release is certified.
