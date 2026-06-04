import Testing
import Foundation
import RhoeMarkdownKit
import RhoeMarkdownModel

@Suite("Wave 2: Semantic Core Completion")
struct SprintW2ConformanceTests {

    // MARK: - W2-1.1 Attribute Categorization

    @Test("Semantic keys extracted from Attributes")
    func semanticKeysExtracted() {
        let attrs = RhoeMarkdownKit.Attributes(keyValues: [
            "role": "theorem", "alt": "diagram", "kind": "data",
            "width": "100", "visible": "screen"
        ])
        #expect(attrs.semantic["role"] == "theorem")
        #expect(attrs.semantic["alt"] == "diagram")
        #expect(attrs.semantic["kind"] == "data")
        #expect(attrs.semantic["width"] == nil) // presentational, not semantic
        #expect(attrs.semantic["visible"] == nil) // projection, not semantic
    }

    @Test("Projection keys extracted from Attributes")
    func projectionKeysExtracted() {
        let attrs = RhoeMarkdownKit.Attributes(keyValues: [
            "visible": "screen,print", "hidden": "llm",
            "assistive-only": "true", "role": "theorem"
        ])
        #expect(attrs.projection["visible"] == "screen,print")
        #expect(attrs.projection["hidden"] == "llm")
        #expect(attrs.projection["assistive-only"] == "true")
        #expect(attrs.projection["role"] == nil) // semantic, not projection
    }

    @Test("Writer-hint keys extracted from Attributes")
    func writerHintKeysExtracted() {
        let attrs = RhoeMarkdownKit.Attributes(keyValues: [
            "html-tag": "aside", "typst-kind": "theorem",
            "latex-env": "enumerate*", "role": "theorem"
        ])
        #expect(attrs.writerHints["html-tag"] == "aside")
        #expect(attrs.writerHints["typst-kind"] == "theorem")
        #expect(attrs.writerHints["latex-env"] == "enumerate*")
        #expect(attrs.writerHints["role"] == nil)
    }

    @Test("Interaction keys extracted from Attributes")
    func interactionKeysExtracted() {
        let attrs = RhoeMarkdownKit.Attributes(keyValues: [
            "required": "true", "placeholder": "Enter email",
            "min": "0", "max": "100"
        ])
        #expect(attrs.interaction["required"] == "true")
        #expect(attrs.interaction["placeholder"] == "Enter email")
        #expect(attrs.interaction.count == 4)
    }

    // MARK: - W2-1.2 Attribute Validation

    @Test("Projection validation detects contradictory visibility")
    func projectionContradiction() async {
        let div = Block.div(
            content: [.paragraph([.text("test")])],
            attributes: RhoeMarkdownKit.Attributes(keyValues: [
                "visible": "presenter", "hidden": "presenter"
            ])
        )
        let doc = RhoeMarkdownKit.Document(blocks: [div])
        let pass = AttributeValidationPass()
        let result = pass.process(doc)
        #expect(!result.metadata.attributeValidationDiagnostics.isEmpty)
        #expect(result.metadata.attributeValidationDiagnostics.first?.severity == .error)
        #expect(result.metadata.attributeValidationDiagnostics.first?.message.contains("Contradictory") == true)
    }

    @Test("Semantic validation warns on decorative with alt")
    func decorativeWithAltWarning() async {
        let div = Block.div(
            content: [.paragraph([.text("img")])],
            attributes: RhoeMarkdownKit.Attributes(keyValues: [
                "decorative": "true", "alt": "Important diagram"
            ])
        )
        let doc = RhoeMarkdownKit.Document(blocks: [div])
        let pass = AttributeValidationPass()
        let result = pass.process(doc)
        #expect(!result.metadata.attributeValidationDiagnostics.isEmpty)
        #expect(result.metadata.attributeValidationDiagnostics.first?.severity == .warning)
    }

    // MARK: - W2-2 Projection Filtering

