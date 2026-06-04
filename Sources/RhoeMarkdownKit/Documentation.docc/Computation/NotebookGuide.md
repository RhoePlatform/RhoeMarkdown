# Notebook Format

The `.rhoenb` package format for persistent, version-controlled computational documents.

## Overview

RhoeMarkdown notebooks (`.rhoenb`) are directory packages that bundle a RhoeMarkdown source document with execution state, output artifacts, and configuration metadata. The format is designed for computational authoring workflows where code cell results, reactive store snapshots, and generated assets must persist across editing sessions and travel through version control.

A `.rhoenb` package is a plain directory with a fixed internal layout. Tools that do not understand the format can still read the source Markdown directly.

## Package Structure

A notebook package has the following layout:

```
my-notebook.rhoenb/
  manifest.json          # Package metadata and configuration
  document.md            # The RhoeMarkdown source document
  state/
    store.json           # Reactive store snapshot
    cells/
      cell-0.json        # Per-cell execution state
      cell-1.json
      ...
  assets/
    plot-abc123.png      # Generated display outputs
    data-def456.csv      # Exported data artifacts
  .rhoenb-lock           # Lock file for concurrent access
```

### manifest.json

The manifest declares the package version, kernel requirements, and execution configuration:

```json
{
  "formatVersion": "1.0",
  "rhoemarkdownVersion": "3.3",
  "title": "Data Analysis Notebook",
  "created": "2026-03-15T10:30:00Z",
  "modified": "2026-03-27T14:22:00Z",
  "kernels": {
    "python": {
      "version": ">=3.11",
      "packages": ["numpy", "pandas", "matplotlib"]
    }
  },
  "persistence": "selective",
  "executionOrder": "topological"
}
```

Key fields:

| Field | Type | Purpose |
| --- | --- | --- |
| `formatVersion` | String | Package format version (currently `"1.0"`) |
| `rhoemarkdownVersion` | String | Minimum RhoeMarkdown version required |
| `title` | String | Human-readable notebook title |
| `kernels` | Object | Per-kernel version and dependency requirements |
| `persistence` | String | Persistence mode: `"all"`, `"selective"`, or `"none"` |
| `executionOrder` | String | Cell ordering: `"topological"` or `"document"` |

### document.md

The source document is a standard RhoeMarkdown file. It contains all prose, code cells, expressions, and input fields. The document is the single source of truth for content; the state sidecar only stores execution results.

### State Sidecar

The `state/` directory holds execution results so that opening a notebook does not require re-executing every cell.

**store.json** contains the full reactive store snapshot:

```json
{
  "version": 42,
  "timestamp": "2026-03-27T14:22:00Z",
  "bindings": {
    "data": { "$rhoe:kind": "dataframe", "columns": ["x", "y"], "data": [[1, 2], [3, 4]] },
    "result": { "$rhoe:kind": "float", "value": 2.5 }
  }
}
```

**cells/cell-N.json** stores per-cell execution metadata:

```json
{
  "cellIndex": 0,
  "language": "python",
  "executedAt": "2026-03-27T14:22:00Z",
  "duration": 0.342,
  "status": "success",
  "outputs": [
    { "type": "text", "content": "Processing complete." },
    { "type": "image", "asset": "assets/plot-abc123.png", "mime": "image/png" }
  ],
  "inputHash": "a1b2c3d4",
  "codeHash": "e5f6g7h8"
}
```

The `inputHash` and `codeHash` fields enable staleness detection: if the code or its input bindings change, the cell is marked stale and queued for re-execution.

## Persistence Modes

The `persistence` field in the manifest controls what execution state is stored:

| Mode | Behavior |
| --- | --- |
| `all` | Every cell's output, every store binding, and all generated assets are persisted. Notebooks open instantly with full state. |
| `selective` | Only cells marked with `{persist}` in their attributes have state stored. Other cells re-execute on open. Balances storage with reproducibility. |
| `none` | No execution state is stored. The state directory is empty. Every open triggers full re-execution. Guarantees reproducibility at the cost of startup time. |

