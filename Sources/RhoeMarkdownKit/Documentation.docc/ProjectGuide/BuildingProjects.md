# Building Multi-Document Projects

Use the `rhoe build` CLI to compile multi-document projects into websites, books, reports, and other output formats.

## Overview

The RhoeProject build system compiles collections of RhoeMarkdown documents into output artifacts. A single project can produce multiple targets simultaneously -- an HTML documentation site, a PDF book, and an LLM knowledge bundle -- all from the same source documents, using projection filtering to tailor content for each format.

Building a project involves four stages: configuration loading, document discovery, compilation, and output assembly. The `ProjectBuilder` orchestrates these stages, with `DocumentCompiler` handling individual document compilation and `OutputManager` writing the results.

## CLI Usage

### Basic Build

```bash
# Build all enabled targets
rhoe build

# Build from a specific project root
rhoe build --root /path/to/project

# Build with a specific profile
rhoe build --profile production
```

### Target Selection

```bash
# Build a specific target
rhoe build --target docs-site

# Build multiple targets
rhoe build --target docs-site --target book

# List available targets without building
rhoe project targets
```

### Profile Selection

```bash
# Development build (lenient validation, code cells enabled)
rhoe build --profile dev

# Production build (strict validation, full optimization)
rhoe build --profile production

# CI build (strict validation, no code execution)
rhoe build --profile ci
```

### Validation Without Building

```bash
# Validate project configuration
rhoe project validate

# Validate and show target summary
rhoe project targets --verbose
```

## Build Process

### Stage 1: Configuration Loading

The `ProjectConfigurationLoader` reads `rhoe.project.yaml` (or `_config.yml`) and produces a typed `ProjectConfiguration`:

```swift
let loader = ProjectConfigurationLoader()
let config = try loader.load(from: projectRoot.appendingPathComponent("rhoe.project.yaml"))
```

The loader parses YAML using the built-in frontmatter parser, decodes all sections into typed structs, and validates required fields.

### Stage 2: Document Discovery

The `CollectionScanner` discovers documents in each collection's directory:

```swift
let scanner = CollectionScanner()
let discovered = try scanner.scan(
    collectionPath: "_docs",
    collectionName: "docs",
    projectRoot: projectRoot
)
```

For each discovered document, frontmatter is extracted to produce `CollectionDocument` instances with metadata (title, date, weight, layout, tags, draft status).

The `ProjectGraph` assembles all collections, resolves defaults, and builds the complete document graph:

```swift
let graph = try ProjectGraph(
    configuration: config,
    projectRoot: projectRoot
)
```

### Stage 3: Compilation

The `ProjectBuilder` compiles documents for each target. Compilation uses `DocumentCompiler`, which wraps the standard `DocumentParser` and `HTMLRenderer` (or other format-specific renderers):

```swift
let builder = ProjectBuilder()
let result = try await builder.build(
    target: "docs-site",
    graph: graph,
    projectRoot: projectRoot
)
```

Documents are compiled in parallel using Swift concurrency's `TaskGroup`. The build respects:

- **Projection filtering** -- Documents and blocks marked with `visible` or `target` attributes are filtered per-target
- **Format mapping** -- The `TargetFormatResolver` maps each target type to its output format and renderer
- **Collection scoping** -- Only collections listed in the target's `collections` array are compiled

### Stage 4: Output Assembly

The `OutputManager` writes compiled output to the target's output directory:

```
_site/
├── docs-site/
│   ├── index.html
│   ├── docs/
│   │   ├── getting-started.html
│   │   └── expressions.html
│   ├── guides/
│   │   └── quick-start.html
│   └── assets/
│       ├── style.css
│       └── logo.svg
├── book/
│   └── rhoe-docs.pdf
└── llm-bundle/
    └── knowledge.json
```

## Target Selection and Format Mapping

Each target type maps to a default output format and renderer:

| Target Type | Default Format | Renderer |
|-------------|---------------|----------|
| `static_site` | HTML | `HTMLRenderer` |
| `docs_site` | HTML | `HTMLRenderer` |
| `wiki_site` | HTML | `HTMLRenderer` |
| `book` | PDF | `PDFRenderer` (via LaTeX/Typst) |
| `report` | PDF | `PDFRenderer` |
| `brochure` | PDF | `PDFRenderer` |
| `deck` | HTML | `HTMLRenderer` (slide mode) |
| `single_file_html` | HTML | `HTMLRenderer` (bundled) |
| `llm_bundle` | JSON | `JSONRenderer` |

Targets can override the default format with the `output_format` property:

```yaml
targets:
  book:
    type: book
    output_format: typst    # Use Typst instead of LaTeX for PDF
```

## Asset Copying

Static assets (images, CSS, JavaScript, fonts) are copied from the project's `assets/` directory to each target's output:

1. The build scans the `paths.assets` directory recursively
2. All non-Markdown files are copied to the corresponding location in the output directory
3. Asset references in documents (`![](assets/image.png)`) resolve correctly in the output

Assets are copied per-target, allowing different targets to have different asset configurations. The `OutputManager` handles deduplication when multiple targets share the same output root.

## Build Results

The `ProjectBuilder.build()` method returns a `BuildResult` with detailed metrics:

```swift
let result = try await builder.build(target: "docs-site", graph: graph, projectRoot: root)

print("Target: \(result.targetName)")
print("Documents built: \(result.documentsBuilt)")
print("Total time: \(result.timing.totalDuration)s")
print("Parse time: \(result.timing.parseTime)s")
print("Render time: \(result.timing.renderTime)s")
print("Diagnostics: \(result.diagnostics.count)")
```

### Diagnostic Levels

| Level | Meaning | Build Behavior |
|-------|---------|----------------|
| `info` | Informational message | Build continues |
| `warning` | Potential issue | Build continues (fails under `fail_on_warning`) |
| `error` | Document compilation failure | Document skipped, build continues |

The build process is resilient: individual document failures do not halt the entire build. Failed documents are reported in diagnostics, and the build completes with a summary of successes and failures.

## Navigation Generation

For targets that include navigation (sites, docs, wikis), the `NavigationGenerator` produces a `NavigationTree` based on the configured navigation mode:

```swift
let navGen = NavigationGenerator()
let tree = navGen.generate(
    mode: config.navigation.mode,
    documents: graph.documents(for: "docs-site"),
    projectRoot: projectRoot
)
```

The navigation tree is serialized to JSON by `NavigationSerializer` and included in the output for consumption by frontend navigation components:

```json
{
    "items": [
        {
            "title": "Getting Started",
            "url": "/docs/getting-started.html",
            "children": []
        },
        {
            "title": "Guides",
            "children": [
                {
                    "title": "Expressions",
                    "url": "/guides/expressions.html"
                }
            ]
        }
    ]
}
```

## Incremental Builds

The build system supports incremental builds through source hash tracking:

1. Each document's source is hashed (SHA-256)
2. Hashes are stored in `.cache/source-hashes.json`
3. On subsequent builds, only documents with changed hashes are recompiled
4. Documents whose dependencies changed (via transclusion or data files) are also recompiled

To force a full rebuild:

```bash
rhoe build --clean
```

This removes the `.cache/` directory and recompiles all documents.

## See Also

- <doc:ProjectConfiguration>
- <doc:ProjectAPI>
- <doc:GettingStarted>
