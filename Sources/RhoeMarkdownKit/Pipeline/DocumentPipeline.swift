import Foundation
import RhoeMarkdownModel

/// A single post-parse processing pass that transforms a document.
///
/// Passes run sequentially between parsing and rendering. Each pass
/// receives the document and can modify blocks, metadata, or resolved
/// references. Common passes include bibliography collection, citation
/// resolution, and cross-reference numbering.
public protocol DocumentPass: Sendable {
    /// Process the document, returning a new document with modifications.
    func process(_ document: RhoeMarkdownKit.Document) -> RhoeMarkdownKit.Document
}

/// Orchestrates a sequence of post-parse document processing passes.
///
/// The pipeline runs passes in order, feeding each pass's output
/// into the next. This enables multi-phase resolution where earlier
/// passes (e.g., bibliography collection) provide data that later
/// passes (e.g., citation resolution) consume.
public struct DocumentPipeline: Sendable {
    private let passes: [any DocumentPass]

    public init(passes: [any DocumentPass]) {
        self.passes = passes
    }

    /// Run all passes in sequence, returning the fully processed document.
    public func run(_ document: RhoeMarkdownKit.Document) -> RhoeMarkdownKit.Document {
        var result = document
        for pass in passes {
            result = pass.process(result)
        }
        return result
    }
}

/// Builds the document pipeline aligned with the 10-stage processing model.
/// defined in Ring 0, ch.04.
///
/// ## Stage Mapping
///
/// | Stage | Name | Passes |
/// |-------|------|--------|
/// | 0 | Metadata Prelude | (handled by parser: frontmatter extraction) |
/// | 1 | Phase 1 Preprocessing | (handled by Phase1Preprocessor before parsing) |
/// | 2 | Parsing | (handled by RhoeParser) |
/// | 3 | Structural Normalization | DisplayMathHoisting, StructuralNormalization, SectionHierarchy, TableNormalization, TransclusionResolution, ComponentExpansion |
/// | 4 | Phase 2 Planning | AttributeValidation, ExtensionResolution |
/// | 5 | Phase 2 Execution | Phase2Execution, Phase2Normalization |
/// | 6 | Semantic Normalization | Bibliography, Citation, CrossRefNumbering, CrossRefResolution, DiagramRendering |
/// | 7 | Canonical Semantic Freeze | CanonicalFreezeValidation (diagnostic-only) |
/// | 8 | Projection Normalization | ProjectionFiltering (applied at render time) |
/// | 9 | Target Emission | (handled by writers: HTML, LaTeX, Typst, DOCX, etc.) |
///
/// Stages 0-2 and 8-9 are handled outside this pipeline (by the parser and writers).
/// This function builds the Stage 3-7 pipeline.
public func buildDocumentPipeline(
    for configuration: RhoeMarkdownKit.Configuration,
    diagramConfiguration: RhoeMarkdownKit.DiagramConfiguration = .disabled,
    extensionRegistry: ExtensionRegistry = ExtensionRegistry()
) -> DocumentPipeline {
    var passes: [any DocumentPass] = []

    // ── Stage 3: Structural Normalization ──────────────────────────
    // Single merged pass combining display math hoisting, structural
    // normalization, section hierarchy, and table normalization into
    // one AST traversal (4x reduction in tree walks).

    passes.append(Stage3NormalizationPass())

    // TransclusionResolutionPass is async and requires a DocumentResolver;
    // it runs separately in DocumentParser when transclusions are enabled.
    if configuration.enableComponents {
        passes.append(ComponentExpansionPass())
    }

    // ── Stage 4: Phase 2 Planning and Validation ──────────────────
    // Validates attributes, resolves extensions, plans transforms.

    passes.append(AttributeValidationPass())
    passes.append(ExtensionResolutionPass(registry: extensionRegistry))

    // ── Stage 5: Phase 2 Execution ────────────────────────────────
    // Executes {@ @} semantic transforms and repairs structure.

    if configuration.enablePhase2Transforms {
        passes.append(Phase2ExecutionPass())
        passes.append(Phase2NormalizationPass())
    }

    // ── Stage 6: Semantic Normalization ───────────────────────────
    // Assigns numbering, resolves citations and cross-references,
    // renders diagrams.

    if configuration.enableCitations {
        passes.append(BibliographyCollectionPass())
        passes.append(CitationResolutionPass())
    }
    if configuration.enableCrossReferences {
        passes.append(CrossReferenceNumberingPass())
        passes.append(CrossReferenceResolutionPass())
    }
    if diagramConfiguration.enableDiagramRendering {
        passes.append(DiagramRenderingPass(configuration: diagramConfiguration))
    }

    // ── Stage 7: Canonical Semantic Freeze ────────────────────────
    // Validates that no pipeline-internal nodes survived normalization.
    // Diagnostic-only in debug builds; skipped in release for performance.

    #if DEBUG
    passes.append(CanonicalFreezeValidationPass())
    #endif

    // Stages 8 (projection normalization) and 9 (target emission) are
    // handled at render time by the projection filtering pass and writers.

    return DocumentPipeline(passes: passes)
}
