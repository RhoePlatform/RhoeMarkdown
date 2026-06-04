# Inline Syntax

Represents all inline-level elements within the RhoeMarkdown `0.1.0` AST.

## Overview

`Inline` is an enum with 32 cases covering the public inline element surface. The cases span text, formatting, links, images, math, citations, cross-references, wiki-style references, emoji, raw content, component references, placeholders, expressions, and input fields.

## Text and Formatting

The foundational inline elements for text content and typographic formatting.

### text

```swift
case text(String)
```

A run of plain text. The leaf node of most inline content trees.

### emphasis

```swift
case emphasis([Inline])
```

Emphasis (typically italic). Delimited by `*` or `_`.

### strong

```swift
case strong([Inline])
```

Strong emphasis (typically bold). Delimited by `**` or `__`.

### strikethrough

```swift
case strikethrough([Inline])
```

Strikethrough text. Delimited by `~~`.

### code

```swift
case code(String, attributes: Attributes = Attributes())
```

An inline code span. Delimited by backticks. Supports attributes for language hints or styling.

### highlight

```swift
case highlight([Inline])
```

Highlighted/marked text. Delimited by `==`.

### superscript

```swift
case superscript([Inline])
```

Superscript text. Delimited by `^`.

### subscript

```swift
case `subscript`([Inline])
```

Subscript text. Delimited by `~`. Note the backtick-escaped name because `subscript` is a Swift keyword.

### hardBreak

```swift
case hardBreak
```

A hard line break (two trailing spaces or backslash at end of line).

### softBreak

```swift
case softBreak
```

A soft line break (single newline within a paragraph). Renderers typically convert this to a space or preserve it depending on configuration.

## Links and Images

### link

```swift
case link(
    text: [Inline],
    url: String,
    title: String?,
    attributes: Attributes = Attributes()
)
```

A hyperlink with inline content as the link text, a destination URL, and an optional title. Supports attributes for target, rel, and other link behavior.

### image

```swift
case image(
    alt: [Inline],
    url: String,
    title: String?,
    attributes: Attributes = Attributes()
)
```

An image element with structured alt text (as inline content), source URL, and optional title. Attributes can specify width, height, loading behavior, and captioning.

### wikilink

```swift
case wikilink(target: String, display: [Inline]?)
```

A wiki-style link: `[[target]]` or `[[target|display text]]`. `target` is the page name or path; `display` is optional custom link text.

## Math

### mathInline

```swift
case mathInline(expression: String, attributes: Attributes = Attributes())
```

Inline math: `$E = mc^2$`. The `expression` string contains LaTeX math content. Rendered to MathML or kept as LaTeX depending on the output format.

### mathDisplay

```swift
case mathDisplay(expression: String, attributes: Attributes = Attributes())
```

Display math: `$$\int_0^\infty e^{-x^2} dx$$`. Block-level math rendered as an inline AST node. Typically centered and set on its own line.

## Footnotes and Citations

### footnoteReference

```swift
case footnoteReference(id: String)
```

A footnote reference: `[^id]`. Links to the corresponding `Block.footnoteDefinition(id:content:)`.

### inlineFootnote

```swift
case inlineFootnote(content: [Inline])
```

An inline footnote defined at the point of use: `^[footnote content]`. The content is rendered as a footnote without a separate definition block.

### citation

```swift
case citation(items: [CitationItem], mode: CitationMode)
```

A citation group: `[@smith2024; @jones2023, p. 42]`. Each `CitationItem` carries a key, optional locator, and author-suppression flag. `CitationMode` is `.parenthetical`, `.inText`, or `.suppressAuthor`.

### resolvedCitation

```swift
case resolvedCitation(text: String, keys: [String], mode: CitationMode)
```

A citation after bibliography resolution. `text` is the formatted citation string (e.g., "(Smith 2024; Jones 2023, p. 42)"). `keys` preserves the original citation keys for linking.

### crossReference

```swift
case crossReference(prefix: CrossRefPrefix, id: String)
```

A cross-reference to a labeled element: `@fig:diagram`, `@sec:intro`, `@eq:euler`. `CrossRefPrefix` identifies the target type (sec, fig, tbl, eq, thm, and 13 others).

### resolvedCrossReference

```swift
case resolvedCrossReference(text: String, targetId: String)
```

A cross-reference after resolution. `text` is the rendered label (e.g., "Figure 3"); `targetId` links to the target block's anchor.

## Spans and Raw Content

### span

```swift
case span(content: [Inline], attributes: Attributes)
```

An attributed inline span: `[text]{#id .class key=value}`. The primary vehicle for applying the six-category attribute system to inline content.

### rawInline

```swift
case rawInline(content: String, format: String)
```

Raw format-specific inline content. `format` identifies the target (e.g., `"html"`, `"latex"`, `"typst"`). The content is passed through verbatim to matching writers and stripped by others.

### html

```swift
case html(String)
```

Raw inline HTML. Preserved for CommonMark compatibility. Emitted verbatim by the HTML renderer.

## Composition

Composition inlines support multi-document inclusion, author annotations, and component wiring.

### transclusionInline

```swift
case transclusionInline(
    target: String,
    fragment: String?,
    mode: TransclusionMode?,
    attributes: Attributes = Attributes()
)
```

Inline transclusion from another document. Mirrors `Block.transclusion` but resolves to inline content rather than block content.

### annotationInline

```swift
case annotationInline(kind: AnnotationKind, text: String)
```

An inline author annotation. Like `Block.authorAnnotation`, these are stripped from published output. `AnnotationKind` is `.todo`, `.doc`, `.info`, or `.comment`.

### paramRef

```swift
case paramRef(name: String)
```

A reference to a component parameter by name. Resolved during component instantiation.

### slotRef

```swift
case slotRef(name: String?)
```

A reference to a component slot. `name` is `nil` for the default slot. Resolved during component instantiation.

## Computation

Computation inlines introduce dynamic evaluation and interactive inputs within running text.

### placeholderInline

```swift
case placeholderInline(fields: [String: String])
```

An inline placeholder: `{? name: "Field" ?}`. The `fields` dictionary captures all declared key-value pairs.

### expressionInline

```swift
case expressionInline(expr: String)
```

An inline expression evaluation: `<<= expr >>`. Evaluated by the expression engine during the execute phase; the result is substituted into the inline content flow.

### inputFieldInline

```swift
case inputFieldInline(
    name: String,
    fieldType: String,
    attributes: Attributes = Attributes()
)
```

An inline input field binding: `<<field name {type=text}>>`. Renders an interactive control inline within text. The value is bound to the reactive store under `name`.

## See Also

- <doc:LanguageOverview>
- <doc:SyntaxReference>
- <doc:Block>
- <doc:CompatibilityAndDeferred>
