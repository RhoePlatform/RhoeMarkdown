# Core Blocks

The public block-level AST surface for RhoeMarkdown `0.1.0`.

## Overview

`Block` is an enum with 49 cases that represents every block-level element in a RhoeMarkdown `0.1.0` document. The cases span core CommonMark structure, GFM extensions, semantic containers, visual/layout containers, project and presentation surfaces, composition primitives, computation nodes, structural execution, semantic transforms, and raw passthrough.

Every case that accepts child content also carries an `attributes` parameter of type `Attributes`, supporting the six-category attribute system (identity, presentational, semantic, interaction, projection, writer-hint).

## Core Structure

These cases cover the foundational block elements inherited from CommonMark and GFM.

### paragraph

```swift
case paragraph(_ content: [Inline], attributes: Attributes = Attributes())
```

A run of inline content forming a paragraph. The most common block type in any document.

### heading

```swift
case heading(level: Int, content: [Inline], attributes: Attributes = Attributes())
```

An ATX or setext heading. `level` ranges from 1 (H1) to 6 (H6). Supports id attributes for cross-reference anchors.

### blockQuote

```swift
case blockQuote(_ content: [Block], attributes: Attributes = Attributes())
```

A block quotation containing nested blocks. Indicated by `>` prefix lines.

### list

```swift
case list(type: ListType, items: [ListItem], attributes: Attributes = Attributes())
```

An ordered, unordered, or task list. `ListType` distinguishes `.unordered`, `.ordered(start:style:)`, and `.task` variants. Each `ListItem` carries its own `[Block]` content and an optional `checked` state for task items.

### codeBlock

```swift
case codeBlock(language: String?, content: String, attributes: Attributes = Attributes())
```

A fenced or indented code block. `language` is the info-string token (e.g., `"swift"`, `"python"`). Attributes may carry execution hints like `in=`, `out=`, or kernel directives for computable code cells.

### horizontalRule

```swift
case horizontalRule
```

A thematic break rendered as a horizontal rule. Carries no content or attributes.

### table

```swift
case table(
    headers: [TableCell],
    rows: [[TableCell]],
    caption: [Inline]? = nil,
    attributes: Attributes = Attributes()
)
```

A GFM pipe table with per-cell alignment, optional row and column spanning, an optional caption, and block-level cell content support via `TableCell.blockContent`.

### definitionList

```swift
case definitionList(items: [DefinitionListItem], attributes: Attributes = Attributes())
```

A Pandoc-style definition list. Each `DefinitionListItem` pairs a term (`[Inline]`) with one or more definitions (`[[Block]]`).

## Footnotes and References

### footnoteDefinition

```swift
case footnoteDefinition(id: String, content: [Block])
```

A footnote body referenced elsewhere by `Inline.footnoteReference(id:)`. The `id` string matches the reference label.

### abbreviationDefinition

```swift
case abbreviationDefinition(abbreviation: String, expansion: String)
```

Declares an abbreviation expansion (e.g., `*[HTML]: HyperText Markup Language`). During normalization, all matching text is wrapped in tooltip markup.

## Container Blocks

Container blocks hold nested block content and are distinguished by their delimiter family.

### admonition

```swift
case admonition(
    type: String,
    title: String?,
    content: [Block],
    collapsible: AdmonitionCollapsible?,
    attributes: Attributes = Attributes()
)
```

A semantic callout block using the `!!!` delimiter family. `type` is a freeform string (common values: `note`, `warning`, `tip`, `danger`, `info`, `example`). `collapsible` is `.expanded` or `.collapsed` when the admonition supports toggling.

### div

```swift
case div(content: [Block], attributes: Attributes = Attributes())
```

A generic container block using the `:::` delimiter family. Serves as the base for layout wrappers, columns, tabs, and any custom container identified by class or data attributes.

### visualBlock

```swift
case visualBlock(name: String, content: [Block], attributes: Attributes = Attributes())
```

A named visual container from the `:::` family. `name` identifies the visual type (e.g., `"columns"`, `"card"`, `"tabs"`). Distinguished from `div` by carrying an explicit semantic name rather than relying on class attributes.

### lineBlock

```swift
case lineBlock(lines: [[Inline]])
```

A block of lines preserving exact line breaks, useful for poetry, addresses, or other content where line structure is meaningful. Each inner array is one line.

## Notebook Surfaces

Notebook surface blocks create auxiliary UI surfaces within a `.rhoenb` notebook. In non-notebook contexts, they degrade to standard block-level elements.

### widget

```swift
case widget(title: String?, content: [Block], attributes: Attributes = Attributes())
```

A compact auxiliary surface rendered as a panel in the notebook UI. `title` provides the panel header. Uses the `:::` delimiter family with the `widget` keyword. In non-notebook contexts, widgets render as styled aside blocks.

### tab

```swift
case tab(title: String?, content: [Block], attributes: Attributes = Attributes())
```

