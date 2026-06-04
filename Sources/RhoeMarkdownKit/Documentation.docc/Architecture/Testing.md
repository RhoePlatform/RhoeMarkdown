# Testing

Comprehensive testing strategies for RhoeMarkdownKit with Swift Testing framework.

## Overview

RhoeMarkdownKit includes an extensive testing suite using Swift Testing framework, covering unit tests, integration tests, performance benchmarks, and specification compliance. This guide covers testing strategies, patterns, and best practices.

## Testing Architecture

### Test Organization

```
RhoeMarkdownKitTests/
├── Unit/                    # Unit tests for individual components
│   ├── ParserTests/
│   ├── RendererTests/
│   ├── ExtensionTests/
│   └── UtilityTests/
├── Integration/            # End-to-end integration tests
│   ├── DocumentTests/
│   ├── FeatureTests/
│   └── WorkflowTests/
├── Performance/           # Performance benchmarks
│   ├── ParsingBenchmarks/
│   ├── RenderingBenchmarks/
│   └── MemoryTests/
├── Compliance/           # Specification compliance tests
│   ├── CommonMarkTests/
│   ├── GFMTests/
│   └── PandocTests/
└── Fixtures/            # Test data and resources
    ├── Documents/
    ├── Expected/
    └── Resources/
```

## Unit Testing

### Basic Test Structure

```swift
import Testing
@testable import RhoeMarkdownKit

struct ParserTests {
    
    @Test("Parse simple paragraph")
    func testParagraphParsing() async throws {
        let markdown = "This is a simple paragraph."
        
        let result = await RhoeMarkdownKit.parse(markdown)
        
        #expect(result.document.blocks.count == 1)
        
        guard case .paragraph(let inlines, _) = result.document.blocks[0] else {
            Issue.record("Expected paragraph block")
            return
        }
        
        #expect(inlines.count == 1)
        
        guard case .text(let text) = inlines[0] else {
            Issue.record("Expected text inline")
            return
        }
        
        #expect(text == "This is a simple paragraph.")
    }
    
    @Test("Parse headings", arguments: [
        (1, "#"),
        (2, "##"),
        (3, "###"),
        (4, "####"),
        (5, "#####"),
        (6, "######")
    ])
    func testHeadingLevels(level: Int, prefix: String) async throws {
        let markdown = "\(prefix) Heading \(level)"
        
        let result = await RhoeMarkdownKit.parse(markdown)
        
        guard case .heading(let parsedLevel, let content, _) = result.document.blocks[0] else {
            Issue.record("Expected heading block")
            return
        }
        
        #expect(parsedLevel == level)
        #expect(plainText(from: content) == "Heading \(level)")
    }
}
```

### Testing Inline Elements

```swift
struct InlineTests {
    
    @Test("Parse emphasis variations")
    func testEmphasis() async throws {
        let testCases = [
            ("*italic*", "italic"),
            ("_italic_", "italic"),
            ("**bold**", "bold"),
            ("__bold__", "bold"),
            ("***bold italic***", "bold italic"),
            ("___bold italic___", "bold italic")
        ]
        
        for (markdown, expected) in testCases {
            let result = await RhoeMarkdownKit.parse(markdown)
            let text = extractText(from: result.document)
            #expect(text == expected, "Failed for: \(markdown)")
        }
    }
    
    @Test("Parse links with titles")
    func testLinksWithTitles() async throws {
        let markdown = """
        [Link 1](https://example.com)
        [Link 2](https://example.com "Title")
        [Link 3](https://example.com 'Title')
        """
        
        let result = await RhoeMarkdownKit.parse(markdown)
        let links = extractLinks(from: result.document)
        
        #expect(links.count == 3)
        #expect(links[0].url == "https://example.com")
        #expect(links[0].title == nil)
        #expect(links[1].title == "Title")
        #expect(links[2].title == "Title")
    }
}
```

### Testing Custom Features

