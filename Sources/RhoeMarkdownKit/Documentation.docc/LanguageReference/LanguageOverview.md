# RhoeMarkdown Language Reference

Authoritative reference for the public RhoeMarkdown `0.1.0` document language.

## Overview

RhoeMarkdown `0.1.0` is a semantic Markdown language for documents that need to stay readable as plain text while remaining precise enough for compilers, editors, publication systems, and WebAssembly runtimes. The language starts from CommonMark and GitHub Flavored Markdown, then adds RhoePlatform extensions for attributes, semantic containers, presentation structure, math, citations, Liquid preprocessing, and multi-format projection.

This reference describes the public compiler surface implemented by the staged `RhoeMarkdown` package. The companion RhoeLanguage repository defines the cross-format AST doctrine; this repository defines the concrete Markdown syntax accepted by the `rhoemd` compiler, Swift API, and `RhoeMarkdownWasm` facade.

## Compatibility Labels

Every feature belongs to one of the following public status categories:

| Label | Meaning |
| --- | --- |
| CommonMark | Baseline Markdown syntax shared with CommonMark-compatible processors. |
| GitHub Flavored Markdown | GFM-compatible extensions such as tables, task lists, and strikethrough. |
| RhoeMarkdown extension | Syntax owned by this compiler and documented here. |
| RhoePlatform projection | Syntax that preserves semantic metadata for downstream RhoePlatform tools. |
| Native only | Available in native Swift builds, but not in the current Wasm subset. |
| Wasm compatible | Available from `RhoeMarkdownWasm` without platform services. |
| Deferred | Reserved or planned surface that is intentionally not guaranteed in `0.1.0`. |

## Processing Pipeline

RhoeMarkdown uses one compiler pipeline. Each delimiter family belongs to one phase so authors can see what will happen before render time.

| Phase | Syntax | Responsibility |
| --- | --- | --- |
| Liquid preprocessing | `{{ value }}` and `{% tag %}` | Optional RhoeLiquid expansion before Markdown parsing. |
| Markdown parsing | Markdown, GFM, `!!!`, `:::`, attributes | Builds the `Block` and `Inline` AST. |
| Parse-native inputs | `{? name: "Field" ?}` | Captures placeholders and input declarations as AST nodes. |
| Semantic transforms | `{@ command key=value @}` | Mutates an already parsed AST when transforms are enabled. |
| Normalization | generated AST only | Resolves sections, cross-references, citations, abbreviations, and projection visibility. |
| Rendering | CLI/API selected target | Emits HTML, LaTeX, Typst, DOCX, PDF, EPUB, JSON API data, or presentation/project projections. |

## Delimiter Families

| Delimiter | Label | Purpose |
| --- | --- | --- |
| `{{ }}` | RhoeLiquid | Value interpolation before parsing. |
| `{% %}` | RhoeLiquid | Liquid control flow before parsing. |
| `{? ?}` | RhoeMarkdown extension | Placeholder/input declaration captured by the parser. |
| `{@ @}` | RhoeMarkdown extension | Semantic transform directive. |
| `!!!` | RhoeMarkdown extension | Semantic block family: admonitions, formal blocks, contracts, and semantic components. |
| `:::` | RhoeMarkdown extension | Visual/layout block family: divs, visual blocks, widgets, tabs, grids, modules, and visual components. |
| `%%%` | RhoeMarkdown extension | Slide boundary used by the presentation parser. |

## Attribute Model

RhoeMarkdown uses Pandoc-style attribute lists:

````markdown
## Result Summary {#result-summary .key-result role=doc-subsection}

[Open the report](report.html){.primary-link target=_blank}

```swift {#model .sample executable=false}
let score = 0.97
```
````

Attributes are preserved as `Attributes(id:classes:keyValues:)` and flow through parse, normalization, and render. Public attributes are intentionally stringly typed so downstream renderers can carry domain-specific metadata without changing the AST.

The recommended attribute buckets are:

| Bucket | Examples | Use |
| --- | --- | --- |
| Identity | `#id`, `.class` | Anchors, CSS classes, selector targets. |
| Semantic | `role=`, `kind=`, `family=` | Meaning, editorial intent, accessibility hints. |
| Presentation | `width=`, `height=`, `align=`, `color=` | Renderer-visible layout/style hints. |
| Projection | `format=`, `visible=`, `hidden=`, `docx-style=` | Output-specific behavior. |
| Interaction | `editable=`, `required=`, `type=` | Input and editor behavior. |
| Writer hint | `draft=`, `todo=`, `reviewer=` | Authoring metadata that may be stripped from final output. |

## Output Surfaces

The `rhoemd` CLI supports six public output formats in `0.1.0`: `html`, `latex`, `typst`, `docx`, `pdf`, and `epub`. The Swift API and `RhoeMarkdownWasm` target also expose AST-near JSON serialization helpers for tooling integrations.

## Reference Sections

- <doc:SyntaxReference>
- <doc:Block>
- <doc:Inline>
- <doc:MathematicalRendering>
- <doc:IconLibraries>
- <doc:CustomExtensions>
- <doc:CompatibilityAndDeferred>
