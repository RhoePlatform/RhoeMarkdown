import Testing
import RhoeMarkdownKit

@Suite("Sprint 3.1-A: Block Family Doctrine + Case Handling")
struct Sprint31AConformanceTests {

    // MARK: - Named Visual Blocks

    @Test("Named visual block ::: Circle parses to visualBlock")
    func namedVisualBlock() async {
        let md = "::: Circle {radius=50}\n:::"
        let result = await RhoeMarkdownKit.parse(md)
        let blocks = result.document.blocks
        guard case .visualBlock(let name, _, _) = blocks.first else {
            Issue.record("Expected .visualBlock, got \(blocks.first.debugDescription)")
            return
        }
        #expect(name == "circle") // Case-normalized
    }

    @Test("Named visual block ::: Mermaid parses to visualBlock with content")
    func mermaidVisualBlock() async {
        let md = "::: Mermaid\ngraph TD\n  A --> B\n:::"
        let result = await RhoeMarkdownKit.parse(md)
        let blocks = result.document.blocks
        guard case .visualBlock(let name, let content, _) = blocks.first else {
            Issue.record("Expected .visualBlock, got \(blocks.first.debugDescription)")
            return
        }
        #expect(name == "mermaid")
        #expect(!content.isEmpty)
    }

    @Test("Anonymous fenced div still produces .div")
    func anonymousFencedDiv() async {
        let md = "::: {.columns}\nContent\n:::"
        let result = await RhoeMarkdownKit.parse(md)
        let blocks = result.document.blocks
        guard case .div = blocks.first else {
            Issue.record("Expected .div, got \(blocks.first.debugDescription)")
            return
        }
    }

    @Test("Visual block renders as HTML div with rhoe-visual class")
    func visualBlockHTML() async {
        let md = "::: Rectangle {width=200}\nInner content.\n:::"
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("rhoe-visual"))
        #expect(html.contains("rectangle"))
    }

    @Test("Extension visual block ::: @vendor.chart renders as unresolved when not registered")
    func extensionVisualBlock() async {
        let md = "::: @vendor.chart\nData here.\n:::"
        let result = await RhoeMarkdownKit.parse(md)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        // Without a registered extension, @vendor.chart becomes an unresolved placeholder
        #expect(html.contains("rhoe-extension-unresolved"))
        #expect(html.contains("@vendor.chart"))
    }

    // MARK: - Case-Insensitive Admonitions

    @Test("!!! NOTE and !!! note produce same admonition type")
    func caseInsensitiveAdmonition() async {
        let md1 = "!!! NOTE\nContent.\n!!!"
        let md2 = "!!! note\nContent.\n!!!"
        let result1 = await RhoeMarkdownKit.parse(md1)
        let result2 = await RhoeMarkdownKit.parse(md2)

        guard case .admonition(let type1, _, _, _, _) = result1.document.blocks.first,
              case .admonition(let type2, _, _, _, _) = result2.document.blocks.first else {
            Issue.record("Expected admonition blocks")
            return
        }
        #expect(type1 == type2)
        #expect(type1 == "note")
    }

    @Test("!!! Warning and !!! warning produce same type")
    func caseInsensitiveWarning() async {
        let md = "!!! Warning\nBe careful.\n!!!"
        let result = await RhoeMarkdownKit.parse(md)
        guard case .admonition(let type, _, _, _, _) = result.document.blocks.first else {
            Issue.record("Expected admonition")
            return
        }
        #expect(type == "warning")
    }

    // MARK: - Case-Insensitive Visual Block Names

    @Test("::: circle and ::: Circle produce same name")
    func caseInsensitiveVisualBlock() async {
        let md1 = "::: circle\n:::"
        let md2 = "::: Circle\n:::"
        let md3 = "::: CIRCLE\n:::"
        let r1 = await RhoeMarkdownKit.parse(md1)
        let r2 = await RhoeMarkdownKit.parse(md2)
        let r3 = await RhoeMarkdownKit.parse(md3)

        guard case .visualBlock(let n1, _, _) = r1.document.blocks.first,
              case .visualBlock(let n2, _, _) = r2.document.blocks.first,
              case .visualBlock(let n3, _, _) = r3.document.blocks.first else {
            Issue.record("Expected visual blocks")
            return
        }
        #expect(n1 == n2)
        #expect(n2 == n3)
        #expect(n1 == "circle")
    }

    // MARK: - Case-Insensitive Attributes

    @Test("Attribute keys are case-normalized for recognized keys")
    func caseInsensitiveAttributeKeys() async {
        let md = "Paragraph text.\n{Visible=Print Role=theorem}"
        let result = await RhoeMarkdownKit.parse(md)
        if case .paragraph(_, let attrs) = result.document.blocks.first {
            // Keys should be lowercased
            #expect(attrs.keyValues["visible"] == "print")
            #expect(attrs.keyValues["role"] == "theorem")
            // Original case keys should not exist
            #expect(attrs.keyValues["Visible"] == nil)
            #expect(attrs.keyValues["Role"] == nil)
        }
    }

    @Test("Enumerated values are case-normalized")
    func caseInsensitiveEnumeratedValues() async {
        let md = "Text.\n{kind=Warning visible=Presenter,Print}"
        let result = await RhoeMarkdownKit.parse(md)
        if case .paragraph(_, let attrs) = result.document.blocks.first {
            #expect(attrs.keyValues["kind"] == "warning")
            #expect(attrs.keyValues["visible"] == "presenter,print")
        }
    }

    // MARK: - Configuration Gates

    @Test("Strict config disables visual blocks")
    func strictDisablesVisualBlocks() async {
        let md = "::: Circle\n:::"
        let result = await RhoeMarkdownKit.parse(md, configuration: .strict)
        // With strict config, fenced divs are disabled entirely
        let blocks = result.document.blocks
        if case .visualBlock = blocks.first {
            Issue.record("Visual blocks should not parse under strict config")
        }
    }

    // MARK: - New AST Types Exist

    @Test("AnnotationKind has all four cases")
    func annotationKindCases() {
        #expect(AnnotationKind.allCases.count == 4)
        #expect(AnnotationKind.todo.rawValue == "todo")
        #expect(AnnotationKind.doc.rawValue == "doc")
        #expect(AnnotationKind.info.rawValue == "info")
        #expect(AnnotationKind.comment.rawValue == "comment")
    }

    @Test("BlockFamily has semantic and visual cases")
    func blockFamilyCases() {
        #expect(BlockFamily.semantic.rawValue == "semantic")
        #expect(BlockFamily.visual.rawValue == "visual")
    }

    @Test("TransclusionMode has all five cases")
    func transclusionModeCases() {
        #expect(TransclusionMode.block.rawValue == "block")
        #expect(TransclusionMode.inline.rawValue == "inline")
        #expect(TransclusionMode.excerpt.rawValue == "excerpt")
        #expect(TransclusionMode.literal.rawValue == "literal")
        #expect(TransclusionMode.quote.rawValue == "quote")
    }
}
