import Foundation
import RhoeMarkdownModel
import RhoeDSLParsing

/// Parses RhoeDSL source through the full document pipeline.
///
/// Produces the same `ParseResult` as the classic `DocumentParser`,
/// running the identical post-parse pipeline (numbering, Phase 2,
/// projection filtering, etc.) on the canonical AST.
public struct DSLDocumentParser: Sendable {
    public let configuration: RhoeMarkdownKit.Configuration
    public let diagramConfiguration: RhoeMarkdownKit.DiagramConfiguration
    public let extensionRegistry: ExtensionRegistry

    public init(
        configuration: RhoeMarkdownKit.Configuration = .default,
        diagramConfiguration: RhoeMarkdownKit.DiagramConfiguration = .disabled,
        extensionRegistry: ExtensionRegistry = ExtensionRegistry()
    ) {
        self.configuration = configuration
        self.diagramConfiguration = diagramConfiguration
        self.extensionRegistry = extensionRegistry
    }

    public func parse(_ dsl: String) async -> RhoeMarkdownKit.ParseResult {
        let startTime = Date().timeIntervalSinceReferenceDate

        // Parse DSL into AST blocks
        let parser = RhoeDSLParser(configuration: configuration)
        let (blocks, dslDiagnostics) = parser.parse(dsl)

        let document = RhoeMarkdownKit.Document(blocks: blocks)

        // Run the same post-parse pipeline as classic Markdown
        let pipeline = buildDocumentPipeline(
            for: configuration,
            diagramConfiguration: diagramConfiguration,
            extensionRegistry: extensionRegistry
        )
        let processedDocument = pipeline.run(document)

        let parseTime = Date().timeIntervalSinceReferenceDate - startTime

        // Convert DSL diagnostics to kit diagnostics
        let diagnostics: [RhoeMarkdownKit.Diagnostic] = dslDiagnostics.map { diag in
            RhoeMarkdownKit.Diagnostic(
                severity: .warning,
                message: diag.message,
                line: diag.line,
                column: diag.column,
                sourceRange: nil
            )
        }

        return RhoeMarkdownKit.ParseResult(
            document: processedDocument,
            diagnostics: diagnostics,
            parseTime: parseTime
        )
    }
}
