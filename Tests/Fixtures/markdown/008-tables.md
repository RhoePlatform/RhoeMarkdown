# Tables Tests (GFM)

## Basic Table

| Header 1 | Header 2 |
|----------|----------|
| Cell 1   | Cell 2   |
| Cell 3   | Cell 4   |

## Table with Alignment

| Left | Center | Right |
|:-----|:------:|------:|
| L1   | C1     | R1    |
| L2   | C2     | R2    |

## Table with Formatting

| Column 1 | Column 2 |
|----------|----------|
| **Bold** | *Italic* |
| `code`   | [link](https://example.com) |
| ![](img.jpg) | ~~strike~~ |

## Table with Complex Content

| Math | Code |
|------|------|
| $x^2 + y^2 = z^2$ | `print("hello")` |
| $\frac{a}{b}$ | `var x = 42;` |

## Minimal Table

Header 1 | Header 2
---------|----------
Cell 1   | Cell 2

## Table with Empty Cells

| A | B | C |
|---|---|---|
| 1 |   | 3 |
|   | 2 |   |

## Table with Escaped Pipes

| Column 1 | Column 2 |
|----------|----------|
| Normal   | With \| pipe |
| More     | Data |