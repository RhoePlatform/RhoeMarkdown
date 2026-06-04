# Grid Layouts

Create sophisticated Excel-style grid layouts with formulas, spanning, and advanced styling.

## Overview

RhoeMarkdownKit's Grid Layout system brings spreadsheet-like capabilities to markdown, enabling complex data presentations, dashboards, and reports with cell references, formulas, and professional formatting.

## Grid Notation

### Cell References

RhoeMarkdownKit supports two notation styles:

1. **Bracket Notation**: `[row,column]`
   - Example: `[1,1]` for first row, first column
   - Range: `[1,1:2,3]` spans from row 1, col 1 to row 2, col 3

2. **Excel Notation**: `A1`, `B2`, etc.
   - Column letters (A-Z, AA-ZZ) + row numbers
   - Range: `A1:C3` for a 3x3 grid

## Basic Grid Syntax

### Simple Table Grid

```markdown
|[1,1] **Header 1** |[1,2] **Header 2** |[1,3] **Header 3** |
|[2,1] Data A |[2,2] Data B |[2,3] Data C |
|[3,1] Data D |[3,2] Data E |[3,3] Data F |
```

### Cell Spanning

Merge cells across rows and columns:

```markdown
|[1,1:2] **Merged Header** |[1,3] **Side** |
|[2,1] Left |[2,2] Center |[2,3] Right |
|[3,1:3] **Full Width Footer** |
```

## Cell Styling

### Alignment

Control text alignment within cells:

```markdown
|[1,1] :Left aligned |[1,2] :Center: |[1,3] Right: |
```

### Colors and Formatting

Add inline styles:

```markdown
|[1,1] **Bold** {bg="#e8f5e9"} |[1,2] *Italic* {color="red"} |
|[2,1] Normal {border="double"} |[2,2] Large {size="18px"} |
```

### Complete Style Options

```markdown
|[1,1] Styled Cell {
  bg="#3498db"        # Background color
  color="white"       # Text color
  border="solid"      # Border style
  size="14px"         # Font size
  weight="bold"       # Font weight
} |
```

## Formulas and Calculations

### Basic Formulas

RhoeMarkdownKit supports Excel-style formulas:

```markdown
|[1,1] **Item** |[1,2] **Price** |[1,3] **Quantity** |[1,4] **Total** |
|[2,1] Widget A |[2,2] $10.00 |[2,3] 5 |[2,4] =B2*C2 |
|[3,1] Widget B |[3,2] $15.00 |[3,3] 3 |[3,4] =B3*C3 |
|[4,1:3] **Grand Total** |[4,4] =SUM(D2:D3) |
```

### Supported Functions

| Function | Description | Example |
|----------|-------------|---------|
| `SUM` | Sum of range | `=SUM(A1:A10)` |
| `AVG` | Average of range | `=AVG(B2:B5)` |
| `COUNT` | Count non-empty cells | `=COUNT(C1:C10)` |
| `MAX` | Maximum value | `=MAX(D1:D10)` |
| `MIN` | Minimum value | `=MIN(E1:E10)` |
| `IF` | Conditional logic | `=IF(A1>10,"High","Low")` |

## Advanced Grid Features

### Dashboard Layout

Create professional dashboards:

```markdown
<!-- grid: title="Sales Dashboard" striped=true hoverable=true -->
|[1,1:4] **Q4 2024 Sales Dashboard** {bg="#2c3e50" color="white" size="20px"} |

|[2,1] **Metric** |[2,2] **Target** |[2,3] **Actual** |[2,4] **Status** |
|[3,1] Revenue |[3,2] $1M |[3,3] $1.2M {color="green"} |[3,4] ✅ +20% |
|[4,1] Orders |[4,2] 500 |[4,3] 487 {color="orange"} |[4,4] ⚠️ -2.6% |
|[5,1] Customers |[5,2] 100 |[5,3] 125 {color="green"} |[5,4] ✅ +25% |

|[6,1:4] **Top Products** {bg="#ecf0f1"} |
|[7,1] 1. Premium Widget |[7,2] $450K |[7,3:4] 📈 37.5% of revenue |
|[8,1] 2. Standard Widget |[8,2] $300K |[8,3:4] 📊 25% of revenue |
```

### Responsive Grids

Configure responsive behavior:

```markdown
<!-- grid: responsive=true -->
|[1,1] Mobile First |[1,2] Tablet View |[1,3] Desktop View |
```

### Grid Metadata

Add metadata for enhanced functionality:

```markdown
<!-- grid: 
  title="Financial Report"
  caption="All figures in USD"
  responsive=true
  striped=true
  bordered=true
  hoverable=true
-->
```

## Using GridLayoutEngine

### Basic Parsing

```swift
import RhoeMarkdownKit

let gridMarkdown = """
|[1,1] **Product** |[1,2] **Price** |
|[2,1] Widget A |[2,2] $99.99 |
|[3,1] Widget B |[3,2] $149.99 |
"""

let engine = GridLayoutEngine()
let grid = try await engine.parseGrid(gridMarkdown)

print("Grid size: \(grid.rows)x\(grid.columns)")
print("Total cells: \(grid.cells.count)")
```

### Accessing Cells

```swift
// Access individual cells
for cell in grid.cells {
    let position = cell.reference.notation // e.g., "A1"
    let content = cell.content
    
    if let formula = cell.formula {
        print("Cell \(position) has formula: =\(formula)")
    }
    
    if let span = cell.span {
        print("Cell spans \(span.rowSpan) rows, \(span.colSpan) columns")
    }
}
```

