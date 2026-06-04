# Input Bindings & Forms

Declare interactive input fields in your documents and bind them to expressions for dynamic, reactive computation.

## Overview

RhoeMarkdown input bindings connect interactive form elements to the expression engine. When a user changes an input value, all expressions that reference that value are automatically recomputed, and the document updates in real time. This creates interactive documents -- budgets, calculators, configurators, and decision tools -- entirely within Markdown.

Input bindings use three components working together:

1. **Input field declarations** (`{? ?}`) define the fields, their types, and default values
2. **Form containers** group related fields into logical units
3. **Expression references** (`in.*` namespace) consume field values in formulas and inline text

## Declaring Input Fields

Input fields are declared using the parser-native `{? ?}` placeholder syntax. Each field has a name, a type, and optional configuration:

```markdown
{? name: "quantity", type: number, default: 1, min: 0, max: 100 ?}
{? name: "product_name", type: text, default: "Widget", placeholder: "Enter product name" ?}
{? name: "priority", type: select, options: ["Low", "Medium", "High"], default: "Medium" ?}
{? name: "include_tax", type: toggle, default: true ?}
```

### Field Types

| Type | HTML Element | Description |
|------|-------------|-------------|
| `text` | `<input type="text">` | Single-line text input |
| `number` | `<input type="number">` | Numeric input with optional min/max/step |
| `select` | `<select>` | Dropdown selection from a list of options |
| `toggle` | `<input type="checkbox">` | Boolean on/off switch |
| `slider` | `<input type="range">` | Numeric slider with min/max/step |
| `date` | `<input type="date">` | Calendar date picker |
| `textarea` | `<textarea>` | Multi-line text input |
| `radio` | `<input type="radio">` | Radio button group (single selection) |
| `color` | `<input type="color">` | Color picker |

### Field Configuration

Each field type supports type-specific configuration attributes:

#### Number Fields

```markdown
{? name: "rate", type: number, default: 5.0, min: 0, max: 100, step: 0.5, label: "Interest Rate (%)" ?}
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `default` | number | Initial value |
| `min` | number | Minimum allowed value |
| `max` | number | Maximum allowed value |
| `step` | number | Increment/decrement step size |
| `label` | string | Human-readable label |
| `placeholder` | string | Placeholder text when empty |

#### Text Fields

```markdown
{? name: "company", type: text, default: "Acme Corp", maxlength: 100, label: "Company Name" ?}
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `default` | string | Initial value |
| `maxlength` | number | Maximum character count |
| `pattern` | string | Validation regex pattern |
| `label` | string | Human-readable label |
| `placeholder` | string | Placeholder text |

#### Select Fields

```markdown
{? name: "region", type: select, options: ["North", "South", "East", "West"], default: "North", label: "Sales Region" ?}
```

| Attribute | Type | Description |
|-----------|------|-------------|
| `options` | array | List of selectable values |
| `default` | string | Initially selected value |
| `label` | string | Human-readable label |
| `multiple` | bool | Allow multiple selections (default: false) |

#### Slider Fields

```markdown
{? name: "confidence", type: slider, default: 50, min: 0, max: 100, step: 5, label: "Confidence Level" ?}
```

Sliders share the same attributes as number fields, with the visual presentation as a range slider.

## Form Containers

Form containers group related input fields into logical units. They provide visual grouping, shared validation, and transactional semantics.

### Basic Form Container

```markdown
!!! form {id=pricing-inputs title="Pricing Parameters"}
{? name: "base_price", type: number, default: 100, label: "Base Price ($)" ?}
{? name: "tax_rate", type: number, default: 0.08, step: 0.01, label: "Tax Rate" ?}
{? name: "discount", type: slider, default: 0, min: 0, max: 50, label: "Discount (%)" ?}
!!!
```

### Form Container Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | string | Unique identifier for the form |
| `title` | string | Display title |
| `layout` | string | Layout mode: `vertical` (default), `horizontal`, `grid` |
| `collapsed` | bool | Start in collapsed state (default: false) |

### Form Transactions

The `FormTransactionManager` ensures that multiple related field changes are applied atomically. When a user interacts with fields inside a form container, changes are batched:

1. User modifies field A
2. User modifies field B
3. Both changes are applied together
4. Dependent expressions recalculate once (not twice)

This prevents flickering and intermediate invalid states when multiple fields contribute to the same computation.

## Binding to Expressions

Input field values are accessed in expressions through the `in.*` namespace. The namespace key matches the field's `name` attribute.

### Basic Binding

