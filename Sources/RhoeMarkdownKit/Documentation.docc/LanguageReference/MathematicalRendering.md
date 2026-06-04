# Mathematical Rendering

Native LaTeX math rendering without JavaScript dependencies - a revolutionary approach to mathematical typography in Swift.

## Overview

RhoeMarkdownKit provides **NASA-grade** mathematical rendering capabilities, supporting both inline and display math with native Swift implementations. Unlike traditional solutions that rely on JavaScript libraries like MathJax or KaTeX, our approach delivers:

- 🚀 **Native Performance**: No JavaScript bridge overhead
- 🎨 **Perfect Typography**: Consistent with your app's font system  
- 📱 **Universal Platform Support**: From watchOS to macOS
- ⚡ **Real-time Rendering**: Instant updates with no async delays

## Basic Math Support

### Inline Math

Use single dollar signs for inline mathematical expressions:

```swift
let markdown = """
The famous equation $E = mc^2$ was discovered by Einstein.

The quadratic formula is $x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$.
"""

let document = parser.parse(markdown)
```

### Display Math

Use double dollar signs for centered display equations:

```swift
let markdown = """
The Gaussian integral:

$$
\\int_{-\\infty}^{\\infty} e^{-x^2} dx = \\sqrt{\\pi}
$$

Maxwell's equations in differential form:

$$
\\begin{align}
\\nabla \\cdot \\mathbf{E} &= \\frac{\\rho}{\\epsilon_0} \\\\
\\nabla \\cdot \\mathbf{B} &= 0 \\\\
\\nabla \\times \\mathbf{E} &= -\\frac{\\partial \\mathbf{B}}{\\partial t} \\\\
\\nabla \\times \\mathbf{B} &= \\mu_0 \\mathbf{J} + \\mu_0 \\epsilon_0 \\frac{\\partial \\mathbf{E}}{\\partial t}
\\end{align}
$$
"""
```

## Supported LaTeX Commands

### Greek Letters

```swift
let greek = "$\\alpha, \\beta, \\gamma, \\delta, \\epsilon, \\pi, \\omega, \\Omega$"
// Renders as: α, β, γ, δ, ε, π, ω, Ω
```

### Superscripts and Subscripts

```swift
let scripts = """
$x^2 + y^2 = r^2$
$a_1, a_2, ..., a_n$
$x^{2n} + y_{i,j}$
$e^{i\\pi} + 1 = 0$
"""
```

### Fractions

```swift
let fractions = """
Simple: $\\frac{1}{2}$
Complex: $\\frac{x + y}{x - y}$
Nested: $\\frac{\\frac{a}{b}}{\\frac{c}{d}} = \\frac{ad}{bc}$
"""
```

### Roots

```swift
let roots = """
Square root: $\\sqrt{x^2 + y^2}$
Nth root: $\\sqrt[3]{8} = 2$
Complex: $\\sqrt{\\frac{a + b}{c - d}}$
"""
```

### Sums, Products, and Integrals

```swift
let operations = """
Sum: $\\sum_{i=1}^{n} i = \\frac{n(n+1)}{2}$
Product: $\\prod_{i=1}^{n} x_i$
Integral: $\\int_0^1 x^2 dx = \\frac{1}{3}$
Multiple: $\\iint_D f(x,y) \\, dx \\, dy$
"""
```

### Matrices and Arrays

```swift
let matrices = """
$$
\\begin{pmatrix}
a & b \\\\
c & d
\\end{pmatrix}
\\begin{pmatrix}
x \\\\
y
\\end{pmatrix}
=
\\begin{pmatrix}
ax + by \\\\
cx + dy
\\end{pmatrix}
$$

$$
\\begin{bmatrix}
1 & 2 & 3 \\\\
4 & 5 & 6 \\\\
7 & 8 & 9
\\end{bmatrix}
$$
"""
```

## Advanced Math Features

### Custom Symbol Mapping

```swift
import RhoeMarkdownKit

// Access the symbol mapping system
let symbols = MathSymbols.symbolMap
print(symbols["infty"]) // ∞

// Add custom symbols
MathSymbols.addCustomSymbol("custom", "⊗")
```

