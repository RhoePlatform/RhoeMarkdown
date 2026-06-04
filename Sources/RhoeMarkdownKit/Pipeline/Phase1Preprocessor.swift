import Foundation
import RhoeMarkdownModel
import RhoeLiquid
import LiquidCore

/// Phase 1 Liquid preprocessor for RhoeMarkdown.
///
/// Runs the RhoeLiquid template engine on markdown source BEFORE parsing.
/// Resolves `{{ }}` value interpolation and `{% %}` control flow.
/// Output is pure RhoeMarkdown text with no Liquid syntax remaining.
///
/// Phase 1 is text-in, text-out. It has no access to the AST (which doesn't exist yet).
public struct Phase1Preprocessor: Sendable {
    private let engine: LiquidEngine
    private let allowGeneratedTransforms: Bool

    public init(
        configuration: LiquidConfiguration = .default,
        allowGeneratedTransforms: Bool = false
    ) {
        self.engine = LiquidEngine(configuration: configuration)
        self.allowGeneratedTransforms = allowGeneratedTransforms
    }

    /// Preprocess markdown source through the Liquid engine.
    ///
    /// 1. Extracts frontmatter (not Liquid-processed)
    /// 2. Builds context from frontmatter + provided context
    /// 3. Runs Liquid engine on the body
    /// 4. Validates generated transform gateway
    /// 5. Reassembles frontmatter + preprocessed body
    public func preprocess(
        _ markdown: String,
        context: Phase1Context = .init()
    ) async -> Phase1Result {
        let startTime = Date().timeIntervalSinceReferenceDate
        var diagnostics: [Phase1Diagnostic] = []

        // 1. Extract frontmatter (preserved literally — not Liquid-processed)
        let (frontmatter, body) = extractFrontmatter(markdown)

        // 2. Build Liquid context
        var liquidContext: [String: Any] = context.custom

        // page.* namespace from frontmatter
        if let fm = frontmatter {
            var pageVars: [String: Any] = [:]
            for (key, value) in fm {
                pageVars[key] = value.liquidValue
            }
            liquidContext["page"] = pageVars
        }

        // site.* namespace from project context
        if !context.site.isEmpty {
            liquidContext["site"] = context.site
        }

        // data.* namespace from _data directory
        if !context.data.isEmpty {
            liquidContext["data"] = context.data
        }

        // 3. Run Liquid engine
        let preprocessedBody: String
        do {
            preprocessedBody = try await engine.render(template: body, context: liquidContext)
        } catch {
            // Liquid errors → diagnostic, fall back to original body
            diagnostics.append(Phase1Diagnostic(
                severity: .error,
                message: "Liquid preprocessing failed: \(error.localizedDescription)",
                line: nil,
                column: nil
            ))
            let elapsed = Date().timeIntervalSinceReferenceDate - startTime
            return Phase1Result(
                markdown: markdown, // Return original unchanged
                frontmatter: frontmatter,
                diagnostics: diagnostics,
                preprocessingTime: elapsed,
                hasGeneratedTransforms: false
            )
        }

        // 4. Validate generated transform gateway
        let hasGeneratedTransforms = preprocessedBody.contains("{@") && preprocessedBody.contains("@}")
        if hasGeneratedTransforms && !allowGeneratedTransforms {
            diagnostics.append(Phase1Diagnostic(
                severity: .error,
                message: "Phase 2 directives ({@ @}) found in Phase 1 output. Enable allowGeneratedSemanticTransforms or use {% transform %} gateway.",
                line: nil,
                column: nil
            ))
        } else if hasGeneratedTransforms {
            diagnostics.append(Phase1Diagnostic(
                severity: .info,
                message: "Generated semantic transforms detected in Phase 1 output.",
                line: nil,
                column: nil
            ))
        }

        // 5. Reassemble: frontmatter + preprocessed body
        let reassembled: String
        if frontmatter != nil {
            // Reconstruct frontmatter block from original source (preserve literally)
            let originalFrontmatterBlock = extractFrontmatterBlock(markdown)
            reassembled = originalFrontmatterBlock + preprocessedBody
        } else {
            reassembled = preprocessedBody
        }

        let elapsed = Date().timeIntervalSinceReferenceDate - startTime
        return Phase1Result(
            markdown: reassembled,
            frontmatter: frontmatter,
            diagnostics: diagnostics,
            preprocessingTime: elapsed,
            hasGeneratedTransforms: hasGeneratedTransforms
        )
    }

