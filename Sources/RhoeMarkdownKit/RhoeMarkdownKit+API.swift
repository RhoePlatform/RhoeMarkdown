import Foundation
import RhoeLoggingKit
import RhoeDSLParsing
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownPresentation
import RhoeMarkdownRendering

/// Errors from the RhoeMarkdownKit public API.
public enum RhoeMarkdownError: Error, LocalizedError, Sendable {
    /// A file output path could not be opened by the caller.
    case cannotOpenFile(String)

    /// User-facing error message.
    public var errorDescription: String? {
        switch self {
        case .cannotOpenFile(let path): return "Cannot open file for writing: \(path)"
        }
    }
}

public extension RhoeMarkdownKit {
    private static var logger: RhoeLogger { RhoeLogger.shared }
    private static var logCategory: LogCategory {
        LogCategory(name: "Core", subsystem: "RhoeMarkdownKit")
    }

    /// Initialize shared resources and warm parser caches for long-lived processes.
    static func initialize() async throws {
        logger.info("Initializing RhoeMarkdownKit \(version)", category: logCategory)
        configurePerformanceMonitoring()
        preloadResources()
        await warmupParsers()
        logger.info("RhoeMarkdownKit initialized successfully", category: logCategory)
    }

    /// Parse Markdown using the default RhoeMarkdown configuration.
    static func parse(_ markdown: String) async -> ParseResult {
        await DocumentParser().parse(markdown)
    }

    /// Parse Markdown using an explicit parser configuration.
    static func parse(_ markdown: String, configuration: Configuration) async -> ParseResult {
        await DocumentParser(configuration: configuration).parse(markdown)
    }

    /// Parse Markdown using explicit parser and diagram-rendering configuration.
    static func parse(
        _ markdown: String,
        configuration: Configuration,
        diagramConfiguration: DiagramConfiguration
    ) async -> ParseResult {
        await DocumentParser(
            configuration: configuration,
            diagramConfiguration: diagramConfiguration
        ).parse(markdown)
    }

    /// Render a parsed document to HTML.
    static func renderHTML(
        _ document: Document,
        configuration: HTMLConfiguration = .default
    ) -> String {
        HTMLRenderer(configuration: configuration).render(document)
    }

    /// Return runtime performance statistics collected by the shared monitor.
    @MainActor
    static func getPerformanceStatistics() -> PerformanceStatistics {
        PerformanceMonitor.shared.getStatistics()
    }