```swift
struct SlideSystemTests {
    
    @Test("Parse slide delimiters")
    func testSlideDelimiters() async throws {
        let markdown = """
        %%% Title Slide
        # Presentation
        
        %% Content Slide
        Content here
        
        % Speaker notes
        Notes for presenter
        """
        
        let parser = SlideEnhancedParser()
        let presentation = try await parser.parseEnhanced(markdown)
        
        #expect(presentation.slides.count == 2)
        #expect(presentation.slides[0].metadata.title == "Title Slide")
        #expect(presentation.slides[1].metadata.speakerNotes == "Notes for presenter")
    }
    
    @Test("Parse slide transitions")
    func testSlideTransitions() async throws {
        let markdown = """
        %%% Slide {transition=zoom duration=2}
        # Content
        """
        
        let parser = SlideEnhancedParser()
        let presentation = try await parser.parseEnhanced(markdown)
        
        let metadata = presentation.slides[0].metadata
        #expect(metadata.transition == .zoom)
        #expect(metadata.duration == 2)
    }
}
```

## Integration Testing

### Document Processing

```swift
struct DocumentIntegrationTests {
    
    @Test("Complete document workflow")
    func testDocumentWorkflow() async throws {
        // Load test document
        let markdown = try loadFixture("complex-document.md")
        
        // Parse
        let parseResult = await RhoeMarkdownKit.parse(markdown)
        #expect(parseResult.diagnostics.isEmpty)
        
        // Transform with extensions
        let transformed = await applyExtensions(parseResult.document)
        
        // Render to HTML
        let html = RhoeMarkdownKit.renderHTML(transformed)
        #expect(!html.isEmpty)
        
        // Validate output
        let expected = try loadFixture("complex-document.html")
        #expect(normalizeHTML(html) == normalizeHTML(expected))
    }
    
    @Test("Large document handling")
    func testLargeDocument() async throws {
        // Generate 10MB document
        let markdown = generateLargeMarkdown(sizeInMB: 10)
        
        // Measure parsing time
        let startTime = Date()
        let result = await RhoeMarkdownKit.parse(markdown)
        let parseTime = Date().timeIntervalSince(startTime)
        
        #expect(parseTime < 2.0, "Parsing took \(parseTime)s")
        #expect(result.document.blocks.count > 0)
    }
}
```

### Feature Integration

```swift
struct FeatureIntegrationTests {
    
    @Test("Grid with formulas")
    func testGridFormulas() async throws {
        let markdown = """
        |[1,1] A |[1,2] B |[1,3] Total |
        |[2,1] 10 |[2,2] 20 |[2,3] =A2+B2 |
        |[3,1] 15 |[3,2] 25 |[3,3] =A3+B3 |
        |[4,1:2] Grand Total |[4,3] =SUM(C2:C3) |
        """
        
        let engine = GridLayoutEngine()
        let grid = try await engine.parseGrid(markdown)
        let evaluated = await engine.evaluateFormulas(grid)
        
        // Check formula results
        let totalCell = evaluated.cells.first { $0.reference.row == 2 && $0.reference.column == 3 }
        #expect(totalCell?.content == "30")
        
        let grandTotal = evaluated.cells.first { $0.reference.row == 4 && $0.reference.column == 3 }
        #expect(grandTotal?.content == "70")
    }
    
    @Test("Shape rendering pipeline")
    func testShapeRendering() async throws {
        let renderer = ShapeSystemRenderer()
        
        let shapes = [
            Shape(type: .cloud, label: "Cloud", position: ShapePosition(x: 0, y: 0)),
            Shape(type: .arrow-right),
            Shape(type: .server, label: "Server", position: ShapePosition(x: 100, y: 0))
        ]
        
        // Add connection
        shapes[0].connections.append(
            ShapeConnection(targetId: shapes[2].id)
        )
        
        let svg = renderer.composeDiagram(shapes)
        
        #expect(svg.contains("<svg"))
        #expect(svg.contains("Cloud"))
        #expect(svg.contains("Server"))
        #expect(svg.contains("<line")) // Connection
    }
}
```

## Performance Testing

### Benchmark Tests

