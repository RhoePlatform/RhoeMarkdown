# Execution Engine Architecture

Understand the five-phase execution pipeline that transforms RhoeMarkdown source into fully evaluated, rendered output with computed values, executed code cells, and reactive expressions.

## Overview

The RhoeMarkdown execution engine extends the parser-renderer pipeline with computation capabilities. Where the core pipeline handles text parsing and HTML generation, the execution engine adds expression evaluation, code cell execution, bridge protocol communication, and reactive dependency tracking.

The execution engine is Phase 5 of the five-phase pipeline defined in the RhoeMarkdown v3.2 specification. It operates on the fully normalized AST produced by Phases 1 through 4, evaluating all computable content and producing the final document state.

## Five-Phase Pipeline Overview

The compilation pipeline processes a RhoeMarkdown document through five strictly ordered phases:

```
Source Text
    │
    ▼
┌──────────────────────────────────┐
│ Phase 1: Preprocessing (Liquid)   │
│ {{ }}, {% %}  →  expanded text    │
└──────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────┐
│ Phase 2: AST Construction         │
│ GFMLexer → GFMParser → Document   │
└──────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────┐
│ Phase 3: AST Transformation       │
│ ComponentExpansionPass            │
│ ExtensionResolutionPass           │
│ Phase2ExecutionPass               │
└──────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────┐
│ Phase 4: Normalization            │
│ CrossReferenceNumberingPass       │
│ CrossReferenceResolutionPass      │
│ ProjectionFilteringPass           │
│ CitationResolutionPass            │
└──────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────┐
│ Phase 5: Execution                │
│ ExpressionEngine                  │
│ Kernel Orchestrator               │
│ BridgeProtocol                    │
│ ReactiveEvaluator                 │
└──────────────────────────────────┘
    │
    ▼
Evaluated AST + Artifacts
```

Each phase consumes the output of the previous phase. Phases are not interleaved: Phase N completes entirely before Phase N+1 begins. This strict ordering ensures that each phase operates on a well-defined, stable input.

### Phase Responsibilities

| Phase | Engine | Responsibility |
|-------|--------|----------------|
| 1 | RhoeLiquidKit | Expand `{{ }}` and `{% %}` template directives |
| 2 | GFMParser | Lex, parse, and build the structural AST |
| 3 | DocumentPipeline (Tier A) | Expand components, resolve extensions, execute Phase 2 transforms |
| 4 | DocumentPipeline (Tier B+C) | Number elements, resolve references, filter projections, resolve citations |
| 5 | Execution Engine | Evaluate expressions, execute code cells, manage bridge protocol, drive reactivity |

## Graph Derivation

Before any computation begins, the execution engine derives an execution graph from the normalized AST. The graph is a directed acyclic graph (DAG) representing all computable nodes and their data dependencies.

### Graph Construction

```swift
// Conceptual graph construction
let graph = ExecutionGraph()

for node in ast.computableNodes {
    graph.addNode(node)
    for ref in node.dependencies {
        graph.addEdge(from: ref.source, to: node)
    }
}

try graph.validateAcyclicity()
let order = graph.topologicalSort()
```

The graph construction scans the AST for:

- Table cell formulas (`=expr`)
- Inline expressions (`<<= expr >>`)
- Code cells with bridge attributes (`in=`, `out=`)
- Input field bindings with expression dependencies

### Topological Execution

Computable nodes execute in topological order: a node evaluates only after all its dependencies have completed. Nodes with no mutual dependencies can execute in parallel.

```
Layer 0: [input fields, independent code cells, constant expressions]
Layer 1: [cells depending on Layer 0 outputs]
Layer 2: [cells depending on Layer 1 outputs]
...
```

Each layer can be parallelized. Layers execute sequentially, respecting the dependency ordering.

## Kernel Implementations

The execution engine supports seven language kernels for code cell execution. Each kernel provides an isolated execution environment for a specific programming language.

### Supported Kernels

| Kernel | Language | Isolation |
|--------|----------|-----------|
| `python` | Python 3.x | Subprocess or WASM (Pyodide) |
| `javascript` | JavaScript ES2022+ | JavaScriptCore or V8 isolate |
| `julia` | Julia 1.x | Subprocess |
| `r` | R 4.x | Subprocess |
| `deno` | TypeScript | Deno subprocess (`--allow-none`) |
| `swift` | Swift 6.x | Subprocess or in-process |
| `rust` | Rust (stable) | Compile-and-execute via `rustc` |

