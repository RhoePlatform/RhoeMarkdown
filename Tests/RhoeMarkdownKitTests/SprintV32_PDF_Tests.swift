import Testing
import Foundation
import RhoeMarkdownKit
import RhoeMarkdownModel
import RhoeMarkdownRendering

@Suite("v3.2: Native PDF Rendering")
struct SprintV32PDFTests {

    // MARK: - PDFConfiguration

    @Test("PDFConfiguration defaults to WebKit pipeline")
    func pdfConfigDefaults() {
        let config = RhoeMarkdownKit.PDFConfiguration.default
        #expect(config.pipeline == .webkit)
        #expect(config.paperSize == "a4")
        #expect(config.orientation == "portrait")
        #expect(config.fontSize == "11pt")
        #expect(config.enableTableOfContents == false)
        #expect(config.page == nil)
        #expect(config.fromPage == nil)
        #expect(config.toPage == nil)
    }

    @Test("PDFConfiguration page selection stores values")
    func pdfConfigPageSelection() {
        let single = RhoeMarkdownKit.PDFConfiguration(page: 3)
        #expect(single.page == 3)
        #expect(single.fromPage == nil)

        let range = RhoeMarkdownKit.PDFConfiguration(fromPage: 2, toPage: 5)
        #expect(range.fromPage == 2)
        #expect(range.toPage == 5)
        #expect(range.page == nil)
    }

    @Test("PDFConfiguration orientation is configurable")
    func pdfConfigOrientation() {
        let landscape = RhoeMarkdownKit.PDFConfiguration(orientation: "landscape")
        #expect(landscape.orientation == "landscape")

        let portrait = RhoeMarkdownKit.PDFConfiguration()
        #expect(portrait.orientation == "portrait")
    }

    @Test("PDFPipeline has three options")
    func pdfPipelineOptions() {
        let pipelines = RhoeMarkdownKit.PDFConfiguration.PDFPipeline.allCases
        #expect(pipelines.count == 3)
        #expect(pipelines.contains(.latex))
        #expect(pipelines.contains(.typst))
        #expect(pipelines.contains(.webkit))
    }

    @Test("Convenience presets create correct configs")
    func pdfConfigPresets() {
        let typst = RhoeMarkdownKit.PDFConfiguration.typst
        #expect(typst.pipeline == .typst)

        let latex = RhoeMarkdownKit.PDFConfiguration.latex
        #expect(latex.pipeline == .latex)
    }

    // MARK: - PDFPageSize

    @Test("A4 dimensions are correct (595.28 × 841.89 points)")
    func pageSizeA4() {
        let a4 = PDFPageSize.a4
        #expect(abs(a4.width - 595.28) < 0.01)
        #expect(abs(a4.height - 841.89) < 0.01)
    }

    @Test("Letter dimensions are correct (612 × 792 points)")
    func pageSizeLetter() {
        let letter = PDFPageSize.letter
        #expect(abs(letter.width - 612.0) < 0.01)
        #expect(abs(letter.height - 792.0) < 0.01)
    }

    @Test("Landscape 16:9 dimensions are correct (1024 × 768 points)")
    func pageSizeLandscape() {
        let slide = PDFPageSize.landscape16x9
        #expect(abs(slide.width - 1024.0) < 0.01)
        #expect(abs(slide.height - 768.0) < 0.01)
    }

    @Test("Custom page size stores dimensions")
    func pageSizeCustom() {
        let custom = PDFPageSize.custom(width: 500, height: 700)
        #expect(custom.width == 500)
        #expect(custom.height == 700)
    }

    @Test("PDFPageSize initializes from name string")
    func pageSizeFromName() {
        #expect(PDFPageSize(name: "a4") == .a4)
        #expect(PDFPageSize(name: "A4") == .a4)
        #expect(PDFPageSize(name: "letter") == .letter)
        #expect(PDFPageSize(name: "Letter") == .letter)
        #expect(PDFPageSize(name: "landscape") == .landscape16x9)
        #expect(PDFPageSize(name: "16x9") == .landscape16x9)
        #expect(PDFPageSize(name: "unknown") == nil)
        #expect(PDFPageSize(name: "") == nil)
    }

