import Testing
import Foundation
import RhoeMarkdownKit
import RhoeMarkdownModel
import RhoeMarkdownRendering

/// Performance throughput benchmarks for the RhoeMarkdown compiler.
///
/// Thresholds are set for debug mode (5x release targets).
/// Release targets: 10KB parse < 50ms, 100KB parse < 500ms.
@Suite("Performance: Throughput Benchmarks")
struct PerformanceTests {

    // Debug builds are ~5x slower; use generous thresholds that catch gross regressions
    // without failing on normal debug-mode overhead.
    #if DEBUG
    private static let multiplier: Double = 10.0
    private static let jitterAllowanceMS: Double = 50.0
    #else
    private static let multiplier: Double = 1.0
    private static let jitterAllowanceMS: Double = 0.0
    #endif

    private static let hostedCIMultiplier: Double =
        ProcessInfo.processInfo.environment["CI"] == "true" ? 3.0 : 1.0

    private static func limit(_ baseline: Double) -> Double {
        ((baseline * multiplier) + jitterAllowanceMS) * hostedCIMultiplier
    }

    // MARK: - Test Document Generation

    private func generateDocument(sizeKB: Int) -> String {
        var lines: [String] = ["# Performance Test Document\n"]
        let paragraph = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.\n"
        let codeFence = "```swift\nlet x = 42\nprint(x)\n```\n"
        let table = "| A | B | C |\n|---|---|---|\n| 1 | 2 | 3 |\n| 4 | 5 | 6 |\n"
        let targetBytes = sizeKB * 1024
        var currentSize = lines.joined().utf8.count
        var sectionCount = 0

        while currentSize < targetBytes {
            sectionCount += 1
            lines.append("\n## Section \(sectionCount)\n")
            lines.append(paragraph)
            lines.append("Some **bold** and *italic* text with `inline code` and a [link](https://example.com).\n")
            lines.append(paragraph)
            if sectionCount % 3 == 0 { lines.append(codeFence) }
            if sectionCount % 5 == 0 { lines.append(table) }
            currentSize = lines.joined().utf8.count
        }
        return lines.joined()
    }

    // MARK: - Parse Throughput

    @Test("Parse 10KB document within threshold")
    func parse10KB() async {
        let doc = generateDocument(sizeKB: 10)
        let start = CFAbsoluteTimeGetCurrent()
        let _ = await RhoeMarkdownKit.parse(doc)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let limit = Self.limit(50.0)
        #expect(elapsed < limit, "Parse 10KB: \(String(format: "%.1f", elapsed))ms (limit: \(String(format: "%.0f", limit))ms)")
    }

    @Test("Parse 100KB document within threshold")
    func parse100KB() async {
        let doc = generateDocument(sizeKB: 100)
        let start = CFAbsoluteTimeGetCurrent()
        let _ = await RhoeMarkdownKit.parse(doc)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let limit = Self.limit(500.0)
        #expect(elapsed < limit, "Parse 100KB: \(String(format: "%.1f", elapsed))ms (limit: \(String(format: "%.0f", limit))ms)")
    }

    // MARK: - HTML Render Throughput

    @Test("HTML render 10KB document within threshold")
    func htmlRender10KB() async {
        let doc = generateDocument(sizeKB: 10)
        let parsed = await RhoeMarkdownKit.parse(doc)
        let start = CFAbsoluteTimeGetCurrent()
        let _ = RhoeMarkdownKit.renderHTML(parsed.document)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let limit = Self.limit(50.0)
        #expect(elapsed < limit, "HTML render 10KB: \(String(format: "%.1f", elapsed))ms (limit: \(String(format: "%.0f", limit))ms)")
    }

    @Test("HTML render 100KB document within threshold")
    func htmlRender100KB() async {
        let doc = generateDocument(sizeKB: 100)
        let parsed = await RhoeMarkdownKit.parse(doc)
        let start = CFAbsoluteTimeGetCurrent()
        let _ = RhoeMarkdownKit.renderHTML(parsed.document)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let limit = Self.limit(500.0)
        #expect(elapsed < limit, "HTML render 100KB: \(String(format: "%.1f", elapsed))ms (limit: \(String(format: "%.0f", limit))ms)")
    }

