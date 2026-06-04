import Testing
import Foundation
import RhoeMarkdownKit
import RhoeMarkdownRendering
@testable import RhoeMarkdownPresentation

@Suite("Sprint 10: PDF, EPUB, Enhanced PPTX Writers")
struct Sprint10ConformanceTests {

    // MARK: - 10.1 PDFConfiguration

    @Test("PDFConfiguration defaults are correct")
    func pdfConfigurationDefaults() {
        let config = RhoeMarkdownKit.PDFConfiguration.default
        #expect(config.pipeline == .webkit)
        #expect(config.paperSize == "a4")
        #expect(config.fontSize == "11pt")
        #expect(config.enableTableOfContents == false)
    }

    @Test("PDFConfiguration LaTeX pipeline")
    func pdfLatexPipeline() {
        let config = RhoeMarkdownKit.PDFConfiguration(pipeline: .latex)
        #expect(config.pipeline == .latex)
    }

    // MARK: - 10.2 PDF Writer

    @Test("PDF writer produces Data via Typst when available")
    func pdfTypstPipeline() async {
        let writer = PDFWriter()
        guard writer.isAvailable() else { return }

        let data = await RhoeMarkdownKit.toPDF("# Hello\n\nWorld.")
        #expect(!data.isEmpty)
        // PDF magic bytes: %PDF
        if data.count >= 4 {
            let header = String(data: data.prefix(4), encoding: .ascii)
            #expect(header == "%PDF")
        }
    }

    @Test("PDF writer returns empty Data when tool unavailable")
    func pdfFallback() async {
        let writer = PDFWriter()
        if !writer.isAvailable() {
            let data = await RhoeMarkdownKit.toPDF("# Hello")
            #expect(data.isEmpty)
        }
    }

    @Test("PDF writer via LaTeX pipeline when available")
    func pdfLatexPipelineOutput() async {
        let config = RhoeMarkdownKit.PDFConfiguration(pipeline: .latex)
        let writer = PDFWriter(configuration: config)
        guard writer.isAvailable() else { return }

        let result = await RhoeMarkdownKit.parse("# Hello\n\nWorld.")
        let data = RhoeMarkdownKit.renderPDF(result.document, configuration: config)
        #expect(!data.isEmpty)
    }

    // MARK: - 10.3 EPUBConfiguration

    @Test("EPUBConfiguration defaults are correct")
    func epubConfigurationDefaults() {
        let config = RhoeMarkdownKit.EPUBConfiguration.default
        #expect(config.chapterLevel == 1)
        #expect(config.tocDepth == 3)
        #expect(config.language == "en")
        #expect(config.cssContent == nil)
    }

    // MARK: - 10.4 EPUB Writer

    @Test("EPUB produces non-empty data")
    func epubProducesData() async {
        let md = "# Chapter 1\n\nHello world.\n\n# Chapter 2\n\nGoodbye world."
        let data = await RhoeMarkdownKit.toEPUB(md)
        #expect(!data.isEmpty)
    }

    @Test("EPUB starts with PK (ZIP header)")
    func epubIsZip() async {
        let data = await RhoeMarkdownKit.toEPUB("# Hello\n\nWorld.")
        #expect(data.count > 10)
        if data.count >= 2 {
            #expect(data[0] == 0x50) // P
            #expect(data[1] == 0x4B) // K
        }
    }

    @Test("EPUB with multiple chapters")
    func epubMultipleChapters() async {
        let md = """
        ---
        title: My Book
        author: Thor
        ---

        # Chapter One

        First chapter content.

        # Chapter Two

        Second chapter content.

        # Chapter Three

        Third chapter content.
        """
        let data = await RhoeMarkdownKit.toEPUB(md)
        #expect(!data.isEmpty)
        // Verify it's a valid ZIP
        if data.count >= 2 {
            #expect(data[0] == 0x50)
            #expect(data[1] == 0x4B)
        }
    }

    @Test("EPUB without headings produces single chapter")
    func epubNoHeadings() async {
        let md = "Just some text.\n\nAnother paragraph."
        let data = await RhoeMarkdownKit.toEPUB(md)
        #expect(!data.isEmpty)
    }

    @Test("EPUB with custom CSS")
    func epubCustomCSS() async {
        let config = RhoeMarkdownKit.EPUBConfiguration(
            cssContent: "body { color: red; }"
        )
        let result = await RhoeMarkdownKit.parse("# Test\n\nStyled content.")
        let data = RhoeMarkdownKit.renderEPUB(result.document, configuration: config)
        #expect(!data.isEmpty)
    }

    @Test("EPUB with frontmatter metadata")
    func epubFrontmatter() async {
        let md = """
        ---
        title: Test Book
        author: Test Author
        ---

        # Introduction

        Hello.
        """
        let data = await RhoeMarkdownKit.toEPUB(md)
        #expect(!data.isEmpty)
    }

    // MARK: - 10.5 Enhanced PPTX

    @Test("PPTXSlide supports speaker notes")
    func pptxSpeakerNotes() {
        let slide = PPTXSlide(
            id: 1,
            shapes: [],
            speakerNotes: "Remember to explain this clearly."
        )
        #expect(slide.speakerNotes == "Remember to explain this clearly.")
    }

    @Test("PPTXSlide supports transitions")
    func pptxTransitions() {
        let slide = PPTXSlide(
            id: 1,
            shapes: [],
            transition: .fade
        )
        #expect(slide.transition == .fade)
    }

    @Test("PPTXTransitionType generates XML elements")
    func pptxTransitionXML() {
        #expect(PPTXTransitionType.fade.xmlElement.contains("fade"))
        #expect(PPTXTransitionType.push.xmlElement.contains("push"))
        #expect(PPTXTransitionType.wipe.xmlElement.contains("wipe"))
        #expect(PPTXTransitionType.none.xmlElement.isEmpty)
    }

    @Test("PPTXSlideGenerator includes notes XML")
    func pptxSlideGeneratorNotes() {
        let slide = PPTXSlide(
            id: 1,
            shapes: [],
            speakerNotes: "Test note"
        )
        let xml = PPTXSlideGenerator.generateSlide(slide)
        #expect(xml.contains("p:notes"))
        #expect(xml.contains("Test note"))
    }

    @Test("PPTXSlideGenerator includes transition XML")
    func pptxSlideGeneratorTransition() {
        let slide = PPTXSlide(
            id: 1,
            shapes: [],
            transition: .dissolve
        )
        let xml = PPTXSlideGenerator.generateSlide(slide)
        #expect(xml.contains("p:transition"))
        #expect(xml.contains("dissolve"))
    }
}
