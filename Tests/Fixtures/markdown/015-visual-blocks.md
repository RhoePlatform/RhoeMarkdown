# Visual Blocks

## Named Visual Block

::: Circle {radius=50 color=blue}
:::

## Visual Block with Content

::: Mermaid
graph TD
  A --> B
:::

## Anonymous Container

::: {.columns}
This is inside a generic fenced div container.
:::

## Nested Containers

::: {.outer}
Outer content.

:::: {.inner}
Inner content.
::::
:::