    @Test("ProjectionFilteringPass removes hidden blocks")
    func projectionFilteringRemovesHidden() {
        let blocks: [Block] = [
            .paragraph([.text("Visible")]),
            .paragraph([.text("Hidden from print")], attributes: .init(keyValues: ["hidden": "print"])),
            .paragraph([.text("Also visible")])
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = ProjectionFilteringPass(domain: .print)
        let result = pass.process(doc)
        #expect(result.blocks.count == 2)
    }

    @Test("visible=presenter content excluded from print projection")
    func presenterOnlyExcludedFromPrint() {
        let blocks: [Block] = [
            .paragraph([.text("Speaker notes")], attributes: .init(keyValues: ["visible": "presenter"])),
            .paragraph([.text("Normal content")])
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = ProjectionFilteringPass(domain: .print)
        let result = pass.process(doc)
        #expect(result.blocks.count == 1)
    }

    @Test("assistive-only content excluded from screen projection")
    func assistiveOnlyExcludedFromScreen() {
        let blocks: [Block] = [
            .div(content: [.paragraph([.text("Description")])],
                 attributes: .init(keyValues: ["assistive-only": "true"])),
            .paragraph([.text("Visible")])
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = ProjectionFilteringPass(domain: .screen)
        let result = pass.process(doc)
        #expect(result.blocks.count == 1)
    }

    @Test("Nested hidden blocks filtered correctly")
    func nestedFilteringWorks() {
        let blocks: [Block] = [
            .blockQuote([
                .paragraph([.text("Visible quote")]),
                .paragraph([.text("Hidden")], attributes: .init(keyValues: ["hidden": "screen"]))
            ])
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = ProjectionFilteringPass(domain: .screen)
        let result = pass.process(doc)
        #expect(result.blocks.count == 1)
        if case .blockQuote(let nested, _) = result.blocks.first {
            #expect(nested.count == 1)
        }
    }

    @Test("Pipeline has three tiers documented")
    func pipelineHasTiers() {
        let pipeline = buildDocumentPipeline(for: .default)
        let doc = RhoeMarkdownKit.Document(blocks: [.paragraph([.text("test")])])
        let result = pipeline.run(doc)
        #expect(!result.blocks.isEmpty)
    }

    // MARK: - W2-3 JSON AST Projection

    @Test("JSON output is valid JSON")
    func jsonOutputValid() async {
        let data = await RhoeMarkdownKit.toJSON("# Hello\n\nWorld.")
        #expect(!data.isEmpty)
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json != nil)
    }

    @Test("JSON schema version present")
    func jsonSchemaVersion() async {
        let data = await RhoeMarkdownKit.toJSON("# Test")
        let jsonStr = String(data: data, encoding: .utf8)!
        // v4.0: canonical JSON envelope uses rhoeVersion 4.0 and schema URI
        #expect(jsonStr.contains("\"rhoeVersion\" : \"4.0\""))
        #expect(jsonStr.contains("\"schema\" : \"rhoejson-canonical\\/v1\""))
    }

    @Test("JSON block types encoded correctly")
    func jsonBlockTypes() async {
        let data = await RhoeMarkdownKit.toJSON("# Heading\n\nParagraph.\n\n> Quote")
        let jsonStr = String(data: data, encoding: .utf8)!
        // v4.0: Heading is wrapped in Section; JSON uses PascalCase node names
        #expect(jsonStr.contains("\"Section\""))
        #expect(jsonStr.contains("\"Paragraph\""))
        #expect(jsonStr.contains("\"BlockQuote\""))
    }

    @Test("JSON inline types encoded correctly")
    func jsonInlineTypes() async {
        let data = await RhoeMarkdownKit.toJSON("This is **bold** and *italic*.")
        let jsonStr = String(data: data, encoding: .utf8)!
        // v4.0: JSON uses PascalCase node names
        #expect(jsonStr.contains("\"Strong\""))
        #expect(jsonStr.contains("\"Emphasis\""))
        #expect(jsonStr.contains("\"Text\""))
    }

    @Test("JSON attributes survive serialization")
    func jsonAttributesPreserved() {
        let block = Block.heading(level: 2, content: [.text("Title")],
                                   attributes: .init(id: "intro", classes: ["hero"], keyValues: ["role": "theorem"]))
        let doc = RhoeMarkdownKit.Document(blocks: [block])
        let data = RhoeMarkdownKit.renderJSON(doc)
        let jsonStr = String(data: data, encoding: .utf8)!
        #expect(jsonStr.contains("\"intro\""))
        #expect(jsonStr.contains("hero"))
        #expect(jsonStr.contains("theorem"))
    }
}
