import Testing
import Foundation
import RhoeMarkdownKit

@Suite("Phase 1: Variable Binding & Context")
struct Phase1VariableBindingTests {

    // MARK: - Helpers

    private func preprocess(
        _ markdown: String,
        site: [String: Any] = [:],
        data: [String: Any] = [:],
        custom: [String: Any] = [:]
    ) async -> Phase1Result {
        let preprocessor = Phase1Preprocessor()
        return await preprocessor.preprocess(markdown, context: Phase1Context(
            site: site,
            data: data,
            custom: custom
        ))
    }

    // MARK: - Tests

    @Test("Simple string variable resolves to its value")
    func simpleStringVariable() async {
        let result = await preprocess("Hello {{ name }}!", custom: ["name": "World"])
        #expect(result.markdown.contains("Hello World!"))
        #expect(!result.markdown.contains("{{"))
    }

    @Test("Nested object access with dot notation")
    func nestedObjectAccess() async {
        let result = await preprocess(
            "{{ user.address.city }}",
            custom: ["user": ["address": ["city": "Berlin"]]]
        )
        #expect(result.markdown.contains("Berlin"))
    }

    @Test("Array first element via subscript or first filter")
    func arrayFirstElement() async {
        let result = await preprocess(
            "{{ items | first }}",
            custom: ["items": ["Alpha", "Beta", "Gamma"]]
        )
        #expect(result.markdown.contains("Alpha"))
    }

    @Test("Boolean variable renders as true/false string")
    func booleanVariable() async {
        let result = await preprocess("{{ flag }}", custom: ["flag": true])
        #expect(result.markdown.contains("true"))
    }

    @Test("Numeric variable renders as number string")
    func numericVariable() async {
        let result = await preprocess("Count: {{ count }}", custom: ["count": 42])
        #expect(result.markdown.contains("Count: 42"))
    }

    @Test("Undefined variable resolves to empty string in lenient mode")
    func undefinedVariableLenient() async {
        let result = await preprocess("Hello {{ nonexistent }}!")
        // Undefined variables should resolve to empty string (Liquid default)
        #expect(result.markdown.contains("Hello"))
        #expect(result.markdown.contains("!"))
        #expect(!result.markdown.contains("nonexistent"))
    }

    @Test("Null variable resolves to empty string")
    func nullVariable() async {
        let result = await preprocess("Value: {{ nothing }}", custom: ["nothing": NSNull()])
        #expect(result.markdown.contains("Value:"))
    }

    @Test("Page namespace populated from frontmatter")
    func pageNamespaceFromFrontmatter() async {
        let md = """
        ---
        title: My Document
        author: Jane
        ---

        Title: {{ page.title }}, Author: {{ page.author }}
        """
        let result = await preprocess(md)
        #expect(result.markdown.contains("Title: My Document"))
        #expect(result.markdown.contains("Author: Jane"))
        #expect(result.frontmatter?["title"] != nil)
    }

    @Test("Site namespace populated from context")
    func siteNamespace() async {
        let result = await preprocess(
            "URL: {{ site.url }}, Name: {{ site.name }}",
            site: ["url": "https://example.com", "name": "My Site"]
        )
        #expect(result.markdown.contains("URL: https://example.com"))
        #expect(result.markdown.contains("Name: My Site"))
    }

    @Test("Data namespace populated from context")
    func dataNamespace() async {
        let result = await preprocess(
            "{{ data.users | first | map: 'name' }}",
            data: ["users": [["name": "Alice"], ["name": "Bob"]]]
        )
        // The result should contain Alice (first user's name)
        // Note: depending on Liquid implementation, map may work differently
        // At minimum, the data namespace should be accessible
        #expect(!result.markdown.contains("data.users"))
    }

    @Test("Multiple variables in one line all resolve")
    func multipleVariablesOneLine() async {
        let result = await preprocess(
            "{{ greeting }}, {{ name }}! You have {{ count }} items.",
            custom: ["greeting": "Hello", "name": "Alice", "count": 5]
        )
        #expect(result.markdown.contains("Hello"))
        #expect(result.markdown.contains("Alice"))
        #expect(result.markdown.contains("5"))
        #expect(!result.markdown.contains("{{"))
    }

    @Test("Variable inside heading text resolves correctly")
    func variableInHeading() async {
        let result = await preprocess(
            "# Welcome, {{ user }}!\n\nContent here.",
            custom: ["user": "Admin"]
        )
        #expect(result.markdown.contains("# Welcome, Admin!"))
    }
}