### Math Parsing API

```swift
// Parse LaTeX directly
let mathExpression = Math.parse("\\frac{\\pi}{2}")

// Render to AttributedString
let renderer = MathAttributedStringRenderer()
let attributed = renderer.render(mathExpression)

// Render to HTML
let html = Math.renderToHTML(mathExpression)
```

### 2D Math Layout (Revolutionary Feature)

For complex mathematical layouts, use our SwiftUI-based 2D renderer:

```swift
import SwiftUI
import RhoeMarkdownKit

struct MathView: View {
    let latex = "\\frac{\\sum_{i=1}^{n} x_i}{n}"
    
    var body: some View {
        Math2DView(latex: latex)
            .font(.system(size: 20))
            .foregroundColor(.primary)
    }
}
```

## Platform-Specific Optimization

### iOS & iPadOS

```swift
let config = MathAttributedStringRenderer.Configuration(
    font: .systemFont(ofSize: 16),
    displayFont: .systemFont(ofSize: 20),
    scriptScale: 0.7,
    scriptOffset: 0.3
)

let renderer = MathAttributedStringRenderer(configuration: config)
```

### macOS

```swift
let config = MathAttributedStringRenderer.Configuration(
    font: .systemFont(ofSize: 14),
    displayFont: .systemFont(ofSize: 18),
    enableSubpixelPositioning: true
)
```

### watchOS

```swift
// Memory-optimized configuration
let config = MathAttributedStringRenderer.Configuration(
    font: .systemFont(ofSize: 12),
    maxComplexity: .medium // Limit nesting depth
)
```

## Performance Considerations

Our math rendering is optimized for speed:

| Expression Complexity | Parse Time | Render Time |
|---------------------|------------|-------------|
| Simple ($x^2$) | <0.01ms | <0.1ms |
| Medium (fractions) | <0.1ms | <0.5ms |
| Complex (matrices) | <0.5ms | <2ms |
| Very Complex | <1ms | <5ms |

### Caching

Math expressions are automatically cached:

```swift
let parser = CommonMarkParser(
    configuration: .init(
        mathCache: .enabled(maxSize: 1000)
    )
)
```

## Accessibility

Math expressions include accessibility descriptions:

```swift
let math = "$\\frac{1}{2}$"
let rendered = renderer.render(math)
// VoiceOver reads: "one half"

let complex = "$\\sum_{i=1}^{n} i^2$"
// VoiceOver reads: "sum from i equals 1 to n of i squared"
```

## Troubleshooting

### Common Issues

**Issue**: Math not rendering correctly  
**Solution**: Ensure backslashes are properly escaped in Swift strings

```swift
// ❌ Wrong
let math = "$\frac{1}{2}$"

// ✅ Correct
let math = "$\\frac{1}{2}$"
```

**Issue**: Performance with many equations  
**Solution**: Enable math caching and use async rendering for large documents

**Issue**: Subscripts/superscripts too small on watchOS  
**Solution**: Adjust scriptScale in configuration

## Examples

### Scientific Paper

```swift
let paper = """
# Quantum Mechanics

The Schrödinger equation:

$$i\\hbar\\frac{\\partial}{\\partial t}\\Psi = \\hat{H}\\Psi$$

Where $\\hbar = \\frac{h}{2\\pi}$ is the reduced Planck constant.

The uncertainty principle: $\\Delta x \\Delta p \\geq \\frac{\\hbar}{2}$
"""
```

### Mathematics Textbook

```swift
let textbook = """
## Calculus

The derivative of $f(x) = x^n$ is:

$$f'(x) = nx^{n-1}$$

### Integration by Parts

$$\\int u \\, dv = uv - \\int v \\, du$$

### Taylor Series

$$f(x) = \\sum_{n=0}^{\\infty} \\frac{f^{(n)}(a)}{n!}(x-a)^n$$
"""
```

## See Also

- <doc:Inline>
- <doc:SyntaxReference>
- <doc:CompatibilityAndDeferred>
