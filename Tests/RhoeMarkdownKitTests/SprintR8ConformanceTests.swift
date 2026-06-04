import Testing
import RhoeMarkdownKit
import RhoeMarkdownModel

@Suite("Sprint R8: Transclusion + Schema Resolution")
struct SprintR8ConformanceTests {

    // MARK: - R8.1 Block Transclusion Placeholder

    @Test("Block transclusion renders visible placeholder")
    func blockTransclusionPlaceholder() {
        let block = Block.transclusion(
            target: "./chapter2.md",
            fragment: "methodology",
            mode: .block
        )
        let doc = RhoeMarkdownKit.Document(blocks: [block])
        let html = RhoeMarkdownKit.renderHTML(doc)
        #expect(html.contains("rhoe-transclusion"))
        #expect(html.contains("chapter2.md"))
        #expect(html.contains("methodology"))
        #expect(!html.isEmpty)
    }

    @Test("Block transclusion without fragment renders target only")
    func blockTransclusionNoFragment() {
        let block = Block.transclusion(
            target: "./intro.md",
            fragment: nil,
            mode: .block
        )
        let doc = RhoeMarkdownKit.Document(blocks: [block])
        let html = RhoeMarkdownKit.renderHTML(doc)
        #expect(html.contains("intro.md"))
        #expect(html.contains("rhoe-transclusion-placeholder"))
    }

    // MARK: - R8.2 Inline Transclusion Placeholder

    @Test("Inline transclusion renders inline placeholder")
    func inlineTransclusionPlaceholder() {
        let inline = Inline.transclusionInline(
            target: "./glossary.md",
            fragment: "fixed-point",
            mode: .inline
        )
        let doc = RhoeMarkdownKit.Document(blocks: [
            .paragraph([.text("Term: "), inline])
        ])
        let html = RhoeMarkdownKit.renderHTML(doc)
        #expect(html.contains("rhoe-transclusion-inline"))
        #expect(html.contains("glossary.md"))
    }

    // MARK: - R8.3 Schema Island Rendering

    @Test("Schema island renders as code block")
    func schemaIslandRendering() {
        let block = Block.schemaIsland(
            schema: "rhoedsl",
            body: "Section(id: \"intro\") { H1 { Welcome } }"
        )
        let doc = RhoeMarkdownKit.Document(blocks: [block])
        let html = RhoeMarkdownKit.renderHTML(doc)
        #expect(html.contains("rhoe-schema-island"))
        #expect(html.contains("language-rhoedsl"))
        #expect(html.contains("Section"))
    }

    // MARK: - R8.4 Writer Placeholders

    @Test("LaTeX writer produces non-empty transclusion output")
    func latexTransclusion() {
        let block = Block.transclusion(target: "./ch2.md", fragment: "intro", mode: .block)
        let doc = RhoeMarkdownKit.Document(blocks: [block])
        let latex = RhoeMarkdownKit.renderLaTeX(doc)
        #expect(latex.contains("ch2.md"))
        #expect(latex.contains("Transclusion"))
    }

    @Test("Typst writer produces non-empty transclusion output")
    func typstTransclusion() {
        let block = Block.transclusion(target: "./ch2.md", fragment: "intro", mode: .block)
        let doc = RhoeMarkdownKit.Document(blocks: [block])
        let typst = RhoeMarkdownKit.renderTypst(doc)
        #expect(typst.contains("ch2.md"))
        #expect(typst.contains("Transclusion"))
    }

    @Test("Schema island renders in LaTeX as verbatim")
    func latexSchemaIsland() {
        let block = Block.schemaIsland(schema: "rhoedsl", body: "Paragraph { test }")
        let doc = RhoeMarkdownKit.Document(blocks: [block])
        let latex = RhoeMarkdownKit.renderLaTeX(doc)
        #expect(latex.contains("verbatim"))
        #expect(latex.contains("Paragraph"))
    }

    @Test("Unresolved transclusion renders graceful placeholder")
    func unresolvedTransclusionGraceful() {
        // Without a resolver, transclusion stays as-is and renders placeholder
        let block = Block.transclusion(
            target: "./nonexistent.md",
            fragment: nil,
            mode: .block
        )
        let doc = RhoeMarkdownKit.Document(blocks: [block])
        let html = RhoeMarkdownKit.renderHTML(doc)
        // Should render something visible, not empty
        #expect(!html.isEmpty)
        #expect(html.contains("nonexistent.md"))
    }
}
