import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// Live-preview engine for near-instant document re-rendering during editing.
///
/// Maintains state across edits: previous document, render cache, and structural
/// fingerprint. Uses a two-tier dispatch strategy:
///
/// - **Fast path** (~95% of edits): Non-structural changes (paragraph text, inline edits).
///   Runs only Stage 3 normalization, skips bibliography/citation/cross-ref passes.
///   Renders with block-level cache (95%+ hit rate). Target: <20ms.
///
/// - **Slow path** (~5% of edits): Structural changes (add/remove headings, change sections).
///   Runs full 10-stage pipeline. Invalidates render cache. Target: <100ms.
///
/// ## Usage
///
/// ```swift
/// let engine = LivePreviewEngine()
///
/// // Initial render
/// let (html, metrics) = await engine.update(markdown)
///
/// // After user edits a paragraph...
/// let (newHTML, editMetrics) = await engine.update(editedMarkdown)
/// print("Latency: \(editMetrics.totalTime * 1000)ms, cache hit: \(editMetrics.cacheHitRate)")
/// ```
public actor LivePreviewEngine {

    // MARK: - State (persisted across edits)

    /// Previous parsed document (for structural comparison).
    private var previousDocument: RhoeMarkdownKit.Document?

    /// Block-level render cache (FNV-1a hash-keyed).
    private var renderCache: RenderCache

    /// Structural fingerprint of previous document.
    private var previousHeadingSignature: [HeadingSignature] = []

    /// Cached metadata from previous full pipeline run.
    private var cachedMetadata: RhoeMarkdownKit.DocumentMetadata?

    // MARK: - Configuration

    private let parserConfiguration: RhoeMarkdownKit.Configuration
    private let htmlConfiguration: RhoeMarkdownKit.HTMLConfiguration

    // MARK: - Metrics

    /// Metrics from the most recent edit cycle.
    public struct EditMetrics: Sendable {
        /// Time spent parsing the markdown source.
        public let parseTime: TimeInterval
        /// Time spent in pipeline passes.
        public let pipelineTime: TimeInterval
        /// Time spent rendering HTML (with cache).
        public let renderTime: TimeInterval
        /// Total wall-clock time from edit to HTML.
        public let totalTime: TimeInterval
        /// Block-level render cache hit rate (0.0 to 1.0).
        public let cacheHitRate: Double
        /// Whether the fast path was used (true) or full pipeline (false).
        public let usedFastPath: Bool
        /// Number of top-level blocks in the document.
        public let blockCount: Int
    }

    // MARK: - Initialization

    public init(
        configuration: RhoeMarkdownKit.Configuration = .default,
        htmlConfiguration: RhoeMarkdownKit.HTMLConfiguration = .init()
    ) {
        self.parserConfiguration = configuration
        self.htmlConfiguration = htmlConfiguration
        self.renderCache = RenderCache()
    }

    // MARK: - Main Entry Point

    /// Process a document edit and return updated HTML with performance metrics.
    ///
    /// Call this on every edit (keystroke, paste, etc.). The engine automatically
    /// detects whether the edit is structural (heading changes) or non-structural
    /// (paragraph/inline changes) and dispatches to the appropriate path.
    ///
    /// - Parameter markdown: The full markdown source after the edit
    /// - Returns: Tuple of rendered HTML and performance metrics
    public func update(_ markdown: String) async -> (html: String, metrics: EditMetrics) {
        let totalStart = Date().timeIntervalSinceReferenceDate

        // Phase 1: Parse (full re-parse, parallel for large documents)
        let parseStart = Date().timeIntervalSinceReferenceDate
        let parser = DocumentParser(configuration: parserConfiguration)
        let parseResult = await parser.parseOnly(markdown)
        let parseTime = Date().timeIntervalSinceReferenceDate - parseStart

        // Phase 2: Detect structural change
        let structuralChange = detectStructuralChange(parseResult.document)

        // Phase 3: Pipeline (fast or slow path)
        let pipelineStart = Date().timeIntervalSinceReferenceDate
        let processedDocument: RhoeMarkdownKit.Document

        if structuralChange || previousDocument == nil {
            // SLOW PATH: Full pipeline + cache invalidation
            processedDocument = fullPipeline(parseResult.document)
            renderCache.clear()
            cachedMetadata = processedDocument.metadata
        } else {
            // FAST PATH: Stage 3 normalization only, reuse cached metadata
            processedDocument = fastPipeline(parseResult.document)
        }
        let pipelineTime = Date().timeIntervalSinceReferenceDate - pipelineStart

        // Phase 4: Render with cache
        let renderStart = Date().timeIntervalSinceReferenceDate
        let renderer = HTMLRenderer(configuration: htmlConfiguration)
        let (html, hitRate) = renderer.renderCached(processedDocument, cache: &renderCache)
        let renderTime = Date().timeIntervalSinceReferenceDate - renderStart

        // Update state for next edit
        previousDocument = processedDocument

        let totalTime = Date().timeIntervalSinceReferenceDate - totalStart

        let metrics = EditMetrics(
            parseTime: parseTime,
            pipelineTime: pipelineTime,
            renderTime: renderTime,
            totalTime: totalTime,
            cacheHitRate: hitRate,
            usedFastPath: !structuralChange && previousDocument != nil,
            blockCount: processedDocument.blocks.count
        )

        return (html: html, metrics: metrics)
    }

    /// Reset all cached state (call when switching documents).
    public func reset() {
        previousDocument = nil
        renderCache.clear()
        previousHeadingSignature = []
        cachedMetadata = nil
    }

    /// Get the current render cache statistics.
    public var cacheStats: (entries: Int, hitRate: Double) {
        (entries: renderCache.count, hitRate: renderCache.hitRate)
    }

    // MARK: - Structural Change Detection

    /// Lightweight heading signature for structural change detection.
    private struct HeadingSignature: Equatable {
        let level: Int
        let titleHash: Int
    }

    /// Detect whether the document structure changed (heading count/titles).
    /// O(n) scan of top-level blocks, but very fast (no rendering).
    private func detectStructuralChange(_ newDocument: RhoeMarkdownKit.Document) -> Bool {
        let newSignature = extractHeadingSignature(newDocument.blocks)
        let changed = newSignature != previousHeadingSignature
        previousHeadingSignature = newSignature
        return changed
    }

    /// Extract a lightweight heading signature from a block sequence.
    private func extractHeadingSignature(_ blocks: [Block]) -> [HeadingSignature] {
        var signatures: [HeadingSignature] = []
        for block in blocks {
            switch block {
            case .heading(let level, let content, _):
                let titleHash = content.map { String(describing: $0) }.joined().hashValue
                signatures.append(HeadingSignature(level: level, titleHash: titleHash))
            case .section(let level, let title, let children, _):
                let titleHash = title.map { String(describing: $0) }.joined().hashValue
                signatures.append(HeadingSignature(level: level, titleHash: titleHash))
                // Recurse into section children for nested headings
                signatures.append(contentsOf: extractHeadingSignature(children))
            default:
                break
            }
        }
        return signatures
    }

    // MARK: - Pipeline Dispatch

    /// Fast pipeline: only Stage 3 normalization (for non-structural edits).
    /// Skips bibliography, citation, cross-reference, Phase 2, and extension passes.
    private func fastPipeline(_ document: RhoeMarkdownKit.Document) -> RhoeMarkdownKit.Document {
        let passes: [any DocumentPass] = [Stage3NormalizationPass()]
        let pipeline = DocumentPipeline(passes: passes)
        var result = pipeline.run(document)

        // Reuse cached metadata from last full pipeline run (cross-ref numbers, bibliography)
        if let cached = cachedMetadata {
            var metadata = result.metadata
            metadata.resolvedReferences = cached.resolvedReferences
            result = RhoeMarkdownKit.Document(blocks: result.blocks, metadata: metadata)
        }

        return result
    }

    /// Full pipeline: all stages (for structural changes or first render).
    private func fullPipeline(_ document: RhoeMarkdownKit.Document) -> RhoeMarkdownKit.Document {
        let pipeline = buildDocumentPipeline(for: parserConfiguration)
        return pipeline.run(document)
    }
}

