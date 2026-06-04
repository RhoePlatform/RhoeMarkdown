import Foundation
import RhoeMarkdownModel
import RhoeMarkdownKit
import RhoeMarkdownParsing

/// Extracts YAML frontmatter from markdown files without full parsing.
public struct FrontmatterExtractor: Sendable {

    public init() {}

    /// Extract frontmatter from a file URL.
    public func extract(from url: URL) throws -> [String: RhoeMarkdownKit.YAMLValue]? {
        let content = try String(contentsOf: url, encoding: .utf8)
        return extract(from: content)
    }

    /// Extract frontmatter from a markdown string.
    public func extract(from markdown: String) -> [String: RhoeMarkdownKit.YAMLValue]? {
        guard markdown.hasPrefix("---\n") || markdown.hasPrefix("---\r\n") else {
            return nil
        }

        let content = String(markdown.dropFirst(4))
        guard let endRange = content.range(of: "\n---") else {
            return nil
        }

        let yamlContent = String(content[content.startIndex..<endRange.lowerBound])
        guard !yamlContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let result = RhoeParser().parseYAMLContent(yamlContent)
        return result.isEmpty ? nil : result
    }
}
