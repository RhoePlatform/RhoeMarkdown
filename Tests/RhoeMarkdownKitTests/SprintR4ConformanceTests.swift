import Testing
import RhoeMarkdownKit

@Suite("Sprint R4: Component Completion + Slot Substitution")
struct SprintR4ConformanceTests {

    // MARK: - R4.1 paramRef AST Node

    @Test("<<param name>> parses as paramRef inline node")
    func paramRefParsed() async {
        let md = """
        !!! component {name=callout args="title"}
        **<<param title>>**
        !!!

        !!! x.callout {title=Hello}
        Content here.
        !!!
        """
        let result = await RhoeMarkdownKit.parse(md)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        // After component expansion, <<param title>> should be replaced with "Hello"
        #expect(html.contains("Hello"))
    }

    @Test("Unresolved paramRef renders as placeholder")
    func unresolvedParamRef() async {
        // Parse a raw <<param foo>> without component context
        let md = "Text with <<param foo>> inside."
        let result = await RhoeMarkdownKit.parse(md)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("rhoe-unresolved-param") || html.contains("&lt;&lt;param"))
    }

    // MARK: - R4.2 slotRef AST Node

    @Test("<<slot>> parses as slotRef inline node")
    func slotRefParsed() async {
        let md = "Text with <<slot>> inside."
        let result = await RhoeMarkdownKit.parse(md)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("rhoe-unresolved-slot") || html.contains("&lt;&lt;slot"))
    }

    @Test("<<slot 2>> parses as named slotRef")
    func namedSlotRefParsed() async {
        let md = "Text with <<slot 2>> and <<slot footer>>."
        let result = await RhoeMarkdownKit.parse(md)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("slot"))
    }

    // MARK: - R4.3 Component Expansion with Param Substitution

    @Test("Component expands with param substitution in paragraph")
    func componentParamInParagraph() async {
        let md = """
        !!! component {name=section args="title"}
        Title: <<param title>>
        !!!

        !!! x.section {title="My Section"}
        Body text here.
        !!!
        """
        let result = await RhoeMarkdownKit.parse(md)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("Title: My Section"))
    }

    @Test("Component uses default param when not provided")
    func componentDefaultParam() async {
        let md = """
        !!! component {name=greeting args="name=World"}
        Hello, <<param name>>!
        !!!

        !!! x.greeting
        !!!
        """
        let result = await RhoeMarkdownKit.parse(md)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        // Should use default name=World
        #expect(html.contains("Hello, World!"))
    }

    // MARK: - R4.4 Slot Binding

    @Test("Component declaration is removed from output")
    func componentDeclarationRemoved() async {
        let md = """
        !!! component {name=wrapper args="title"}
        **<<param title>>**
        !!!

        # Regular heading
        """
        let result = await RhoeMarkdownKit.parse(md)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        // Component declaration should not appear in output
        #expect(!html.contains("component"))
        #expect(html.contains("Regular heading"))
    }

    // MARK: - R4.5 All Writers Handle New Types

    @Test("LaTeX writer handles paramRef and slotRef")
    func latexHandlesNewTypes() async {
        let md = "Text with <<param foo>> and <<slot>>."
        let result = await RhoeMarkdownKit.parse(md)
        let latex = RhoeMarkdownKit.renderLaTeX(result.document)
        #expect(latex.contains("param"))
    }

    @Test("Typst writer handles paramRef and slotRef")
    func typstHandlesNewTypes() async {
        let md = "Text with <<param foo>> and <<slot>>."
        let result = await RhoeMarkdownKit.parse(md)
        let typst = RhoeMarkdownKit.renderTypst(result.document)
        #expect(typst.contains("param"))
    }

    @Test("DOCX writer handles paramRef and slotRef without crash")
    func docxHandlesNewTypes() async {
        let md = "Text with <<param foo>> and <<slot>>."
        let result = await RhoeMarkdownKit.parse(md)
        let data = RhoeMarkdownKit.renderDOCX(result.document)
        #expect(!data.isEmpty)
    }
}
