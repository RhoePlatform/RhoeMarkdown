# Migration Guide

Complete guide for migrating to RhoeMarkdownKit from other markdown libraries.

## Overview

This guide provides step-by-step instructions for migrating from popular markdown libraries to RhoeMarkdownKit. Whether you're coming from CommonMark, Marked, Markdown-it, or other parsers, this guide will help you transition smoothly while taking advantage of RhoeMarkdownKit's revolutionary features.

## Migration Paths

### Quick Migration Reference

| From Library | Difficulty | Breaking Changes | Feature Parity | Migration Time |
|--------------|------------|------------------|----------------|----------------|
| CommonMark | Easy | Minimal | 100% + extras | < 1 day |
| Marked.js | Easy | Some | 95% + extras | 1-2 days |
| Markdown-it | Medium | Moderate | 90% + extras | 2-3 days |
| Showdown | Medium | Moderate | 90% + extras | 2-3 days |
| Remarkable | Medium | Moderate | 85% + extras | 2-3 days |
| Swift Markdown | Easy | Minimal | 100% + extras | < 1 day |
| Ink (Swift) | Easy | Some | 95% + extras | 1-2 days |

## From CommonMark

### Basic Migration

```swift
// Before: CommonMark
import CommonMark

let document = try Document(parsing: markdown)
let html = document.render(format: .html)

// After: RhoeMarkdownKit
import RhoeMarkdownKit

let result = await RhoeMarkdownKit.parse(markdown)
let html = RhoeMarkdownKit.renderHTML(result.document)
```

### Feature Mapping

| CommonMark Feature | RhoeMarkdownKit Equivalent |
|-------------------|----------------------------|
| `Document` | `RhoeMarkdownKit.Document` |
| `Block` | `Block` enum |
| `Inline` | `Inline` enum |
| `Node` | `ASTNode` |
| `Visitor` | `DocumentVisitor` protocol |
| `render()` | `renderHTML()` |

### Advanced Features

```swift
// CommonMark extensions
let document = try Document(
    parsing: markdown,
    options: [.smart, .unsafe]
)

// RhoeMarkdownKit with extensions
let config = RhoeMarkdownKit.Configuration(
    enableSmartPunctuation: true,
    enableUnsafeHTML: true // Not recommended
)
let result = await RhoeMarkdownKit.parse(markdown, configuration: config)
```

## From Marked.js

### Basic Migration

```javascript
// Before: Marked.js
const marked = require('marked');
const html = marked.parse(markdown);

// After: RhoeMarkdownKit (Swift)
import RhoeMarkdownKit

let html = await RhoeMarkdownKit.toHTML(markdown)
```

### Configuration Migration

```javascript
// Before: Marked.js configuration
marked.setOptions({
  renderer: new marked.Renderer(),
  highlight: function(code, lang) {
    return hljs.highlight(code, {language: lang}).value;
  },
  pedantic: false,
  gfm: true,
  breaks: false,
  sanitize: false,
  smartLists: true,
  smartypants: false,
  xhtml: false
});

// After: RhoeMarkdownKit configuration
let config = RhoeMarkdownKit.Configuration(
    enableTables: true,           // gfm
    enableStrikethrough: true,    // gfm
    enableTaskLists: true,        // gfm
    enableAutolinks: true,        // gfm
    enableSmartPunctuation: false // smartypants
)

let htmlConfig = RhoeMarkdownKit.HTMLConfiguration(
    prettyPrint: false,
    enableSyntaxHighlighting: true,
    sanitizeHTML: false // sanitize
)
```

### Custom Renderer Migration

```swift
// Before: Marked.js custom renderer
const renderer = {
  heading(text, level) {
    return `<h${level} class="custom-heading">${text}</h${level}>`;
  },
  paragraph(text) {
    return `<p class="custom-paragraph">${text}</p>`;
  }
};

// After: RhoeMarkdownKit custom renderer
struct CustomHTMLRenderer: Renderer {
    func renderHeading(_ level: Int, content: [Inline]) -> String {
        "<h\(level) class=\"custom-heading\">\(renderInlines(content))</h\(level)>"
    }
    
    func renderParagraph(_ inlines: [Inline]) -> String {
        "<p class=\"custom-paragraph\">\(renderInlines(inlines))</p>"
    }
}
```

## From Swift Markdown

### API Comparison

```swift
// Before: Swift Markdown
import Markdown

let document = Document(parsing: markdown)
document.accept(MyVisitor())

// After: RhoeMarkdownKit
import RhoeMarkdownKit

let result = await RhoeMarkdownKit.parse(markdown)
let visitor = MyVisitor()
visitor.visit(result.document)
```