    /// Export all collected performance metrics as pretty-printed JSON.
    @MainActor
    static func exportPerformanceMetrics() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(PerformanceMonitor.shared.getAllMetrics())
    }

    /// Parse Markdown with the default configuration and render HTML.
    static func toHTML(_ markdown: String) async -> String {
        let result = await parse(markdown)
        return renderHTML(result.document)
    }

    /// Render a parsed document to LaTeX.
    static func renderLaTeX(
        _ document: Document,
        configuration: LaTeXConfiguration = .default
    ) -> String {
        LaTeXRenderer(configuration: configuration).render(document)
    }

    /// Parse Markdown with the default configuration and render LaTeX.
    static func toLaTeX(_ markdown: String) async -> String {
        let result = await parse(markdown)
        return renderLaTeX(result.document)
    }

    /// Render a parsed document to Typst.
    static func renderTypst(
        _ document: Document,
        configuration: TypstConfiguration = .default
    ) -> String {
        TypstRenderer(configuration: configuration).render(document)
    }

    /// Parse Markdown with the default configuration and render Typst.
    static func toTypst(_ markdown: String) async -> String {
        let result = await parse(markdown)
        return renderTypst(result.document)
    }

    /// Render a parsed document to DOCX bytes.
    static func renderDOCX(
        _ document: Document,
        configuration: DOCXConfiguration = .default
    ) -> Data {
        DOCXRenderer(configuration: configuration).render(document)
    }

    /// Parse Markdown with the default configuration and render DOCX bytes.
    static func toDOCX(_ markdown: String) async -> Data {
        let result = await parse(markdown)
        return renderDOCX(result.document)
    }

    /// Render a document to PDF using the configured pipeline.
    ///
    /// The synchronous version uses Typst or LaTeX external compilers.
    /// For native WebKit rendering on Apple platforms, use ``renderPDFAsync(_:configuration:)`` instead.
    ///
    /// - Parameters:
    ///   - document: The parsed document to render.
    ///   - configuration: PDF generation options (pipeline, paper size, page selection).
    /// - Returns: PDF data, or empty `Data` if the compilation tool is unavailable.
    static func renderPDF(
        _ document: Document,
        configuration: PDFConfiguration = .default
    ) -> Data {
        PDFRenderer(configuration: configuration).render(document)
    }

    /// Render a document to PDF asynchronously, using WebKit on Apple platforms.
    ///
    /// This is the preferred PDF rendering method. On macOS/iOS/visionOS, it uses
    /// the HTML→WebKit→PDF pipeline for native, high-fidelity rendering with full
    /// CSS support. On other platforms, it falls back to Typst or LaTeX compilers.
    ///
    /// - Parameters:
    ///   - document: The parsed document to render.
    ///   - configuration: PDF generation options (pipeline, paper size, page selection).
    /// - Returns: PDF data.
    @MainActor
    static func renderPDFAsync(
        _ document: Document,
        configuration: PDFConfiguration = .default
    ) async -> Data {
        await PDFWriter(configuration: configuration).writeAsync(document)
    }

    /// Render a single page/slide of a document to PDF.
    ///
    /// For presentation documents with `%%%` slide syntax, this renders only the
    /// specified slide (1-based index) as a single-page landscape PDF.
    ///
    /// - Parameters:
    ///   - document: The parsed document to render.
    ///   - page: The 1-based page number to render.
    /// - Returns: PDF data for the specified page.
    @MainActor
    static func renderPDFAsync(
        _ document: Document,
        page: Int
    ) async -> Data {
        let config = PDFConfiguration(page: page)
        return await PDFWriter(configuration: config).writeAsync(document)
    }

    /// Render a range of pages/slides of a document to PDF.
    ///
    /// For presentation documents, this renders slides `fromPage` through `toPage`
    /// (inclusive, 1-based) as a multi-page landscape PDF.
    ///
    /// - Parameters:
    ///   - document: The parsed document to render.
    ///   - fromPage: The 1-based start page (inclusive).
    ///   - toPage: The 1-based end page (inclusive).
    /// - Returns: PDF data for the specified page range.
    @MainActor
    static func renderPDFAsync(
        _ document: Document,
        fromPage: Int,
        toPage: Int
    ) async -> Data {
        let config = PDFConfiguration(fromPage: fromPage, toPage: toPage)
        return await PDFWriter(configuration: config).writeAsync(document)
    }

    /// Parse markdown and render to PDF in one step.
    ///
    /// Uses the async WebKit pipeline on Apple platforms for native rendering.
    /// Falls back to Typst or LaTeX on other platforms.
    ///
    /// - Parameter markdown: The markdown source to render.
    /// - Returns: PDF data.
    @MainActor
    static func toPDF(_ markdown: String) async -> Data {
        let result = await parse(markdown)
        return await renderPDFAsync(result.document)
    }

    /// Render a parsed document to EPUB bytes.
    static func renderEPUB(
        _ document: Document,
        configuration: EPUBConfiguration = .default
    ) -> Data {
        EPUBRenderer(configuration: configuration).render(document)
    }

    /// Parse Markdown with the default configuration and render EPUB bytes.
    static func toEPUB(_ markdown: String) async -> Data {
        let result = await parse(markdown)
        return renderEPUB(result.document)
    }

    /// Render a parsed document to canonical JSON bytes.
    static func renderJSON(_ document: Document) -> Data {
        JSONRenderer().render(document)
    }

    /// Parse Markdown with the default configuration and render canonical JSON bytes.
    static func toJSON(_ markdown: String) async -> Data {
        let result = await parse(markdown)
        return renderJSON(result.document)
    }

    /// Render a document to the specified output format.
    ///
    /// Returns the rendered output as `Data`. For text formats (HTML, LaTeX, Typst),
    /// the data is UTF-8 encoded. For binary formats (DOCX, PDF, EPUB),
    /// the data is the raw binary output.
    static func render(_ document: Document, format: OutputFormat) -> Data {
        switch format {
        case .html:
            return Data(renderHTML(document).utf8)
        case .latex:
            return Data(renderLaTeX(document).utf8)
        case .typst:
            return Data(renderTypst(document).utf8)
        case .docx:
            return renderDOCX(document)
        case .pdf:
            return renderPDF(document)
        case .epub:
            return renderEPUB(document)
        }
    }

    /// Parse markdown and render to the specified output format in one step.
    static func convert(_ markdown: String, format: OutputFormat) async -> Data {
        let result = await parse(markdown)
        return render(result.document, format: format)
    }

    // MARK: - Streaming Output

    /// Render HTML as an async stream of fragments for progressive output.
    ///
    /// Each yielded string is one rendered block element. Ideal for:
    /// - Writing large documents to files without holding all HTML in memory
    /// - Streaming HTTP responses
    /// - Progressive rendering in editors
    static func renderHTMLStream(_ document: Document) -> AsyncStream<String> {
        let html = renderHTML(document)
        return AsyncStream { continuation in
            continuation.yield(html)
            continuation.finish()
        }
    }

    /// Parse markdown and render HTML as an async stream (one-step streaming).
    static func convertHTMLStream(_ markdown: String) async -> AsyncStream<String> {
        let result = await parse(markdown)
        return renderHTMLStream(result.document)
    }

    /// Parse and write output directly to a file for maximum efficiency.
    ///
    /// For large documents, this avoids holding both the AST and the rendered
    /// output in memory simultaneously — blocks are rendered and written
    /// one at a time.
    static func renderToFile(
        _ markdown: String,
        outputURL: URL,
        format: OutputFormat = .html
    ) async throws {
        let result = await parse(markdown)

        if format == .html {
            // Fall back to a single-pass HTML render until the streaming HTML
            // renderer is exported cleanly through dependency builds.
            let html = renderHTML(result.document)
            try html.write(to: outputURL, atomically: true, encoding: .utf8)
        } else {
            // Other formats: render to Data, write once
            let data = render(result.document, format: format)
            try data.write(to: outputURL)
        }
    }

    // MARK: - RhoeDSL

    /// Parse RhoeDSL source into the canonical AST with full pipeline processing.
    static func parseDSL(_ dsl: String) async -> ParseResult {
        await DSLDocumentParser().parse(dsl)
    }

    /// Parse RhoeDSL source with custom configuration.
    static func parseDSL(_ dsl: String, configuration: Configuration) async -> ParseResult {
        await DSLDocumentParser(configuration: configuration).parse(dsl)
    }

    /// Parse RhoeDSL and render to HTML in one step.
    static func dslToHTML(_ dsl: String) async -> String {
        let result = await parseDSL(dsl)
        return renderHTML(result.document)
    }

    /// Convert a document AST to RhoeDSL source text.
    static func toRhoeDSL(_ document: Document) -> String {
        MarkdownToDSLConverter().convert(document)
    }

    /// Convert a document AST to RhoeMarkdown source text.
    static func toRhoeMarkdown(_ document: Document) -> String {
        DSLToMarkdownConverter().convert(document)
    }

    /// Round-trip: parse Markdown, emit as DSL.
    static func markdownToDSL(_ markdown: String) async -> String {
        let result = await parse(markdown)
        return toRhoeDSL(result.document)
    }

    /// Round-trip: parse DSL, emit as Markdown.
    static func dslToMarkdown(_ dsl: String) async -> String {
        let result = await parseDSL(dsl)
        return toRhoeMarkdown(result.document)
    }

    /// Parse Markdown and return diagnostics without rendering.
    static func validate(_ markdown: String) async -> [Diagnostic] {
        let result = await parse(markdown)
        return result.diagnostics
    }

    /// Parse Markdown and return computed document metadata.
    static func statistics(_ markdown: String) async -> DocumentMetadata {
        let result = await parse(markdown)
        return result.document.metadata
    }

    private static func configurePerformanceMonitoring() {
        PerformanceMonitor.shared.configure(
            warningThresholds: PerformanceThresholds(
                cpuUsage: 0.8,
                memoryUsage: 0.7,
                executionTime: 1.0
            ),
            enableSIMDOptimization: true,
            enableBenchmarking: true
        )
        logger.debug("Performance monitoring configured", category: logCategory)
    }

    private static func preloadResources() {
        let resourceManager = ResourceManager.shared
        _ = resourceManager.availableIcons(for: .lucide)
        _ = resourceManager.availableIcons(for: .fluent)
        _ = resourceManager.getEmoji(for: "rocket")
        logger.debug("Critical resources preloaded", category: logCategory)
    }

    private static func warmupParsers() async {
        _ = await DocumentParser().parse("# Warmup\n\nThis is **warmup** content.")
        logger.debug("Parsers warmed up", category: logCategory)
    }
}
