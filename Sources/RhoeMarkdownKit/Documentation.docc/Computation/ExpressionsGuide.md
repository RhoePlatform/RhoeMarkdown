# Expressions & Computation

Use the RhoeMarkdown expression language to compute values in table cells and inline text, creating dynamic documents that derive results from structured data.

## Overview

RhoeMarkdown includes a render-layer expression language that evaluates pure, side-effect-free formulas within your documents. Expressions compute display values from cell references, input field bindings, and built-in functions -- without requiring code cells or external runtimes.

Expressions are designed for document-level computation: totals, averages, conditional formatting, and data derivation. They are not a general-purpose programming language. For complex algorithms, data fetching, or I/O, use code cells with kernel runtimes instead.

## When to Use Expressions

Expressions are the right tool when you need to:

- **Compute table values** -- totals, averages, percentages, conditional cells
- **Derive inline text** -- dynamic values embedded in prose
- **React to input fields** -- recalculate when the user changes a form value
- **Format data** -- currency, percentages, rounding

Expressions are **not** the right tool when you need to:

- Run algorithms or data processing (use a Python/JavaScript code cell)
- Fetch data from external sources (use Phase 1 data sources or code cells)
- Modify document structure (use Phase 2 transforms)
- Generate images or artifacts (use code cells with artifact output)

## Table Cell Formulas

In any table cell, a leading `=` introduces a formula expression:

```markdown
| Item     | Qty | Price  | Total       |
|----------|-----|--------|-------------|
| Widgets  | 10  | 5.00   | =B2*C2      |
| Gizmos   | 5   | 12.50  | =B3*C3      |
| **Total**|     |        | =SUM(D2:D3) |
```

The expression engine evaluates each formula and replaces the cell content with the computed result. Cell references use spreadsheet-style notation: `A1` is column A row 1, `B2:B5` is the range from B2 to B5.

### Cell Reference Patterns

| Reference | Meaning |
|-----------|---------|
| `A1` | Single cell |
| `B2:B10` | Column range (for aggregation functions) |
| `A1:C3` | Rectangular range |
| `$A$1` | Absolute reference (fixed column and row) |
| `table1.A2` | Cross-table reference (by table ID) |

### Common Formula Patterns

```markdown
| Description          | Formula               | Purpose                    |
|---------------------|-----------------------|----------------------------|
| Row product         | =B2*C2                | Multiply two cells          |
| Column sum          | =SUM(B2:B10)          | Sum a range                 |
| Conditional value   | =IF(C2>100, "High", "Low") | Branch on condition   |
| Percentage          | =D2/D10*100           | Compute percentage          |
| Running total       | =SUM(D$2:D2)          | Cumulative sum              |
```

## Inline Expressions

Within paragraph text, the `<<= >>` delimiter pair introduces an inline expression:

```markdown
The project has <<= COUNT(A2:A10) >> items with a total cost
of <<= TEXT(SUM(D2:D10), "$#,##0.00") >>.
```

Inline expressions can reference table cells, input field values, and bridge outputs from code cells. They participate in the same reactive dependency graph as table formulas.

### Inline Expression Examples

```markdown
Your effective rate is <<= in.base_rate * (1 + in.surcharge) >>%.

The mean score is <<= AVERAGE(B2:B20) >> with a range of
<<= MAX(B2:B20) - MIN(B2:B20) >>.

Status: <<= IF(out.test_result.passed, "All tests passed", "Failures detected") >>
```

## Namespace References

Expressions access values from four namespace domains:

### Input Fields (`in.*`)

Read current values from interactive input fields declared with `{? ?}` syntax:

```markdown
{? name: "discount", type: number, default: 0.10 ?}

| Item  | Price | Discount            | Final              |
|-------|-------|---------------------|---------------------|
| Bolt  | 5.00  | =C2 * in.discount   | =C2 - D2           |
```

When the user changes the discount value, all dependent expressions recalculate automatically.

