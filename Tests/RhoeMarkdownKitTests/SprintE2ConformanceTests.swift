import Testing
import Foundation
import RhoeMarkdownKit
import RhoeMarkdownModel
import RhoeDSLParsing

@Suite("Wave E2: DSL Round-Trip Converters")
struct SprintE2ConformanceTests {

    // MARK: - Markdown-to-DSL Converter

    @Test("Markdown heading converts to DSL H1 node")
    func markdownHeadingToDSL() async {
        let dsl = await RhoeMarkdownKit.markdownToDSL("# Hello World")
        #expect(dsl.contains("H1"))
        #expect(dsl.contains("Hello World"))
    }

    @Test("Markdown paragraph converts to DSL Paragraph node")
    func markdownParagraphToDSL() async {
        let dsl = await RhoeMarkdownKit.markdownToDSL("Hello **world**.")
        #expect(dsl.contains("Paragraph"))
        #expect(dsl.contains("**world**"))
    }

    @Test("Markdown list converts to DSL List node")
    func markdownListToDSL() async {
        let dsl = await RhoeMarkdownKit.markdownToDSL("- First\n- Second")
        #expect(dsl.contains("List"))
        #expect(dsl.contains("ListItem"))
        #expect(dsl.contains("First"))
    }

    @Test("Markdown code block converts to DSL Code node")
    func markdownCodeToDSL() async {
        let dsl = await RhoeMarkdownKit.markdownToDSL("```python\nprint('hi')\n```")
        #expect(dsl.contains("Code"))
        #expect(dsl.contains("language"))
        #expect(dsl.contains("python"))
    }

    @Test("Markdown admonition converts to DSL Admonition node")
    func markdownAdmonitionToDSL() async {
        let md = "!!! note \"Important\"\nContent here.\n!!!"
        let dsl = await RhoeMarkdownKit.markdownToDSL(md)
        #expect(dsl.contains("Admonition") || dsl.contains("Note"))
    }

    // MARK: - DSL-to-Markdown Converter

    @Test("DSL heading converts to Markdown heading")
    func dslHeadingToMarkdown() async {
        let md = await RhoeMarkdownKit.dslToMarkdown("H1 { Hello World }")
        #expect(md.contains("# "))
        #expect(md.contains("Hello"))
    }

    @Test("DSL paragraph converts to Markdown paragraph")
    func dslParagraphToMarkdown() async {
        let md = await RhoeMarkdownKit.dslToMarkdown("Paragraph { Hello world. }")
        #expect(md.contains("Hello"))
        #expect(md.contains("world"))
    }

    @Test("DSL admonition converts to Markdown admonition")
    func dslAdmonitionToMarkdown() async {
        let md = await RhoeMarkdownKit.dslToMarkdown("""
        Admonition(kind: "note", title: "Important") {
            Paragraph { This matters. }
        }
        """)
        #expect(md.contains("!!!"))
        #expect(md.contains("note"))
    }

    // MARK: - Round-Trip Integrity

    @Test("Markdown → DSL → Markdown preserves heading semantics")
    func markdownRoundTrip() async {
        let original = "# Title\n\nBody text."
        let dsl = await RhoeMarkdownKit.markdownToDSL(original)
        #expect(dsl.contains("H1"))

        // Parse DSL back to AST
        let dslResult = await RhoeMarkdownKit.parseDSL(dsl)
        let blocks = dslResult.document.blocks
        // v4.0: headings become sections after pipeline passes
        let hasHeadingOrSection = blocks.contains { block in
            if case .heading = block { return true }
            if case .section = block { return true }
            return false
        }
        #expect(hasHeadingOrSection)
    }

    @Test("DSL → AST → Markdown → AST produces equivalent structure")
    func dslRoundTrip() async {
        let dsl = """
        H2 { Section Title }
        Paragraph { Some content with **bold** text. }
        """
        let dslResult = await RhoeMarkdownKit.parseDSL(dsl)
        let md = RhoeMarkdownKit.toRhoeMarkdown(dslResult.document)

        // Parse the Markdown back
        let mdResult = await RhoeMarkdownKit.parse(md)

        // Both should have same number of blocks
        #expect(dslResult.document.blocks.count == mdResult.document.blocks.count)
    }

    @Test("Direct converter APIs produce non-empty output")
    func directConverterAPIs() async {
        let result = await RhoeMarkdownKit.parse("# Test\n\nParagraph.")
        let dsl = RhoeMarkdownKit.toRhoeDSL(result.document)
        let md = RhoeMarkdownKit.toRhoeMarkdown(result.document)

        #expect(!dsl.isEmpty)
        #expect(!md.isEmpty)
        // v4.0: section nodes produce H1 in DSL and # in Markdown
        #expect(dsl.contains("H1"))
        #expect(md.contains("#"))
    }

    @Test("Converter handles empty document")
    func emptyDocument() {
        let doc = RhoeMarkdownKit.Document(blocks: [])
        let dsl = MarkdownToDSLConverter().convert(doc)
        let md = DSLToMarkdownConverter().convert(doc)
        #expect(dsl.isEmpty)
        #expect(md.isEmpty)
    }

    @Test("Converter handles code block with attributes")
    func codeBlockWithAttributes() {
        let block = Block.codeBlock(
            language: "swift",
            content: "let x = 42",
            attributes: RhoeMarkdownKit.Attributes(id: "example-1")
        )
        let doc = RhoeMarkdownKit.Document(blocks: [block])

        let dsl = MarkdownToDSLConverter().convert(doc)
        #expect(dsl.contains("Code"))
        #expect(dsl.contains("swift"))
        #expect(dsl.contains("example-1"))

        let md = DSLToMarkdownConverter().convert(doc)
        #expect(md.contains("```swift"))
        #expect(md.contains("let x = 42"))
    }

    @Test("Converter handles table")
    func tableConversion() {
        let block = Block.table(
            headers: [TableCell(content: [.text("Name")]), TableCell(content: [.text("Value")])],
            rows: [[TableCell(content: [.text("A")]), TableCell(content: [.text("1")])]],
            caption: nil,
            attributes: .init()
        )
        let doc = RhoeMarkdownKit.Document(blocks: [block])

        let dsl = MarkdownToDSLConverter().convert(doc)
        #expect(dsl.contains("Table"))
        #expect(dsl.contains("TableRow"))
        #expect(dsl.contains("TableCell"))

        let md = DSLToMarkdownConverter().convert(doc)
        #expect(md.contains("| Name | Value |"))
        #expect(md.contains("| A | 1 |"))
    }
}