// MARK: - DocumentParser Extension for Parse-Only

extension DocumentParser {
    /// Parse without running the post-parse pipeline.
    /// Used by LivePreviewEngine which runs its own pipeline dispatch.
    func parseOnly(_ markdown: String) async -> RhoeMarkdownKit.ParseResult {
        var sourceToParse = markdown

        // Phase 1: Liquid preprocessing (if enabled)
        if configuration.enablePhase1Preprocessing {
            let preprocessor = Phase1Preprocessor(
                allowGeneratedTransforms: configuration.allowGeneratedSemanticTransforms
            )
            let phase1Result = await preprocessor.preprocess(markdown, context: phase1Context)
            sourceToParse = phase1Result.markdown
        }

        // Three-tier dispatch (same as parse(), but no pipeline)
        let inputSize = sourceToParse.utf8.count

        if streamingParsingEnabled && inputSize > streamingParsingThreshold {
            if #available(macOS 13.0, iOS 16.0, *) {
                let parallelParser = ParallelMarkdownParser()
                return await parallelParser.parse(sourceToParse)
            } else {
                return await parseSequentialOnly(sourceToParse)
            }
        } else if parallelParsingEnabled && inputSize > parallelParsingThreshold {
            if #available(macOS 13.0, iOS 16.0, *) {
                let parallelParser = ParallelMarkdownParser()
                return await parallelParser.parse(sourceToParse)
            } else {
                return await parseSequentialOnly(sourceToParse)
            }
        } else {
            return await parseSequentialOnly(sourceToParse)
        }
    }

    /// Sequential parse without pipeline.
    private func parseSequentialOnly(_ markdown: String) async -> RhoeMarkdownKit.ParseResult {
        let parser = RhoeParser(configuration: configuration)
        return await parser.parse(markdown)
    }
}
