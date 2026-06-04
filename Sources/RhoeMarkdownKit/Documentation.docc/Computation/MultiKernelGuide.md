# Multi-Kernel Execution

Running computable code blocks across seven language kernels with typed bridging and sandbox isolation.

## Overview

RhoeMarkdown `0.1.0` documents can carry computable code-block metadata for execution kernels. A fenced code block with a recognized language tag and bridge attributes becomes a live code cell in runtimes that opt into execution: the execution engine dispatches it to the appropriate kernel, captures output, and feeds results back into the document's reactive store.

Code cells participate in the five-phase pipeline at the Execute stage. They can read values produced by earlier cells or input fields, run computation, and write results that downstream expressions and cells consume.

## Supported Kernels

| Kernel | Language | Runtime | Notes |
| --- | --- | --- | --- |
| `python` | Python 3.x | CPython subprocess | NumPy, pandas, matplotlib available when installed |
| `javascript` | JavaScript ES2022+ | JavaScriptCore (embedded) | In-process for low-latency evaluation |
| `julia` | Julia 1.x | Julia subprocess | Full Julia standard library |
| `r` | R 4.x | Rscript subprocess | Tidyverse-compatible |
| `deno` | TypeScript | Deno subprocess | Secure by default, explicit permissions |
| `swift` | Swift 6.x | Swift subprocess | Full Foundation and standard library |
| `rust` | Rust stable | Compile-and-execute via `rustc` | Single-file programs, no Cargo |

Each subprocess kernel is spawned on first use and reused for subsequent cells within the same document execution. JavaScriptCore runs in-process for minimal overhead.

## Code Cell Syntax

A code cell is a standard fenced code block annotated with bridge attributes that declare its data inputs and outputs:

````markdown
```python {in=data out=result}
import statistics
result = statistics.mean(data)
```
````

The `in=` attribute names variables that are injected into the kernel's namespace before execution. The `out=` attribute names variables that are captured from the kernel's namespace after execution and written back to the document's reactive store.

Multiple inputs and outputs are comma-separated:

````markdown
```python {in=prices,quantities out=total,average}
total = sum(p * q for p, q in zip(prices, quantities))
average = total / len(quantities)
```
````

### Kernel Selection

The kernel is selected by the code block's language tag. If the tag is not one of the seven recognized kernels, the block is treated as a static code block and is not executed.

### Display Output

Cells can produce display output (charts, tables, HTML fragments) in addition to variable bindings. Display output is captured from stdout and, for kernels that support it, from rich display hooks:

````markdown
```python {out=plot}
import matplotlib.pyplot as plt
plt.plot([1, 2, 3], [4, 5, 6])
plt.title("Example")
plt.savefig("$rhoe:display")  # Magic path triggers capture
```
````

## Bridge Protocol

The bridge protocol governs how values are serialized between the document's reactive store and kernel namespaces. All values cross the boundary as `BridgeValue`, a typed encoding that preserves structure and type information.

### BridgeValue Types

| Type Tag | Swift Type | JSON Encoding |
| --- | --- | --- |
| `null` | `nil` | `null` |
| `bool` | `Bool` | `true` / `false` |
| `int` | `Int64` | Number |
| `float` | `Double` | Number |
| `string` | `String` | String |
| `array` | `[BridgeValue]` | Array |
| `object` | `[String: BridgeValue]` | Object |
| `bytes` | `Data` | Base64 string |
| `image` | Image data | Base64 with MIME |
| `dataframe` | Tabular data | Column-oriented object |

### Tagged JSON Encoding

On the wire, bridge values use `$rhoe:kind` tagged JSON to disambiguate types that JSON conflates:

```json
{
  "$rhoe:kind": "dataframe",
  "columns": ["name", "score"],
  "data": [["Alice", 95], ["Bob", 87]]
}
```

The `$rhoe:kind` tag is stripped when deserializing into a kernel's native types. Python receives a pandas DataFrame; JavaScript receives a plain object; Julia receives a DataFrame from DataFrames.jl.

### Type Mapping

Each kernel maps BridgeValue types to its native equivalents:

| BridgeValue | Python | JavaScript | Julia | R | Swift |
| --- | --- | --- | --- | --- | --- |
| `int` | `int` | `number` | `Int64` | `integer` | `Int64` |
| `float` | `float` | `number` | `Float64` | `numeric` | `Double` |
| `string` | `str` | `string` | `String` | `character` | `String` |
| `array` | `list` | `Array` | `Vector` | `list` | `[BridgeValue]` |
| `object` | `dict` | `Object` | `Dict` | `list` (named) | `[String: BridgeValue]` |
| `dataframe` | `pd.DataFrame` | `Object` | `DataFrame` | `data.frame` | `DataFrame` |

## Sandbox Isolation

Every kernel execution operates under a sandbox that enforces 12 prohibitions to protect the host system and ensure reproducibility:

1. **No filesystem writes** outside a designated scratch directory
2. **No network access** unless explicitly granted via `{net=allow}`
3. **No process spawning** beyond the kernel's own runtime
4. **No environment variable mutation** of the host process
5. **No signal handling** that could affect the host
6. **No shared memory** access across kernel instances
7. **No GPU access** unless explicitly granted via `{gpu=allow}`
8. **No stdin reads** (all input comes through bridge variables)
9. **No persistent state** between document executions (cells within a single execution share state)
10. **No clock manipulation** (system time is read-only)
11. **No dynamic library loading** outside the kernel's standard library
12. **No raw socket creation**

Violations are caught at the runtime level and reported as execution errors with the offending operation identified.

### Resource Limits

Each cell execution is subject to configurable resource limits:

| Resource | Default | Attribute Override |
| --- | --- | --- |
| Wall-clock timeout | 30 seconds | `{timeout=60}` |
| Memory ceiling | 256 MB | `{mem=512mb}` |
| Output capture size | 1 MB | `{maxout=5mb}` |
| Scratch disk | 50 MB | `{disk=100mb}` |

Exceeding any limit terminates the cell with a resource-limit error.

## See Also

- <doc:ExecutionEngine>
- <doc:ExpressionsGuide>
- <doc:NotebookGuide>
- <doc:InputBindingsGuide>
