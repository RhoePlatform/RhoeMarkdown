import Testing
import Foundation
import RhoeMarkdownKit
@testable import RhoeMDCore

@Suite("Sprint 11: CLI Expansion + Public API")
struct Sprint11ConformanceTests {

    // MARK: - 11.1 OutputFormat Enum

    @Test("OutputFormat file extensions are correct")
    func outputFormatExtensions() {
        #expect(RhoeMarkdownKit.OutputFormat.html.fileExtension == "html")
        #expect(RhoeMarkdownKit.OutputFormat.latex.fileExtension == "tex")
        #expect(RhoeMarkdownKit.OutputFormat.typst.fileExtension == "typ")
        #expect(RhoeMarkdownKit.OutputFormat.docx.fileExtension == "docx")
        #expect(RhoeMarkdownKit.OutputFormat.pdf.fileExtension == "pdf")
        #expect(RhoeMarkdownKit.OutputFormat.epub.fileExtension == "epub")
    }

    @Test("OutputFormat binary flag is correct")
    func outputFormatBinary() {
        #expect(!RhoeMarkdownKit.OutputFormat.html.isBinary)
        #expect(!RhoeMarkdownKit.OutputFormat.latex.isBinary)
        #expect(!RhoeMarkdownKit.OutputFormat.typst.isBinary)
        #expect(RhoeMarkdownKit.OutputFormat.docx.isBinary)
        #expect(RhoeMarkdownKit.OutputFormat.pdf.isBinary)
        #expect(RhoeMarkdownKit.OutputFormat.epub.isBinary)
    }

    @Test("OutputFormat detects from file extension")
    func outputFormatFromExtension() {
        #expect(RhoeMarkdownKit.OutputFormat.fromExtension("html") == .html)
        #expect(RhoeMarkdownKit.OutputFormat.fromExtension("htm") == .html)
        #expect(RhoeMarkdownKit.OutputFormat.fromExtension("tex") == .latex)
        #expect(RhoeMarkdownKit.OutputFormat.fromExtension("typ") == .typst)
        #expect(RhoeMarkdownKit.OutputFormat.fromExtension("docx") == .docx)
        #expect(RhoeMarkdownKit.OutputFormat.fromExtension("pdf") == .pdf)
        #expect(RhoeMarkdownKit.OutputFormat.fromExtension("epub") == .epub)
        #expect(RhoeMarkdownKit.OutputFormat.fromExtension("xyz") == nil)
    }

    @Test("OutputFormat has all six cases")
    func outputFormatAllCases() {
        #expect(RhoeMarkdownKit.OutputFormat.allCases.count == 6)
    }

    // MARK: - 11.2 CLI Argument Parsing

    @Test("CLI parses --format flag")
    func cliFormatParsing() {
        let args = ["rhoemd", "input.md", "--format", "latex"]
        let options = RhoeMD.parseArguments(args)
        #expect(options.format == .latex)
    }

    @Test("CLI parses -F short flag")
    func cliFormatShortFlag() {
        let args = ["rhoemd", "input.md", "-F", "typst"]
        let options = RhoeMD.parseArguments(args)
        #expect(options.format == .typst)
    }

    @Test("CLI default format is html")
    func cliDefaultFormat() {
        let args = ["rhoemd", "input.md"]
        let options = RhoeMD.parseArguments(args)
        #expect(options.resolvedFormat() == .html)
    }

    @Test("CLI auto-detects format from output extension")
    func cliAutoDetectFormat() {
        let args = ["rhoemd", "input.md", "-o", "output.pdf"]
        let options = RhoeMD.parseArguments(args)
        #expect(options.format == nil) // Not explicitly set
        #expect(options.resolvedFormat() == .pdf) // Detected from .pdf
    }

    @Test("CLI parses --toc flag")
    func cliTocFlag() {
        let args = ["rhoemd", "input.md", "--toc"]
        let options = RhoeMD.parseArguments(args)
        #expect(options.tableOfContents == true)
    }

