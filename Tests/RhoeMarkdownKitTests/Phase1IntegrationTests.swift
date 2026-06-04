import Testing
import Foundation
import RhoeMarkdownKit

@Suite("Phase 1: Full Pipeline Integration")
struct Phase1IntegrationTests {

    // MARK: - Phase 1 → Parser → HTML

    @Test("Variable interpolation flows through full pipeline to HTML")
    func phase1ThroughParserToHTML() async {
        let context = Phase1Context(custom: ["name": "World"])
        let parser = DocumentParser(phase1Context: context)
        let result = await parser.parse("# Hello {{ name }}")
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("Hello World"))
        #expect(html.contains("<h1"))
    }

    @Test("Frontmatter plus Liquid variables produce correct HTML")
    func frontmatterPlusLiquid() async {
        let md = """
        ---
        title: My Page
        author: Jane
        ---

        # {{ page.title }}

        Written by {{ page.author }}.
        """
        let parser = DocumentParser()
        let result = await parser.parse(md)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("My Page"))
        #expect(html.contains("Jane"))
    }

    @Test("Conditional admonition renders only when condition is true")
    func conditionalAdmonition() async {
        let md = """
        {% if show_warning %}
        ::: warning
        Be careful with this operation!
        :::
        {% endif %}

        Normal content.
        """
        let contextTrue = Phase1Context(custom: ["show_warning": true])
        let parserTrue = DocumentParser(phase1Context: contextTrue)
        let resultTrue = await parserTrue.parse(md)
        let htmlTrue = RhoeMarkdownKit.renderHTML(resultTrue.document)
        #expect(htmlTrue.contains("Be careful"))

        let contextFalse = Phase1Context(custom: ["show_warning": false])
        let parserFalse = DocumentParser(phase1Context: contextFalse)
        let resultFalse = await parserFalse.parse(md)
        let htmlFalse = RhoeMarkdownKit.renderHTML(resultFalse.document)
        #expect(!htmlFalse.contains("Be careful"))
    }

    @Test("Generated table rows from for loop produce HTML table")
    func generatedTableRows() async {
        let md = """
        | Name | Score |
        | --- | --- |
        {% for student in students %}| {{ student.name }} | {{ student.score }} |
        {% endfor %}
        """
        let context = Phase1Context(custom: [
            "students": [
                ["name": "Alice", "score": "95"],
                ["name": "Bob", "score": "87"]
            ]
        ])
        let parser = DocumentParser(phase1Context: context)
        let result = await parser.parse(md)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("Alice"))
        #expect(html.contains("Bob"))
        #expect(html.contains("95"))
    }

    @Test("Conditional theorem block renders when enabled")
    func conditionalTheorem() async {
        let md = """
        {% if show_proof %}
        **Theorem 1.** For all $n \\geq 1$, the result holds.

        *Proof.* By induction on $n$.
        {% endif %}
        """
        let context = Phase1Context(custom: ["show_proof": true])
        let parser = DocumentParser(phase1Context: context)
        let result = await parser.parse(md)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("Theorem 1"))
        #expect(html.contains("Proof"))
    }

    // MARK: - Multiple Output Formats

    @Test("Phase 1 variables resolve in LaTeX output pipeline")
    func variablesInLaTeXOutput() async {
        let context = Phase1Context(custom: ["title": "My Report"])
        let parser = DocumentParser(phase1Context: context)
        let result = await parser.parse("# {{ title }}")
        let latex = RhoeMarkdownKit.renderLaTeX(result.document)
        #expect(latex.contains("My Report"))
    }

    @Test("Phase 1 variables resolve in Typst output pipeline")
    func variablesInTypstOutput() async {
        let context = Phase1Context(custom: ["heading": "Introduction"])
        let parser = DocumentParser(phase1Context: context)
        let result = await parser.parse("# {{ heading }}")
        let typst = RhoeMarkdownKit.renderTypst(result.document)
        #expect(typst.contains("Introduction"))
    }

    // MARK: - Variable Precedence

    @Test("Custom variables take precedence at top level")
    func variablePrecedence() async {
        // custom vars are at the top level; page.* is namespaced
        let md = """
        ---
        name: FromFrontmatter
        ---

        Custom: {{ name }}, Page: {{ page.name }}
        """
        let context = Phase1Context(custom: ["name": "FromCustom"])
        let parser = DocumentParser(phase1Context: context)
        let result = await parser.parse(md)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        // Custom var "name" should resolve from custom context
        #expect(html.contains("FromCustom"))
        // page.name should resolve from frontmatter
        #expect(html.contains("FromFrontmatter"))
    }

    // MARK: - Diagnostics Merge

    @Test("Phase 1 diagnostics merge with parser diagnostics")
    func diagnosticsMerge() async {
        // Use allowGeneratedSemanticTransforms: false to trigger a Phase 1 diagnostic
        let config = RhoeMarkdownKit.Configuration(
            enablePhase1Preprocessing: true,
            allowGeneratedSemanticTransforms: false
        )
        let md = "Content with {@ hide @} directive."
        let parser = DocumentParser(configuration: config)
        let result = await parser.parse(md)
        // Phase 1 should detect {@ @} and produce a diagnostic
        let phase1Diags = result.diagnostics.filter { $0.message.contains("[Phase 1]") }
        #expect(!phase1Diags.isEmpty)
    }

    @Test("toHTML convenience function works with default Phase 1")
    func toHTMLConvenience() async {
        let html = await RhoeMarkdownKit.toHTML("# Simple heading\n\nParagraph text.")
        #expect(html.contains("<h1"))
        #expect(html.contains("Simple heading"))
        #expect(html.contains("Paragraph text"))
    }
}