    // MARK: - PDFPageMargins

    @Test("Default margins are 1 inch (72 points)")
    func defaultMargins() {
        let m = PDFPageMargins.default
        #expect(m.top == 72)
        #expect(m.right == 72)
        #expect(m.bottom == 72)
        #expect(m.left == 72)
    }

    @Test("No margins are zero")
    func noMargins() {
        let m = PDFPageMargins.none
        #expect(m.top == 0 && m.right == 0 && m.bottom == 0 && m.left == 0)
    }

    @Test("Narrow margins are 0.5 inch (36 points)")
    func narrowMargins() {
        let m = PDFPageMargins.narrow
        #expect(m.top == 36)
        #expect(m.left == 36)
    }

    @Test("Custom margins store values")
    func customMargins() {
        let m = PDFPageMargins(top: 50, right: 40, bottom: 60, left: 30)
        #expect(m.top == 50)
        #expect(m.right == 40)
        #expect(m.bottom == 60)
        #expect(m.left == 30)
    }

    // MARK: - PDFPageOrientation

    @Test("Orientation raw values are correct")
    func orientationRawValues() {
        #expect(PDFPageOrientation.portrait.rawValue == "portrait")
        #expect(PDFPageOrientation.landscape.rawValue == "landscape")
    }

    // MARK: - Print CSS

    @Test("Document print CSS contains @page rule with size")
    func documentPrintCSS() {
        let css = RhoePrintCSS.documentCSS(pageSize: .a4, orientation: .portrait)
        #expect(css.contains("@page"))
        #expect(css.contains("A4"))
        #expect(css.contains("portrait"))
    }

    @Test("Document print CSS contains page-break rules")
    func documentPrintCSSBreaks() {
        let css = RhoePrintCSS.documentCSS(pageSize: .letter, orientation: .landscape)
        #expect(css.contains("page-break-after: avoid"))
        #expect(css.contains("page-break-inside: avoid"))
        #expect(css.contains("letter"))
        #expect(css.contains("landscape"))
    }

    @Test("Slide print CSS contains landscape and page-break")
    func slidePrintCSS() {
        let css = RhoePrintCSS.slideCSS
        #expect(css.contains("landscape"))
        #expect(css.contains("page-break-after: always"))
        #expect(css.contains("rhoe-slide-page"))
        #expect(css.contains("100vw"))
        #expect(css.contains("100vh"))
    }

    @Test("Slide print CSS includes heading styles")
    func slidePrintCSSTypography() {
        let css = RhoePrintCSS.slideCSS
        #expect(css.contains("h1"))
        #expect(css.contains("h2"))
        #expect(css.contains("font-family"))
    }

    // MARK: - PDFWriter Availability

    @Test("WebKit pipeline reports availability on Apple platforms")
    func webkitAvailability() {
        let writer = PDFWriter(configuration: .init(pipeline: .webkit))
        #if canImport(WebKit) && (os(macOS) || os(iOS) || os(visionOS))
        #expect(writer.isAvailable())
        #else
        #expect(!writer.isAvailable())
        #endif
    }

    @Test("Typst pipeline availability depends on tool")
    func typstAvailability() {
        let writer = PDFWriter(configuration: .init(pipeline: .typst))
        // May or may not be available depending on environment
        _ = writer.isAvailable()
    }

    @Test("LaTeX pipeline availability depends on tool")
    func latexAvailability() {
        let writer = PDFWriter(configuration: .init(pipeline: .latex))
        _ = writer.isAvailable()
    }

    // MARK: - Sync Rendering

    @Test("Synchronous renderPDF does not crash on empty document")
    func syncRenderEmptyDoc() {
        let doc = RhoeMarkdownKit.Document(blocks: [])
        let data = RhoeMarkdownKit.renderPDF(doc)
        // May be empty if no compiler — the point is no crash
        _ = data
    }