    @Test("CLI parses --toc-depth flag")
    func cliTocDepthFlag() {
        let args = ["rhoemd", "input.md", "--toc", "--toc-depth", "2"]
        let options = RhoeMD.parseArguments(args)
        #expect(options.tocDepth == 2)
    }

    @Test("CLI usage text includes all formats")
    func cliUsageText() {
        let usage = RhoeMD.usage()
        #expect(usage.contains("html"))
        #expect(usage.contains("latex"))
        #expect(usage.contains("typst"))
        #expect(usage.contains("docx"))
        #expect(usage.contains("pdf"))
        #expect(usage.contains("epub"))
        #expect(usage.contains("--format"))
        #expect(usage.contains("--toc"))
    }

    // MARK: - 11.3 Unified Writer API

    @Test("Unified render dispatches to HTML")
    func unifiedRenderHTML() async {
        let result = await RhoeMarkdownKit.parse("# Hello\n\n**World**.")
        let data = RhoeMarkdownKit.render(result.document, format: .html)
        let html = String(data: data, encoding: .utf8)!
        #expect(html.contains("<h1"))
        #expect(html.contains("<strong>"))
    }

    @Test("Unified render dispatches to LaTeX")
    func unifiedRenderLaTeX() async {
        let result = await RhoeMarkdownKit.parse("# Hello\n\n**World**.")
        let data = RhoeMarkdownKit.render(result.document, format: .latex)
        let latex = String(data: data, encoding: .utf8)!
        #expect(latex.contains("RhoeSection"))
        #expect(latex.contains("textbf"))
    }

    @Test("Unified render dispatches to Typst")
    func unifiedRenderTypst() async {
        let result = await RhoeMarkdownKit.parse("# Hello\n\n*World*.")
        let data = RhoeMarkdownKit.render(result.document, format: .typst)
        let typst = String(data: data, encoding: .utf8)!
        #expect(typst.contains("#rhoe-section"))
        #expect(typst.contains("_World_"))
    }

    @Test("Unified render dispatches to DOCX (binary)")
    func unifiedRenderDOCX() async {
        let result = await RhoeMarkdownKit.parse("# Hello\n\n**World**.")
        let data = RhoeMarkdownKit.render(result.document, format: .docx)
        #expect(!data.isEmpty)
        #expect(data[0] == 0x50) // PK zip header
    }

    @Test("Unified convert produces non-empty Data")
    func unifiedConvert() async {
        let data = await RhoeMarkdownKit.convert("# Test\n\nHello.", format: .html)
        let html = String(data: data, encoding: .utf8)!
        #expect(html.contains("<h1"))
    }

    // MARK: - 11.4 CLI Multi-Format Compile

    @Test("CLI compiles to LaTeX format")
    func cliCompileLaTeX() async throws {
        let options = RhoeMD.Options(format: .latex)
        let result = try await RhoeMD.compileMarkdown("# Hello\n\nWorld.", options: options)
        let latex = String(data: result.data, encoding: .utf8)!
        #expect(result.format == .latex)
        #expect(latex.contains("RhoeSection"))
    }

    @Test("CLI compiles to EPUB format")
    func cliCompileEPUB() async throws {
        let options = RhoeMD.Options(format: .epub)
        let result = try await RhoeMD.compileMarkdown("# Chapter\n\nContent.", options: options)
        #expect(result.format == .epub)
        #expect(!result.data.isEmpty)
        #expect(result.data[0] == 0x50) // PK
    }

    @Test("CLI benchmark metrics are populated")
    func cliBenchmarkMetrics() async throws {
        let options = RhoeMD.Options(benchmark: true)
        let result = try await RhoeMD.compileMarkdown("# Test\n\nHello.", options: options)
        #expect(result.metrics != nil)
        #expect(result.metrics!.parseTime > 0)
        #expect(result.metrics!.renderTime >= 0)
        #expect(result.metrics!.inputSize > 0)
        #expect(result.metrics!.outputSize > 0)
    }
}
