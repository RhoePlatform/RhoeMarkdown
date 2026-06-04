import Testing
import Foundation
import RhoeMarkdownKit

@Suite("Phase 1: Stress Tests")
struct Phase1StressTests {

    // MARK: - Helpers

    private func preprocess(
        _ markdown: String,
        custom: [String: Any] = [:]
    ) async -> Phase1Result {
        let preprocessor = Phase1Preprocessor()
        return await preprocessor.preprocess(markdown, context: Phase1Context(custom: custom))
    }

    // MARK: - High Volume Tests

    @Test("5000 variable interpolations complete without crash")
    func manyVariableInterpolations() async {
        var lines: [String] = []
        for i in 0..<5_000 {
            lines.append("Line \(i): {{ greeting }}")
        }
        let md = lines.joined(separator: "\n")
        let result = await preprocess(md, custom: ["greeting": "Hi"])

        #expect(result.markdown.contains("Hi"))
        #expect(!result.markdown.contains("{{ greeting }}"))
        // Verify all lines were processed
        #expect(result.markdown.contains("Line 0:"))
        #expect(result.markdown.contains("Line 4999:"))
        #expect(result.diagnostics.isEmpty)
    }

    @Test("Deeply nested conditionals (15 levels) complete without crash")
    func deeplyNestedConditionals() async {
        let depth = 15
        var md = ""

        // Build nested if blocks
        for i in 0..<depth {
            let indent = String(repeating: "  ", count: i)
            md += "\(indent){% if v\(i) %}\n"
            md += "\(indent)Content at depth \(i)\n"
        }
        // Close all blocks
        for i in stride(from: depth - 1, through: 0, by: -1) {
            let indent = String(repeating: "  ", count: i)
            md += "\(indent){% endif %}\n"
        }

        // All conditions true
        var context: [String: Any] = [:]
        for i in 0..<depth {
            context["v\(i)"] = true
        }

        let result = await preprocess(md, custom: context)

        // Should render all content levels
        #expect(result.markdown.contains("Content at depth 0"))
        #expect(result.markdown.contains("Content at depth 14"))
        #expect(result.diagnostics.isEmpty)
    }

    @Test("500 for-loop iterations complete without crash")
    func manyForLoopIterations() async {
        let items = (0..<500).map { "item_\($0)" }
        let md = "{% for item in items %}{{ forloop.index }}. {{ item }}\n{% endfor %}"

        let result = await preprocess(md, custom: ["items": items])

        #expect(result.markdown.contains("1. item_0"))
        #expect(result.markdown.contains("500. item_499"))
        #expect(result.diagnostics.isEmpty)
    }

    @Test("Mixed Liquid and complex markdown complete without crash")
    func mixedLiquidAndMarkdown() async {
        var md = ""

        // Build a complex document with many different markdown constructs
        // interspersed with Liquid
        for section in 0..<50 {
            md += """
            {% if show_section %}
            ## Section {{ section_prefix }}-\(section)

            This paragraph has **bold**, *italic*, and `code` formatting.

            | Column A | Column B |
            | --- | --- |
            {% for row in rows %}| {{ row }} | Value |
            {% endfor %}

            > Blockquote in section \(section)

            - List item {{ item_label }} alpha
            - List item {{ item_label }} beta

            ---

            {% endif %}

            """
        }

        let context: [String: Any] = [
            "show_section": true,
            "section_prefix": "S",
            "rows": ["R1", "R2", "R3"],
            "item_label": "L"
        ]

        let result = await preprocess(md, custom: context)

        #expect(result.markdown.contains("## Section S-0"))
        #expect(result.markdown.contains("## Section S-49"))
        #expect(result.markdown.contains("| R1 | Value |"))
        #expect(result.markdown.contains("List item L alpha"))
        #expect(result.diagnostics.isEmpty)
    }

    @Test("Concurrent preprocessing of 3 documents completes without data races")
    func concurrentPreprocessing() async {
        // Build Phase1Context values eagerly so the [String: Any] dictionaries
        // are not captured across a sendability boundary.
        let inputs: [(Int, String, Phase1Context)] = [
            (0, "Doc A: {{ name }}", Phase1Context(custom: ["name": "Alice"])),
            (1, "Doc B: {{ name }}", Phase1Context(custom: ["name": "Bob"])),
            (2, "Doc C: {{ name }}", Phase1Context(custom: ["name": "Charlie"]))
        ]

        let results = await withTaskGroup(
            of: (Int, Phase1Result).self,
            returning: [(Int, Phase1Result)].self
        ) { group in
            for (index, md, ctx) in inputs {
                let capturedIndex = index
                let capturedMd = md
                let capturedCtx = ctx
                group.addTask {
                    let preprocessor = Phase1Preprocessor()
                    let result = await preprocessor.preprocess(
                        capturedMd,
                        context: capturedCtx
                    )
                    return (capturedIndex, result)
                }
            }

            var collected: [(Int, Phase1Result)] = []
            for await item in group {
                collected.append(item)
            }
            return collected.sorted { $0.0 < $1.0 }
        }

        #expect(results.count == 3)
        #expect(results[0].1.markdown.contains("Alice"))
        #expect(results[1].1.markdown.contains("Bob"))
        #expect(results[2].1.markdown.contains("Charlie"))

        // No cross-contamination
        #expect(!results[0].1.markdown.contains("Bob"))
        #expect(!results[0].1.markdown.contains("Charlie"))
        #expect(!results[1].1.markdown.contains("Alice"))
        #expect(!results[2].1.markdown.contains("Alice"))
    }
}
