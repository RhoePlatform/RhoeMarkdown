---
title: "Compact Compiler Notes"
author: "RhoePlatform"
status: "example"
---

> Run: `rhoemd Examples/sources/typst-paper.md -o Examples/outputs/typst-paper.typ --format typst`

# Compact Compiler Notes {#compiler-notes}

## Abstract

RhoeMarkdown demonstrates how a plain-text document can become a structured
compiler input without losing readability for human authors. This example is
rendered to Typst so users can inspect the publication-oriented output.

## Method

The pipeline separates parsing, normalization, rendering, and projection. This
makes it possible to add output targets without changing the authoring surface.

!!! theorem "Renderer Independence" {#thm-renderer-independence}
If two renderers consume the same normalized document, any output-specific
differences should be local to the writer, not the authoring syntax.
!!!

The result follows directly from @thm-renderer-independence and the compiler
contract documented in the public API.

## Result

| Target | Use case | Artifact |
| --- | --- | --- |
| HTML | review and web publishing | `.html` |
| Typst | modern publication pipelines | `.typ` |
| LaTeX | academic publishing | `.tex` |
| WASM | editor and browser integrations | `.wasm` |

Inline math remains readable: $quality = structure / ceremony$.

## Citation Note

The source can carry citations such as [@rhoe2026] without forcing authors to
leave Markdown while drafting.
