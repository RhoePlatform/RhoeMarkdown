---
title: "RhoeMarkdown 0.1.0 Release Candidate"
author: "RhoePlatform"
status: "example"
---

> Run: `rhoemd Examples/sources/release-note.md -o Examples/outputs/release-note.html --format html --css --pretty`

# RhoeMarkdown 0.1.0 Release Candidate {#release-note}

RhoeMarkdown is now staged as a public Apache 2.0 compiler package.

!!! success "Release posture"
The public repo is designed to feel useful on day one: CLI, examples,
documentation, language reference, cross-build scripts, and release templates
travel together.
!!!

## Highlights

- Compiler-focused Swift package surface.
- `rhoemd` CLI for local document generation.
- DocC documentation and example gallery.
- Linux and WebAssembly build routes.
- Homebrew packaging template for the release bridge.

## Compatibility Matrix

| Surface | Status | Notes |
| --- | --- | --- |
| macOS CLI | ready | primary development target |
| Static Linux CLI | ready | validated with Swiftly toolchain selection |
| WebAssembly target | ready | uses WASI emulation flags |
| PDF rendering | platform-dependent | Typst/LaTeX tools required |

## Try It

```bash
swift build -c release --product rhoemd
rhoemd Examples/sources/release-note.md -o Examples/outputs/release-note.html --format html --css --pretty
```

## Upgrade Signal

The release is still `0.1.0`, but the repo structure already behaves like a
maintainer-facing project: deterministic examples, drift checks, and clear
public docs.
