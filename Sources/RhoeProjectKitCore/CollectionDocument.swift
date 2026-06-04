import Foundation
import RhoeMarkdownModel

/// A document within a project collection, with extracted metadata.
public struct CollectionDocument: Sendable, Equatable, Identifiable {
    public let id: String
    public let url: URL
    public let relativePath: String
    public let collectionName: String
    public let frontmatter: [String: RhoeMarkdownKit.YAMLValue]

    public var title: String? { stringValue("title") }
    public var date: Date? { dateValue("date") }
    public var weight: Int? { intValue("weight") }
    public var layout: String? { stringValue("layout") }
    public var slug: String? { stringValue("slug") }
    public var draft: Bool { boolValue("draft") ?? false }

    public var tags: [String] {
        guard case .array(let arr) = frontmatter["tags"] else { return [] }
        return arr.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
    }

    public init(
        id: String,
        url: URL,
        relativePath: String,
        collectionName: String,
        frontmatter: [String: RhoeMarkdownKit.YAMLValue] = [:]
    ) {
        self.id = id
        self.url = url
        self.relativePath = relativePath
        self.collectionName = collectionName
        self.frontmatter = frontmatter
    }

    /// Create from a discovered document with extracted frontmatter.
    public init(from discovered: DiscoveredDocument, frontmatter: [String: RhoeMarkdownKit.YAMLValue]) {
        self.id = discovered.relativePath
            .replacingOccurrences(of: ".md", with: "")
            .replacingOccurrences(of: ".markdown", with: "")
            .replacingOccurrences(of: "/", with: "-")
        self.url = discovered.url
        self.relativePath = discovered.relativePath
        self.collectionName = discovered.collectionName
        self.frontmatter = frontmatter
    }

    // MARK: - Helpers

    private func stringValue(_ key: String) -> String? {
        if case .string(let s) = frontmatter[key] { return s }
        return nil
    }

    private func intValue(_ key: String) -> Int? {
        if case .int(let i) = frontmatter[key] { return i }
        return nil
    }

    private func boolValue(_ key: String) -> Bool? {
        if case .bool(let b) = frontmatter[key] { return b }
        return nil
    }

    private func dateValue(_ key: String) -> Date? {
        guard case .string(let s) = frontmatter[key] else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: s)
    }
}