### Kernel Lifecycle

Each kernel follows a four-stage lifecycle:

1. **Initialize** -- Create the kernel process or isolate. Load the standard library. Apply sandbox restrictions.
2. **Configure** -- Apply per-document settings: timeout limits, memory caps, allowed imports.
3. **Execute** -- Send code cells in topological order. Capture results via the result contract.
4. **Teardown** -- Destroy the kernel. Release all resources. No state persists between documents.

### Per-Document Runtime

A document gets one kernel instance per language. If a document has both Python and JavaScript cells, two independent kernels exist. Within a language, cells share state by default (`runtime=shared`), following the Jupyter notebook model.

### Sandbox Enforcement

Every kernel enforces the twelve prohibitions from the isolation doctrine:

- No AST access, no numbering engine, no cross-reference state
- No frontmatter access, no Phase 1/Phase 2 state
- No document DOM, no parser state, no introspection
- No AST mutation, no implicit data access

Enforcement is architectural: the kernel process simply does not have APIs for document access. There is no `document` object, no `ast` object, no `compiler` object in the kernel environment.

## Bridge Protocol

The bridge protocol enables typed data exchange between code cells, between kernels, and between code cells and the expression engine.

### Data Flow

```
Python cell (out=data) ──→ BridgeValue ──→ JavaScript cell (in=data)
                                │
                                └──→ Expression (out.data.mean)
```

### BridgeValue Encoding

All bridge values are serialized as tagged JSON with `$rhoe:kind` discriminators:

```json
{
    "$rhoe:kind": "object",
    "value": {
        "mean": { "$rhoe:kind": "number", "value": 42.5 },
        "label": { "$rhoe:kind": "string", "value": "result" }
    }
}
```

The `BridgeEncoder` serializes Swift-side `ExprValue` instances to tagged JSON. The `BridgeDecoder` deserializes tagged JSON back to `ExprValue`. Type preservation across serialization boundaries ensures that a number stays a number, an array stays an array, and errors carry their diagnostic codes.

### Type Mapping

Bridge values map to kernel-native types automatically:

- `number` becomes `float` (Python), `number` (JS), `Float64` (Julia)
- `string` becomes `str` (Python), `string` (JS), `String` (Julia)
- `dataframe` becomes `pandas.DataFrame` (Python), `Array<Object>` (JS)

## Sandbox Boundaries

The execution engine maintains strict boundaries between the computation layer and the document model:

### What Code Cells CAN Do

- Read their own source code parameters
- Access explicitly bridged input values (`in=`)
- Produce output values (`out=`)
- Write to stdout/stderr (captured by result contract)
- Generate artifacts (images, data files)
- Use language-standard libraries (policy-gated)

### What Code Cells CANNOT Do

- Read the AST or any document structure
- Modify numbering, references, or projections
- Access frontmatter, Liquid state, or Phase 2 transforms
- Inject content that creates global authority
- Execute other code cells or trigger re-evaluation
- Access the filesystem or network (unless policy-gated)

### Result Sanitization

All code cell output passes through Safe Result Markdown parsing before reaching the document. Forbidden constructs (Liquid delimiters, Phase 2 directives, frontmatter, reference targets) are escaped or stripped. This ensures that code cells cannot escalate their privileges through their output channel.

## Expression Engine

The `ExpressionEngine` evaluates table cell formulas and inline expressions. It is a synchronous, pure evaluator with no side effects:

```swift
// Conceptual usage
let engine = ExpressionEngine(context: evaluationContext)
let result = engine.evaluate("SUM(B2:B5) * in.tax_rate")
// result: ExprValue.number(42.0)
```

### Evaluation Properties

- **Pure** -- No side effects, no state mutation
- **Bounded** -- Maximum 256 recursion depth, 10,000 evaluation steps
- **Type-safe** -- Full `ExprValue` type system with explicit coercion rules
- **Error-propagating** -- Errors flow through expressions with diagnostic codes

### Integration with Kernels

The expression engine consumes bridge outputs from code cells through the `out.*` namespace. When a code cell produces a bridge value, it becomes available to all expressions that reference it. If the cell has not yet executed, `out.*` references resolve to `.missing`.

## See Also

- <doc:ExpressionsGuide>
- <doc:ReactiveModelGuide>
- <doc:ExecutionAPI>
- <doc:Security>
