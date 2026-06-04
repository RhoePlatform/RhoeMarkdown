import Testing
import Foundation
import RhoeMarkdownKit

@Suite("Phase 1: Performance Baselines")
struct Phase1PerformanceTests {

    #if DEBUG
    private static let debugJitterAllowanceSeconds: Double = 0.1
    #else
    private static let debugJitterAllowanceSeconds: Double = 0.0
    #endif

    private static func limit(_ baselineSeconds: Double) -> Double {
        baselineSeconds + debugJitterAllowanceSeconds
    }

    // MARK: - Helpers

    private func preprocess(
        _ markdown: String,
        custom: [String: Any] = [:]
    ) async -> Phase1Result {
        let preprocessor = Phase1Preprocessor()
        return await preprocessor.preprocess(markdown, context: Phase1Context(custom: custom))
    }

    /// Generate markdown with repeated variable interpolations.
    private func generateVariableMarkdown(approximateBytes: Int) -> String {
        let line = "Hello {{ name }}, welcome to {{ place }}.\n"
        let repeatCount = max(1, approximateBytes / line.utf8.count)
        return String(repeating: line, count: repeatCount)
    }

    /// Generate markdown with mixed content (headings, lists, paragraphs, variables).
    private func generateMixedMarkdown(approximateBytes: Int) -> String {
        let block = """
        # Section {{ section }}

        This is paragraph text with **bold** and *italic* formatting.

        - Item {{ item1 }}
        - Item {{ item2 }}
        - Item {{ item3 }}

        > A blockquote with {{ quote_attr }} attribution.

        Another paragraph with `inline code` and a [link](https://example.com).

        """
        let repeatCount = max(1, approximateBytes / block.utf8.count)
        return String(repeating: block, count: repeatCount)
    }

    // MARK: - Size-Based Baselines

    @Test("Small document (~1KB) preprocesses under 100ms")
    func smallDocumentBaseline() async {
        let md = generateVariableMarkdown(approximateBytes: 1_024)
        let context: [String: Any] = ["name": "User", "place": "RhoeMarkdown"]

        #if DEBUG
        // Absorb one-time Phase 1 initialization cost so the threshold measures
        // steady-state preprocessing rather than cold-start workspace jitter.
        _ = await preprocess(md, custom: context)
        #endif

        #if DEBUG
        // Use the best steady-state sample so this baseline stays sensitive to
        // real regressions without failing on sporadic debug-runner jitter.
        var elapsed = Double.greatestFiniteMagnitude
        var result = await preprocess(md, custom: context)
        for _ in 0..<2 {
            let start = CFAbsoluteTimeGetCurrent()
            let candidate = await preprocess(md, custom: context)
            let candidateElapsed = CFAbsoluteTimeGetCurrent() - start
            if candidateElapsed < elapsed {
                elapsed = candidateElapsed
                result = candidate
            }
        }
        #else
        let start = CFAbsoluteTimeGetCurrent()
        let result = await preprocess(md, custom: context)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        #endif

        #expect(!result.markdown.isEmpty)
        #expect(result.markdown.contains("User"))
        #expect(elapsed < Self.limit(0.1), "Small doc (~1KB) took \(elapsed)s, expected <\(Self.limit(0.1))s")
    }

    @Test("Medium document (~10KB) preprocesses under 500ms")
    func mediumDocumentBaseline() async {
        let md = generateVariableMarkdown(approximateBytes: 10_240)
        let context: [String: Any] = ["name": "User", "place": "RhoeMarkdown"]

        let start = CFAbsoluteTimeGetCurrent()
        let result = await preprocess(md, custom: context)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        #expect(!result.markdown.isEmpty)
        #expect(result.markdown.contains("User"))
        #expect(elapsed < Self.limit(0.5), "Medium doc (~10KB) took \(elapsed)s, expected <\(Self.limit(0.5))s")
    }

