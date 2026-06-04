# Reactive Evaluation

Understand how the dependency graph drives incremental recomputation when input values or code cell outputs change.

## Overview

RhoeMarkdown's reactive evaluation system ensures that when any source value changes -- an input field, a code cell output, or a cell edit -- all dependent expressions are recomputed automatically and efficiently. The system builds a dependency graph at evaluation time, then uses topological ordering to propagate changes with minimal work.

Reactive evaluation is the mechanism that makes interactive documents feel responsive: change a tax rate slider, and every formula that references it updates immediately without re-evaluating the entire document.

## Dependency Graph Concept

The dependency graph is a directed acyclic graph (DAG) where:

- **Source nodes** represent values that can change independently: input fields (`in.*`), bridge outputs (`out.*`), and manually edited cell values
- **Derived nodes** represent expressions that compute values from sources or other derived nodes
- **Edges** represent data dependencies: an edge from Y to X means "X depends on Y"

```
┌──────────────┐
│ in.tax_rate   │ ─────────────────────┐
│ (source)      │                       │
└──────────────┘                       ▼
                                ┌──────────────┐
┌──────────────┐                │ =C2*in.tax   │
│ Cell C2       │ ─────────────→│ (derived)     │ ────┐
│ (source)      │                └──────────────┘     │
└──────────────┘                                      ▼
                                                ┌──────────────┐
┌──────────────┐                                │ =SUM(D2:D5)  │
│ Cell C3       │ ──→ =C3*in.tax ──────────────→│ (derived)     │
│ (source)      │                                └──────────────┘
└──────────────┘
```

### Graph Construction

The `DependencyGraph` is constructed during Phase 5 execution by scanning all computable nodes in the normalized AST:

1. **Identify computable nodes** -- table cell formulas, inline expressions, input field bindings
2. **Parse references** from each expression -- cell references (`A1`, `B2:B5`), namespace references (`in.rate`, `out.data`), local function calls (`local.tax(...)`)
3. **Create edges** from each referenced node to the referencing expression
4. **Validate acyclicity** -- circular dependencies are detected and reported as `CYCLE_ERROR`

### Graph Properties

The dependency graph satisfies three invariants:

1. **Acyclicity** -- No circular dependency chains exist. A cycle means the system cannot determine evaluation order, so it is an error.
2. **Completeness** -- Every reference in every expression has a corresponding source node in the graph (or is flagged as `.missing`).
3. **Minimality** -- Only actual data dependencies create edges. Expressions in the same table that do not reference each other have no edges between them.

## Change Propagation Flow

When a source value changes, the reactive evaluator executes a four-step propagation:

### Step 1: Record the Change

The `InputValueStore` (for input fields) or the execution engine (for code cell outputs) records the new value. The changed node is marked as dirty.

### Step 2: Identify Dependents

The `DependencyGraph` traverses all outgoing edges from the changed node, collecting the transitive closure of dependent nodes:

```
in.tax_rate changed
  → D2 depends on in.tax_rate (direct)
  → D3 depends on in.tax_rate (direct)
  → D4 depends on in.tax_rate (direct)
  → D6 depends on D2, D3, D4 via SUM (transitive)
  → inline expression depends on D6 (transitive)
```

Only nodes reachable from the changed source are collected. Nodes with no dependency path from the change are untouched.

### Step 3: Topological Recomputation

Dependent nodes are recomputed in topological order -- a node evaluates only after all its dependencies have their new values:

```
Layer 0: in.tax_rate = 0.10  (new value)
Layer 1: D2 = C2 * 0.10      (recomputed)
         D3 = C3 * 0.10      (recomputed)
         D4 = C4 * 0.10      (recomputed)
Layer 2: D6 = SUM(D2:D4)     (recomputed after D2, D3, D4)
Layer 3: inline = TEXT(D6...) (recomputed after D6)
```

Nodes within the same layer are independent and can be evaluated in parallel.

### Step 4: Render Update

Changed values are written to the rendering context. Only cells and inline expressions whose values actually changed are re-rendered. If a recomputation produces the same value as before (e.g., `=IF(x > 0, "yes", "no")` where the branch does not change), the cell is not re-rendered.

## Cycle Detection

Circular dependencies are detected during graph construction, not at evaluation time. The graph builder uses depth-first traversal with a visited set to identify back edges.

When a cycle is detected:

1. All nodes participating in the cycle receive `ExprValue.error("CYCLE_ERROR", "Circular dependency: A2 -> B2 -> A2")`
2. The error message includes the full cycle path for debugging
3. Nodes outside the cycle are unaffected and evaluate normally
4. A diagnostic warning is emitted with the cycle path

### Common Cycle Patterns

```markdown
| A | B |
|---|---|
| =B2 | =A2 |  ← Direct cycle: A2 depends on B2, B2 depends on A2
```

```markdown
| =B2 + 1 | =C2 + 1 | =A2 + 1 |  ← Transitive cycle: A→B→C→A
```

## Performance Characteristics

### Incremental Evaluation

The reactive system evaluates only what changed. For a document with 1,000 expressions where one input field changes:

- **Without reactivity:** All 1,000 expressions re-evaluate
- **With reactivity:** Only the expressions transitively dependent on the changed input re-evaluate (typically 5-50)

### Bounded Recomputation

To prevent runaway cascades, the reactive evaluator enforces bounds:

| Bound | Limit | Error |
|-------|-------|-------|
| Maximum nodes per cycle | 1,000 | `EVAL_LIMIT` on remaining nodes |
| Maximum dependency depth | 256 levels | `EVAL_LIMIT` on deep nodes |
| Maximum evaluation steps | 10,000 per expression | `EVAL_LIMIT` on the expression |

If bounds are exceeded, affected nodes display `#LIMIT!` and a diagnostic warning identifies the bottleneck.

### Memory Characteristics

The dependency graph is stored as adjacency lists with O(N + E) space where N is the number of computable nodes and E is the number of dependency edges. For typical documents:

| Document Size | Nodes | Edges | Graph Memory |
|--------------|-------|-------|--------------|
| Small (1 table, 20 cells) | ~20 | ~40 | < 1 KB |
| Medium (5 tables, 200 cells) | ~200 | ~500 | ~10 KB |
| Large (50 tables, 2000 cells) | ~2,000 | ~5,000 | ~100 KB |

### Evaluation Timing

Expression evaluation is fast because expressions are pure arithmetic and function calls with no I/O:

| Operation | Typical Time |
|-----------|-------------|
| Single cell formula | < 1 microsecond |
| Aggregation over 100 cells | ~10 microseconds |
| Full propagation (50 nodes) | < 1 millisecond |
| Full propagation (500 nodes) | ~5 milliseconds |

These timings ensure that interactive documents with input fields feel instantaneous to users, even on mobile devices.

## Integration with Code Cells

Code cell outputs enter the dependency graph through the `out.*` namespace. When a code cell re-executes and produces a new bridge value, the reactive evaluator treats it as a source change and propagates to all dependent expressions.

However, code cell re-execution is not triggered by the reactive system. The reactive system only handles expression-level recomputation. Code cells are re-executed by the kernel orchestrator during Phase 5, or manually by the user.

The interaction flow:

```
User changes in.threshold
  → Expressions referencing in.threshold recompute (reactive)
  → Code cells are NOT re-executed (they use in.* at execution time only)
  → If user re-executes a code cell:
      → out.* value updates
      → Expressions referencing out.* recompute (reactive)
```

## See Also

- <doc:ExpressionsGuide>
- <doc:InputBindingsGuide>
- <doc:ExecutionEngine>
- <doc:ExecutionAPI>
