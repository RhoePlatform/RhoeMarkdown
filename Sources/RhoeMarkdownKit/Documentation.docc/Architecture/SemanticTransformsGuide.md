# Semantic Transforms

Phase 2 AST manipulation using the `{@ @}` directive system.

## Overview

Semantic transforms are the third phase of the RhoeMarkdown `0.1.0` pipeline. After Liquid expansion (Phase 1) and parsing (Phase 2), the document exists as a fully parsed `Block`/`Inline` AST. Phase 2 transform directives — written as `{@ command args @}` in the source — walk this AST and apply structural mutations: selecting nodes, modifying attributes, hiding or revealing content, collecting elements into new structures, and rearranging document order.

Transforms operate on the AST in place. They do not re-parse text or produce new Markdown. Their input and output are both `[Block]` arrays.

## The {@ @} Syntax

A transform directive consists of a command name followed by keyword arguments:

```markdown
{@ hide selector=".draft" @}
```

### Block Form

Block-form directives wrap content and operate on it:

```markdown
{@ collect into="appendix" @}

## Supplementary Data

Tables, figures, and extended analysis.

{@ endcollect @}
```

### Inline Form

Inline directives appear within a line and apply to adjacent content or to targets identified by selector:

```markdown
This paragraph contains {@ annotate kind="editorial" @}a contested claim{@ endannotate @} that requires review.
```

### AST Representation

In the parsed AST, transform directives become `Block.phase2Directive` nodes:

```swift
case phase2Directive(
    command: String,
    arguments: [String: String],
    body: String?,
    attributes: Attributes = Attributes()
)
```

The transform engine processes these nodes in document order, applying each directive's operation to the surrounding AST.

## Commands

RhoeMarkdown `0.1.0` defines eight transform commands.

### select

Marks nodes matching a selector for subsequent operations. `select` does not modify the AST on its own; it establishes a working set for chained commands.

```markdown
{@ select selector=".figure" @}
```

### set

Modifies attributes on nodes matching a selector. Adds, replaces, or removes attribute keys.

```markdown
{@ set selector="h2" class="section-heading" data-toc="true" @}
```

Multiple attributes can be set in a single directive. To remove an attribute, set its value to the empty string:

```markdown
{@ set selector=".legacy" data-deprecated="" @}
```

### hide

Removes nodes matching a selector from the rendered output. Hidden nodes remain in the AST (they can be restored by `show`) but are skipped during rendering.

```markdown
{@ hide selector=".internal-only" @}
```

### show

Restores previously hidden nodes matching a selector. This is the inverse of `hide`.

```markdown
{@ show selector=".internal-only" @}
```

`show` has no effect on nodes that are not hidden.

### collect

Gathers nodes matching a selector and moves them into a named collection point elsewhere in the document.

```markdown
{@ collect selector=".endnote" into="endnotes-section" @}
```

The collected nodes are removed from their original positions and appended, in document order, to the block whose `id` attribute matches the `into` value. If no target block exists, a new div with that id is appended to the document root.

### clone

Copies nodes matching a selector to a target location without removing the originals.

```markdown
{@ clone selector=".key-finding" into="executive-summary" @}
```

Cloned nodes receive fresh metadata (new UUIDs) to avoid id collisions.

### move

Relocates nodes matching a selector to a target location, removing them from their original positions.

```markdown
{@ move selector="#references" after="#conclusion" @}
```

`move` supports positional arguments `before=`, `after=`, and `into=` to control placement relative to the target.

### annotate

Attaches metadata annotations to nodes matching a selector. Annotations do not change rendering but are available to downstream tools, export filters, and accessibility layers.

```markdown
{@ annotate selector=".claim" kind="requires-citation" reviewer="editor" @}
```

Annotations are stored in the node's `Attributes` under writer-hint keys.

## Selector Atoms

Selectors identify target nodes in the AST. They use a CSS-inspired syntax with 11 atoms that can be combined.

| Atom | Syntax | Matches |
| --- | --- | --- |
| **Type** | `paragraph`, `heading`, `codeBlock`, etc. | Nodes of that block or inline type |
| **Id** | `#introduction` | The node whose `id` attribute equals the value |
| **Class** | `.draft` | Nodes whose `class` attribute contains the value |
| **Attribute presence** | `[data-lang]` | Nodes that have the named attribute |
| **Attribute value** | `[data-lang="swift"]` | Nodes whose attribute equals the value |
| **Attribute prefix** | `[data-lang^="py"]` | Nodes whose attribute starts with the value |
| **Attribute suffix** | `[data-lang$="on"]` | Nodes whose attribute ends with the value |
| **Attribute contains** | `[data-lang*="th"]` | Nodes whose attribute contains the value |
| **Heading level** | `h1`, `h2`, ..., `h6` | Heading nodes at the specified level |
| **Nth-child** | `:nth-child(2)` | The nth child of its parent container |
| **Negation** | `:not(.published)` | Nodes that do not match the inner selector |

### Combining Atoms

Atoms chain without spaces for intersection (AND):

```markdown
{@ hide selector="heading.draft[data-status='wip']" @}
```

This matches heading nodes that have class `draft` AND attribute `data-status` equal to `wip`.

Comma-separated selectors form a union (OR):

```markdown
{@ hide selector=".draft, .archived" @}
```

Descendant combinators use a space:

```markdown
{@ set selector="#appendix .figure" class="appendix-figure" @}
```

This matches `.figure` nodes that are descendants of the node with id `appendix`.

## Pipeline Integration

Transform directives are processed in a specific order within the five-phase pipeline:

1. **Liquid** (Phase 1) may conditionally emit `{@ @}` directives via `{% transform %}`.
2. **Parse** (Phase 2) captures directives as `Block.phase2Directive` nodes in the AST.
3. **Transform** (Phase 3) executes directives in document order. Each directive sees the AST as modified by all preceding directives.
4. **Normalize** (Phase 4) runs after all transforms complete. It resolves cross-references, numbers footnotes, and validates the final structure.
5. **Execute / Render** (Phase 5) works with the fully transformed and normalized AST.

### Execution Order

Directives execute in strict document order (top to bottom). A directive at line 10 runs before a directive at line 50. This ordering is deterministic and observable: a `hide` at line 10 prevents a `select` at line 50 from matching the hidden nodes (unless `show` intervenes).

### Idempotency

Most commands are idempotent: applying them twice produces the same result as applying them once. `hide` on an already-hidden node is a no-op. `set` with the same value is a no-op. The exceptions are `collect` and `move`, which relocate nodes and therefore change the document structure irreversibly.

### Error Handling

If a selector matches zero nodes, the directive is silently skipped. This is not an error because selectors may target content that was conditionally excluded by Liquid or by an earlier `hide` directive.

If a directive has an unrecognized command name, it is reported as a warning and left in the AST as an inert `phase2Directive` node that renderers skip.

## See Also

- <doc:LiquidPreprocessingGuide>
- <doc:LanguageOverview>
- <doc:Block>
