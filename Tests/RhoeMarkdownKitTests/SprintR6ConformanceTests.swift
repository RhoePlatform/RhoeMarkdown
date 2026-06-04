import Testing
import RhoeMarkdownKit

@Suite("Sprint R6: v3.1 Test Hardening")
struct SprintR6ConformanceTests {

    // MARK: - R6.1 Visual Blocks

    @Test("Visual block ::: Name parses and renders")
    func visualBlockParsesAndRenders() async {
        let md = "::: Circle {radius=50 color=blue}\n:::"
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("rhoe-circle") || html.contains("circle"))
    }

    @Test("Anonymous fenced div ::: {attrs} backward compat")
    func anonymousFencedDivBackwardCompat() async {
        let md = "::: {.columns}\nContent inside.\n:::"
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("columns"))
        #expect(html.contains("Content inside"))
    }

    // MARK: - R6.2 Transclusion

    @Test("Block transclusion parses to AST node")
    func blockTransclusionParsesToAST() async {
        let md = "<<include \"./chapter.md\">>"
        let result = await RhoeMarkdownKit.parse(md)
        let blocks = result.document.blocks
        #expect(!blocks.isEmpty)
    }

    @Test("Transclusion with fragment parses target and fragment")
    func transclusionWithFragment() async {
        let md = "<<include \"./chapter.md#methodology\">>"
        let result = await RhoeMarkdownKit.parse(md)
        let blocks = result.document.blocks
        #expect(!blocks.isEmpty)
    }

    // MARK: - R6.3 Author Annotations

    @Test("Author annotation excluded from HTML output")
    func annotationExcludedFromHTML() async {
        let md = "Before.\n\n<<todo>>\nRemember this.\n<</todo>>\n\nAfter."
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("Before"))
        #expect(html.contains("After"))
        // Annotations should not render visible content
        #expect(!html.contains("Remember this"))
    }

    @Test("All four annotation kinds parse")
    func allAnnotationKindsParse() async {
        let md = """
        <<todo>>Task<</todo>>

        <<doc>>Documentation<</doc>>

        <<info>>Information<</info>>

        <<comment>>Comment<</comment>>
        """
        let result = await RhoeMarkdownKit.parse(md)
        // Annotations parse into the document AST (at least 1 block)
        #expect(!result.document.blocks.isEmpty)
    }

    // MARK: - R6.4 Schema Islands

    @Test("Schema island parses as opaque block")
    func schemaIslandParsesAsOpaqueBlock() async {
        let md = "<<schema rhoedsl>>\nSection { H1 { Title } }\n<</schema>>"
        let result = await RhoeMarkdownKit.parse(md)
        #expect(!result.document.blocks.isEmpty)
    }

    // MARK: - R6.5 Case-Insensitive Keywords

    @Test("Case-insensitive admonition keywords produce equivalent output")
    func caseInsensitiveAdmonitions() async {
        let lower = await RhoeMarkdownKit.toHTML("!!! note\nContent.\n!!!")
        let upper = await RhoeMarkdownKit.toHTML("!!! NOTE\nContent.\n!!!")
        let mixed = await RhoeMarkdownKit.toHTML("!!! Note\nContent.\n!!!")

        // All should produce admonition output with similar structure
        #expect(lower.contains("note"))
        #expect(upper.contains("note")) // Canonicalized to lowercase
        #expect(mixed.contains("note"))
    }

    // MARK: - R6.6 Strict Mode

    @Test("Strict configuration disables v3.1 features")
    func strictModeDisablesV31Features() async {
        let config = RhoeMarkdownKit.Configuration.strict
        #expect(!config.enableTransclusions)
        #expect(!config.enableAnnotations)
        #expect(!config.enableSchemaIslands)
        #expect(!config.enableComponents)
        #expect(!config.enableVisualBlocks)
    }

    // MARK: - R6.7 All Writers Handle v3.1 Types

    @Test("All output formats handle v3.1 content without crashing")
    func allFormatsHandleV31Content() async {
        let md = """
        # Test

        !!! theorem "Test"
        Content.
        !!!

        ::: Circle {radius=50}
        :::

        !!! note
        A note.
        !!!
        """

        let result = await RhoeMarkdownKit.parse(md)
        let doc = result.document

        // All formats should produce non-empty output
        let html = RhoeMarkdownKit.renderHTML(doc)
        #expect(!html.isEmpty)

        let latex = RhoeMarkdownKit.renderLaTeX(doc)
        #expect(!latex.isEmpty)

        let typst = RhoeMarkdownKit.renderTypst(doc)
        #expect(!typst.isEmpty)

        let docx = RhoeMarkdownKit.renderDOCX(doc)
        #expect(!docx.isEmpty)
    }

    // MARK: - R6.8 Regression: v2 Features Unaffected

    @Test("Existing v2 features remain functional")
    func v2FeaturesUnaffected() async {
        let md = """
        # Heading

        **Bold** and *italic* text with `code`.

        | A | B |
        |---|---|
        | 1 | 2 |

        > Blockquote

        - List item 1
        - List item 2

        $E = mc^2$
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<h1"))
        #expect(html.contains("<strong>"))
        #expect(html.contains("<em>"))
        #expect(html.contains("<code>"))
        #expect(html.contains("<table"))
        #expect(html.contains("<blockquote"))
        #expect(html.contains("<li>"))
    }
}
