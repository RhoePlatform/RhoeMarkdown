import Foundation
import RhoeMarkdownModel

/// Scope-based default frontmatter values.
public struct DefaultScope: Sendable, Equatable {
    public let scope: ScopePattern
    public let values: [String: RhoeMarkdownKit.YAMLValue]

    public init(scope: ScopePattern, values: [String: RhoeMarkdownKit.YAMLValue]) {
        self.scope = scope
        self.values = values
    }
}

/// Pattern for matching documents to default scopes.
public struct ScopePattern: Sendable, Equatable {
    public let path: String?
    public let type: String?

    public init(path: String? = nil, type: String? = nil) {
        self.path = path
        self.type = type
    }

    /// Check if a document matches this scope pattern.
    public func matches(documentPath: String, collectionName: String) -> Bool {
        var pathMatch = true
        var typeMatch = true

        if let path {
            pathMatch = documentPath.hasPrefix(path)
        }
        if let type {
            typeMatch = collectionName == type
        }

        return pathMatch && typeMatch
    }

    /// Specificity of this scope (longer path = more specific).
    public var specificity: Int {
        (path?.count ?? 0) + (type != nil ? 1 : 0)
    }
}
