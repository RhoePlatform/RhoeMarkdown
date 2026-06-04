---
title: RhoeMarkdown Slide System Test Deck
author: RhoeMarkdownKit Test Suite
date: 2025-07-31
theme: default
---

%%% {#title-slide .hero background=gradient}
### COMPREHENSIVE TEST DECK

# RhoeMarkdown Slide System

## Every Feature Demonstrated

!!! footer-left
    RhoeMarkdownKit v1.0

!!! footer-center
    Test Suite Documentation

!!! footer-right
    Slide 1 of 20

!!! sticker
    TEST DECK

!!! logo
    ![RhoePlatform Logo](https://rhoe.dev/logo.svg)

%%%

### SLIDE 2: BASIC ELEMENTS

# Simple Slide with Headings

## This tests basic markdown rendering

This is a paragraph with **bold text**, *italic text*, and `inline code`.

Here's a list:
- First item
- Second item with **nested bold**
- Third item with [a link](https://example.com)

> And a blockquote for good measure.
> It can span multiple lines.

!!! footer-center
    Basic Elements Test

!!! footer-right
    Slide 2 of 20

%%%

# Slide 3: Simple Grid Layout

%% B2
% A1 **Cell A1**
  This is top-left

% B1 **Cell B1**
  This is top-right

% A2 **Cell A2**
  This is bottom-left

% B2 **Cell B2**
  This is bottom-right

!!! footer-left
    Grid Test 1

!!! footer-right
    Slide 3 of 20

%%%

### SLIDE 4: COMPLEX GRID

# 4×3 Grid Layout Test

%% D3 {.data-grid #complex-grid}
% A1 **Metric 1**
  Value: 42

% B1 **Metric 2**
  Value: 84

% C1 **Metric 3**
  Value: 126

% D1 **Metric 4**
  Value: 168

% A2 Chart placeholder
  ![](chart1.png)

% B2 Chart placeholder
  ![](chart2.png)

% C2 Chart placeholder
  ![](chart3.png)

% D2 Chart placeholder
  ![](chart4.png)

% A3 Status: ✅
% B3 Status: ✅
% C3 Status: ⚠️
% D3 Status: ❌

!!! footer-center
    Complex Grid Test

!!! footer-right
    Slide 4 of 20

%%% {#multi-line-test}

# Slide 5: Multi-line Cell Content

%% C2
% A1 **Multi-line Content Test**
  This cell has multiple lines
  Each maintaining proper indentation
  
  Even with blank lines between
  
  And it continues here

% B1 **List in Cell**
  - First item
  - Second item
    - Nested item
    - Another nested
  - Third item

% C1 **Code in Cell**
  ```python
  def hello():
      print("Hello from cell!")
  ```

% A2 **Mixed Content**
  Some text here
  
  > A blockquote in a cell
  > With multiple lines
  
  And more text after

% B2 **Links and Images**
  Check out [our website](https://example.com)
  
  ![Small image](thumb.jpg)
  
  More content below image

% C2 **Final Cell**
  The last cell with
  multiple paragraphs
  
  And a conclusion.

!!! footer-right
    Slide 5 of 20

%%%

### SLIDE 6: NESTED GRIDS

# Nested Grid Demonstration

%% B2 {.main-grid}
% A1 **Parent Cell with Nested Grid**
  
  This cell contains a nested grid:
  
  %% C3 {.nested-grid}
  % A1 Nested 1-1
  % B1 Nested 1-2
  % C1 Nested 1-3
  % A2 Nested 2-1
  % B2 Nested 2-2
  % C2 Nested 2-3
  % A3 Nested 3-1
  % B3 Nested 3-2
  % C3 Nested 3-3

% B1 **Regular Cell**
  This is just a normal cell
  next to the nested grid cell

% A2 **Another Regular Cell**
  Bottom left content

% B2 **Deep Nesting Test**
  
  %% B2
  % A1 Level 2 Grid
    
    %% B2
    % A1 Level 3!
    % B1 Amazing!
    
  % B1 Back to Level 2

!!! footer-center
    Nested Grid Test

!!! footer-right
    Slide 6 of 20

!!! sticker
    COMPLEX

%%%

# Slide 7: All Semantic Elements

### This slide has a supertitle (H3)

## And also a subtitle (H2)

Regular content appears here in the main area.

!!! footer-left
    Left footer content
    Can be multi-line

!!! footer-center
    Center footer content
    Also supports multiple lines

!!! footer-right
    Right footer content
    Page 7 of 20

!!! sticker
    DRAFT

!!! sticker
    CONFIDENTIAL

!!! sticker
    WIP

!!! logo
    ![Company Logo](logo.png)

%%%

# Slide 8: Excel Reference Edge Cases

Testing various Excel-style references:

%% Z3
% A1 First column
% Z1 Last single-letter column (26)
% A3 Bottom of first column
% Z3 Bottom-right corner

%%%

# Slide 9: Multi-letter Columns

%% AC5
% AA1 Column 27 (first double-letter)
% AB1 Column 28
% AC1 Column 29
% AA5 Multi-letter bottom-left
% AC5 Multi-letter bottom-right

!!! footer-center
    Excel Reference Test

!!! footer-right
    Slide 9 of 20

%%% {.code-heavy}

# Slide 10: Code Block Tests

Regular code block:

```javascript
function createSlide(content) {
    return {
        type: 'slide',
        content: content,
        timestamp: Date.now()
    };
}
```

%% B2
% A1 **Code in Grid Cell**
  ```python
  def process():
      return "Hello"
  ```

% B1 **Another Language**
  ```swift
  let slide = Slide(
      blocks: blocks
  )
  ```

% A2 Inline `code` test
% B2 More `inline code` here

!!! footer-right
    Slide 10 of 20

%%%

### MATHEMATICS TEST

# Slide 11: Math Support

Inline math: $E = mc^2$ and $\sum_{i=1}^{n} i = \frac{n(n+1)}{2}$

Display math:

$$
\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}
$$

%% B2
% A1 **Math in Cells**
  The formula $a^2 + b^2 = c^2$
  is fundamental

% B1 **Display Math in Cell**
  $$\frac{d}{dx} \sin(x) = \cos(x)$$

% A2 Mixed: $\alpha + \beta$
% B2 Unicode: α + β = γ

!!! footer-center
    Math Rendering Test

!!! footer-right
    Slide 11 of 20

%%%

# Slide 12: Tables in Slides

Regular table outside grid:

| Feature | Status | Notes |
|---------|--------|-------|
| Parser | ✅ Complete | Full implementation |
| Renderer | ✅ Complete | HTML output |
| Viewer | ✅ Complete | Dual modes |

%% B1
% A1 **Table in Grid Cell**
  | Col1 | Col2 |
  |------|------|
  | A    | B    |
  | C    | D    |

% B1 **List and Table**
  - First item
  - Second item
  
  | X | Y |
  |---|---|
  | 1 | 2 |

!!! footer-right
    Slide 12 of 20

%%% {#images-test}

# Slide 13: Images and Media

%% C3
% A1 ![Chart 1](chart1.png)
% B1 ![Chart 2](chart2.png)
% C1 ![Chart 3](chart3.png)

% A2 **Image with Caption**
  ![Dashboard](dashboard.png)
  *Figure 1: Sales Dashboard*

% B2 **Multiple Images**
  ![Icon 1](icon1.png) ![Icon 2](icon2.png)
  ![Icon 3](icon3.png) ![Icon 4](icon4.png)

% C2 **Linked Image**
  [![Click me](button.png)](https://example.com)

% A3 Text under image
% B3 More text here
% C3 Final text cell

!!! footer-center
    Media Test

!!! footer-right
    Slide 13 of 20

%%%

### ATTRIBUTES TEST

# Slide 14: Pandoc Attributes {#attrs-slide .special data-bg=blue}

%% B2 {#my-grid .centered .bordered}
% A1 Cell with content
% B1 Another cell {.highlight}
% A2 Bottom left
% B2 Bottom right {#special-cell}

This slide tests Pandoc-style attributes on:
- Slide delimiters
- Grid declarations  
- Individual cells (future)

!!! footer-right
    Slide 14 of 20

%%%

# Slide 15: Special Characters

Testing special character handling:

%% B2
% A1 **Symbols**
  • Bullet point
  → Arrow
  © Copyright
  ™ Trademark
  € Euro

% B1 **Emoji**
  😀 😎 🚀 🔥
  ✅ ❌ ⚠️ ℹ️
  📊 📈 📉 💹

% A2 **Escaping**
  Literal % percent
  Double %% percents
  Triple %%% percents

% B2 **Quotes**
  "Smart quotes"
  'Single quotes'
  `Backtick quotes`

!!! footer-center
    Special Characters Test

!!! footer-right
    Slide 15 of 20

%%%

# Slide 16: Empty Cells Test

%% D4
% A1 First cell
% D1 Last cell in row 1
% A4 First cell in last row
% D4 Last cell in grid
% B2 One cell in middle

This tests sparse grid population - only 5 of 16 cells are filled.

!!! footer-right
    Slide 16 of 20

%%% {#indentation-test}

# Slide 17: Indentation Edge Cases

%% B2
% A1 Two space indent test
  Line with 2 spaces
  Another line with 2
    Line with 4 spaces
  Back to 2 spaces

% B1 Tab indent test
	Line with 1 tab
	Another with tab
		Line with 2 tabs
	Back to 1 tab

% A2 Mixed indents (not recommended)
  2 spaces first
	Then a tab
  Back to spaces

% B2 Empty lines test
  
  Empty line above
  
  
  Two empty lines above

!!! footer-center
    Indentation Test

!!! footer-right
    Slide 17 of 20

%%%

# Slide 18: Blockquotes and Admonitions

> Regular blockquote at slide level
> Can have multiple lines

%% B2
% A1 **Blockquote in Cell**
  > This is quoted text
  > Inside a grid cell
  > 
  > With multiple paragraphs

% B1 **Admonition in Cell**
  !!! note
      This is a note
      Inside a grid cell
  
  !!! warning
      A warning here

% A2 **Nested Quotes**
  > Level 1
  > > Level 2
  > > > Level 3

% B2 **Mixed Content**
  Text before
  
  > Quote in middle
  
  Text after

!!! footer-right
    Slide 18 of 20

%%%

### PERFORMANCE TEST

# Slide 19: Large Grid Stress Test

%% J10 {.stress-test}
% A1 Cell 1,1
% B1 Cell 2,1
% C1 Cell 3,1
% D1 Cell 4,1
% E1 Cell 5,1
% F1 Cell 6,1
% G1 Cell 7,1
% H1 Cell 8,1
% I1 Cell 9,1
% J1 Cell 10,1
% A10 Cell 1,10
% J10 Cell 10,10
% E5 Center cell
% E6 Below center

This creates a 10×10 grid (100 cells) but only populates some of them.

!!! footer-center
    Performance Test

!!! footer-right
    Slide 19 of 20

!!! sticker
    STRESS TEST

%%% {#final-slide .conclusion}

### THE END

# Test Deck Complete! 🎉

## All Features Tested Successfully

This comprehensive test deck has demonstrated:

✅ Basic slides with semantic elements
✅ Simple and complex grid layouts  
✅ Multi-line cell content
✅ Nested grids (multiple levels)
✅ All footer positions
✅ Multiple stickers
✅ Logo placement
✅ Excel-style references (A1 to J10)
✅ Multi-letter columns (AA, AB, AC)
✅ Code blocks and inline code
✅ Math rendering
✅ Tables
✅ Images and media
✅ Special characters
✅ Empty cells
✅ Indentation handling
✅ Blockquotes and admonitions
✅ Pandoc attributes
✅ Large grid stress test

!!! footer-left
    © 2025 RhoePlatform

!!! footer-center
    Thank you for viewing!

!!! footer-right
    Slide 20 of 20

!!! sticker
    COMPLETE

!!! sticker
    TESTED

!!! sticker
    SHIPPED

!!! logo
    ![RhoePlatform](logo.svg)