A full-size companion surface rendered as a separate tab in the notebook UI. `title` sets the tab label. Uses the `:::` delimiter family with the `tab` keyword. In non-notebook contexts, tabs render as document sections.

## Composition

Composition blocks support multi-document authoring, annotations, schemas, and reusable components.

### transclusion

```swift
case transclusion(
    target: String,
    fragment: String?,
    mode: TransclusionMode?,
    attributes: Attributes = Attributes()
)
```

Includes content from another document. `target` is a path or URI; `fragment` selects a subsection. `TransclusionMode` governs how the included content is integrated: `.block`, `.inline`, `.excerpt`, `.literal`, or `.quote`.

### authorAnnotation

```swift
case authorAnnotation(
    kind: AnnotationKind,
    text: String,
    attributes: Attributes = Attributes()
)
```

An author-facing annotation that does not appear in published output. `AnnotationKind` is one of `.todo`, `.doc`, `.info`, or `.comment`.

### schemaIsland

```swift
case schemaIsland(
    schema: String,
    body: String,
    attributes: Attributes = Attributes()
)
```

An embedded structured-data island (JSON-LD, YAML, etc.) identified by `schema`. The `body` is the raw schema content. Used for SEO metadata, dataset declarations, or configuration blocks.

### componentDeclaration

```swift
case componentDeclaration(
    family: BlockFamily,
    name: String,
    args: String?,
    slots: String?,
    body: [Block],
    attributes: Attributes = Attributes()
)
```

Declares a reusable component. `family` is `.semantic` (`!!!`) or `.visual` (`:::`). `name` identifies the component type. `args` and `slots` carry the argument and slot strings. `body` contains the component's block content.

## Computation

Computation blocks introduce dynamic, evaluable, and interactive content.

### placeholder

```swift
case placeholder(fields: [String: String], attributes: Attributes = Attributes())
```

A parser-native placeholder declared with `{? name: "Field", type: text ?}` syntax. The `fields` dictionary captures all key-value pairs from the placeholder declaration.

### expression

```swift
case expression(expr: String, attributes: Attributes = Attributes())
```

A block-level expression evaluation node: `<<= expr >>`. The `expr` string is evaluated by the expression engine during the execute phase, and the result replaces the block.

### field

```swift
case field(
    name: String,
    fieldType: String,
    attributes: Attributes = Attributes()
)
```

A block-level input field binding: `<<field name {type=text}>>`. `name` is the binding key in the reactive store; `fieldType` determines the rendered control (text, number, select, toggle, etc.).

### form

```swift
case form(
    name: String?,
    content: [Block],
    attributes: Attributes = Attributes()
)
```

A transactional input form: `<<form>>...<</form>>`. Groups multiple input fields with commit/rollback semantics. `name` is an optional form identifier.

## Structural Execution

Structural execution blocks define typed, composable execution pipelines within notebook documents.

### stage

```swift
case stage(kind: StageKind, content: [Block], attributes: Attributes = Attributes())
```

A pipeline execution stage using the `:::` delimiter family with `stage.<kind>` syntax. `StageKind` determines the execution topology: `.rack` (fan-out/parallel merge), `.case` (conditional selection), `.template` (replica expansion), `.iterate` (bounded recurrence), or `.adapter` (shape adaptation). Content contains lane blocks and optional prose.

### lane

```swift
case lane(content: [Block], attributes: Attributes = Attributes())
```

An execution slot within a stage, delimited by `=== lane ... ===`. Lanes contain module blocks and optional prose. They inherit execution semantics from their parent stage kind.

### module

```swift
case module(family: String, name: String, content: [Block], attributes: Attributes = Attributes())
```

A typed execution unit within a lane, using `:::` with a dotted `module.<family>.<name>` identifier. `family` groups related operations (transform, records, validate, io, debug, interaction, variables, connector). `name` specifies the operation within the family (e.g., `map`, `filter`, `sort`).

### contractDirective

```swift
    case contractDirective(kind: ContractKind, content: String, attributes: Attributes = Attributes())
```

An input/output contract declaration using the `!!!` admonition syntax with reserved keywords `input` or `output`. Contracts declare data bindings for stages, enabling the execution engine to wire pipeline segments and validate data flow.

## Transforms

### phase2Directive

```swift
case phase2Directive(
    command: String,
    arguments: [String: String],
    body: String?,
    attributes: Attributes = Attributes()
)
```

A Phase 2 semantic transform directive: `{@ command args @}`. The `command` identifies the transform operation (e.g., `select`, `set`, `hide`, `show`, `collect`, `clone`, `move`, `annotate`). `arguments` carries the directive's parameters, and `body` holds optional inline content.

## Legacy

### html

```swift
case html(String)
```

Raw HTML passthrough. Preserved for CommonMark compatibility. The string is emitted verbatim by the HTML renderer and converted or stripped by other format writers.

## See Also

- <doc:LanguageOverview>
- <doc:SyntaxReference>
- <doc:Inline>
- <doc:CompatibilityAndDeferred>
