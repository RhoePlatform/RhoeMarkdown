import Foundation
import PDFKit
import Testing
import RhoeMarkdownKit

@Suite("Compiler Render Contract")
struct CompilerRenderContractTests {
    @Test("Render capabilities report the preferred PDF pipeline")
    func renderCapabilitiesReportPreferredPipeline() {
        let capabilities = RhoeMarkdownKit.renderingCapabilities()

        #expect(capabilities.preferredPipeline == .webkit)
        #expect(capabilities.pipelines.count == 3)
        #expect(capabilities.pipelines.contains(where: { $0.pipeline == .webkit }))
        #expect(capabilities.pipelines.contains(where: { $0.pipeline == .typst }))
        #expect(capabilities.pipelines.contains(where: { $0.pipeline == .latex }))
    }

    @Test("Selected slide PDF rendering returns a single-page PDF")
    func selectedSlidePDFRendering() async throws {
        let result = try await RhoeMarkdownKit.renderPDF(
            presentationMarkdown,
            selection: .slide(index: 1)
        )

        #expect(result.selection == .slide(index: 1))
        #expect(result.sourcePageCount == 2)
        #expect(result.outputPageCount == 1)
        #expect(result.selectedPage?.pageIndex == 1)
        #expect(result.backend == .presentationHTMLPDF)

        let pdf = try #require(PDFDocument(data: result.pdfData))
        #expect(pdf.pageCount == 1)
    }

    @Test("Deck PNG rendering returns one PNG per slide page")
    func deckPNGRendering() async throws {
        let result = try await RhoeMarkdownKit.renderPNG(
            presentationMarkdown,
            selection: .deck
        )

        #expect(result.selection == .deck)
        #expect(result.sourcePageCount == 2)
        #expect(result.pages.count == 2)
        #expect(result.pages.allSatisfy { !$0.pngData.isEmpty })
        #expect(result.backend == .presentationHTMLPDF)
    }

    @Test("Selected slide PNG rendering preserves the original slide index")
    func selectedSlidePNGRendering() async throws {
        let pdf = try await RhoeMarkdownKit.renderPDF(
            presentationMarkdown,
            selection: .slide(index: 0)
        )
        let png = try await RhoeMarkdownKit.renderPNG(
            presentationMarkdown,
            selection: .slide(index: 0)
        )

        #expect(pdf.selectedPage?.pageIndex == 0)
        #expect(png.pages.count == 1)
        #expect(png.pages.first?.metadata.pageIndex == 0)
        #expect(png.pages.first?.metadata.pointWidth == pdf.selectedPage?.pointWidth)
        #expect(png.pages.first?.metadata.pointHeight == pdf.selectedPage?.pointHeight)
    }

    @Test("Invalid slide index fails explicitly")
    func invalidSlideIndexFails() async throws {
        do {
            _ = try await RhoeMarkdownKit.renderPDF(
                presentationMarkdown,
                selection: .slide(index: 9)
            )
            Issue.record("Expected invalid slide selection to throw.")
        } catch let error as RhoeMarkdownKit.RenderError {
            #expect(error == .invalidSelectedSlideIndex(index: 9, availableSlides: 2))
        }
    }

    private var presentationMarkdown: String {
        """
        ---
        title: Engine Contract
        theme: corporate
        ---

        %%% Intro {layout=title, background=gradient(#102030,#305070,25)}
        # Intro

        Authoritative compiler rendering.

        %%% Grid Walkthrough {layout=two-column, transition=fade}
        # Grid Walkthrough

        - Left column
        - Right column
        """
    }
}
