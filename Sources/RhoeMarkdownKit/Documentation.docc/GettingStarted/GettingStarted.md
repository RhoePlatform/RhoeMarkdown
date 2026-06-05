# Getting Started

Use RhoeMarkdownKit when you want a Swift-native semantic Markdown compiler with
multi-format rendering and a command-line tool.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/RhoePlatform/RhoeMarkdown.git", from: "0.1.1")
]
```

```swift
.target(
    name: "YourTool",
    dependencies: ["RhoeMarkdownKit"]
)
```

## Parse Markdown

```swift
import RhoeMarkdownKit

let result = await RhoeMarkdownKit.parse("""
# Welcome

This is **bold** text with a follow-up paragraph.
""")

let document = result.document
let diagnostics = result.diagnostics
```

## Render HTML

```swift
let html = RhoeMarkdownKit.renderHTML(
    document,
    configuration: .init(prettyPrint: true)
)
```

## Render In One Call

```swift
let html = await RhoeMarkdownKit.toHTML("# Hello from RhoeMarkdown")
let typst = await RhoeMarkdownKit.toTypst("# Publication Draft")
let latex = await RhoeMarkdownKit.toLaTeX("# Paper Draft")
```

## Use The CLI

```bash
swift build -c release --product rhoemd
./.build/release/rhoemd Examples/sources/research-note.md \
  -o Examples/outputs/research-note.html \
  --format html \
  --css \
  --pretty
```

## Smoke-Tested Surface

The first public release candidate validates:

- `RhoeMarkdownKit.parse`
- `RhoeMarkdownKit.renderHTML`
- `RhoeMarkdownKit.toHTML`
- `RhoeMarkdownKit.toLaTeX`
- `RhoeMarkdownKit.toTypst`
- `RhoeMarkdownWasm`
- `rhoemd`