```swift
struct PerformanceBenchmarks {
    
    @Test("Parsing performance")
    func benchmarkParsing() async throws {
        let sizes = [1, 10, 100, 1000] // KB
        
        for size in sizes {
            let markdown = generateMarkdown(sizeKB: size)
            
            let measurements = await measure(iterations: 100) {
                _ = await RhoeMarkdownKit.parse(markdown)
            }
            
            print("Size: \(size)KB")
            print("  Average: \(measurements.average)ms")
            print("  Median: \(measurements.median)ms")
            print("  95th percentile: \(measurements.percentile95)ms")
            
            // Performance assertions
            let expectedTime = Double(size) * 2.0 // 2ms per KB
            #expect(measurements.average < expectedTime)
        }
    }
    
    @Test("Memory usage")
    func testMemoryUsage() async throws {
        let markdown = generateMarkdown(sizeKB: 1000) // 1MB
        
        let memoryBefore = currentMemoryUsage()
        
        autoreleasepool {
            _ = await RhoeMarkdownKit.parse(markdown)
        }
        
        let memoryAfter = currentMemoryUsage()
        let memoryUsed = memoryAfter - memoryBefore
        
        print("Memory used: \(memoryUsed / 1024 / 1024)MB")
        
        // Should use less than 50MB for 1MB document
        #expect(memoryUsed < 50_000_000)
    }
    
    @Test("Concurrent parsing")
    func testConcurrentParsing() async throws {
        let documents = (0..<100).map { i in
            generateMarkdown(sizeKB: 10, seed: i)
        }
        
        let startTime = Date()
        
        await withTaskGroup(of: Document.self) { group in
            for doc in documents {
                group.addTask {
                    let result = await RhoeMarkdownKit.parse(doc)
                    return result.document
                }
            }
            
            var results: [Document] = []
            for await result in group {
                results.append(result)
            }
            
            #expect(results.count == 100)
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        print("Parsed 100 documents in \(totalTime)s")
        
        #expect(totalTime < 5.0) // Should complete within 5 seconds
    }
}
```

### SIMD Performance

```swift
struct SIMDPerformanceTests {
    
    @Test("SIMD vs Sequential")
    func compareSIMDPerformance() async throws {
        let text = String(repeating: "a", count: 1_000_000)
        
        // Sequential scanning
        let sequentialTime = await measure {
            var count = 0
            for char in text {
                if char == "a" { count += 1 }
            }
        }
        
        // SIMD scanning
        let simdTime = await measure {
            let optimizer = SIMDOptimizer()
            _ = optimizer.countOccurrences(of: "a", in: text)
        }
        
        print("Sequential: \(sequentialTime)ms")
        print("SIMD: \(simdTime)ms")
        print("Speedup: \(sequentialTime / simdTime)x")
        
        #expect(simdTime < sequentialTime)
    }
}
```

## Compliance Testing

### CommonMark Compliance

```swift
struct CommonMarkComplianceTests {
    
    @Test("CommonMark specification examples")
    func testCommonMarkExamples() async throws {
        let specTests = try loadCommonMarkTests()
        
        var passed = 0
        var failed: [(example: Int, expected: String, actual: String)] = []
        
        for test in specTests {
            let result = await RhoeMarkdownKit.parse(test.markdown)
            let html = RhoeMarkdownKit.renderHTML(result.document)
            
            if normalizeHTML(html) == normalizeHTML(test.html) {
                passed += 1
            } else {
                failed.append((test.example, test.html, html))
            }
        }
        
        print("CommonMark Compliance: \(passed)/\(specTests.count) passed")
        
        if !failed.isEmpty {
            print("Failed examples:")
            for (example, expected, actual) in failed.prefix(5) {
                print("  Example \(example):")
                print("    Expected: \(expected)")
                print("    Actual: \(actual)")
            }
        }
        
        // Expect 100% compliance
        #expect(passed == specTests.count)
    }
}
```

### GFM Compliance

