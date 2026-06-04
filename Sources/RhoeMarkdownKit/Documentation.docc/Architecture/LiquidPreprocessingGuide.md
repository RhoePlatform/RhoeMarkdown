# Liquid Preprocessing

Phase 1 template expansion using `{{ }}` interpolation and `{% %}` control flow.

## Overview

Liquid preprocessing is the first phase of the RhoeMarkdown `0.1.0` pipeline. Before the parser ever sees the document text, the Liquid engine evaluates all `{{ }}` interpolation tags and `{% %}` control flow tags, producing plain Markdown that flows into Phase 2 (parsing).

This phase is intentionally limited in power: it can substitute variables, iterate over collections, and conditionally include or exclude text regions, but it cannot modify the AST (which does not yet exist) or trigger side effects. Its sole output is expanded Markdown text.

## Interpolation: {{ }}

Double-brace tags insert values from data sources into the document text:

```markdown
# {{ title }}

Written by {{ author.name }} on {{ date | date: "%B %d, %Y" }}.
```

### Filters

Values can be piped through filters using the `|` operator:

| Filter | Purpose | Example |
| --- | --- | --- |
| `date` | Format a date | `{{ date \| date: "%Y-%m-%d" }}` |
| `upcase` | Convert to uppercase | `{{ name \| upcase }}` |
| `downcase` | Convert to lowercase | `{{ name \| downcase }}` |
| `capitalize` | Capitalize first letter | `{{ name \| capitalize }}` |
| `strip` | Remove leading/trailing whitespace | `{{ text \| strip }}` |
| `truncate` | Limit string length | `{{ body \| truncate: 100 }}` |
| `default` | Fallback for nil/empty | `{{ subtitle \| default: "Untitled" }}` |
| `size` | Collection or string length | `{{ items \| size }}` |
| `join` | Join array elements | `{{ tags \| join: ", " }}` |
| `sort` | Sort a collection | `{{ items \| sort: "name" }}` |
| `where` | Filter a collection | `{{ posts \| where: "draft", false }}` |
| `map` | Extract a property | `{{ users \| map: "email" }}` |
| `first` / `last` | First or last element | `{{ items \| first }}` |
| `escape` | HTML-escape content | `{{ raw_html \| escape }}` |
| `markdownify` | Process value as Markdown | `{{ snippet \| markdownify }}` |

Filters chain left to right: `{{ title | downcase | truncate: 30 }}`.

## Control Flow: {% %}

Brace-percent tags provide conditionals and loops that control which text regions appear in the output.

### Conditionals

```markdown
{% if audience == "technical" %}
See the API reference for implementation details.
{% elsif audience == "executive" %}
Key metrics are summarized below.
{% else %}
Welcome to the documentation.
{% endif %}
```

Supported conditional operators: `==`, `!=`, `>`, `<`, `>=`, `<=`, `contains`, `and`, `or`.

### Unless

The inverse of `if`:

```markdown
{% unless draft %}
This document is approved for distribution.
{% endunless %}
```

### Case/When

Multi-branch selection:

```markdown
{% case output_format %}
{% when "latex" %}
Compile with `pdflatex` for best results.
{% when "html" %}
Open in any modern browser.
{% when "docx" %}
Requires Microsoft Word 2019 or later.
{% else %}
Format-specific notes are not available.
{% endcase %}
```

### For Loops

Iterate over collections:

```markdown
{% for item in chapters %}
## {{ item.title }}

{{ item.summary }}

{% endfor %}
```

Loop variables available inside `{% for %}`:

| Variable | Type | Meaning |
| --- | --- | --- |
| `forloop.index` | Int | 1-based iteration counter |
| `forloop.index0` | Int | 0-based iteration counter |
| `forloop.first` | Bool | True on first iteration |
| `forloop.last` | Bool | True on last iteration |
| `forloop.length` | Int | Total number of iterations |

Loop modifiers:

```markdown
{% for item in items limit:5 offset:2 %}
{{ item.name }}
{% endfor %}

{% for i in (1..10) reversed %}
Countdown: {{ i }}
{% endfor %}
```

### Assign and Capture

Create local variables within the template:

```markdown
{% assign full_name = author.first | append: " " | append: author.last %}
By {{ full_name }}.

{% capture bio %}
{{ author.name }} is a {{ author.role }} at {{ author.org }}.
{% endcapture %}

{{ bio }}
```

### Comment

Suppress content from the output entirely:

```markdown
{% comment %}
This text will not appear in the expanded output.
{% endcomment %}
```

## Data Sources

Liquid variables are populated from three sources, resolved in priority order:

1. **YAML frontmatter** in the document itself:

   ```yaml
   ---
   title: "Quarterly Report"
   author:
     name: "Alice Chen"
     role: "Lead Analyst"
   tags: [finance, Q1, 2026]
   ---
   ```

2. **External data files** referenced in the frontmatter or project configuration:

   ```yaml
   ---
   data:
     metrics: data/q1-metrics.json
     team: data/team.yaml
   ---
   ```

   Loaded data is accessible under the declared key: `{{ metrics.revenue }}`, `{{ team | size }}`.

3. **Project-level variables** defined in the project configuration file (`rhoeproject.yaml`):

   ```yaml
   variables:
     company: "Acme Corp"
     year: 2026
     version: "3.3"
   ```

   Project variables serve as defaults that individual documents can override via frontmatter.

When the same key appears at multiple levels, document frontmatter wins over external data, which wins over project variables.

## The Transform Gateway: {% transform %}

The `{% transform %}` tag is the bridge between Phase 1 (Liquid) and Phase 2 (semantic transforms). It allows Liquid logic to conditionally emit Phase 2 directives:

```markdown
{% if audience == "internal" %}
{% transform %}
{@ hide selector=".public-only" @}
{% endtransform %}
{% endif %}
```

The content inside `{% transform %}...{% endtransform %}` is emitted verbatim into the expanded Markdown. The parser then captures it as `Block.phase2Directive` nodes, and Phase 2 applies the transforms to the AST.

This gateway is the only mechanism by which Liquid can influence AST-level behavior. Direct AST manipulation from Liquid is not possible.

## Constraints

Liquid preprocessing operates under strict constraints that preserve the pipeline's phase separation:

1. **No AST access.** Liquid runs before parsing. It sees and produces only text.
2. **No side effects.** Liquid evaluation does not write files, make network requests, or modify state outside the template engine.
3. **No code execution.** Liquid filters are a fixed set of pure functions. Custom filters cannot execute arbitrary code.
4. **No recursion.** A `{{ }}` tag cannot produce another `{{ }}` tag that gets re-evaluated. Expansion is single-pass.
5. **No cross-document access.** Liquid in one document cannot read variables from another document. Cross-document data sharing is handled at the project level.
6. **Deterministic output.** Given the same data sources, Liquid always produces the same expanded text. There is no randomness or time-dependent behavior (the `date` filter formats existing values; it does not read the current time).

These constraints ensure that Liquid preprocessing is fast, predictable, and safe to cache.

## See Also

- <doc:SemanticTransformsGuide>
- <doc:LanguageOverview>
- <doc:ExpressionsGuide>
