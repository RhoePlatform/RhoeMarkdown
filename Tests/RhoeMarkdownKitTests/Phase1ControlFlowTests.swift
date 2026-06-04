import Testing
import Foundation
import RhoeMarkdownKit

@Suite("Phase 1: Control Flow")
struct Phase1ControlFlowTests {

    // MARK: - Helpers

    private func preprocess(
        _ markdown: String,
        custom: [String: Any] = [:]
    ) async -> Phase1Result {
        let preprocessor = Phase1Preprocessor()
        return await preprocessor.preprocess(markdown, context: Phase1Context(custom: custom))
    }

    // MARK: - Conditional Tests

    @Test("If true renders content")
    func ifTrue() async {
        let result = await preprocess(
            "{% if show %}Visible{% endif %}",
            custom: ["show": true]
        )
        #expect(result.markdown.contains("Visible"))
    }

    @Test("If false hides content")
    func ifFalse() async {
        let result = await preprocess(
            "{% if show %}Visible{% endif %}",
            custom: ["show": false]
        )
        #expect(!result.markdown.contains("Visible"))
    }

    @Test("If/else selects correct branch")
    func ifElse() async {
        let result = await preprocess(
            "{% if premium %}Pro{% else %}Free{% endif %}",
            custom: ["premium": false]
        )
        #expect(!result.markdown.contains("Pro"))
        #expect(result.markdown.contains("Free"))
    }

    @Test("If/elsif/else selects correct branch")
    func ifElsifElse() async {
        let md = """
        {% if tier == "gold" %}Gold{% elsif tier == "silver" %}Silver{% else %}Bronze{% endif %}
        """
        let result = await preprocess(md, custom: ["tier": "silver"])
        #expect(result.markdown.contains("Silver"))
        #expect(!result.markdown.contains("Gold"))
        #expect(!result.markdown.contains("Bronze"))
    }

    @Test("Unless inverts condition")
    func unless() async {
        let result = await preprocess(
            "{% unless hidden %}Shown{% endunless %}",
            custom: ["hidden": false]
        )
        #expect(result.markdown.contains("Shown"))

        let result2 = await preprocess(
            "{% unless hidden %}Shown{% endunless %}",
            custom: ["hidden": true]
        )
        #expect(!result2.markdown.contains("Shown"))
    }

    // MARK: - Loop Tests

    @Test("For loop iterates over array")
    func forLoop() async {
        let result = await preprocess(
            "{% for item in items %}{{ item }} {% endfor %}",
            custom: ["items": ["A", "B", "C"]]
        )
        #expect(result.markdown.contains("A"))
        #expect(result.markdown.contains("B"))
        #expect(result.markdown.contains("C"))
    }

    @Test("For loop exposes forloop.index")
    func forLoopIndex() async {
        let result = await preprocess(
            "{% for item in items %}{{ forloop.index }}.{{ item }} {% endfor %}",
            custom: ["items": ["X", "Y", "Z"]]
        )
        #expect(result.markdown.contains("1.X"))
        #expect(result.markdown.contains("2.Y"))
        #expect(result.markdown.contains("3.Z"))
    }

    @Test("For loop with limit and offset")
    func forLoopLimitOffset() async {
        let result = await preprocess(
            "{% for item in items limit:2 offset:1 %}{{ item }} {% endfor %}",
            custom: ["items": ["A", "B", "C", "D", "E"]]
        )
        #expect(result.markdown.contains("B"))
        #expect(result.markdown.contains("C"))
        #expect(!result.markdown.contains("A"))
        #expect(!result.markdown.contains("D"))
    }

    @Test("Nested for loops produce output for both levels")
    func nestedForLoops() async {
        let result = await preprocess(
            "{% for row in rows %}{% for col in cols %}[{{ col }}]{% endfor %}\n{% endfor %}",
            custom: ["rows": ["R1", "R2"], "cols": ["C1", "C2"]]
        )
        // Both loop levels execute — inner loop runs for each outer iteration
        #expect(result.markdown.contains("[C1]"))
        #expect(result.markdown.contains("[C2]"))
        // The output should contain content from both outer iterations
        let c1Count = result.markdown.components(separatedBy: "[C1]").count - 1
        #expect(c1Count >= 2) // [C1] appears at least twice (once per outer row)
    }

    @Test("For loop with break exits early")
    func forLoopBreak() async {
        let result = await preprocess(
            "{% for item in items %}{% if item == \"C\" %}{% break %}{% endif %}{{ item }} {% endfor %}",
            custom: ["items": ["A", "B", "C", "D"]]
        )
        #expect(result.markdown.contains("A"))
        #expect(result.markdown.contains("B"))
        #expect(!result.markdown.contains("D"))
    }

    // MARK: - Assignment Tests

    @Test("Assign creates new variable")
    func assign() async {
        let result = await preprocess(
            "{% assign greeting = \"Hello\" %}{{ greeting }} World"
        )
        #expect(result.markdown.contains("Hello World"))
    }

    @Test("Capture collects block output into variable")
    func capture() async {
        let result = await preprocess("""
        {% capture full_name %}{{ first }} {{ last }}{% endcapture %}Name: {{ full_name }}
        """, custom: ["first": "John", "last": "Doe"])
        #expect(result.markdown.contains("Name: John Doe"))
    }
}