```swift
struct GFMComplianceTests {
    
    @Test("Tables")
    func testGFMTables() async throws {
        let markdown = """
        | Header 1 | Header 2 |
        |----------|----------|
        | Cell 1   | Cell 2   |
        | Cell 3   | Cell 4   |
        """
        
        let result = await RhoeMarkdownKit.parse(markdown)
        
        guard case .table(let headers, let rows, _, _) = result.document.blocks[0] else {
            Issue.record("Expected table block")
            return
        }
        
        #expect(headers.count == 2)
        #expect(rows.count == 2)
        #expect(rows[0].count == 2)
    }
    
    @Test("Strikethrough")
    func testStrikethrough() async throws {
        let markdown = "~~strikethrough~~"
        
        let result = await RhoeMarkdownKit.parse(markdown)
        
        guard case .paragraph(let inlines, _) = result.document.blocks[0],
              case .strikethrough(let content) = inlines[0] else {
            Issue.record("Expected strikethrough")
            return
        }
        
        #expect(plainText(from: content) == "strikethrough")
    }
    
    @Test("Task lists")
    func testTaskLists() async throws {
        let markdown = """
        - [x] Completed
        - [ ] Incomplete
        - [x] Also completed
        """
        
        let result = await RhoeMarkdownKit.parse(markdown)
        
        guard case .list(let type, let items, _) = result.document.blocks[0] else {
            Issue.record("Expected list block")
            return
        }
        
        #expect(type == .task)
        #expect(items[0].checked == true)
        #expect(items[1].checked == false)
        #expect(items[2].checked == true)
    }
}
```

## Error Testing

### Error Handling

