import Testing
import Foundation
import RhoeMarkdownKit
import RhoeMarkdownModel

@Suite("Wave 5: Extension Resolution + AST-Near Writers")
struct SprintW5ConformanceTests {

    // MARK: - W5-1: Extension Resolution Pipeline

    @Test("Resolved extension produces blocks from fragment")
    func extensionResolved() {
        let registry = ExtensionRegistry()
        registry.register(ExtensionManifest(
            name: "@test.hello",
            handler: { _ in .rhoeMarkdownFragment("Hello from extension!") }
        ))

        let blocks: [Block] = [
            .admonition(type: "@test.hello", title: nil, content: [
                .paragraph([.text("Body")])
            ], collapsible: nil)
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = ExtensionResolutionPass(registry: registry)
        let result = pass.process(doc)

        // Should have resolved to paragraph(s), not admonition
        let hasAdmonition = result.blocks.contains { if case .admonition = $0 { return true }; return false }
        #expect(!hasAdmonition)
        #expect(!result.blocks.isEmpty)
    }

    @Test("Unresolved extension produces diagnostic div")
    func extensionUnresolved() {
        let blocks: [Block] = [
            .admonition(type: "@missing.ext", title: nil, content: [
                .paragraph([.text("Body")])
            ], collapsible: nil)
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = ExtensionResolutionPass()
        let result = pass.process(doc)

        let html = RhoeMarkdownKit.renderHTML(result)
        #expect(html.contains("rhoe-extension-unresolved"))
        #expect(html.contains("@missing.ext"))
    }

    @Test("Extension receives body text and produces output")
    func extensionBodyText() {
        let registry = ExtensionRegistry()
        registry.register(ExtensionManifest(
            name: "@test.echo",
            handler: { payload in
                // Echo back the body text to prove we received it
                return .rhoeMarkdownFragment("Echo: \(payload.bodyText)")
            }
        ))

        let blocks: [Block] = [
            .admonition(type: "@test.echo", title: nil, content: [
                .paragraph([.text("Test body content")])
            ], collapsible: nil)
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = ExtensionResolutionPass(registry: registry)
        let result = pass.process(doc)

        let html = RhoeMarkdownKit.renderHTML(result)
        #expect(html.contains("Echo: Test body content"))
    }

    @Test("Visual extension block resolves via registry")
    func visualExtensionResolved() {
        let registry = ExtensionRegistry()
        registry.register(ExtensionManifest(
            name: "@chart.bar",
            handler: { _ in .svgArtifact("<svg><rect width='100' height='50'/></svg>") }
        ))

        let blocks: [Block] = [
            .visualBlock(name: "@chart.bar", content: [], attributes: .init())
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = ExtensionResolutionPass(registry: registry)
        let result = pass.process(doc)

        let html = RhoeMarkdownKit.renderHTML(result)
        #expect(html.contains("<svg>"))
    }

    @Test("Extension registry operations work correctly")
    func extensionRegistryOps() {
        let registry = ExtensionRegistry()
        #expect(registry.isEmpty)

        registry.register(ExtensionManifest(
            name: "@test.a",
            handler: { _ in .unresolved(message: "test") }
        ))
        #expect(!registry.isEmpty)
        #expect(registry.lookup("@test.a") != nil)
        #expect(registry.lookup("@test.b") == nil)
        #expect(registry.allExtensions.count == 1)

        registry.remove(name: "@test.a")
        #expect(registry.isEmpty)
    }

    @Test("Extension pass runs in pipeline before Phase 2")
    func extensionPipelineOrdering() {
        let registry = ExtensionRegistry()
        registry.register(ExtensionManifest(
            name: "@test.simple",
            handler: { _ in .rhoeMarkdownFragment("Resolved content.") }
        ))

        let blocks: [Block] = [
            .admonition(type: "@test.simple", title: nil, content: [], collapsible: nil),
            .paragraph([.text("Regular content")])
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pipeline = buildDocumentPipeline(for: .default, extensionRegistry: registry)
        let result = pipeline.run(doc)

        // Extension should have been resolved (no @test.simple admonition)
        let hasExtAdmonition = result.blocks.contains { block in
            if case .admonition(let type, _, _, _, _) = block { return type.hasPrefix("@") }
            return false
        }
        #expect(!hasExtAdmonition)
    }

    // MARK: - W5-3: Typst AST-Near Writer

    @Test("Typst heading emits #rhoe-section in AST-near mode")
    func typstAstNearHeading() async {
        let result = await RhoeMarkdownKit.parse("# Hello")
        let typst = RhoeMarkdownKit.renderTypst(result.document)
        // v4.0: heading becomes section node; AST-near Typst renders via visitSection
        #expect(typst.contains("#rhoe-section(level: 1)"))
    }

    @Test("Typst admonition emits #rhoe-admonition in AST-near mode")
    func typstAstNearAdmonition() {
        let block = Block.admonition(type: "note", title: "Important", content: [
            .paragraph([.text("Content")])
        ], collapsible: nil)
        let doc = RhoeMarkdownKit.Document(blocks: [block])
        let typst = RhoeMarkdownKit.renderTypst(doc)
        #expect(typst.contains("#rhoe-admonition(kind: \"note\""))
    }

    @Test("Typst flat mode uses classic syntax")
    func typstFlatMode() async {
        let config = RhoeMarkdownKit.TypstConfiguration.flat
        let result = await RhoeMarkdownKit.parse("# Hello")
        let typst = RhoeMarkdownKit.renderTypst(result.document, configuration: config)
        #expect(typst.contains("= Hello"))
        #expect(!typst.contains("#rhoe-section"))
    }

    @Test("Typst preamble includes function definitions in AST-near mode")
    func typstPreambleFunctions() async {
        let result = await RhoeMarkdownKit.parse("# Hello")
        let typst = RhoeMarkdownKit.renderTypst(result.document)
        #expect(typst.contains("#let rhoe-section"))
        #expect(typst.contains("#let rhoe-admonition"))
    }

    // MARK: - W5-4: LaTeX AST-Near Writer

    @Test("LaTeX heading emits RhoeSection in AST-near mode")
    func latexAstNearHeading() async {
        let result = await RhoeMarkdownKit.parse("# Hello")
        let latex = RhoeMarkdownKit.renderLaTeX(result.document)
        // v4.0: heading becomes section node; AST-near LaTeX wraps in RhoeSection
        #expect(latex.contains("\\begin{RhoeSection}"))
    }

    @Test("LaTeX admonition emits RhoeAdmonition in AST-near mode")
    func latexAstNearAdmonition() {
        let block = Block.admonition(type: "warning", title: "Caution", content: [
            .paragraph([.text("Be careful")])
        ], collapsible: nil)
        let doc = RhoeMarkdownKit.Document(blocks: [block])
        let latex = RhoeMarkdownKit.renderLaTeX(doc)
        #expect(latex.contains("\\begin{RhoeAdmonition}"))
    }

    @Test("LaTeX flat mode uses classic syntax")
    func latexFlatMode() async {
        let config = RhoeMarkdownKit.LaTeXConfiguration.flat
        let result = await RhoeMarkdownKit.parse("# Hello")
        let latex = RhoeMarkdownKit.renderLaTeX(result.document, configuration: config)
        #expect(latex.contains("\\section"))
        #expect(!latex.contains("RhoeSection"))
    }

    @Test("LaTeX preamble includes environment declarations in AST-near mode")
    func latexPreambleEnvs() async {
        let result = await RhoeMarkdownKit.parse("# Hello")
        let latex = RhoeMarkdownKit.renderLaTeX(result.document)
        #expect(latex.contains("\\NewDocumentEnvironment{RhoeSection}"))
        #expect(latex.contains("\\NewDocumentEnvironment{RhoeAdmonition}"))
    }
}
