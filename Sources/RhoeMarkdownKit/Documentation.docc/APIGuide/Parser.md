# ``RhoeMarkdownKit/DocumentParser``

Parse RhoeMarkdown source into the public document AST and run the standard post-parse processing pipeline.

## Overview

`DocumentParser` is the package-level parser facade used by `RhoeMarkdownKit.parse(_:)`, the `rhoemd` CLI, and higher-level render helpers. It accepts a `RhoeMarkdownKit.Configuration`, applies Phase 1 Liquid preprocessing when enabled, dispatches to the sequential, parallel, or streaming parsing path based on input size, and then runs the document pipeline for normalization, citations, cross-references, component expansion, and diagram handling.

Use `DocumentParser` directly when you need explicit parser configuration, diagram-rendering configuration, or custom performance thresholds. Use `RhoeMarkdownKit.parse(_:)` for the default public parser surface.

## Creating a Parser

```swift
import RhoeMarkdownKit

let parser = DocumentParser()
let strictParser = DocumentParser(configuration: .strict)
```

For explicit diagram behavior:

```swift
let parser = DocumentParser(
    configuration: .default,
    diagramConfiguration: .disabled
)
```

## Parsing Documents

`parse(_:)` is asynchronous because Phase 1 preprocessing, parallel parsing, and future resolver-backed passes can require asynchronous work.

```swift
let source = """
# Release Notes

See [@smith2024] for background.
"""

let result = await parser.parse(source)
let document = result.document

print(document.blocks.count)
print(result.diagnostics)
```

The returned `ParseResult` contains:

- `document`: the parsed and normalized `RhoeMarkdownKit.Document`.
- `diagnostics`: parser, preprocessing, and pipeline diagnostics.
- `parseTime`: elapsed parse time in seconds.

## Configuration

`RhoeMarkdownKit.Configuration` controls language features such as tables, task lists, citations, cross-references, YAML frontmatter, Liquid preprocessing, Phase 2 transforms, and RhoeMarkdown-specific block families.

```swift
let configuration = RhoeMarkdownKit.Configuration(
    enableCitations: true,
    enableCrossReferences: true,
    enablePhase1Preprocessing: true,
    enablePhase2Transforms: true
)

let parser = DocumentParser(configuration: configuration)
```

Use `.github` for a GitHub Flavored Markdown-oriented profile and `.strict` for a minimal CommonMark-oriented profile with RhoeMarkdown extensions disabled.

## Performance Dispatch

`DocumentParser` selects one of three parsing paths:

- Sequential parsing for ordinary documents.
- Parallel parsing for documents larger than `parallelParsingThreshold`.
- Streaming/large-document parsing for documents larger than `streamingParsingThreshold`.

The defaults are tuned for release use:

| Threshold | Default |
| --- | --- |
| Parallel parsing | `100_000` bytes |
| Streaming parsing | `1_000_000` bytes |

You can override the thresholds for benchmarking or constrained hosts:

```swift
let parser = DocumentParser(
    parallelParsingThreshold: 250_000,
    streamingParsingThreshold: 2_000_000,
    parallelParsingEnabled: true,
    streamingParsingEnabled: true
)
```

## Pipeline Contract

After parsing, `DocumentParser` runs the standard document pipeline. In the default profile this includes structural normalization, attribute validation, extension resolution, Phase 2 transforms, bibliography collection, citation resolution, cross-reference numbering and resolution, and debug-time canonical-freeze validation.

If you need lower-level control for editor previews, use the specialized preview APIs documented elsewhere in the catalog rather than bypassing the parser pipeline in application code.

## See Also

- <doc:APIReference>
- <doc:SyntaxReference>
- <doc:Performance>
- <doc:GettingStarted>