### Visitor Pattern Migration

```swift
// Before: Swift Markdown visitor
struct MyVisitor: MarkupVisitor {
    func visitHeading(_ heading: Heading) {
        print("Level \(heading.level): \(heading.plainText)")
    }
    
    func visitParagraph(_ paragraph: Paragraph) {
        print("Paragraph: \(paragraph.plainText)")
    }
}

// After: RhoeMarkdownKit visitor
struct MyVisitor: DocumentVisitor {
    func visitHeading(_ level: Int, content: [Inline]) {
        print("Level \(level): \(plainText(from: content))")
    }
    
    func visitParagraph(_ inlines: [Inline]) {
        print("Paragraph: \(plainText(from: inlines))")
    }
}
```

## From Ink (Swift)

### Basic Migration

```swift
// Before: Ink
import Ink

let parser = MarkdownParser()
let html = parser.html(from: markdown)

// After: RhoeMarkdownKit
import RhoeMarkdownKit

let html = await RhoeMarkdownKit.toHTML(markdown)
```

### Modifier Migration

```swift
// Before: Ink modifiers
var parser = MarkdownParser()

let modifier = Modifier(target: .codeBlocks) { html, markdown in
    let highlighted = highlightCode(markdown)
    return "<pre><code class='highlighted'>\(highlighted)</code></pre>"
}

parser.addModifier(modifier)

// After: RhoeMarkdownKit extensions
struct CodeHighlightExtension: MarkdownExtension {
    func transform(_ node: ASTNode, context: TransformContext) async throws -> ASTNode {
        guard case .block(let block) = node,
              case .codeBlock(let lang, let code, let attrs) = block else {
            return node
        }
        
        let highlighted = highlightCode(code, language: lang)
        return .custom(HighlightedCodeBlock(code: highlighted, language: lang))
    }
}

RhoeMarkdownKit.registerExtension(CodeHighlightExtension())
```

## Revolutionary Features

### Migrating to Slides

Transform your documents into presentations:

```swift
// Traditional markdown
let markdown = """
# Section 1
Content for section 1

# Section 2
Content for section 2
"""

// RhoeMarkdownKit slides
let slides = """
%%% Section 1
# Section 1
Content for section 1

%%% Section 2 {transition=zoom}
# Section 2
Content for section 2

% Speaker notes
Remember to explain the transition
"""

let presentation = try await SlideEnhancedParser().parseEnhanced(slides)
```

### Migrating to Grid Layouts

Replace HTML tables with powerful grids:

```swift
// Before: HTML table
let html = """
<table>
  <tr><td>A1</td><td>B1</td></tr>
  <tr><td>A2</td><td>B2</td></tr>
</table>
"""

// After: RhoeMarkdownKit grid
let grid = """
|[1,1] A1 |[1,2] B1 |
|[2,1] A2 |[2,2] B2 |
"""

let gridLayout = try await GridLayoutEngine().parseGrid(grid)
```

### Adding Shape Support

Enhance diagrams with semantic shapes:

```swift
// Before: ASCII art or images
let diagram = """
    [Cloud]
       |
       v
    [Server]
       |
       v
   [Database]
"""

// After: RhoeMarkdownKit shapes
let shapes = """
<shape type="cloud" label="Cloud Services" />
<shape type="arrow-down" />
<shape type="server" label="API Server" />
<shape type="arrow-down" />
<shape type="database" label="PostgreSQL" />
"""
```

## Performance Migration

### Optimizing Large Documents

```swift
// Before: Parse entire document
let document = parser.parse(largeMarkdown)

// After: Stream processing
let stream = RhoeMarkdownKit.streamParse(largeMarkdown)
for await chunk in stream {
    // Process incrementally
    processChunk(chunk)
}
```

### Caching Strategy

```swift
// Implement caching for better performance
class CachedParser {
    private var cache = NSCache<NSString, Document>()
    
    func parse(_ markdown: String) async -> Document {
        let key = NSString(string: markdown.hashValue.description)
        
        if let cached = cache.object(forKey: key) {
            return cached
        }
        
        let result = await RhoeMarkdownKit.parse(markdown)
        cache.setObject(result.document, forKey: key)
        
        return result.document
    }
}
```

## Native UI Migration

Native UI components are deferred from the first public compiler release. For
application migrations today, render HTML with `RhoeMarkdownKit` and embed the
result in the platform view layer you already own.

### From Web Views