```swift
struct ErrorHandlingTests {
    
    @Test("Handle malformed markdown")
    func testMalformedMarkdown() async throws {
        let malformed = """
        [Unclosed link(
        ![Unclosed image[
        ```
        Unclosed code block
        """
        
        let result = await RhoeMarkdownKit.parse(malformed)
        
        // Should still produce output
        #expect(!result.document.blocks.isEmpty)
        
        // Should have diagnostics
        #expect(!result.diagnostics.isEmpty)
        
        // Check diagnostic types
        let hasUnclosedLink = result.diagnostics.contains { $0.message.contains("link") }
        #expect(hasUnclosedLink)
    }
    
    @Test("Resource limits")
    func testResourceLimits() async throws {
        // Test extremely deep nesting
        let deepNesting = String(repeating: "> ", count: 1000) + "Content"
        
        let result = await RhoeMarkdownKit.parse(deepNesting)
        
        // Should handle gracefully
        #expect(result.document.blocks.count > 0)
        
        // May have warning about depth
        let hasDepthWarning = result.diagnostics.contains { $0.severity == .warning }
        #expect(hasDepthWarning)
    }
}
```

## Test Utilities

### Helper Functions

```swift
// Test helper utilities
extension RhoeMarkdownKitTests {
    
    func loadFixture(_ name: String) throws -> String {
        let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")!
        return try String(contentsOf: url)
    }
    
    func generateMarkdown(sizeKB: Int, seed: Int = 0) -> String {
        var rng = SeededRandomNumberGenerator(seed: seed)
        var markdown = ""
        let targetSize = sizeKB * 1024
        
        while markdown.count < targetSize {
            markdown += generateRandomBlock(using: &rng)
            markdown += "\n\n"
        }
        
        return String(markdown.prefix(targetSize))
    }
    
    func normalizeHTML(_ html: String) -> String {
        html
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "> <", with: "><")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func plainText(from inlines: [Inline]) -> String {
        inlines.map { inline in
            switch inline {
            case .text(let str): return str
            case .emphasis(let content): return plainText(from: content)
            case .strong(let content): return plainText(from: content)
            default: return ""
            }
        }.joined()
    }
    
    func extractLinks(from document: Document) -> [(url: String, title: String?)] {
        var links: [(String, String?)] = []
        
        for block in document.blocks {
            links.append(contentsOf: extractLinksFromBlock(block))
        }
        
        return links
    }
}
```

### Custom Assertions

```swift
// Custom test assertions
extension Testing {
    
    func expectBlock<T>(_ block: Block, toBe type: T.Type, file: StaticString = #file, line: UInt = #line) -> T? {
        guard let typed = block as? T else {
            Issue.record("Expected \(type) but got \(block)", sourceLocation: SourceLocation(file: file, line: line))
            return nil
        }
        return typed
    }
    
    func expectMarkdownEquals(_ actual: String, _ expected: String, file: StaticString = #file, line: UInt = #line) async {
        let actualDoc = await RhoeMarkdownKit.parse(actual).document
        let expectedDoc = await RhoeMarkdownKit.parse(expected).document
        
        if !documentsEqual(actualDoc, expectedDoc) {
            Issue.record("Documents not equal", sourceLocation: SourceLocation(file: file, line: line))
        }
    }
}
```

### Test Fixtures

```swift
// Generate test fixtures
struct FixtureGenerator {
    
    static func generateComplexDocument() -> String {
        """
        ---
        title: Complex Test Document
        author: Test Suite
        date: 2024-01-01
        ---
        
        # Main Heading
        
        This is a paragraph with **bold**, *italic*, and ***bold italic*** text.
        
        ## Lists
        
        - Unordered item 1
        - Unordered item 2
          - Nested item 2.1
          - Nested item 2.2
        - Unordered item 3
        
        1. Ordered item 1
        2. Ordered item 2
        3. Ordered item 3
        
        ## Code
        
        ```swift
        func hello() {
            print("Hello, World!")
        }
        ```
        
        ## Table
        
        | Column 1 | Column 2 | Column 3 |
        |----------|----------|----------|
        | Cell 1   | Cell 2   | Cell 3   |
        | Cell 4   | Cell 5   | Cell 6   |
        
        ## Links and Images
        
        [Link text](https://example.com "Title")
        ![Alt text](image.jpg "Image title")
        
        ## Block Quote
        
        > This is a block quote.
        > It can span multiple lines.
        
        ## Math
        
        Inline: $a^2 + b^2 = c^2$
        
        Display:
        $$
        \\int_{-\\infty}^{\\infty} e^{-x^2} dx = \\sqrt{\\pi}
        $$
        """
    }
}
```

## Test Coverage

### Coverage Reporting

```swift
// Generate coverage report
struct CoverageReporter {
    
    static func generateReport() async throws {
        let coverage = try await measureCoverage {
            try await runAllTests()
        }
        
        print("Coverage Report:")
        print("  Line Coverage: \(coverage.lineCoverage)%")
        print("  Branch Coverage: \(coverage.branchCoverage)%")
        print("  Function Coverage: \(coverage.functionCoverage)%")
        
        // Generate detailed HTML report
        let html = generateHTMLReport(coverage)
        try html.write(to: URL(fileURLWithPath: "coverage.html"))
    }
}
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.4.app
      
      - name: Run Tests
        run: swift test --parallel
      
      - name: Generate Coverage
        run: |
          swift test --enable-code-coverage
          xcrun llvm-cov export \
            .build/debug/RhoeMarkdownKitPackageTests.xctest/Contents/MacOS/RhoeMarkdownKitPackageTests \
            -instr-profile .build/debug/codecov/default.profdata \
            -format lcov > coverage.lcov
      
      - name: Upload Coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.lcov
```

## Best Practices

1. **Test early and often** - Write tests alongside code
2. **Use descriptive names** - Clear test names document behavior
3. **Test edge cases** - Don't just test the happy path
4. **Keep tests fast** - Use mocks and stubs when appropriate
5. **Test in isolation** - Each test should be independent
6. **Use fixtures** - Consistent test data across runs
7. **Measure coverage** - Aim for 90%+ coverage
8. **Performance test** - Catch regressions early
9. **Test concurrency** - Verify thread safety
10. **Document failures** - Clear error messages help debugging

## Next Steps

- Explore <doc:Performance> for optimization testing
- Learn about <doc:Security> for security testing
- Use the repository CI workflows as the release automation reference.
- Check <doc:Troubleshooting> for diagnostic workflows.
