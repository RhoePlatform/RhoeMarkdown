import Foundation
import RhoeMarkdownModel

/// Resolves the output format for a target based on explicit config or type defaults.
public struct TargetFormatResolver: Sendable {

    public init() {}

    /// Resolve the output format for a target.
    public func resolve(target: TargetDefinition) -> RhoeMarkdownKit.OutputFormat {
        // Use explicit format if specified
        if let explicit = target.outputFormat,
           let format = RhoeMarkdownKit.OutputFormat(rawValue: explicit) {
            return format
        }

        // Default based on target type
        switch target.type {
        case .staticSite, .docsSite, .wikiSite, .singleFileHTML, .deck:
            return .html
        case .book, .report, .brochure:
            return .pdf
        case .llmBundle:
            return .html // LLM bundle uses HTML as base; actual output may be raw markdown
        }
    }
}
