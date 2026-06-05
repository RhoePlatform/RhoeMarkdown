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

## Preview Daemon

`rhoemd preview <file.md>` launches or reuses a shared localhost Hummingbird
daemon. The daemon registers one watched Markdown source per route, renders the
current HTML through `LivePreviewEngine`, serves each document at its assigned
URL path, and exposes lightweight health, route, and version endpoints for the
CLI and browser reload loop.

Route selection is intentionally CLI-native: in preview mode, `-o`/`--output`
is treated as a URL path or full local URL instead of a filesystem output path.
When two different source files request the same route, the daemon keeps the
first route and assigns fallback paths such as `.1` and `.2` to later
registrations.

The daemon also exposes route deletion and shutdown endpoints for local control
surfaces. `PreviewDaemonControlClient` is the shared Swift API used by the CLI,
tests, and macOS menu bar companion to query status, list watched files, stop a
route, stop the daemon, and restart the server without duplicating HTTP details.

## macOS Preview Menu

`rhoemd-preview-menu` is a macOS 26-only SwiftUI `MenuBarExtra` executable. It
is accessory-only by design, polls the daemon every two seconds, and provides
quick actions for opening preview URLs, revealing sources, copying routes,
stopping watched files, opening logs, and starting/stopping the shared daemon.
The CLI launches it automatically on macOS unless `--no-menu` or
`RHOEMD_PREVIEW_MENU=0` is set. Linux remains CLI-only.

## Deferred Lanes

SwiftUI preview components, design-kit helpers, and premium studio applications
are intentionally deferred so the first public release is easy to audit,
consume, and package.