```swift
// Before: WKWebView
let webView = WKWebView()
webView.loadHTMLString(html, baseURL: nil)

// After: Native SwiftUI
struct ContentView: View {
    @State private var document: RhoeDocument?
    
    var body: some View {
        if let document = document {
            RhoeDocumentView(document: document)
                .nativeRendering(true) // No web view needed
        }
    }
}
```

## Extension Migration

### Plugin System Comparison

| Feature | CommonMark | Marked.js | RhoeMarkdownKit |
|---------|------------|-----------|-----------------|
| Custom blocks | ❌ | Limited | ✅ Full support |
| Custom inline | ❌ | Limited | ✅ Full support |
| AST manipulation | Limited | ✅ | ✅ Enhanced |
| Multiple phases | ❌ | ❌ | ✅ Pre/Post/Transform |
| Type safety | ✅ | ❌ | ✅ Swift 6 |

### Creating Compatible Extensions

```swift
// Wrapper for legacy extensions
struct LegacyExtensionWrapper: MarkdownExtension {
    let legacyExtension: CommonMarkExtension
    
    func transform(_ node: ASTNode, context: TransformContext) async throws -> ASTNode {
        // Convert to legacy format
        let legacyNode = convertToLegacy(node)
        
        // Apply legacy extension
        let transformed = legacyExtension.process(legacyNode)
        
        // Convert back
        return convertFromLegacy(transformed)
    }
}
```

## Testing Migration

### Test Suite Adaptation

```swift
// Adapt existing tests
extension XCTestCase {
    func migrateCommonMarkTest(_ input: String, expected: String) async throws {
        let result = await RhoeMarkdownKit.parse(input)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        
        XCTAssertEqual(normalizeHTML(html), normalizeHTML(expected))
    }
}

// Batch migration
func migrateAllTests() async throws {
    let commonMarkTests = loadCommonMarkTests()
    
    for test in commonMarkTests {
        try await migrateCommonMarkTest(test.input, expected: test.output)
    }
}
```

## Migration Checklist

### Phase 1: Setup (Day 1)
- [ ] Add RhoeMarkdownKit dependency
- [ ] Import RhoeMarkdownKit modules
- [ ] Set up basic configuration
- [ ] Create migration branch

### Phase 2: Core Migration (Day 2-3)
- [ ] Replace parser initialization
- [ ] Update parsing calls
- [ ] Migrate rendering logic
- [ ] Update configuration

### Phase 3: Features (Day 4-5)
- [ ] Migrate custom extensions
- [ ] Update custom renderers
- [ ] Implement new features
- [ ] Add performance optimizations

### Phase 4: Testing (Day 6-7)
- [ ] Migrate test suite
- [ ] Add new test cases
- [ ] Performance benchmarks
- [ ] Security audit

### Phase 5: Deployment (Day 8)
- [ ] Update documentation
- [ ] Deploy to staging
- [ ] Monitor for issues
- [ ] Deploy to production

## Common Issues

### Issue: Different HTML Output

```swift
// Solution: Normalize HTML for comparison
func normalizeHTML(_ html: String) -> String {
    html
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .replacingOccurrences(of: "> <", with: "><")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
```

### Issue: Missing Extensions

```swift
// Solution: Check available alternatives
if !RhoeMarkdownKit.hasExtension("emoji") {
    // Use built-in emoji support instead
    let result = await RhoeMarkdownKit.parse(markdown)
    // Emojis are automatically converted
}
```

### Issue: Performance Regression

```swift
// Solution: Enable optimizations
RhoeMarkdownKit.configure(
    performance: PerformanceConfiguration(
        enableSIMD: true,
        enableParallelParsing: true,
        cacheSize: 100_000_000
    )
)
```

## Support Resources

### Documentation
- [API Reference](https://docs.rhoesuite.com/rhoemarkdownkit)
- [Examples](https://github.com/rhoesuite/rhoemarkdownkit-examples)
- [Video Tutorials](https://rhoesuite.com/tutorials)

### Community
- [Discord Server](https://discord.gg/rhoesuite)
- [GitHub Discussions](https://github.com/rhoesuite/rhoemarkdownkit/discussions)
- [Stack Overflow Tag](https://stackoverflow.com/questions/tagged/rhoemarkdownkit)

### Professional Support
- Email: support@rhoesuite.com
- Enterprise: enterprise@rhoesuite.com

## Next Steps

- Explore <doc:GettingStarted> for basics
- Learn about <doc:CustomExtensions> for extensibility
- See <doc:Performance> for optimization
- Check <doc:Testing> for quality assurance
