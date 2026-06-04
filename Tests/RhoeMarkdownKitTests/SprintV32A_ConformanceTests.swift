import Testing
import Foundation
import RhoeMarkdownKit
import RhoeMarkdownModel
import RhoeMarkdownRendering

@Suite("v3.2 Wave A: AST-Near Writers")
struct SprintV32AConformanceTests {

    // MARK: - A1: Typst AST-Near

    @Test("Typst heading emits #rhoe-section")
    func typstHeadingASTNear() async {
        let result = await RhoeMarkdownKit.parse("# Hello")
        let typst = RhoeMarkdownKit.renderTypst(result.document)
        // v4.0: heading becomes section node; AST-near Typst emits #rhoe-section
        #expect(typst.contains("#rhoe-section(level: 1)"))
    }

    @Test("Typst paragraph emits #rhoe-paragraph")
    func typstParagraphASTNear() async {
        let result = await RhoeMarkdownKit.parse("Hello world.")
        let typst = RhoeMarkdownKit.renderTypst(result.document)
        #expect(typst.contains("#rhoe-paragraph["))
    }

    @Test("Typst blockquote emits #rhoe-block-quote")
    func typstBlockQuoteASTNear() async {
        let result = await RhoeMarkdownKit.parse("> A quote.")
        let typst = RhoeMarkdownKit.renderTypst(result.document)
        #expect(typst.contains("#rhoe-block-quote["))
    }

    @Test("Typst list emits #rhoe-list with #rhoe-list-item")
    func typstListASTNear() async {
        let result = await RhoeMarkdownKit.parse("- First\n- Second")
        let typst = RhoeMarkdownKit.renderTypst(result.document)
        #expect(typst.contains("#rhoe-list(ordered: false)"))
        #expect(typst.contains("#rhoe-list-item["))
    }

    @Test("Typst HR emits #rhoe-thematic-break")
    func typstHRASTNear() async {
        let result = await RhoeMarkdownKit.parse("---")
        let typst = RhoeMarkdownKit.renderTypst(result.document)
        #expect(typst.contains("#rhoe-thematic-break()"))
    }

    @Test("Typst flat mode produces native Typst")
    func typstFlatMode() async {
        let config = RhoeMarkdownKit.TypstConfiguration(astNearEmission: false)
        let result = await RhoeMarkdownKit.parse("# Hello\n\nWorld.")
        let typst = RhoeMarkdownKit.renderTypst(result.document, configuration: config)
        #expect(typst.contains("= Hello"))
        #expect(!typst.contains("#rhoe-section"))
    }

    @Test("Typst preamble includes all function definitions")
    func typstPreambleFunctions() async {
        let result = await RhoeMarkdownKit.parse("# Test")
        let typst = RhoeMarkdownKit.renderTypst(result.document)
        #expect(typst.contains("#let rhoe-section"))
        #expect(typst.contains("#let rhoe-paragraph"))
        #expect(typst.contains("#let rhoe-block-quote"))
        #expect(typst.contains("#let rhoe-admonition"))
        #expect(typst.contains("#let rhoe-theorem"))
        #expect(typst.contains("#let rhoe-list"))
        #expect(typst.contains("#let rhoe-thematic-break"))
    }

    // MARK: - A2: LaTeX AST-Near

    @Test("LaTeX heading emits \\begin{RhoeSection}")
    func latexHeadingASTNear() async {
        let result = await RhoeMarkdownKit.parse("# Hello")
        let latex = RhoeMarkdownKit.renderLaTeX(result.document)
        // v4.0: heading becomes section node; AST-near LaTeX wraps in RhoeSection
        #expect(latex.contains("\\begin{RhoeSection}"))
        #expect(latex.contains("\\end{RhoeSection}"))
    }

    @Test("LaTeX blockquote emits \\begin{RhoeBlockQuote}")
    func latexBlockQuoteASTNear() async {
        let result = await RhoeMarkdownKit.parse("> A quote.")
        let latex = RhoeMarkdownKit.renderLaTeX(result.document)
        #expect(latex.contains("\\begin{RhoeBlockQuote}"))
    }

