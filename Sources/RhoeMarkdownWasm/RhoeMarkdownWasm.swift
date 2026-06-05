import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// Wasm-compatible subset of the RhoeMarkdown engine.
///
/// Provides markdown parsing, Liquid template preprocessing, and multi-format
/// rendering (HTML, LaTeX, Typst, JSON) without platform-dependent features
/// (PDF, EPUB, DOCX, diagrams).
///
/// ## Supported Features
/// - CommonMark/GFM plus documented RhoeMarkdown extension parsing
/// - Phase 1 Liquid preprocessing (via RhoeLiquid — `{{ }}` variables, `{% %}` control flow)
/// - HTML rendering with CSS (complete, including admonitions, theorems, sections)
/// - LaTeX string output (no compilation)
/// - Typst string output (no compilation)
/// - RhoeJSON canonical serialization
/// - Six-bucket attribute model
/// - 10-stage processing pipeline (except diagram rendering)
///
/// ## Not Supported in Wasm
/// - PDF generation (requires WebKit or external tools)
/// - EPUB/DOCX generation (requires zip via Process)
/// - Diagram rendering (requires external binaries)
/// - File-based transclusion
///
/// ## Build for WebAssembly
/// ```bash
/// swift build --swift-sdk swift-6.3-RELEASE_wasm --target RhoeMarkdownWasm
/// ```
public struct RhoeMarkdownWasm: Sendable {

    /// Current public release version of the WebAssembly-facing API.
    public static let version = "0.1.1"

    // MARK: - Parse

    /// Parse markdown into a document AST.
    public static func parse(
        _ markdown: String,
        configuration: RhoeMarkdownKit.Configuration = .default
    ) async -> RhoeMarkdownKit.ParseResult {
        let parser = RhoeParser(configuration: configuration)
        return await parser.parse(markdown)
    }

    // MARK: - Render (from Document)

    /// Render a document to HTML.
    public static func renderHTML(
        _ document: RhoeMarkdownKit.Document,
        configuration: RhoeMarkdownKit.HTMLConfiguration = .init()
    ) -> String {
        var renderer = RhoeHTMLRenderer(configuration: configuration)
        return renderer.render(document)
    }

    /// Render a document to LaTeX.
    public static func renderLaTeX(
        _ document: RhoeMarkdownKit.Document,
        configuration: RhoeMarkdownKit.LaTeXConfiguration = .init()
    ) -> String {
        let writer = LaTeXWriter(configuration: configuration)
        return writer.write(document)
    }

    /// Render a document to Typst.
    public static func renderTypst(
        _ document: RhoeMarkdownKit.Document,
        configuration: RhoeMarkdownKit.TypstConfiguration = .init()
    ) -> String {
        let writer = TypstWriter(configuration: configuration)
        return writer.write(document)
    }

    /// Render a document to RhoeJSON canonical format.
    public static func renderJSON(_ document: RhoeMarkdownKit.Document) -> Data {
        let writer = JSONWriter()
        return writer.write(document)
    }

    // MARK: - Convenience (parse + render)

    /// Parse markdown and render to HTML.
    public static func toHTML(
        _ markdown: String,
        configuration: RhoeMarkdownKit.Configuration = .default
    ) async -> String {
        let result = await parse(markdown, configuration: configuration)
        return renderHTML(result.document)
    }

    /// Parse markdown and render to LaTeX.
    public static func toLaTeX(
        _ markdown: String,
        configuration: RhoeMarkdownKit.Configuration = .default
    ) async -> String {
        let result = await parse(markdown, configuration: configuration)
        return renderLaTeX(result.document)
    }

    /// Parse markdown and render to Typst.
    public static func toTypst(
        _ markdown: String,
        configuration: RhoeMarkdownKit.Configuration = .default
    ) async -> String {
        let result = await parse(markdown, configuration: configuration)
        return renderTypst(result.document)
    }

    /// Parse markdown and serialize to RhoeJSON.
    public static func toJSON(
        _ markdown: String,
        configuration: RhoeMarkdownKit.Configuration = .default
    ) async -> Data {
        let result = await parse(markdown, configuration: configuration)
        return renderJSON(result.document)
    }

    // MARK: - Phase 1 Liquid Preprocessing

    /// Parse markdown with Phase 1 Liquid preprocessing.
    ///
    /// Runs the RhoeLiquid template engine on the markdown source before parsing,
    /// resolving `{{ variable }}` interpolation and `{% control %}` flow.
    ///
    /// - Parameters:
    ///   - markdown: Markdown source with optional Liquid template syntax
    ///   - context: Liquid template variables (available as `{{ key }}` in templates)
    ///   - site: Site-level Liquid scope exposed as `site`
    ///   - data: Data-file Liquid scope exposed as `data`
    ///   - configuration: Parser configuration
    /// - Returns: ParseResult with the fully processed document
    public static func parseWithLiquid(
        _ markdown: String,
        context: [String: Any] = [:],
        site: [String: Any] = [:],
        data: [String: Any] = [:],
        configuration: RhoeMarkdownKit.Configuration = .default
    ) async -> RhoeMarkdownKit.ParseResult {
        // Phase 1: Liquid preprocessing
        let preprocessor = WasmPhase1Preprocessor(
            allowGeneratedTransforms: configuration.allowGeneratedSemanticTransforms
        )
        let phase1Result = await preprocessor.preprocess(markdown, context: context, site: site, data: data)

        // Phase 2+: Standard parsing
        let parseResult = await parse(phase1Result.markdown, configuration: configuration)

        // Merge Phase 1 diagnostics into parse result
        // Messages starting with "[Phase 1] Liquid preprocessing failed" are errors; others are warnings
        let phase1Diagnostics = phase1Result.diagnostics.map {
            RhoeMarkdownKit.Diagnostic(
                severity: $0.contains("failed") ? .error : .warning,
                message: $0
            )
        }

        return RhoeMarkdownKit.ParseResult(
            document: parseResult.document,
            diagnostics: phase1Diagnostics + parseResult.diagnostics,
            parseTime: phase1Result.preprocessingTime + parseResult.parseTime
        )
    }

    /// Parse markdown with Liquid preprocessing and render to HTML.
    public static func toHTMLWithLiquid(
        _ markdown: String,
        context: [String: Any] = [:],
        configuration: RhoeMarkdownKit.Configuration = .default
    ) async -> String {
        let result = await parseWithLiquid(markdown, context: context, configuration: configuration)
        return renderHTML(result.document)
    }

    /// Parse markdown with Liquid preprocessing and render to LaTeX.
    public static func toLaTeXWithLiquid(
        _ markdown: String,
        context: [String: Any] = [:],
        configuration: RhoeMarkdownKit.Configuration = .default
    ) async -> String {
        let result = await parseWithLiquid(markdown, context: context, configuration: configuration)
        return renderLaTeX(result.document)
    }

    /// Parse markdown with Liquid preprocessing and render to Typst.
    public static func toTypstWithLiquid(
        _ markdown: String,
        context: [String: Any] = [:],
        configuration: RhoeMarkdownKit.Configuration = .default
    ) async -> String {
        let result = await parseWithLiquid(markdown, context: context, configuration: configuration)
        return renderTypst(result.document)
    }

    /// Parse markdown with Liquid preprocessing and serialize to RhoeJSON.
    public static func toJSONWithLiquid(
        _ markdown: String,
        context: [String: Any] = [:],
        configuration: RhoeMarkdownKit.Configuration = .default
    ) async -> Data {
        let result = await parseWithLiquid(markdown, context: context, configuration: configuration)
        return renderJSON(result.document)
    }
}