    // MARK: - Frontmatter Extraction

    /// Extract frontmatter dictionary and body from markdown.
    private func extractFrontmatter(_ markdown: String) -> ([String: RhoeMarkdownKit.YAMLValue]?, String) {
        guard markdown.hasPrefix("---\n") || markdown.hasPrefix("---\r\n") else {
            return (nil, markdown)
        }

        let content = String(markdown.dropFirst(4)) // Drop "---\n"
        guard let endRange = content.range(of: "\n---\n") ?? content.range(of: "\n---\r\n") else {
            return (nil, markdown)
        }

        let yamlString = String(content[content.startIndex..<endRange.lowerBound])
        let body = String(content[content.index(endRange.upperBound, offsetBy: 0)...])

        // Parse YAML using existing parser
        let parser = RhoeMarkdownParsing.RhoeParser()
        let yamlDict = parser.parseYAMLContent(yamlString)

        return (yamlDict, body)
    }

    /// Extract the raw frontmatter block (including delimiters) for literal preservation.
    private func extractFrontmatterBlock(_ markdown: String) -> String {
        guard markdown.hasPrefix("---\n") || markdown.hasPrefix("---\r\n") else {
            return ""
        }

        let content = String(markdown.dropFirst(4))
        if let endRange = content.range(of: "\n---\n") {
            let endIdx = content.index(endRange.upperBound, offsetBy: 0)
            return "---\n" + String(content[content.startIndex..<endIdx])
        }
        if let endRange = content.range(of: "\n---\r\n") {
            let endIdx = content.index(endRange.upperBound, offsetBy: 0)
            return "---\n" + String(content[content.startIndex..<endIdx])
        }
        return ""
    }
}

// MARK: - Phase 1 Context

/// Context for Phase 1 Liquid preprocessing.
///
/// Contains variables available to Liquid templates organized by namespace:
/// - `site.*` — project-level configuration
/// - `page.*` — document frontmatter (auto-populated)
/// - `data.*` — loaded data files from `_data/` directory
/// - `custom` — arbitrary additional variables
public struct Phase1Context: @unchecked Sendable {
    public let site: [String: Any]
    public let data: [String: Any]
    public let custom: [String: Any]

    public init(
        site: [String: Any] = [:],
        data: [String: Any] = [:],
        custom: [String: Any] = [:]
    ) {
        self.site = site
        self.data = data
        self.custom = custom
    }
}

// MARK: - Phase 1 Result

/// Result from Phase 1 Liquid preprocessing.
public struct Phase1Result: Sendable {
    /// The preprocessed markdown (pure RhoeMarkdown, no Liquid syntax).
    public let markdown: String
    /// Extracted frontmatter (from original source, before Liquid).
    public let frontmatter: [String: RhoeMarkdownKit.YAMLValue]?
    /// Diagnostics from preprocessing.
    public let diagnostics: [Phase1Diagnostic]
    /// Time spent in preprocessing.
    public let preprocessingTime: TimeInterval
    /// Whether generated semantic transforms were detected.
    public let hasGeneratedTransforms: Bool
}

// MARK: - Phase 1 Diagnostic

/// A diagnostic message from Phase 1 preprocessing.
public struct Phase1Diagnostic: Sendable {
    public enum Severity: String, Sendable {
        case info, warning, error
    }

    public let severity: Severity
    public let message: String
    public let line: Int?
    public let column: Int?
}

// liquidValue is defined on RhoeMarkdownKit.YAMLValue in RhoeMarkdownModel
// (single canonical definition shared by both native and Wasm targets)