    @Test("LaTeX admonition emits \\begin{RhoeAdmonition}")
    func latexAdmonitionASTNear() async {
        let md = "!!! note\nImportant info.\n!!!"
        let result = await RhoeMarkdownKit.parse(md)
        let latex = RhoeMarkdownKit.renderLaTeX(result.document)
        #expect(latex.contains("\\begin{RhoeAdmonition}"))
    }

    @Test("LaTeX flat mode produces standard LaTeX")
    func latexFlatMode() async {
        let config = RhoeMarkdownKit.LaTeXConfiguration(astNearEmission: false)
        let result = await RhoeMarkdownKit.parse("# Hello\n\nWorld.")
        let latex = RhoeMarkdownKit.renderLaTeX(result.document, configuration: config)
        #expect(latex.contains("\\section{Hello}"))
        #expect(!latex.contains("\\begin{RhoeSection}"))
    }

    @Test("LaTeX preamble includes Rhoe environment definitions")
    func latexPreambleEnvironments() async {
        let result = await RhoeMarkdownKit.parse("# Test")
        let latex = RhoeMarkdownKit.renderLaTeX(result.document)
        #expect(latex.contains("\\NewDocumentEnvironment{RhoeSection}"))
        #expect(latex.contains("\\NewDocumentEnvironment{RhoeBlockQuote}"))
        #expect(latex.contains("\\NewDocumentEnvironment{RhoeAdmonition}"))
        #expect(latex.contains("\\NewDocumentEnvironment{RhoeTheorem}"))
    }

    // MARK: - A3: HTML/CSS Foundation

    @Test("HTML document wrapper emits <main class=\"rhoe-document\">")
    func htmlDocumentWrapper() async {
        let config = RhoeMarkdownKit.HTMLConfiguration(wrapInDocument: true)
        let result = await RhoeMarkdownKit.parse("# Hello\n\nWorld.")
        let html = RhoeMarkdownKit.renderHTML(result.document, configuration: config)
        #expect(html.contains("<main class=\"rhoe-document\""))
        #expect(html.contains("data-rhoe-node=\"Document\""))
        #expect(html.contains("data-rhoe-version=\"0.1.0\""))
        #expect(html.contains("</main>"))
    }

    @Test("HTML includeDefaultCSS injects stylesheet")
    func htmlIncludeCSS() async {
        let config = RhoeMarkdownKit.HTMLConfiguration(includeDefaultCSS: true, wrapInDocument: true)
        let result = await RhoeMarkdownKit.parse("Hello.")
        let html = RhoeMarkdownKit.renderHTML(result.document, configuration: config)
        #expect(html.contains("<style>"))
        #expect(html.contains("--rhoe-color-text"))
        #expect(html.contains("--rhoe-font-body"))
        #expect(html.contains(".rhoe-admonition"))
    }

    @Test("Default CSS contains all core custom properties")
    func defaultCSSProperties() {
        let css = RhoeDefaultCSS.stylesheet
        #expect(css.contains("--rhoe-space-xs"))
        #expect(css.contains("--rhoe-color-note"))
        #expect(css.contains("--rhoe-color-danger"))
        #expect(css.contains("--rhoe-font-mono"))
        #expect(css.contains(".rhoe-theorem"))
        #expect(css.contains(".rhoe-table"))
        #expect(css.contains("prefers-color-scheme: dark"))
    }

    @Test("HTML headings have data-rhoe-node and data-level")
    func htmlHeadingAttributes() async {
        let result = await RhoeMarkdownKit.parse("## Section Title")
        let html = RhoeMarkdownKit.renderHTML(result.document)
        // v4.0: heading becomes section node with data-rhoe-node="Section"
        #expect(html.contains("data-rhoe-node=\"Section\""))
    }
}
