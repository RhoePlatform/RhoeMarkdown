import Foundation
import RhoeMarkdownModel

/// A fully resolved collection of documents with sorting applied.
public struct DocumentCollection: Sendable {
    public let name: String
    public let definition: CollectionDefinition
    public let documents: [CollectionDocument]

    public init(name: String, definition: CollectionDefinition, documents: [CollectionDocument]) {
        self.name = name
        self.definition = definition
        self.documents = documents
    }

    /// Documents sorted according to the collection's sort_by field.
    public var sortedDocuments: [CollectionDocument] {
        guard let sortBy = definition.sortBy else { return documents }

        let sorted = documents.sorted { a, b in
            switch sortBy {
            case "weight":
                return (a.weight ?? Int.max) < (b.weight ?? Int.max)
            case "title":
                return (a.title ?? "") < (b.title ?? "")
            case "date":
                return (a.date ?? .distantPast) < (b.date ?? .distantPast)
            default:
                // Sort by arbitrary frontmatter field (string comparison)
                let aVal = stringFromYAML(a.frontmatter[sortBy])
                let bVal = stringFromYAML(b.frontmatter[sortBy])
                return aVal < bVal
            }
        }

        return definition.reverse ? sorted.reversed() : sorted
    }

    private func stringFromYAML(_ value: RhoeMarkdownKit.YAMLValue?) -> String {
        guard let value else { return "" }
        switch value {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return b ? "true" : "false"
        default: return ""
        }
    }

    /// Non-draft documents only.
    public var publishableDocuments: [CollectionDocument] {
        sortedDocuments.filter { !$0.draft }
    }
}
