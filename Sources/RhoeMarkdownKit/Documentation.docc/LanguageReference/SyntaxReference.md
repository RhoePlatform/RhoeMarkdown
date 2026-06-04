# Syntax Reference

Concrete author-facing syntax accepted by RhoeMarkdown `0.1.0`.

## Overview

This page is the syntax-first companion to the `Block` and `Inline` API references. It answers the practical question: “What can I write in a `.md` file and what does the compiler understand?”

## Document Head

RhoeMarkdown accepts YAML front matter at the start of a file:

```markdown
---
title: "Launch Note"
author: "RhoePlatform"
tags: ["release", "markdown"]
---
```

Front matter is preserved as document metadata. During Liquid preprocessing, front matter is exposed through the `page.*` namespace, while the front matter block itself is not rendered as body content.

## Core Blocks

| Syntax | Status | AST |
| --- | --- | --- |
| Paragraphs separated by blank lines | CommonMark | `paragraph` |
| `#` through `######` headings | CommonMark | `heading`, normalized to `section` where configured |
| `>` block quotes | CommonMark | `blockQuote` |
| `-`, `*`, `+` unordered lists | CommonMark | `list(.unordered)` |
| `1.` ordered lists | CommonMark | `list(.ordered)` |
| `- [ ]` and `- [x]` task items | GitHub Flavored Markdown | `list(.task)` |
| Indented or fenced code blocks | CommonMark | `codeBlock` |
| `---`, `***`, `___` thematic breaks | CommonMark | `horizontalRule` |
| Pipe tables | GitHub Flavored Markdown | `table` |

```markdown
# Status

> Keep the source readable.

- [x] Parse the document
- [ ] Publish the release

| Format | Extension |
| --- | --- |
| HTML | `.html` |
| Typst | `.typ` |
```

## Inline Syntax

| Syntax | Status | AST |
| --- | --- | --- |
| `*emphasis*`, `_emphasis_` | CommonMark | `emphasis` |
| `**strong**`, `__strong__` | CommonMark | `strong` |
| Code spans with backtick delimiters | CommonMark | `codeSpan` |
| `[text](url "title")` | CommonMark | `link` |
| `![alt](url "title")` | CommonMark | `image` |
| `~~deleted~~` | GitHub Flavored Markdown | `strikethrough` |
| `==highlight==` | RhoeMarkdown extension | `highlight` |
| `^superscript^` | RhoeMarkdown extension | `superscript` |
| `~subscript~` | RhoeMarkdown extension | `subscript` |
| `$x^2$` | RhoeMarkdown extension | `inlineMath` |
| `$$x^2$$` | RhoeMarkdown extension | `mathDisplay` |
| `[^note]` | CommonMark-style extension | `footnoteRef` |
| `^[inline note]` | RhoeMarkdown extension | `inlineFootnote` |
| `[@smith2026]` | RhoeMarkdown extension | `citation` |
| `@fig-chart`, `@sec-intro` | RhoeMarkdown extension | `crossReference` |
| `[[Page]]`, `[[Page|label]]` | RhoeMarkdown extension | `wikilink` |
| `:sparkles:` | RhoeMarkdown extension | `emoji` |

```markdown
RhoeMarkdown supports **strong** claims, `code`, $inline math$, citations
like [@smith2026], wiki links like [[Architecture|the architecture note]], and
cross-references such as @fig-signal.
```

## Attributes

Attribute lists attach to blocks and inlines using `{#id .class key=value}`:

```markdown
## Signal Table {#signal-table .evidence role=dataset}

[Download CSV](signal.csv){.button target=_blank}

`raw html`{=html}
```

Class-only raw format markers such as `{=html}`, `{=latex}`, and `{=typst}` after inline code become `rawInline` nodes instead of ordinary code spans.

## Semantic Blocks

Semantic blocks use `!!!` and carry meaning first:

```markdown
!!! note "Operational note" {#ops-note}
Keep release notes short enough to review in one pass.
!!!

!!! theorem "Compiler Invariant" {#thm-ast}
The normalized AST is the shared truth for all renderers.
!!!

!!! proof
Every renderer receives the same normalized document.
!!!
```

Recognized public families include admonitions (`note`, `tip`, `warning`, `danger`, `info`, `example`), formal blocks (`theorem`, `lemma`, `definition`, `example`, `proof`), contract blocks (`input`, `output`), and component declarations (`component`).

## Visual And Layout Blocks

Visual/layout blocks use `:::`:

```markdown
::: {.columns count=2}
Left column content.

Right column content.
:::

::: Mermaid {#flow}
graph TD
  A[Source] --> B[AST]
  B --> C[HTML]
:::
```

Anonymous `:::` blocks parse as attributed `div` containers. Named blocks parse as `visualBlock` or specialized normalized block kinds when the name is reserved by the compiler.

## Composition Directives

Composition directives use `<< >>`:

```markdown
<<include docs/overview.md>>

<<schema jsonld>>
{"@type": "SoftwareSourceCode"}
<</schema>>

<<todo Check release checks>>
```

Supported surfaces include transclusion, author annotations, schema islands, component parameters, slot references, expression nodes, and input fields. File-based transclusion is native-only in `0.1.0`.

## Liquid Preprocessing

RhoeMarkdown can run RhoeLiquid before parsing:

```markdown
# {{ page.title }}

{% for item in items %}
- {{ item.name }}: {{ item.status }}
{% endfor %}
```

Liquid output is parsed as ordinary RhoeMarkdown. Generated semantic transform directives are guarded by configuration so template expansion cannot silently mutate AST structure unless enabled.

## Semantic Transforms

Transform directives use `{@ @}`:

```markdown
{@ select id=summary set=visible value=screen @}
{@ annotate selector=.risk kind=reviewer note="Check before release" @}
```

The public transform vocabulary is intentionally conservative in `0.1.0`: selectors are key-value atoms such as `id=`, `class=`, `role=`, `family=`, `kind=`, `visible=`, `has=`, `numbered=`, and `title=`.

## Presentations

Slide-oriented documents can use `%%%` boundaries:

```markdown
# Launch Narrative

%%%

## 1. Problem

Teams lose semantic continuity across document formats.

%%%

## 2. Move

One source, many projections.
```

The presentation subsystem also supports `deck`, `slide`, `speakerNotes`, grid, shape, and slot-related nodes for richer slide pipelines.

## WebAssembly Subset

`RhoeMarkdownWasm` supports parsing, Liquid preprocessing, HTML rendering, LaTeX string output, Typst string output, and JSON serialization. Native-only features in `0.1.0` include PDF generation, DOCX/EPUB generation, external diagram rendering, filesystem-backed transclusion, and platform-specific profiling.

## See Also

- <doc:LanguageOverview>
- <doc:Block>
- <doc:Inline>
- <doc:CompatibilityAndDeferred>