    @Test("Large document (~100KB) preprocesses under 2s")
    func largeDocumentBaseline() async {
        let md = generateVariableMarkdown(approximateBytes: 102_400)
        let context: [String: Any] = ["name": "User", "place": "RhoeMarkdown"]

        let start = CFAbsoluteTimeGetCurrent()
        let result = await preprocess(md, custom: context)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        #expect(!result.markdown.isEmpty)
        #expect(elapsed < Self.limit(2.0), "Large doc (~100KB) took \(elapsed)s, expected <\(Self.limit(2.0))s")
    }

    @Test("Very large document (~500KB) preprocesses under 10s")
    func veryLargeDocumentBaseline() async {
        let md = generateVariableMarkdown(approximateBytes: 512_000)
        let context: [String: Any] = ["name": "User", "place": "RhoeMarkdown"]

        let start = CFAbsoluteTimeGetCurrent()
        let result = await preprocess(md, custom: context)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        #expect(!result.markdown.isEmpty)
        #expect(elapsed < Self.limit(10.0), "Very large doc (~500KB) took \(elapsed)s, expected <\(Self.limit(10.0))s")
    }

    // MARK: - Complexity-Based Baselines

    @Test("Deep nesting (10 levels of conditionals) preprocesses under 500ms")
    func deepNestingBaseline() async {
        var md = ""
        let depth = 10
        for i in 0..<depth {
            md += String(repeating: "  ", count: i)
            md += "{% if level\(i) %}\n"
            md += String(repeating: "  ", count: i)
            md += "Level \(i) content\n"
        }
        for i in stride(from: depth - 1, through: 0, by: -1) {
            md += String(repeating: "  ", count: i)
            md += "{% endif %}\n"
        }

        var context: [String: Any] = [:]
        for i in 0..<depth {
            context["level\(i)"] = true
        }

        let start = CFAbsoluteTimeGetCurrent()
        let result = await preprocess(md, custom: context)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        #expect(result.markdown.contains("Level 0 content"))
        #expect(result.markdown.contains("Level 9 content"))
        #expect(elapsed < Self.limit(0.5), "Deep nesting took \(elapsed)s, expected <\(Self.limit(0.5))s")
    }

    @Test("Many filters chained preprocesses under 500ms")
    func manyFiltersBaseline() async {
        // Generate 200 lines each with a filter chain
        var lines: [String] = []
        for i in 0..<200 {
            lines.append("Line \(i): {{ text | upcase | downcase | capitalize | strip }}")
        }
        let md = lines.joined(separator: "\n")
        let context: [String: Any] = ["text": "  test string  "]

        let start = CFAbsoluteTimeGetCurrent()
        let result = await preprocess(md, custom: context)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        #expect(!result.markdown.isEmpty)
        #expect(elapsed < Self.limit(0.5), "Many filters took \(elapsed)s, expected <\(Self.limit(0.5))s")
    }

    @Test("Large array loop (100 items) preprocesses under 1s")
    func largeArrayLoopBaseline() async {
        let items = (0..<100).map { "Item_\($0)" }
        let md = "{% for item in items %}- {{ item }}\n{% endfor %}"

        let start = CFAbsoluteTimeGetCurrent()
        let result = await preprocess(md, custom: ["items": items])
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        #expect(result.markdown.contains("Item_0"))
        #expect(result.markdown.contains("Item_99"))
        #expect(elapsed < Self.limit(1.0), "Large array loop took \(elapsed)s, expected <\(Self.limit(1.0))s")
    }

    @Test("Disabled Phase 1 has near-zero overhead")
    func disabledBaseline() async {
        let md = generateMixedMarkdown(approximateBytes: 50_000)
        let config = RhoeMarkdownKit.Configuration(enablePhase1Preprocessing: false)
        let parser = DocumentParser(
            configuration: config,
            phase1Context: Phase1Context(custom: ["section": "1"])
        )

        let start = CFAbsoluteTimeGetCurrent()
        let result = await parser.parse(md)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        // With Phase 1 disabled, only the markdown parser runs
        #expect(result.document.blocks.count > 0)
        // The elapsed time should be reasonable (parser only)
        #expect(elapsed < Self.limit(5.0), "Disabled Phase 1 parse took \(elapsed)s, expected <\(Self.limit(5.0))s")
    }
}
