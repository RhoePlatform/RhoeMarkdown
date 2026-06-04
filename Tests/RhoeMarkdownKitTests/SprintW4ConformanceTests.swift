import Testing
import Foundation
import RhoeMarkdownKit
import RhoeMarkdownModel

@Suite("Wave 4: Hardening & Parser Completeness")
struct SprintW4ConformanceTests {

    // MARK: - W4-1: Placeholders

    @Test("Placeholder AST node constructs correctly")
    func placeholderConstruction() {
        let block = Block.placeholder(fields: ["name": "Recipient", "type": "text"])
        if case .placeholder(let fields, _) = block {
            #expect(fields["name"] == "Recipient")
            #expect(fields["type"] == "text")
        } else {
            #expect(Bool(false), "Expected placeholder")
        }
    }

    @Test("Inline placeholder constructs correctly")
    func placeholderInlineConstruction() {
        let inline = Inline.placeholderInline(fields: ["name": "Email", "required": "true"])
        if case .placeholderInline(let fields) = inline {
            #expect(fields["name"] == "Email")
            #expect(fields["required"] == "true")
        } else {
            #expect(Bool(false), "Expected placeholderInline")
        }
    }

    @Test("Placeholder renders in HTML")
    func placeholderHTML() {
        let block = Block.placeholder(fields: ["name": "Recipient"])
        let doc = RhoeMarkdownKit.Document(blocks: [block])
        let html = RhoeMarkdownKit.renderHTML(doc)
        #expect(html.contains("rhoe-placeholder"))
        #expect(html.contains("Recipient"))
    }

    @Test("Placeholder serializes in JSON")
    func placeholderJSON() {
        let block = Block.placeholder(fields: ["name": "Field", "type": "text"])
        let doc = RhoeMarkdownKit.Document(blocks: [block])
        let data = RhoeMarkdownKit.renderJSON(doc)
        let json = String(data: data, encoding: .utf8)!
        // v4.0: JSON uses PascalCase node name "Placeholder"
        #expect(json.contains("Placeholder"))
        #expect(json.contains("Field"))
    }

    // MARK: - W4-2: HTML data-rhoe-* Attributes

    @Test("HTML heading has data-rhoe-node attribute")
    func htmlHeadingDataRhoe() async {
        let result = await RhoeMarkdownKit.parse("# Hello")
        let html = RhoeMarkdownKit.renderHTML(result.document)
        // v4.0: heading becomes section node with data-rhoe-node="Section"
        #expect(html.contains("data-rhoe-node=\"Section\""))
    }

    @Test("HTML paragraph has data-rhoe-node attribute")
    func htmlParagraphDataRhoe() async {
        let result = await RhoeMarkdownKit.parse("Hello world.")
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("data-rhoe-node=\"paragraph\""))
    }

    @Test("HTML blockquote has data-rhoe-node attribute")
    func htmlBlockquoteDataRhoe() async {
        let result = await RhoeMarkdownKit.parse("> Quote text")
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("data-rhoe-node=\"blockquote\""))
    }

    @Test("HTML list has data-rhoe-node attribute")
    func htmlListDataRhoe() async {
        let result = await RhoeMarkdownKit.parse("- Item one\n- Item two")
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("data-rhoe-node=\"list\""))
    }

    @Test("HTML table has data-rhoe-node attribute")
    func htmlTableDataRhoe() async {
        let result = await RhoeMarkdownKit.parse("| A | B |\n|---|---|\n| 1 | 2 |")
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("data-rhoe-node=\"table\""))
    }

    @Test("HTML code block has data-rhoe-node attribute")
    func htmlCodeBlockDataRhoe() async {
        let result = await RhoeMarkdownKit.parse("```python\nprint('hello')\n```")
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("data-rhoe-node=\"code\""))
    }

    // MARK: - W4-3: Phase 2 Execution Integration

    @Test("Phase 2 hide command works through full pipeline")
    func phase2HideViaPipeline() async {
        // Construct a document with Phase 2 directive + target
        let blocks: [Block] = [
            .phase2Directive(command: "hide", arguments: ["family": "example", "in": "llm"], body: nil),
            .admonition(type: "example", title: "Example 1", content: [
                .paragraph([.text("Content")])
            ], collapsible: nil)
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)

        // Run through pipeline
        let pipeline = buildDocumentPipeline(for: .default)
        let processed = pipeline.run(doc)

        // Phase 2 directive should be removed
        let hasDirective = processed.blocks.contains { if case .phase2Directive = $0 { return true }; return false }
        #expect(!hasDirective)

        // Admonition should have hidden=llm
        for block in processed.blocks {
            if case .admonition(_, _, _, _, let attrs) = block {
                #expect(attrs.keyValues["hidden"]?.contains("llm") == true)
                return
            }
        }
    }

    @Test("Phase 2 set command works through full pipeline")
    func phase2SetViaPipeline() async {
        let blocks: [Block] = [
            .phase2Directive(command: "set", arguments: ["family": "theorem", "summary": "Key result"], body: nil),
            .admonition(type: "theorem", title: "Main", content: [
                .paragraph([.text("Proof body")])
            ], collapsible: nil)
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pipeline = buildDocumentPipeline(for: .default)
        let processed = pipeline.run(doc)

        for block in processed.blocks {
            if case .admonition(_, _, _, _, let attrs) = block {
                #expect(attrs.keyValues["summary"] == "Key result")
                return
            }
        }
    }

    // MARK: - W4-4: Config Gates

    @Test("Phase 2 can be disabled via configuration")
    func phase2DisabledConfig() {
        let config = RhoeMarkdownKit.Configuration(enablePhase2Transforms: false)
        let blocks: [Block] = [
            .phase2Directive(command: "hide", arguments: ["family": "example", "in": "llm"], body: nil),
            .admonition(type: "example", title: "Example", content: [
                .paragraph([.text("Content")])
            ], collapsible: nil)
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pipeline = buildDocumentPipeline(for: config)
        let processed = pipeline.run(doc)

        // Phase 2 should NOT have run — directive may still be present
        // and admonition should NOT have hidden attribute
        for block in processed.blocks {
            if case .admonition(_, _, _, _, let attrs) = block {
                #expect(attrs.keyValues["hidden"] == nil)
                return
            }
        }
    }

    @Test("Placeholder renders in all writers without crashing")
    func placeholderAllWriters() {
        let block = Block.placeholder(fields: ["name": "Field"])
        let doc = RhoeMarkdownKit.Document(blocks: [block])
        let html = RhoeMarkdownKit.renderHTML(doc)
        let latex = RhoeMarkdownKit.renderLaTeX(doc)
        let typst = RhoeMarkdownKit.renderTypst(doc)
        #expect(!html.isEmpty)
        #expect(!latex.isEmpty)
        #expect(!typst.isEmpty)
    }
}
