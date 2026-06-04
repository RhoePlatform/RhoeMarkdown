---
title: "Component Playbook"
author: "RhoePlatform"
status: "example"
---

> Run: `rhoemd Examples/sources/component-playbook.md -o Examples/outputs/component-playbook.html --format html --css --pretty`

# Component Playbook {#component-playbook}

This example shows how a team can describe repeatable content patterns in plain
Markdown before those patterns graduate into stricter component tooling.

::: {.card .hero}
## Hero Card

Use this pattern for a landing-page opener: one sentence, one action, one proof
point.
:::

::: {.grid count=3}
- **Signal**: the promise users should remember.
- **Action**: the next command or click.
- **Evidence**: the output or artifact that proves it worked.
:::

!!! example "Reusable callout"
Write callouts as semantic blocks first. If the pattern becomes common, promote
it to a stricter component later.
!!!

## Pattern Catalog

| Pattern | Markdown shape | Best use |
| --- | --- | --- |
| Hero card | fenced div | landing page sections |
| Proof strip | list inside div | quick evidence |
| Warning block | admonition | risk or limitation |
| Code recipe | fenced code | copy-paste commands |

## Copy-Paste Recipe

```markdown
::: {.card .hero}
## Title

Short promise.
:::
```

The output stays readable today and remains structured enough for tomorrow.
