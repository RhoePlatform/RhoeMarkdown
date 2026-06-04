# Pandoc-Style Attribute Lists Test

## Basic Attributes

This is a paragraph with attributes.{#para-id .highlight .important lang=en}

### Header with ID and Classes {#custom-header .section-header .emphasized}

## Inline Attributes

This has [inline span]{.highlight .warning} with classes.

This has [styled text]{#span-id .custom style="color: blue; font-weight: bold"} with inline styles.

## Code Block Attributes

```python {#code-example .line-numbers .syntax-highlight startFrom=10}
def hello_world():
    print("Hello, World!")
    return 42
```

## Block Quote Attributes

> This is a blockquote with custom styling.
> It can span multiple lines.
{.callout .info style="border-left: 4px solid blue"}

## List Attributes

- First item
- Second item
- Third item
{.custom-list .checklist}

1. Ordered first
2. Ordered second
3. Ordered third
{#ordered-list .numbered-list start=5}

## Image Attributes

![Alt text](image.jpg){#img-id .responsive .bordered width=500 height=300}

## Link Attributes

[Visit our site](https://example.com){.external-link target="_blank" rel="noopener"}

## Table Attributes

| Header 1 | Header 2 | Header 3 |
|----------|----------|----------|
| Cell 1   | Cell 2   | Cell 3   |
| Cell 4   | Cell 5   | Cell 6   |
{#data-table .striped .hoverable}

## Div Attributes

::: {#warning-box .alert .alert-warning}
This is a warning div with Pandoc fence syntax.
It can contain multiple paragraphs.

And even other block elements:
- Like lists
- With items
:::

## Span Attributes

This paragraph contains [important text]{.emphasis .red data-tooltip="Important information"} with data attributes.

## Combined Attributes

### Complex Example {#complex .multi-class .another-class lang=en dir=ltr}

This paragraph combines multiple features.{.intro}

```javascript {.code-block .javascript line-numbers=true}
const example = "code with attributes";
console.log(example);
```
{.code-wrapper}

## Raw HTML Attributes

<div id="custom-div" class="container" data-value="42">
Raw HTML with attributes preserved
</div>

## Math with Attributes

$E = mc^2${#einstein-equation .physics-formula}

$$
\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}
$${#gaussian-integral .centered-math}