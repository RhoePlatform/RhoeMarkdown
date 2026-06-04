# Local Helper Functions

Define reusable, pure computation functions within your document to eliminate formula duplication and improve readability.

## Overview

Local functions let you name and reuse common computation patterns in your RhoeMarkdown expressions. Instead of repeating the same formula in every table cell, define it once as a local function and call it by name. Local functions are pure, side-effect-free, and evaluated inline -- they are syntactic sugar over the expression language, not a separate runtime.

## Declaration Syntax

Local functions are declared using the `<<fn>>` composition directive:

```markdown
<<fn function_name(param1, param2) = expression >>
```

The declaration consists of:

- `<<fn` -- The opening delimiter with function sigil
- `function_name` -- An alphanumeric name (plus underscores)
- `(param1, param2)` -- Zero or more comma-separated parameter names
- `= expression` -- The body expression that computes the return value
- `>>` -- The closing delimiter

### Zero-Parameter Functions

Functions with no parameters act as named constants or computed values:

```markdown
<<fn pi() = 3.14159265358979 >>
<<fn tax_rate() = in.rate / 100 >>
```

### Single-Parameter Functions

The most common pattern -- a single transformation applied to a value:

```markdown
<<fn with_tax(amount) = amount * (1 + in.tax_rate) >>
<<fn to_percent(value) = ROUND(value * 100, 1) >>
<<fn grade(score) = IF(score >= 90, "A", IF(score >= 80, "B", IF(score >= 70, "C", "F"))) >>
```

### Multi-Parameter Functions

Functions with multiple parameters for more flexible computation:

```markdown
<<fn discount(amount, rate) = amount * (1 - rate) >>
<<fn compound(principal, rate, years) = principal * POW(1 + rate, years) >>
<<fn clamp(value, low, high) = MAX(low, MIN(high, value)) >>
```

## Parameters and Let Bindings

### Parameters

Parameters are positional and required. Calling a function with the wrong number of arguments produces a `NAME_ERROR`:

```markdown
<<fn add(a, b) = a + b >>

=local.add(1, 2)       ← OK, returns 3
=local.add(1)           ← Error: NAME_ERROR (missing argument)
=local.add(1, 2, 3)    ← Error: NAME_ERROR (extra argument)
```

Parameters are immutable within the function body. They shadow any namespace references with the same name.

### Let Bindings

For complex functions, `let` bindings introduce named intermediate values:

```markdown
<<fn invoice_total(qty, price, tax_rate, discount_pct) =
    let subtotal = qty * price,
    let discount = subtotal * discount_pct / 100,
    let after_discount = subtotal - discount,
    let tax = after_discount * tax_rate,
    let total = after_discount + tax,
    total
>>
```

Let binding rules:

1. Each `let` binding is separated by a comma
2. Later bindings can reference earlier bindings
3. The final expression after all bindings is the return value
4. Bindings are immutable -- you cannot reassign a name
5. Bindings are scoped to the function body -- they do not leak into the calling context

### Shadowing

Let bindings can shadow parameters, though this is discouraged for clarity:

```markdown
<<fn adjust(amount) =
    let amount = amount * 1.1,
    amount
>>
```

Within the body after the `let`, `amount` refers to the binding, not the parameter.

## Calling from Expressions

Local functions are invoked through the `local.*` namespace, both in table cell formulas and inline expressions.

### In Table Cells

```markdown
<<fn margin(revenue, cost) = (revenue - cost) / revenue * 100 >>

| Product | Revenue | Cost  | Margin (%)              |
|---------|---------|-------|--------------------------|
| Alpha   | 500     | 350   | =local.margin(B2, C2)    |
| Beta    | 800     | 520   | =local.margin(B3, C3)    |
| Gamma   | 300     | 210   | =local.margin(B4, C4)    |
```

### In Inline Expressions

```markdown
<<fn format_usd(amount) = TEXT(amount, "$#,##0.00") >>

The total revenue is <<= local.format_usd(SUM(B2:B4)) >> with an average margin
of <<= ROUND(AVERAGE(D2:D4), 1) >>%.
```

### Composing Functions

Local functions can call other local functions:

```markdown
<<fn base_price(qty, unit_price) = qty * unit_price >>
<<fn with_discount(amount) = amount * (1 - in.discount / 100) >>
<<fn with_tax(amount) = amount * (1 + in.tax_rate) >>
<<fn final_price(qty, unit_price) = local.with_tax(local.with_discount(local.base_price(qty, unit_price))) >>
```

Composition chains are evaluated inside-out: `base_price` first, then `with_discount`, then `with_tax`.

## Purity Constraints

Local functions are subject to strict purity constraints that ensure deterministic, predictable evaluation:

### 1. No Side Effects

Functions cannot modify input field values, cell contents, or any document state. They receive values, compute a result, and return it. Nothing else changes.

### 2. No I/O

Functions cannot read files, make network requests, or interact with the system. They operate exclusively on their parameters and namespace references.

### 3. No Mutation

Parameters and let bindings are immutable. There are no assignment operators within function bodies. Each `let` creates a new binding rather than modifying an existing one.

### 4. Deterministic

Given the same parameter values and the same namespace state, a function always returns the same result. There is no randomness, no timestamp access, and no environment-dependent behavior within the function body.

### 5. No Recursion

Functions cannot call themselves, either directly or through mutual recursion:

```markdown
<<fn factorial(n) = IF(n <= 1, 1, n * local.factorial(n - 1)) >>
```

This produces `CYCLE_ERROR` at evaluation time. The evaluator tracks the call stack and detects when a function appears more than once. Recursive algorithms should use code cells with appropriate language kernels instead.

### Why Purity Matters

Purity constraints enable:

- **Safe caching** -- Function results can be memoized without invalidation concerns
- **Parallel evaluation** -- Independent function calls can execute concurrently
- **Predictable debugging** -- No hidden state means the function result depends only on visible inputs
- **Reactive correctness** -- The dependency graph accurately tracks all data flow through functions

## Practical Patterns

### Conditional Formatting

```markdown
<<fn status_badge(value, threshold) =
    IF(value >= threshold, "Pass", "Fail")
>>

<<fn risk_level(score) =
    IF(score >= 80, "Low",
    IF(score >= 50, "Medium",
    "High"))
>>
```

### Unit Conversion

```markdown
<<fn km_to_miles(km) = km * 0.621371 >>
<<fn celsius_to_fahrenheit(c) = c * 9/5 + 32 >>
<<fn bytes_to_mb(bytes) = ROUND(bytes / 1048576, 2) >>
```

### Financial Calculations

```markdown
<<fn monthly_payment(principal, annual_rate, years) =
    let monthly_rate = annual_rate / 12,
    let num_payments = years * 12,
    let factor = POW(1 + monthly_rate, num_payments),
    principal * monthly_rate * factor / (factor - 1)
>>

<<fn present_value(future_value, rate, periods) =
    future_value / POW(1 + rate, periods)
>>
```

### Data Formatting

```markdown
<<fn pct(value) = CONCAT(ROUND(value * 100, 1), "%") >>
<<fn delta(current, previous) =
    let change = (current - previous) / ABS(previous) * 100,
    IF(change >= 0, CONCAT("+", ROUND(change, 1), "%"), CONCAT(ROUND(change, 1), "%"))
>>
```

## See Also

- <doc:ExpressionsGuide>
- <doc:InputBindingsGuide>
- <doc:ReactiveModelGuide>
- <doc:ExecutionAPI>