```markdown
{? name: "hours", type: number, default: 40, label: "Hours Worked" ?}
{? name: "rate", type: number, default: 25.00, label: "Hourly Rate ($)" ?}

| Description | Amount |
|-------------|--------|
| Gross Pay   | =in.hours * in.rate |
| Tax (22%)   | =in.hours * in.rate * 0.22 |
| Net Pay     | =in.hours * in.rate * 0.78 |
```

### Select Binding

Select field values are strings matching the selected option text:

```markdown
{? name: "tier", type: select, options: ["Basic", "Pro", "Enterprise"], default: "Basic" ?}

| Feature     | Included |
|-------------|----------|
| API Access  | =IF(in.tier == "Basic", "No", "Yes") |
| Support     | =IF(in.tier == "Enterprise", "24/7", IF(in.tier == "Pro", "Business hours", "Community")) |
| Storage     | =IF(in.tier == "Enterprise", "Unlimited", IF(in.tier == "Pro", "100 GB", "5 GB")) |
```

### Toggle Binding

Toggle fields produce boolean values:

```markdown
{? name: "include_tax", type: toggle, default: true, label: "Include Tax" ?}

| Subtotal | =SUM(C2:C10) |
| Tax      | =IF(in.include_tax, SUM(C2:C10) * 0.08, 0) |
| Total    | =SUM(C2:C10) + IF(in.include_tax, SUM(C2:C10) * 0.08, 0) |
```

## Worked Example: Invoice Calculator

This complete example demonstrates input fields, form containers, table formulas, local functions, and inline expressions working together:

```markdown
---
title: "Invoice Generator"
---

!!! form {id=invoice-settings title="Invoice Settings"}
{? name: "client", type: text, default: "Acme Corp", label: "Client Name" ?}
{? name: "tax_rate", type: number, default: 0.08, step: 0.01, min: 0, max: 0.25, label: "Tax Rate" ?}
{? name: "discount_pct", type: slider, default: 0, min: 0, max: 30, step: 5, label: "Discount (%)" ?}
{? name: "currency", type: select, options: ["USD", "EUR", "GBP"], default: "USD", label: "Currency" ?}
!!!

<<fn format_currency(amount) =
    IF(in.currency == "USD", TEXT(amount, "$#,##0.00"),
    IF(in.currency == "EUR", CONCAT(TEXT(amount, "#,##0.00"), " EUR"),
    CONCAT("GBP ", TEXT(amount, "#,##0.00"))))
>>

<<fn apply_discount(amount) = amount * (1 - in.discount_pct / 100) >>

### Invoice for <<= in.client >>

| # | Service              | Hours | Rate   | Amount          |
|---|----------------------|-------|--------|-----------------|
| 1 | Design               | 20    | 150.00 | =C2*D2          |
| 2 | Development          | 40    | 175.00 | =C3*D3          |
| 3 | Testing              | 15    | 125.00 | =C4*D4          |
| 4 | Project Management   | 10    | 200.00 | =C5*D5          |
|   | **Subtotal**         |       |        | =SUM(E2:E5)     |
|   | **Discount**         |       |        | =SUM(E2:E5) * in.discount_pct / 100 |
|   | **After Discount**   |       |        | =local.apply_discount(SUM(E2:E5)) |
|   | **Tax**              |       |        | =local.apply_discount(SUM(E2:E5)) * in.tax_rate |
|   | **Total**            |       |        | =local.apply_discount(SUM(E2:E5)) * (1 + in.tax_rate) |

**Total Due: <<= local.format_currency(local.apply_discount(SUM(E2:E5)) * (1 + in.tax_rate)) >>**
```

This invoice recalculates instantly when the user changes the tax rate, discount percentage, or currency. The form container groups the configuration fields, and local functions encapsulate shared computation logic.

## Validation

Input fields support declarative validation through attributes:

```markdown
{? name: "email", type: text, pattern: "[a-z]+@[a-z]+\\.[a-z]+", label: "Email" ?}
{? name: "age", type: number, min: 0, max: 150, label: "Age" ?}
{? name: "rating", type: slider, min: 1, max: 5, step: 1, label: "Rating" ?}
```

When a value fails validation:

1. The `InputValueStore` rejects the update
2. The field reverts to its previous valid value
3. A validation diagnostic is emitted
4. Dependent expressions are not recalculated (they keep their previous values)

## See Also

- <doc:ExpressionsGuide>
- <doc:ReactiveModelGuide>
- <doc:LocalFunctionsGuide>
- <doc:ExecutionAPI>