    @Test("Synchronous renderPDF does not crash on normal document")
    func syncRenderNormalDoc() async {
        let result = await RhoeMarkdownKit.parse("# Hello\n\nWorld.")
        let data = RhoeMarkdownKit.renderPDF(result.document)
        _ = data
    }

    // MARK: - Async Rendering (WebKit)

    @Test("Async renderPDFAsync produces data on Apple platforms")
    @MainActor
    func asyncRenderProducesData() async {
        let result = await RhoeMarkdownKit.parse("# Hello\n\nThis is a test document.")
        let data = await RhoeMarkdownKit.renderPDFAsync(result.document)
        #if canImport(WebKit) && (os(macOS) || os(iOS) || os(visionOS))
        #expect(!data.isEmpty)
        // Verify PDF magic bytes
        if data.count >= 4 {
            #expect(data[0] == 0x25) // %
            #expect(data[1] == 0x50) // P
            #expect(data[2] == 0x44) // D
            #expect(data[3] == 0x46) // F
        }
        #endif
    }

    @Test("toPDF convenience method produces data")
    @MainActor
    func toPDFConvenience() async {
        let data = await RhoeMarkdownKit.toPDF("# Test\n\nHello world.")
        #if canImport(WebKit) && (os(macOS) || os(iOS) || os(visionOS))
        #expect(!data.isEmpty)
        #endif
    }

    @Test("Async render with landscape orientation")
    @MainActor
    func asyncRenderLandscape() async {
        let config = RhoeMarkdownKit.PDFConfiguration(orientation: "landscape")
        let result = await RhoeMarkdownKit.parse("# Wide Document")
        let data = await RhoeMarkdownKit.renderPDFAsync(result.document, configuration: config)
        #if canImport(WebKit) && (os(macOS) || os(iOS) || os(visionOS))
        #expect(!data.isEmpty)
        #endif
    }

    @Test("Async render with Letter size")
    @MainActor
    func asyncRenderLetter() async {
        let config = RhoeMarkdownKit.PDFConfiguration(paperSize: "letter")
        let result = await RhoeMarkdownKit.parse("# US Letter Document\n\nContent.")
        let data = await RhoeMarkdownKit.renderPDFAsync(result.document, configuration: config)
        #if canImport(WebKit) && (os(macOS) || os(iOS) || os(visionOS))
        #expect(!data.isEmpty)
        #endif
    }

    // MARK: - Edge Cases

    @Test("Empty document renders without crash")
    @MainActor
    func emptyDocumentRender() async {
        let data = await RhoeMarkdownKit.toPDF("")
        // Empty or small is fine — no crash is the requirement
        _ = data
    }

    @Test("Document with only heading renders")
    @MainActor
    func headingOnlyRender() async {
        let data = await RhoeMarkdownKit.toPDF("# Just a Heading")
        #if canImport(WebKit) && (os(macOS) || os(iOS) || os(visionOS))
        #expect(!data.isEmpty)
        #endif
    }

    @Test("Document with code block renders")
    @MainActor
    func codeBlockRender() async {
        let md = "# Code\n\n```python\nprint('hello')\n```"
        let data = await RhoeMarkdownKit.toPDF(md)
        #if canImport(WebKit) && (os(macOS) || os(iOS) || os(visionOS))
        #expect(!data.isEmpty)
        #endif
    }

    @Test("Document with table renders")
    @MainActor
    func tableRender() async {
        let md = "| A | B |\n|---|---|\n| 1 | 2 |"
        let data = await RhoeMarkdownKit.toPDF(md)
        #if canImport(WebKit) && (os(macOS) || os(iOS) || os(visionOS))
        #expect(!data.isEmpty)
        #endif
    }

    @Test("Document with admonition renders")
    @MainActor
    func admonitionRender() async {
        let md = "!!! warning\nBe careful!\n!!!"
        let data = await RhoeMarkdownKit.toPDF(md)
        #if canImport(WebKit) && (os(macOS) || os(iOS) || os(visionOS))
        #expect(!data.isEmpty)
        #endif
    }
}
