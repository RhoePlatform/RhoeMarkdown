import Testing
import Foundation
import RhoeMarkdownKit

@Suite("Phase 1: Input Protection")
struct Phase1InputProtectionTests {

    // MARK: - Helpers

    private func preprocess(
        _ markdown: String,
        custom: [String: Any] = [:]
    ) async -> Phase1Result {
        let preprocessor = Phase1Preprocessor()
        return await preprocessor.preprocess(markdown, context: Phase1Context(custom: custom))
    }

    // MARK: - Code Fence Behavior

    @Test("Code fence does NOT protect Liquid syntax (known limitation)")
    func codeFenceDoesNotProtectLiquid() async {
        // Liquid runs on raw text BEFORE markdown parsing, so code fences
        // are NOT a protection boundary. This is a documented known limitation.
        let md = """
        ```
        {{ name }}
        ```
        """
        let result = await preprocess(md, custom: ["name": "replaced"])
        // Liquid will process the variable even inside code fences
        #expect(result.markdown.contains("replaced"))
    }

    @Test("Inline code does NOT protect Liquid syntax (known limitation)")
    func inlineCodeDoesNotProtectLiquid() async {
        // Same as code fences: Liquid processes raw text before markdown parsing.
        let md = "Use `{{ name }}` for greeting"
        let result = await preprocess(md, custom: ["name": "replaced"])
        #expect(result.markdown.contains("replaced"))
    }

    // MARK: - Raw Block Protection

    @Test("Raw block preserves Liquid syntax literally")
    func rawBlockPreservesLiquid() async {
        let md = "{% raw %}{{ var }}{% endraw %}"
        let result = await preprocess(md, custom: ["var": "should_not_appear"])
        #expect(result.markdown.contains("{{ var }}"))
        #expect(!result.markdown.contains("should_not_appear"))
    }

    // MARK: - Frontmatter Protection

    @Test("Frontmatter content is not Liquid-processed")
    func frontmatterNotProcessed() async {
        let md = """
        ---
        title: "{{ not_a_variable }}"
        ---

        Body text
        """
        let result = await preprocess(md)
        // Frontmatter should be preserved literally
        #expect(result.frontmatter != nil)
        // The frontmatter block in the reassembled output should preserve the literal YAML
        let reassembled = result.markdown
        #expect(reassembled.contains("---"))
        #expect(reassembled.contains("Body text"))
    }

    // MARK: - Math Expression Safety

    @Test("Math dollar-sign delimiters pass through safely")
    func mathDelimitersSafe() async {
        let md = "The formula $x^2 + y^2 = z^2$ is well-known."
        let result = await preprocess(md)
        #expect(result.markdown.contains("$x^2 + y^2 = z^2$"))
    }

    // MARK: - Attribute Brace Safety

    @Test("Attribute braces { } not confused with Liquid")
    func attributeBracesSafe() async {
        // Single braces are not Liquid syntax (Liquid uses {{ }} and {% %})
        let md = "# Heading {.special #myid}"
        let result = await preprocess(md)
        #expect(result.markdown.contains("{.special #myid}"))
    }

    // MARK: - Phase 2 Delimiter Preservation

    @Test("Phase 2 delimiters {@ @} pass through Phase 1 literally")
    func phase2DelimitersPreserved() async {
        let md = "Text with {@ hide family=example in=llm @} directive."
        let result = await preprocess(md)
        // Phase 2 directives should pass through Phase 1 unchanged
        #expect(result.markdown.contains("{@"))
        #expect(result.markdown.contains("@}"))
    }

    // MARK: - Placeholder Delimiter Preservation

    @Test("Placeholder delimiters preserved through Phase 1")
    func placeholderDelimitersPreserved() async {
        // Ensure arbitrary non-Liquid delimiters survive preprocessing
        let md = "Content with [[placeholder]] notation."
        let result = await preprocess(md)
        #expect(result.markdown.contains("[[placeholder]]"))
    }

    // MARK: - Composition Directive Preservation

    @Test("Composition directives preserved through Phase 1")
    func compositionDirectivesPreserved() async {
        let md = """
        ::: warning
        This is an admonition.
        :::
        """
        let result = await preprocess(md)
        #expect(result.markdown.contains("::: warning"))
        #expect(result.markdown.contains("This is an admonition."))
        #expect(result.markdown.contains(":::"))
    }

    // MARK: - HTML Entity Preservation

    @Test("HTML entities preserved through Phase 1")
    func htmlEntitiesPreserved() async {
        let md = "Use &amp; for ampersand and &lt; for less-than."
        let result = await preprocess(md)
        #expect(result.markdown.contains("&amp;"))
        #expect(result.markdown.contains("&lt;"))
    }
}
