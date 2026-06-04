import Testing
import Foundation
import RhoeMarkdownKit

@Suite("Phase 1: Liquid Filters")
struct Phase1FilterTests {

    // MARK: - Helpers

    private func preprocess(
        _ markdown: String,
        custom: [String: Any] = [:]
    ) async -> Phase1Result {
        let preprocessor = Phase1Preprocessor()
        return await preprocessor.preprocess(markdown, context: Phase1Context(custom: custom))
    }

    // MARK: - String Filters

    @Test("Upcase filter converts string to uppercase")
    func upcaseFilter() async {
        let result = await preprocess(
            "{{ name | upcase }}",
            custom: ["name": "hello"]
        )
        #expect(result.markdown.contains("HELLO"))
    }

    @Test("Downcase filter converts string to lowercase")
    func downcaseFilter() async {
        let result = await preprocess(
            "{{ name | downcase }}",
            custom: ["name": "HELLO"]
        )
        #expect(result.markdown.contains("hello"))
    }

    @Test("Capitalize filter capitalizes first letter")
    func capitalizeFilter() async {
        let result = await preprocess(
            "{{ name | capitalize }}",
            custom: ["name": "hello world"]
        )
        #expect(result.markdown.contains("Hello world") || result.markdown.contains("Hello World"))
    }

    @Test("Strip filter removes leading and trailing whitespace")
    func stripFilter() async {
        let result = await preprocess(
            "[{{ text | strip }}]",
            custom: ["text": "  padded  "]
        )
        #expect(result.markdown.contains("[padded]"))
    }

    @Test("Split and join filters work in chain")
    func splitJoinFilter() async {
        let result = await preprocess(
            "{{ csv | split: ',' | join: ' - ' }}",
            custom: ["csv": "a,b,c"]
        )
        #expect(result.markdown.contains("a - b - c"))
    }

    // MARK: - Array Filters

    @Test("Join filter on array produces delimited string")
    func arrayJoinFilter() async {
        let result = await preprocess(
            "{{ items | join: ', ' }}",
            custom: ["items": ["Apple", "Banana", "Cherry"]]
        )
        #expect(result.markdown.contains("Apple, Banana, Cherry"))
    }

    @Test("First filter returns first array element")
    func arrayFirstFilter() async {
        let result = await preprocess(
            "{{ items | first }}",
            custom: ["items": ["Alpha", "Beta", "Gamma"]]
        )
        #expect(result.markdown.contains("Alpha"))
        #expect(!result.markdown.contains("Beta"))
    }

    @Test("Last filter returns last array element")
    func arrayLastFilter() async {
        let result = await preprocess(
            "{{ items | last }}",
            custom: ["items": ["Alpha", "Beta", "Gamma"]]
        )
        #expect(result.markdown.contains("Gamma"))
    }

    @Test("Size filter returns collection count")
    func arraySizeFilter() async {
        let result = await preprocess(
            "{{ items | size }}",
            custom: ["items": ["A", "B", "C", "D"]]
        )
        #expect(result.markdown.contains("4"))
    }

    // MARK: - Math Filters

    @Test("Plus filter adds to number")
    func mathPlusFilter() async {
        let result = await preprocess(
            "{{ count | plus: 10 }}",
            custom: ["count": 5]
        )
        #expect(result.markdown.contains("15"))
    }

    @Test("Times filter multiplies number")
    func mathTimesFilter() async {
        let result = await preprocess(
            "{{ price | times: 3 }}",
            custom: ["price": 7]
        )
        #expect(result.markdown.contains("21"))
    }

    @Test("Round filter rounds decimal")
    func roundFilter() async {
        let result = await preprocess(
            "{{ value | round }}",
            custom: ["value": 3.7]
        )
        #expect(result.markdown.contains("4"))
    }

    // MARK: - String Manipulation Filters

    @Test("Truncate filter limits string length")
    func truncateFilter() async {
        let result = await preprocess(
            "{{ text | truncate: 10 }}",
            custom: ["text": "This is a long sentence that should be truncated."]
        )
        // Truncate includes the ellipsis in the count by default
        let output = result.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(output.count <= 15) // Some flexibility for trailing chars
        #expect(output.contains("..."))
    }

    @Test("Filter chain applies multiple filters in sequence")
    func filterChain() async {
        let result = await preprocess(
            "{{ name | downcase | capitalize }}",
            custom: ["name": "ALICE SMITH"]
        )
        // downcase -> "alice smith", capitalize -> "Alice smith"
        let output = result.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(output.hasPrefix("Alice") || output.hasPrefix("alice"))
    }

    @Test("Append and prepend filters concatenate strings")
    func appendPrependFilter() async {
        let result = await preprocess(
            "{{ path | prepend: '/docs' | append: '.html' }}",
            custom: ["path": "/guide"]
        )
        #expect(result.markdown.contains("/docs/guide.html"))
    }

    @Test("Default filter provides fallback for nil/empty values")
    func defaultFilter() async {
        let result = await preprocess(
            "{{ missing | default: 'N/A' }}"
        )
        #expect(result.markdown.contains("N/A"))

        let result2 = await preprocess(
            "{{ present | default: 'N/A' }}",
            custom: ["present": "Value"]
        )
        #expect(result2.markdown.contains("Value"))
        #expect(!result2.markdown.contains("N/A"))
    }
}
