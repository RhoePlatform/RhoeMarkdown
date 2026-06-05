# Changelog

All notable changes to RhoeMarkdown are documented here.

## 0.1.1 - Preview control release

### Added

- macOS 26 `rhoemd-preview-menu` MenuBarExtra companion for the preview daemon.
- Shared preview daemon control endpoints for health, route listing, route removal, and shutdown.
- `PreviewDaemonControlClient` for menu, CLI, and automation tooling.
- Homebrew template support for installing `rhoemd`, `markdown`, and the macOS-only preview menu companion.

## 0.1.0 - Foundation release candidate

### Added

- Public Apache 2.0 staging surface for the RhoeMarkdown compiler package.
- `RhoeMarkdownKit` parser and multi-format rendering API.
- `rhoemd` command-line compiler for HTML, LaTeX, Typst, DOCX, PDF, EPUB, and JSON outputs.
- `RhoeMDServer` preview/service support and `RhoeMarkdownWasm` browser-facing API.
- Examples gallery, DocC documentation workflow, Homebrew formula template, and maintainer validation scripts.

### Deferred

- SwiftUI preview components, design-kit utilities, and premium studio applications remain outside the first public foundation release.
