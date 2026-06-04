# Project Configuration

Configure multi-document projects with `rhoe.project.yaml` -- define collections, build targets, navigation, and deployment profiles.

## Overview

RhoeProject is the project-level orchestration layer for multi-document publication. A project configuration file (`rhoe.project.yaml`) declares the project's structure: which documents belong to which collections, how they should be built, what navigation to generate, and which output formats to produce.

The configuration model is inspired by Jekyll's proven project conventions -- collections, data directories, layouts, includes -- but extends far beyond static websites. RhoeProject supports nine target types including books, reports, slide decks, documentation sites, wikis, and LLM knowledge bundles, all from a single source project.

## Configuration File

The project configuration lives in `rhoe.project.yaml` at the project root. The compatibility alias `_config.yml` is also accepted by `ProjectConfigurationLoader`.

### Minimal Configuration

```yaml
rhoe_project:
  version: 1

project:
  id: my-docs
  name: "My Documentation"
```

This minimal configuration creates a project with default paths, no collections, and no targets. Documents in the project root are treated as standalone files.

### Complete Configuration

```yaml
rhoe_project:
  version: 1

project:
  id: rhoe-docs
  name: "RhoeMarkdown Documentation"
  title: "RhoeMarkdown v3 Docs"
  description: "Official documentation for the RhoeMarkdown language"
  language: en
  timezone: America/New_York
  version: "3.3.0"

paths:
  source: .
  data: _data
  layouts: _layouts
  includes: _includes
  assets: assets
  output: _site
  build: .build
  cache: .cache

site:
  url: https://docs.rhoemarkdown.dev
  title: "RhoeMarkdown"
  subtitle: "The Semantic Document Language"
  author:
    name: "Thor Fuchs"
    url: https://rhoemarkdown.dev
  logo: assets/logo.svg
  favicon: assets/favicon.png
  locale: en_US

collections:
  docs:
    path: _docs
    output: true
    permalink: /docs/:path/:title/
    sort_by: weight
    defaults:
      layout: doc
      toc: true
    target_roles: [docs, wiki]

  guides:
    path: _guides
    output: true
    permalink: /guides/:title/
    sort_by: weight
    defaults:
      layout: guide
    target_roles: [docs]

  posts:
    path: _posts
    output: true
    permalink: /blog/:year/:month/:title/
    sort_by: date
    reverse: true
    defaults:
      layout: post
    target_roles: [blog]

navigation:
  mode: auto
  sidebar:
    collapsible: true
    max_depth: 3

targets:
  site:
    type: static_site
    enabled: true
    collections: [docs, guides, posts]
    output_format: html
    navigation:
      mode: sidebar

  book:
    type: book
    enabled: true
    collections: [docs]
    output_format: pdf
    assembly:
      order: weight
      front_matter: [introduction, getting-started]
      back_matter: [appendix, glossary]

  api-docs:
    type: docs_site
    enabled: true
    collections: [docs]
    output_format: html
    navigation:
      mode: tree

profiles:
  dev:
    validation:
      strict: false
      warn_missing_refs: true
    execution:
      enable_code_cells: true
      timeout: 30s

  production:
    validation:
      strict: true
      fail_on_warning: true
    execution:
      enable_code_cells: true
      timeout: 60s
    security:
      sandbox: strict
      network: deny

  ci:
    validation:
      strict: true
      fail_on_warning: true
    execution:
      enable_code_cells: false
    security:
      sandbox: strict
```

## Schema Overview

The `ProjectConfiguration` struct mirrors the YAML schema with these top-level sections:

| Section | Type | Purpose |
|---------|------|---------|
| `rhoe_project` | `schemaVersion: Int` | Schema version declaration |
| `project` | `ProjectMetadata` | Project identity and metadata |
| `paths` | `PathConfiguration` | Directory layout |
| `site` | `SiteConfiguration` | Site-level metadata for web targets |
| `collections` | `[String: CollectionDefinition]` | Document collection declarations |
| `defaults` | `[DefaultScope]` | Scoped default frontmatter values |
| `navigation` | `NavigationConfiguration` | Navigation generation settings |
| `targets` | `[String: TargetDefinition]` | Build target declarations |
| `profiles` | `[String: BuildProfile]` | Build profile configurations |

## Collections

Collections organize documents into named groups. Each collection has a directory, output settings, and metadata defaults.

### Declaring Collections

```yaml
collections:
  docs:
    path: _docs
    output: true
    permalink: /docs/:path/:title/
    sort_by: weight
    defaults:
      layout: doc
      toc: true
    target_roles: [docs, wiki]
```

### Collection Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `path` | string | `_{name}` | Directory path relative to project root |
| `output` | bool | `true` | Whether documents generate output files |
| `permalink` | string | `/:collection/:title/` | URL pattern for generated output |
| `sort_by` | string | `nil` | Frontmatter key to sort documents by |
| `reverse` | bool | `false` | Reverse sort order |
| `defaults` | map | `{}` | Default frontmatter values for documents in this collection |
| `target_roles` | array | `[]` | Which targets this collection participates in |

### Sorting

The `sort_by` property determines document ordering within a collection:

- `weight` -- Sort by numeric `weight` frontmatter value (ascending by default)
- `date` -- Sort by `date` frontmatter value (chronological)
- `title` -- Sort alphabetically by document title
- Any frontmatter key -- Sort by that key's value

Combined with `reverse: true`, this supports common patterns like newest-first blog posts:

```yaml
posts:
  sort_by: date
  reverse: true
```

### Default Frontmatter

The `defaults` map provides fallback frontmatter values for documents that do not declare them:

```yaml
docs:
  defaults:
    layout: doc
    toc: true
    sidebar: true
```

A document's explicit frontmatter always takes precedence over collection defaults.

## Targets

Targets define what the project builds. Each target specifies an output type, which collections it includes, and how the output is assembled.

### Nine Target Types

| Type | Value | Description |
|------|-------|-------------|
| Static site | `static_site` | Multi-page HTML website with navigation |
| Documentation site | `docs_site` | Structured documentation with sidebar, search, versioning |
| Wiki site | `wiki_site` | Interlinked wiki with backlinks and graph visualization |
| Book | `book` | Long-form publication with chapters, front/back matter |
| Report | `report` | Structured report with numbered sections and appendices |
| Brochure | `brochure` | Single or few-page designed publication |
| Slide deck | `deck` | Presentation slides |
| Single-file HTML | `single_file_html` | Self-contained HTML file with embedded assets |
| LLM bundle | `llm_bundle` | Structured knowledge export for language model consumption |

### Target Configuration

```yaml
targets:
  docs-site:
    type: docs_site
    enabled: true
    collections: [docs, guides]
    output_format: html
    output_dir: _site/docs
    visibility: docs
    navigation:
      mode: sidebar
    assembly:
      order: weight
```

### Target Properties

| Property | Type | Description |
|----------|------|-------------|
| `type` | `TargetType` | One of the nine target types |
| `enabled` | bool | Whether this target is built (default: true) |
| `collections` | array | Collection names to include |
| `output_format` | string | Output format (html, pdf, epub, latex, typst, docx) |
| `output_dir` | string | Custom output directory (overrides global `paths.output`) |
| `visibility` | string | Projection visibility label for this target |
| `navigation` | object | Target-specific navigation overrides |
| `assembly` | object | Document ordering and assembly rules |

### Assembly Rules

For targets that combine multiple documents into a single output (books, reports), assembly rules control ordering:

```yaml
book:
  type: book
  assembly:
    order: weight
    front_matter: [preface, introduction]
    back_matter: [appendix-a, glossary, bibliography]
    chapter_break: true
    number_chapters: true
```

| Property | Type | Description |
|----------|------|-------------|
| `order` | string | Sort key for document ordering |
| `front_matter` | array | Document IDs for front matter (unnumbered) |
| `back_matter` | array | Document IDs for back matter (appendices) |
| `chapter_break` | bool | Insert page breaks between documents |
| `number_chapters` | bool | Apply chapter numbering |

## Build Profiles

Build profiles configure validation, execution, and security policies for different environments. Select a profile with `--profile` on the CLI.

### Profile Configuration

```yaml
profiles:
  dev:
    validation:
      strict: false
      warn_missing_refs: true
      warn_unused_labels: false
    execution:
      enable_code_cells: true
      timeout: 30s
      max_memory: 512mb
    security:
      sandbox: permissive
      network: allow-localhost

  production:
    validation:
      strict: true
      fail_on_warning: true
    execution:
      enable_code_cells: true
      timeout: 60s
      max_memory: 1gb
    security:
      sandbox: strict
      network: deny
      filesystem: read-only-data

  ci:
    validation:
      strict: true
      fail_on_warning: true
    execution:
      enable_code_cells: false
    security:
      sandbox: strict
```

### Validation Policy

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `strict` | bool | `false` | Treat warnings as errors |
| `fail_on_warning` | bool | `false` | Fail the build on any warning |
| `warn_missing_refs` | bool | `true` | Warn about unresolved cross-references |
| `warn_unused_labels` | bool | `false` | Warn about labels that are never referenced |

### Execution Policy

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_code_cells` | bool | `false` | Enable code cell execution |
| `timeout` | duration | `30s` | Maximum execution time per cell |
| `max_memory` | size | `256mb` | Maximum memory per kernel |

### Security Policy

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `sandbox` | string | `strict` | Sandbox level: `strict`, `permissive` |
| `network` | string | `deny` | Network policy: `deny`, `allow-localhost`, `allow` |
| `filesystem` | string | `none` | Filesystem policy: `none`, `read-only-data`, `read-write-temp` |

## Navigation Modes

The `NavigationConfiguration` controls how the navigation tree is generated for each target.

### Five Navigation Modes

| Mode | Description |
|------|-------------|
| `auto` | Build navigation from filesystem hierarchy and frontmatter weights |
| `explicit` | Navigation defined entirely in YAML configuration |
| `summary` | Navigation defined in a `SUMMARY.md` file (mdBook-compatible) |
| `sidebar` | Collapsible sidebar navigation with configurable depth |
| `tree` | Full tree navigation with expandable sections |

### Auto Mode (Default)

```yaml
navigation:
  mode: auto
```

Auto mode scans collection directories and builds a navigation tree from:

1. Directory structure (subdirectories become sections)
2. Frontmatter `weight` values (for ordering within sections)
3. Document titles (for display labels)

### Sidebar Mode

```yaml
navigation:
  mode: sidebar
  sidebar:
    collapsible: true
    max_depth: 3
    show_icons: true
```

Sidebar mode generates a collapsible sidebar navigation suitable for documentation sites. The `max_depth` property limits nesting to prevent overwhelming navigation trees.

### Explicit Mode

```yaml
navigation:
  mode: explicit
  items:
    - title: "Getting Started"
      children:
        - doc: getting-started/installation
        - doc: getting-started/quick-start
    - title: "Guides"
      children:
        - doc: guides/expressions
        - doc: guides/input-bindings
```

Explicit mode gives full control over navigation structure, ordering, and grouping.

## See Also

- <doc:BuildingProjects>
- <doc:ProjectAPI>
- <doc:GettingStarted>
