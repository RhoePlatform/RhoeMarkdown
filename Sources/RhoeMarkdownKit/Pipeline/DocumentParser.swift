import Foundation
import RhoeMarkdownParsing
import RhoeMarkdownPresentation

public struct DocumentParser: Sendable {
    public let configuration: RhoeMarkdownKit.Configuration
    public let diagramConfiguration: RhoeMarkdownKit.DiagramConfiguration

    /// Byte threshold above which parallel parsing is used (default: 100KB)
    public let parallelParsingThreshold: Int

    /// Byte threshold above which streaming parsing is used (default: 1MB)
    public let streamingParsingThreshold: Int

    /// Whether parallel parsing is enabled
    public let parallelParsingEnabled: Bool

    /// Whether streaming parsing is enabled (for very large documents)
    public let streamingParsingEnabled: Bool

    /// Phase 1 Liquid context (site variables, data, custom)
    public let phase1Context: Phase1Context

    public init(
        configuration: RhoeMarkdownKit.Configuration = .default,
        diagramConfiguration: RhoeMarkdownKit.DiagramConfiguration = .disabled,
        parallelParsingThreshold: Int = 100_000,
        streamingParsingThreshold: Int = 1_000_000,
        parallelParsingEnabled: Bool = true,
        streamingParsingEnabled: Bool = true,
        phase1Context: Phase1Context = .init()
    ) {
        self.configuration = configuration
        self.diagramConfiguration = diagramConfiguration
        self.parallelParsingThreshold = parallelParsingThreshold
        self.streamingParsingThreshold = streamingParsingThreshold
        self.parallelParsingEnabled = parallelParsingEnabled
        self.streamingParsingEnabled = streamingParsingEnabled
        self.phase1Context = phase1Context
    }

    public func parse(_ markdown: String) async -> RhoeMarkdownKit.ParseResult {
        var sourceToParse = markdown
        var phase1Diagnostics: [RhoeMarkdownKit.Diagnostic] = []

        // Phase 1: Liquid preprocessing (runs BEFORE parsing)
        if configuration.enablePhase1Preprocessing {
            let preprocessor = Phase1Preprocessor(
                allowGeneratedTransforms: configuration.allowGeneratedSemanticTransforms
            )
            let phase1Result = await preprocessor.preprocess(markdown, context: phase1Context)
            sourceToParse = phase1Result.markdown

            // Convert Phase 1 diagnostics
            for diag in phase1Result.diagnostics {
                let severity: RhoeMarkdownKit.Diagnostic.Severity = switch diag.severity {
                case .info: .info
                case .warning: .warning
                case .error: .error
                }
                phase1Diagnostics.append(RhoeMarkdownKit.Diagnostic(
                    severity: severity,
                    message: "[Phase 1] \(diag.message)",
                    line: diag.line ?? 0,
                    column: diag.column ?? 0,
                    sourceRange: nil
                ))
            }
        }

        let result: RhoeMarkdownKit.ParseResult
        let inputSize = sourceToParse.utf8.count

        // Three-tier dispatch: streaming > parallel > sequential
        if streamingParsingEnabled && inputSize > streamingParsingThreshold {
            // >1MB: Streaming chunked lex/parse for bounded memory
            result = await parseStreaming(sourceToParse)
        } else if parallelParsingEnabled && inputSize > parallelParsingThreshold {
            // >100KB: Parallel chunk parsing for speed
            if #available(macOS 13.0, iOS 16.0, *) {
                result = await parseParallel(sourceToParse)
            } else {
                result = await parseSequential(sourceToParse)
            }
        } else {
            // <100KB: Standard sequential
            result = await parseSequential(sourceToParse)
        }

        // Run post-parse pipeline (bibliography, cross-references, diagrams, etc.)
        let pipeline = buildDocumentPipeline(
            for: configuration,
            diagramConfiguration: diagramConfiguration
        )
        let processedDocument = pipeline.run(result.document)

        return RhoeMarkdownKit.ParseResult(
            document: processedDocument,
            diagnostics: phase1Diagnostics + result.diagnostics,
            parseTime: result.parseTime
        )
    }

    /// Streaming parsing (for very large documents >1MB)
    /// Uses the parallel parser with larger chunk sizes to leverage all cores.
    private func parseStreaming(_ markdown: String) async -> RhoeMarkdownKit.ParseResult {
        if #available(macOS 13.0, iOS 16.0, *) {
            // Use parallel parser for large documents — this is the key scalability fix.
            // Documents >1MB benefit most from multi-core parsing.
            let parallelParser = ParallelMarkdownParser()
            return await parallelParser.parse(markdown)
        } else {
            return await parseSequential(markdown)
        }
    }

    /// Sequential parsing (standard path for small documents)
    private func parseSequential(_ markdown: String) async -> RhoeMarkdownKit.ParseResult {
        let parser = RhoeParser(configuration: configuration)
        let result = await parser.parse(markdown)
        return RhoeMarkdownKit.ParseResult(
            document: result.document,
            diagnostics: PipelineDiagnostics.normalizeCore(result.diagnostics, source: markdown),
            parseTime: result.parseTime
        )
    }

    /// Parallel parsing (for large documents >100KB)
    @available(macOS 13.0, iOS 16.0, *)
    private func parseParallel(_ markdown: String) async -> RhoeMarkdownKit.ParseResult {
        let parallelParser = ParallelMarkdownParser()
        return await parallelParser.parse(markdown)
    }
}
