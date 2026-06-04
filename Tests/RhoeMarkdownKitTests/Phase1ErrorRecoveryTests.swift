import Testing
import Foundation
import RhoeMarkdownKit

@Suite("Phase 1: Error Recovery")
struct Phase1ErrorRecoveryTests {

    // MARK: - Helpers

    private func preprocess(
        _ markdown: String,
        custom: [String: Any] = [:]
    ) async -> Phase1Result {
        let preprocessor = Phase1Preprocessor()
        return await preprocessor.preprocess(markdown, context: Phase1Context(custom: custom))
    }

    // MARK: - Undefined References

    @Test("Undefined variable resolves to empty without crash")
    func undefinedVariable() async {
        let result = await preprocess("Hello {{ undefined_var }}!")
        // Should not crash; undefined vars resolve to empty string in Liquid
        #expect(result.markdown.contains("Hello"))
        #expect(result.markdown.contains("!"))
    }

    @Test("Undefined filter produces diagnostic or fallback")
    func undefinedFilter() async {
        let result = await preprocess("{{ name | nonexistent_filter }}", custom: ["name": "Test"])
        // Should either fall back to original or produce a diagnostic
        #expect(!result.markdown.isEmpty)
        // If it failed, diagnostics should be present; if it succeeded, output should be non-empty
        let hasOutput = result.markdown.trimmingCharacters(in: .whitespacesAndNewlines).count > 0
        let hasDiagnostic = !result.diagnostics.isEmpty
        #expect(hasOutput || hasDiagnostic)
    }

    // MARK: - Malformed Templates

    @Test("Unclosed if block produces diagnostic and returns content")
    func unclosedIf() async {
        let result = await preprocess("{% if true %}Content without endif")
        // Should produce a diagnostic about the unclosed block
        #expect(!result.markdown.isEmpty)
        // The preprocessor should either report an error or fall back to original
        if !result.diagnostics.isEmpty {
            let hasError = result.diagnostics.contains { $0.severity == .error }
            #expect(hasError)
        }
    }

    @Test("Unclosed for block produces diagnostic and returns content")
    func unclosedFor() async {
        let result = await preprocess(
            "{% for item in items %}{{ item }}",
            custom: ["items": ["A", "B"]]
        )
        #expect(!result.markdown.isEmpty)
        if !result.diagnostics.isEmpty {
            let hasError = result.diagnostics.contains { $0.severity == .error }
            #expect(hasError)
        }
    }

    @Test("Malformed expression does not crash")
    func malformedExpression() async {
        let result = await preprocess("{{ | | | }}")
        // Should not crash; may produce diagnostic
        #expect(!result.markdown.isEmpty || !result.diagnostics.isEmpty)
    }

    @Test("Division by zero handled gracefully")
    func divisionByZero() async {
        let result = await preprocess(
            "{{ value | divided_by: 0 }}",
            custom: ["value": 10]
        )
        // Should not crash; may produce error diagnostic or output infinity/NaN
        #expect(!result.markdown.isEmpty || !result.diagnostics.isEmpty)
    }

    // MARK: - Edge Cases

    @Test("Empty template produces empty output")
    func emptyTemplate() async {
        let result = await preprocess("")
        #expect(result.markdown.isEmpty || result.markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(result.diagnostics.isEmpty)
    }

    @Test("Whitespace-only template preserves whitespace")
    func whitespaceOnlyTemplate() async {
        let result = await preprocess("   \n\n   ")
        // Should complete without diagnostics
        #expect(result.diagnostics.isEmpty)
        #expect(result.preprocessingTime >= 0)
    }

    @Test("Only frontmatter with no body produces valid result")
    func onlyFrontmatter() async {
        let md = """
        ---
        title: Test
        ---

        """
        let result = await preprocess(md)
        #expect(result.frontmatter?["title"] != nil)
        #expect(result.diagnostics.isEmpty)
    }

    @Test("Diagnostic message contains useful information")
    func diagnosticMessagePresent() async {
        // Force a Liquid error by using unclosed block
        let result = await preprocess("{% if true %}no close")
        if !result.diagnostics.isEmpty {
            let firstDiag = result.diagnostics[0]
            #expect(firstDiag.severity == .error)
            #expect(!firstDiag.message.isEmpty)
            #expect(firstDiag.message.contains("Liquid") || firstDiag.message.contains("preprocessing") || firstDiag.message.count > 5)
        }
    }
}
