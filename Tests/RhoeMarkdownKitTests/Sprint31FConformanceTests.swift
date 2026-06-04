import Testing
import RhoeMarkdownKit
@testable import RhoeMarkdownParsing

@Suite("Sprint 3.1-F: Local Components")
struct Sprint31FConformanceTests {

    // MARK: - Component Declaration Parsing (Raw Parser)

    @Test("Semantic component declaration !!! component parses correctly")
    func semanticComponentDeclaration() async {
        // Use raw parser to see declarations before pipeline removes them
        let md = "!!! component {name=callout args=\"title, kind=note\"}\nTemplate body here.\n!!!"
        let parser = RhoeParser(configuration: .default)
        let result = await parser.parse(md)
        let decl = result.document.blocks.first { if case .componentDeclaration = $0 { return true }; return false }
        guard case .componentDeclaration(let family, let name, let args, _, _, _) = decl else {
            Issue.record("Expected .componentDeclaration in raw blocks: \(result.document.blocks)")
            return
        }
        #expect(family == .semantic)
        #expect(name == "callout")
        #expect(args == "title, kind=note")
    }

    @Test("Visual component declaration ::: component parses correctly")
    func visualComponentDeclaration() async {
        let md = "::: component {name=card args=\"title\" slots=\"header, body, footer\"}\nTemplate.\n:::"
        let parser = RhoeParser(configuration: .default)
        let result = await parser.parse(md)
        let decl = result.document.blocks.first { if case .componentDeclaration = $0 { return true }; return false }
        guard case .componentDeclaration(let family, let name, _, let slots, _, _) = decl else {
            Issue.record("Expected .componentDeclaration in raw blocks: \(result.document.blocks)")
            return
        }
        #expect(family == .visual)
        #expect(name == "card")
        #expect(slots == "header, body, footer")
    }

    @Test("Component name is case-normalized")
    func componentNameCaseNormalized() async {
        let md = "!!! component {name=MyCallout}\nBody.\n!!!"
        let parser = RhoeParser(configuration: .default)
        let result = await parser.parse(md)
        let decl = result.document.blocks.first { if case .componentDeclaration = $0 { return true }; return false }
        guard case .componentDeclaration(_, let name, _, _, _, _) = decl else {
            Issue.record("Expected .componentDeclaration")
            return
        }
        #expect(name == "mycallout")
    }

    // MARK: - Component Invocation

    @Test("Semantic component invocation !!! x.callout parses as admonition")
    func semanticInvocation() async {
        let md = "!!! x.callout {title=\"Important\"}\nContent here.\n!!!"
        let result = await RhoeMarkdownKit.parse(md)
        guard case .admonition(let type, _, _, _, _) = result.document.blocks.first else {
            Issue.record("Expected .admonition with x.callout type, got \(result.document.blocks.first.debugDescription)")
            return
        }
        #expect(type == "x.callout")
    }

    @Test("Visual component invocation ::: x.card parses as visualBlock")
    func visualInvocation() async {
        let md = "::: x.card {title=\"Revenue\"}\nContent.\n:::"
        let result = await RhoeMarkdownKit.parse(md)
        guard case .visualBlock(let name, _, _) = result.document.blocks.first else {
            Issue.record("Expected .visualBlock with x.card name, got \(result.document.blocks.first.debugDescription)")
            return
        }
        #expect(name == "x.card")
    }

    // MARK: - Pipeline Effects

    @Test("Component declarations are removed from final output")
    func declarationsRemovedFromOutput() async {
        let md = """
        # Title

        !!! component {name=note}
        Component template.
        !!!

        Regular paragraph.
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<h1"))
        #expect(html.contains("Regular paragraph"))
        #expect(!html.contains("Component template"))
    }

    @Test("Component declarations produce no HTML")
    func declarationProducesNoHTML() async {
        let md = "!!! component {name=test}\nTemplate.\n!!!"
        let html = await RhoeMarkdownKit.toHTML(md)
        // After pipeline, declaration is removed — no output
        #expect(!html.contains("Template"))
    }

    // MARK: - Slot Spec

    @Test("Component declaration with slots spec")
    func namedSlotSpec() async {
        let md = "!!! component {name=card slots=\"header, body\"}\nTemplate.\n!!!"
        let parser = RhoeParser(configuration: .default)
        let result = await parser.parse(md)
        let decl = result.document.blocks.first { if case .componentDeclaration = $0 { return true }; return false }
        guard case .componentDeclaration(_, _, _, let slots, _, _) = decl else {
            Issue.record("Expected .componentDeclaration with slots")
            return
        }
        #expect(slots == "header, body")
    }

    // MARK: - Edge Cases

    @Test("Regular admonition !!! note still works")
    func regularAdmonitionStillWorks() async {
        let md = "!!! note\nThis is a note.\n!!!"
        let result = await RhoeMarkdownKit.parse(md)
        guard case .admonition(let type, _, _, _, _) = result.document.blocks.first else {
            Issue.record("Expected .admonition")
            return
        }
        #expect(type == "note")
    }

    @Test("Regular visual block ::: Circle still works")
    func regularVisualBlockStillWorks() async {
        let md = "::: Circle {radius=50}\n:::"
        let result = await RhoeMarkdownKit.parse(md)
        guard case .visualBlock(let name, _, _) = result.document.blocks.first else {
            Issue.record("Expected .visualBlock")
            return
        }
        #expect(name == "circle")
    }
}