### Formula Evaluation

```swift
// Evaluate formulas in the grid
let evaluatedGrid = await engine.evaluateFormulas(grid)

// Results are calculated and replaced
for cell in evaluatedGrid.cells {
    if cell.formula != nil {
        print("Calculated: \(cell.content)")
    }
}
```

### Rendering to HTML

```swift
// Generate HTML table
let html = engine.renderHTML(grid)

// Custom styling
let styledHTML = """
<style>
.rhoe-grid { 
    font-family: system-ui; 
    border-collapse: collapse; 
}
.rhoe-grid td { 
    padding: 8px; 
    border: 1px solid #ddd; 
}
</style>
\(html)
"""
```

## Export Formats

### CSV Export

```swift
let csv = engine.exportCSV(grid)
// Returns comma-separated values

try csv.write(to: csvURL, atomically: true, encoding: .utf8)
```

### JSON Export

```swift
let json = try engine.exportJSON(grid)
// Returns structured JSON representation

let data = json.data(using: .utf8)!
try data.write(to: jsonURL)
```

### Excel Export (Future)

```swift
// Coming in next version
let excel = try engine.exportExcel(grid)
try excel.write(to: excelURL)
```

## Grid Patterns

### Financial Report

```markdown
|[1,1:4] **Quarterly Financial Report** |
|[2,1] **Category** |[2,2] **Q1** |[2,3] **Q2** |[2,4] **YTD** |
|[3,1] Revenue |[3,2] $250K |[3,3] $300K |[3,4] =SUM(B3:C3) |
|[4,1] Expenses |[4,2] $180K |[4,3] $200K |[4,4] =SUM(B4:C4) |
|[5,1] **Profit** |[5,2] =B3-B4 |[5,3] =C3-C4 |[5,4] =D3-D4 |
```

### Comparison Table

```markdown
|[1,1] **Feature** |[1,2] **Basic** |[1,3] **Pro** |[1,4] **Enterprise** |
|[2,1] Users |[2,2] 10 |[2,3] 100 |[2,4] Unlimited |
|[3,1] Storage |[3,2] 10GB |[3,3] 100GB |[3,4] 1TB |
|[4,1] Support |[4,2] Email |[4,3] Priority |[4,4] Dedicated |
|[5,1] Price |[5,2] $9/mo |[5,3] $49/mo |[5,4] Custom |
```

### Project Timeline

```markdown
|[1,1] **Phase** |[1,2] **Jan** |[1,3] **Feb** |[1,4] **Mar** |[1,5] **Apr** |
|[2,1] Planning |[2,2:3] ████████ | | |
|[3,1] Development | |[3,3:4] ████████ | |
|[4,1] Testing | | |[4,4:5] ████████ |
|[5,1] Launch | | | |[5,5] 🚀 |
```

## Performance Optimization

### Large Grids

For grids with 1000+ cells:

```swift
// Use streaming parse for large grids
let largeGrid = await engine.parseGridStreaming(hugeMarkdown)

// Process in chunks
for await chunk in largeGrid.chunks {
    processChunk(chunk)
}
```

### Caching

Cache rendered grids:

```swift
let cacheKey = gridMarkdown.hashValue
if let cached = gridCache[cacheKey] {
    return cached
}

let rendered = engine.renderHTML(grid)
gridCache[cacheKey] = rendered
```

## Accessibility

Grids automatically include accessibility features:

- Proper table semantics
- Header associations
- ARIA labels for complex cells
- Keyboard navigation support

## Integration with Other Features

### Combine with Shapes

```markdown
|[1,1] **Stage** |[1,2] **Diagram** |
|[2,1] Input |[2,2] <shape type="circle" label="Start" /> |
|[3,1] Process |[3,2] <shape type="rectangle" label="Transform" /> |
|[4,1] Output |[4,2] <shape type="circle" label="End" /> |
```

### Include Icons

```markdown
|[1,1] **Status** |[1,2] **Task** |[1,3] **Progress** |
|[2,1] <icon set="heroicons" name="check" color="green" /> |[2,2] Design |[2,3] 100% |
|[3,1] <icon set="fluent" name="clock" color="orange" /> |[3,2] Development |[3,3] 75% |
|[4,1] <icon set="fontawesome" name="x" color="red" /> |[4,2] Testing |[4,3] 0% |
```

## Best Practices

1. **Use meaningful cell references** - Help readers understand the structure
2. **Keep formulas simple** - Complex calculations should be done in code
3. **Optimize cell spanning** - Use spans to reduce redundancy
4. **Apply consistent styling** - Use metadata for grid-wide styles
5. **Consider mobile view** - Test responsive behavior
6. **Validate formulas** - Ensure calculations are correct
7. **Export appropriately** - Choose the right format for your audience

## Troubleshooting

### Common Issues

- **Formula not evaluating**: Check cell references are correct
- **Spanning conflicts**: Ensure spans don't overlap
- **Style not applying**: Verify syntax and quote usage
- **Export issues**: Check data types match format requirements

## Next Steps

- Explore <doc:ShapeSystem> for adding diagrams
- Learn about <doc:IconLibraries> for visual elements
- See <doc:SlideSystem> for presentations with grids
- Check <doc:Performance> for optimization tips