### Document Metadata (`doc.*`)

Read values from YAML frontmatter:

```markdown
---
title: "Budget Report"
fiscal_year: 2026
---

This is the <<= doc.title >> for FY<<= doc.fiscal_year >>.
```

### Bridge Outputs (`out.*`)

Read values produced by code cells via the bridge protocol:

````markdown
```python {out=stats}
import statistics
data = [23, 45, 67, 89, 12]
{"mean": statistics.mean(data), "stdev": statistics.stdev(data)}
```

The mean is <<= ROUND(out.stats.mean, 2) >> with standard deviation <<= ROUND(out.stats.stdev, 2) >>.
````

### Local Functions (`local.*`)

Call locally defined helper functions:

```markdown
<<fn tax(amount) = amount * in.tax_rate >>

Tax on the first item: <<= local.tax(C2) >>
```

## Built-in Functions

The expression language includes 30+ built-in functions organized by category. Function names are case-insensitive.

### Aggregation

`SUM`, `AVERAGE`, `MIN`, `MAX`, `COUNT`, `PROD` -- operate on cell ranges or arrays.

### Arithmetic

`ADD`, `SUB`, `MUL`, `DIV`, `MOD`, `POW` -- named alternatives to operators.

### Math

`ABS`, `ROUND`, `FLOOR`, `CEIL` -- numeric transformations.

### Logic

`IF(condition, then, else)` -- conditional branching.

### String

`LEN`, `UPPER`, `LOWER`, `CONCAT`, `TEXT` -- string manipulation and formatting.

### Type Coercion

`NUMBER`, `STRING`, `BOOL` -- explicit type conversion.

## Error Handling

When an expression encounters an error, it produces an `ExprValue.error` with a diagnostic code:

| Display | Meaning |
|---------|---------|
| `#DIV/0!` | Division by zero |
| `#REF!` | Invalid cell reference |
| `#NAME?` | Unknown function or variable |
| `#VALUE!` | Type coercion failure |
| `#CYCLE!` | Circular dependency |

Errors propagate through dependent expressions. The `.missing` sentinel is distinct from errors: it means a value has not yet been resolved (e.g., a code cell has not executed), while `.error` means computation failed.

### Handling Missing Values

```markdown
| Safe Total | =IF(A2 == null, 0, A2) + IF(B2 == null, 0, B2) |
```

Aggregation functions like `SUM` and `AVERAGE` skip `.missing` values automatically, so `=SUM(A2:A10)` works correctly even if some cells are empty.

## Worked Example: Budget Calculator

```markdown
{? name: "tax_rate", type: number, default: 0.08, label: "Tax Rate" ?}
{? name: "shipping", type: number, default: 15.00, label: "Shipping" ?}

<<fn with_tax(amount) = amount * (1 + in.tax_rate) >>

| Item       | Qty | Unit Price | Subtotal    | With Tax                  |
|------------|-----|------------|-------------|---------------------------|
| Laptop     | 2   | 999.00     | =B2*C2      | =local.with_tax(D2)       |
| Monitor    | 3   | 349.00     | =B3*C3      | =local.with_tax(D3)       |
| Keyboard   | 5   | 79.00      | =B4*C4      | =local.with_tax(D4)       |
| **Subtotal**|    |            | =SUM(D2:D4) | =SUM(E2:E4)               |
| **Shipping**|    |            |             | =in.shipping               |
| **Total**  |    |            |             | =SUM(E2:E4) + in.shipping |

Grand total: <<= TEXT(SUM(E2:E4) + in.shipping, "$#,##0.00") >>
```

This example demonstrates table formulas, input field bindings, local functions, inline expressions, and the `TEXT` formatting function working together.

## See Also

- <doc:InputBindingsGuide>
- <doc:ReactiveModelGuide>
- <doc:LocalFunctionsGuide>
- <doc:ExecutionEngine>