    // MARK: - Full Pipeline

    @Test("Full pipeline 10KB within threshold")
    func fullPipeline10KB() async {
        let doc = generateDocument(sizeKB: 10)
        let start = CFAbsoluteTimeGetCurrent()
        let _ = await RhoeMarkdownKit.toHTML(doc)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let limit = Self.limit(100.0)
        #expect(elapsed < limit, "Pipeline 10KB: \(String(format: "%.1f", elapsed))ms (limit: \(String(format: "%.0f", limit))ms)")
    }

    @Test("Full pipeline 100KB within threshold")
    func fullPipeline100KB() async {
        let doc = generateDocument(sizeKB: 100)
        let start = CFAbsoluteTimeGetCurrent()
        let _ = await RhoeMarkdownKit.toHTML(doc)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let limit = Self.limit(1000.0)
        #expect(elapsed < limit, "Pipeline 100KB: \(String(format: "%.1f", elapsed))ms (limit: \(String(format: "%.0f", limit))ms)")
    }

    // MARK: - HTML Escape

    @Test("HTML escape fast path for clean strings")
    func htmlEscapeFastPath() {
        let clean = "This is a completely clean string with no special characters at all."
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<10_000 {
            let _ = clean.htmlEscaped()
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let limit = Self.limit(50.0)
        #expect(elapsed < limit, "Escape fast path 10K: \(String(format: "%.1f", elapsed))ms")
    }

    @Test("HTML escape handles special characters efficiently")
    func htmlEscapeSpecialChars() {
        let dirty = "<script>alert('xss');</script> & \"quoted\" text with <tags>"
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<10_000 {
            let _ = dirty.htmlEscaped()
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let limit = Self.limit(100.0)
        #expect(elapsed < limit, "Escape dirty 10K: \(String(format: "%.1f", elapsed))ms")
    }

    // MARK: - Writer Throughput

    @Test("Typst render 10KB within threshold")
    func typstRender10KB() async {
        let doc = generateDocument(sizeKB: 10)
        let parsed = await RhoeMarkdownKit.parse(doc)
        let start = CFAbsoluteTimeGetCurrent()
        let _ = RhoeMarkdownKit.renderTypst(parsed.document)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let limit = Self.limit(50.0)
        #expect(elapsed < limit, "Typst 10KB: \(String(format: "%.1f", elapsed))ms")
    }

    @Test("LaTeX render 10KB within threshold")
    func latexRender10KB() async {
        let doc = generateDocument(sizeKB: 10)
        let parsed = await RhoeMarkdownKit.parse(doc)
        let start = CFAbsoluteTimeGetCurrent()
        let _ = RhoeMarkdownKit.renderLaTeX(parsed.document)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let limit = Self.limit(50.0)
        #expect(elapsed < limit, "LaTeX 10KB: \(String(format: "%.1f", elapsed))ms")
    }

    @Test("JSON render 10KB within threshold")
    func jsonRender10KB() async {
        let doc = generateDocument(sizeKB: 10)
        let parsed = await RhoeMarkdownKit.parse(doc)
        let start = CFAbsoluteTimeGetCurrent()
        let _ = RhoeMarkdownKit.renderJSON(parsed.document)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let limit = Self.limit(50.0)
        #expect(elapsed < limit, "JSON 10KB: \(String(format: "%.1f", elapsed))ms")
    }

    // MARK: - HTMLStringBuilder

    @Test("HTMLStringBuilder handles 10,000 appends efficiently")
    func stringBuilderPerformance() {
        let start = CFAbsoluteTimeGetCurrent()
        var builder = HTMLStringBuilder(estimatedSize: 100_000)
        for i in 0..<10_000 {
            builder.append("<p>Paragraph \(i)</p>")
        }
        let result = builder.build()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        #expect(result.count > 100_000)
        let limit = Self.limit(100.0)
        #expect(elapsed < limit, "StringBuilder 10K: \(String(format: "%.1f", elapsed))ms")
    }
}