The default mode is `selective`.

## Git Lifecycle

The `.rhoenb` format is designed for version control with Git. The recommended `.gitignore` and `.gitattributes` configuration:

### What to Track

| Path | Track? | Reason |
| --- | --- | --- |
| `manifest.json` | Yes | Configuration is part of the document |
| `document.md` | Yes | Source of truth |
| `state/store.json` | Optional | Enables instant open; can be regenerated |
| `state/cells/*.json` | Optional | Execution metadata; can be regenerated |
| `assets/*.png` | Optional | Large binaries; consider Git LFS |
| `.rhoenb-lock` | No | Runtime artifact |

### Recommended .gitignore

```
*.rhoenb/.rhoenb-lock
*.rhoenb/state/
```

For teams that want shared state (avoiding re-execution for reviewers):

```
*.rhoenb/.rhoenb-lock
```

### Merge Strategy

The `document.md` file merges like any Markdown file. The `state/` directory should use an "ours" merge strategy since execution state is regenerable:

```gitattributes
*.rhoenb/state/** merge=ours
*.rhoenb/assets/** merge=ours filter=lfs diff=lfs
```

### Diff and Review

Git diffs of `.rhoenb` packages show meaningful changes in `document.md` and `manifest.json`. State files produce noisy diffs that reviewers typically ignore. The `rhoemd diff` command provides a notebook-aware diff that highlights source changes and summarizes output deltas.

## Concurrent Access

The `.rhoenb-lock` file prevents concurrent writes from multiple processes. The lock uses advisory file locking with a PID and timestamp:

```json
{
  "pid": 12345,
  "timestamp": "2026-03-27T14:22:00Z",
  "host": "workstation.local"
}
```

If the lock is stale (process no longer running), it is automatically broken. The lock is never committed to version control.

## Creating and Opening Notebooks

### Programmatic Creation

```swift
import RhoeMarkdownKit

let notebook = try Notebook.create(
    at: "analysis.rhoenb",
    title: "Data Analysis",
    persistence: .selective,
    kernels: [.python(version: ">=3.11", packages: ["numpy", "pandas"])]
)
```

### CLI

```bash
# Create a new notebook
rhoemd notebook create analysis.rhoenb --title "Data Analysis"

# Execute all cells
rhoemd notebook run analysis.rhoenb

# Export to standalone HTML
rhoemd notebook export analysis.rhoenb --format html --output analysis.html

# Clear execution state
rhoemd notebook clean analysis.rhoenb
```

## Widget & Tab Surfaces

Notebooks support two kinds of auxiliary surface blocks that create additional UI panes alongside the main document.

### Widget Blocks

Widget blocks produce compact, inline panels for status summaries, progress indicators, or auxiliary controls:

```markdown
::: widget {title="Run Summary" id=summary-widget}
Current status: **complete**. Duration: 2.3s.
:::
```

Widgets accept the standard attribute set. The `title` attribute provides the panel header and `id` enables cross-referencing from expressions or other blocks. In non-notebook contexts, widgets degrade to styled aside blocks.

### Tab Blocks

Tab blocks create full-size companion surfaces that appear as separate tabs in the notebook UI:

```markdown
::: tab {title="Analysis Results" id=results-tab}
## Findings
Detailed analysis content here.
:::
```

Tabs can contain any block-level content including code cells, tables, and visualizations. In non-notebook contexts, tabs degrade to document sections. The `title` attribute sets the tab label; `id` enables programmatic activation from expressions.

## Structural Execution

Structural execution blocks define typed, composable execution pipelines within a notebook. The three primary constructs are stages, lanes, and modules.

### Stages

A stage defines a pipeline execution pattern. Stages use the `::: stage.<kind>` syntax, where the kind determines the execution topology:

```markdown
::: stage.rack
=== lane
::: module.transform.map
Map each input record to the output schema.
:::
===
=== lane
::: module.transform.filter
Remove records that fail validation.
:::
===
:::
```

| Kind | Description |
| --- | --- |
| `rack` | Fan-out / parallel merge: all lanes execute concurrently and results merge |
| `case` | Conditional lane selection: one lane is chosen based on a guard expression |
| `template` | Replica expansion: the lane body is instantiated once per element |
| `iterate` | Sequential bounded recurrence: the lane body re-executes until a condition is met |
| `adapter` | Shape adaptation: transforms the data shape between pipeline segments |

### Lanes

Lanes are the execution slots within a stage, delimited by `=== lane ... ===`. Each lane contains one or more module blocks and optional prose. Lanes inherit the execution semantics of their parent stage kind.

### Modules

Modules are typed execution units that perform a specific operation. They use `:::` with a dotted `module.<family>.<name>` identifier:

```markdown
::: module.transform.map
Map each record.
:::

::: module.records.filter {predicate="score > 0.5"}
Filter records by score threshold.
:::
```

Module families group related operations:

| Family | Purpose |
| --- | --- |
| `transform` | Data mapping, filtering, aggregation |
| `records` | Record-level operations (filter, sort, group) |
| `validate` | Schema and constraint validation |
| `io` | File, network, and external system I/O |
| `debug` | Logging, breakpoints, inspection |
| `interaction` | User prompts and confirmations |
| `variables` | Store read/write operations |
| `connector` | External service integrations |

### Contract Directives

Input and output contracts declare the data bindings for a stage, using the `!!!` admonition syntax with reserved keywords:

```markdown
!!! input
from: run.records
defaults: { limit: 100 }
!!!

!!! output
to: run.validated
format: json
!!!
```

Contracts enable the execution engine to wire stages together and validate data flow at compile time.

## History Model

Notebooks maintain a history of execution over three dimensions:

### Runs

A run captures a single top-to-bottom execution of the notebook. Each run records cell outputs, store snapshots, and timing metadata. Runs are identified by an auto-incrementing integer and an ISO 8601 timestamp.

### Experiments

An experiment groups related runs that explore variations of the same analysis. Experiments track parameter sweeps, hyperparameter searches, or A/B comparisons. Each experiment has a name, a description, and a list of associated run IDs.

### Frozen Versions

A frozen version is a point-in-time snapshot of the complete notebook state: document source, store bindings, cell outputs, and generated assets. Frozen versions are immutable and can be exported as standalone HTML or PDF artifacts. They serve as the unit of sharing and publication.

The lifecycle flows from authoring through execution (runs), optional grouping (experiments), and eventual publication (frozen versions).

## Package Browser

The `.rhoenb` package is a directory bundle that tools can inspect without executing:

### Bundle Structure

```
my-notebook.rhoenb/
  manifest.json          # Package metadata and configuration
  document.md            # RhoeMarkdown source document
  state/
    store.json           # Reactive store snapshot
    cells/               # Per-cell execution state
  assets/                # Generated display outputs and data artifacts
  .rhoenb-lock           # Runtime lock file (not committed)
```

### File Classification

| Category | Files | Purpose |
| --- | --- | --- |
| Source | `document.md` | Editable content — always version-controlled |
| Config | `manifest.json` | Kernel requirements, persistence mode, metadata |
| State | `state/store.json`, `state/cells/*.json` | Execution results — optionally version-controlled |
| Assets | `assets/*` | Generated images, data exports — consider Git LFS |
| Runtime | `.rhoenb-lock` | Concurrency lock — never committed |

### Preview

The `rhoemd notebook preview` command renders a notebook package to a temporary local server for browser-based inspection without modifying the package contents. The preview reflects the most recent persisted state and highlights stale cells.

## See Also

- <doc:MultiKernelGuide>
- <doc:ExpressionsGuide>
- <doc:InputBindingsGuide>
- <doc:ReactiveModelGuide>
