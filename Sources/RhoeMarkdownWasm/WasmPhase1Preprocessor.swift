import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeLiquid
import LiquidCore

/// Phase 1 Liquid preprocessor for the Wasm target.
///
/// Runs the RhoeLiquid template engine on markdown source BEFORE parsing.
/// Resolves `{{ }}` value interpolation and `{% %}` control flow.
/// Output is pure RhoeMarkdown text with no Liquid syntax remaining.
///
/// This is a Wasm-compatible adaptation of the native Phase1Preprocessor,
/// using `Date().timeIntervalSinceReferenceDate` for timing (no CoreFoundation dependency).
struct WasmPhase1Preprocessor: Sendable {
    private let engine: LiquidEngine
    private let allowGeneratedTransforms: Bool

    init(allowGeneratedTransforms: Bool = false) {
        self.engine = LiquidEngine(configuration: .default)
        self.allowGeneratedTransforms = allowGeneratedTransforms
    }

    /// Preprocess markdown source through the Liquid engine.
    /// Preprocess markdown source through the Liquid engine.
    ///
    /// - Parameters:
    ///   - markdown: Source markdown with optional Liquid syntax
    ///   - context: Flat context variables (available as `{{ key }}`)
    ///   - site: Project-level variables (available as `{{ site.key }}`)
    ///   - data: Data variables (available as `{{ data.key }}`)
    func preprocess(
        _ markdown: String,
        context: [String: Any] = [:],
        site: [String: Any] = [:],
        data: [String: Any] = [:]
    ) async -> Phase1PreprocessResult {
        let startTime = Date().timeIntervalSinceReferenceDate
        var diagnostics: [String] = []

        // 1. Extract frontmatter (preserved literally — not Liquid-processed)
        let (frontmatter, body) = extractFrontmatter(markdown)

        // 2. Build Liquid context with three-namespace model
        var liquidContext: [String: Any] = context

        // page.* namespace from frontmatter
        if let fm = frontmatter {
            var pageVars: [String: Any] = [:]
            for (key, value) in fm {
                pageVars[key] = value.liquidValue
            }
            liquidContext["page"] = pageVars
        }

        // site.* namespace from project context
        if !site.isEmpty {
            liquidContext["site"] = site
        }

        // data.* namespace from data directory
        if !data.isEmpty {
            liquidContext["data"] = data
        }

        // 3. Run Liquid engine
        let preprocessedBody: String
        do {
            preprocessedBody = try await engine.render(template: body, context: liquidContext)
        } catch {
            diagnostics.append("[Phase 1] Liquid preprocessing failed: \(error.localizedDescription)")
            let elapsed = Date().timeIntervalSinceReferenceDate - startTime
            return Phase1PreprocessResult(
                markdown: markdown,
                diagnostics: diagnostics,
                preprocessingTime: elapsed,
                hasGeneratedTransforms: false
            )
        }

        // 4. Validate generated transform gateway
        let hasGeneratedTransforms = preprocessedBody.contains("{@") && preprocessedBody.contains("@}")
        if hasGeneratedTransforms && !allowGeneratedTransforms {
            diagnostics.append("[Phase 1] Phase 2 directives ({@ @}) found in Phase 1 output. Enable allowGeneratedSemanticTransforms to allow.")
        }

        // 5. Reassemble: frontmatter + preprocessed body
        let reassembled: String
        if frontmatter != nil {
            let originalFrontmatterBlock = extractFrontmatterBlock(markdown)
            reassembled = originalFrontmatterBlock + preprocessedBody
        } else {
            reassembled = preprocessedBody
        }

        let elapsed = Date().timeIntervalSinceReferenceDate - startTime
        return Phase1PreprocessResult(
            markdown: reassembled,
            diagnostics: diagnostics,
            preprocessingTime: elapsed,
            hasGeneratedTransforms: hasGeneratedTransforms
        )
    }

    // MARK: - Frontmatter Extraction

    private func extractFrontmatter(_ markdown: String) -> ([String: RhoeMarkdownKit.YAMLValue]?, String) {
        guard markdown.hasPrefix("---\n") || markdown.hasPrefix("---\r\n") else {
            return (nil, markdown)
        }

        let content = String(markdown.dropFirst(4))
        guard let endRange = content.range(of: "\n---\n") ?? content.range(of: "\n---\r\n") else {
            return (nil, markdown)
        }

        let yamlString = String(content[content.startIndex..<endRange.lowerBound])
        let body = String(content[endRange.upperBound...])

        let parser = RhoeParser()
        let yamlDict = parser.parseYAMLContent(yamlString)

        return (yamlDict, body)
    }

    private func extractFrontmatterBlock(_ markdown: String) -> String {
        guard markdown.hasPrefix("---\n") || markdown.hasPrefix("---\r\n") else {
            return ""
        }

        let content = String(markdown.dropFirst(4))
        if let endRange = content.range(of: "\n---\n") {
            return "---\n" + String(content[content.startIndex..<endRange.upperBound])
        }
        if let endRange = content.range(of: "\n---\r\n") {
            return "---\n" + String(content[content.startIndex..<endRange.upperBound])
        }
        return ""
    }
}

/// Result from Wasm Phase 1 preprocessing.
struct Phase1PreprocessResult: Sendable {
    let markdown: String
    let diagnostics: [String]
    let preprocessingTime: TimeInterval
    let hasGeneratedTransforms: Bool
}

// liquidValue is defined on RhoeMarkdownKit.YAMLValue in RhoeMarkdownModel
// (single canonical definition shared by both native and Wasm targets)
