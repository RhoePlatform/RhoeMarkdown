import Foundation
import RhoeMarkdownModel

/// Resolves scope-based default frontmatter values for documents.
///
/// Precedence (highest wins):
/// 1. Document frontmatter (author-specified)
/// 2. Most specific scope match (longest path prefix)
/// 3. Less specific scope matches
/// 4. Collection defaults
/// 5. Global defaults (no scope)
public struct DefaultsResolver: Sendable {

    public init() {}

    /// Resolve effective frontmatter by merging defaults with document values.
    public func resolve(
        documentFrontmatter: [String: RhoeMarkdownKit.YAMLValue],
        documentPath: String,
        collectionName: String,
        collectionDefaults: [String: RhoeMarkdownKit.YAMLValue],
        globalDefaults: [DefaultScope]
    ) -> [String: RhoeMarkdownKit.YAMLValue] {
        // Start with global defaults (lowest priority)
        var result: [String: RhoeMarkdownKit.YAMLValue] = [:]

        // Apply global defaults (no scope) first
        let noScopeDefaults = globalDefaults.filter { $0.scope.path == nil && $0.scope.type == nil }
        for scope in noScopeDefaults {
            result.merge(scope.values) { _, new in new }
        }

        // Apply matching scopes, sorted by specificity (least specific first)
        let matchingScopes = globalDefaults
            .filter { $0.scope.matches(documentPath: documentPath, collectionName: collectionName) }
            .filter { $0.scope.path != nil || $0.scope.type != nil } // exclude no-scope (already applied)
            .sorted { $0.scope.specificity < $1.scope.specificity }

        for scope in matchingScopes {
            result.merge(scope.values) { _, new in new }
        }

        // Apply collection defaults
        result.merge(collectionDefaults) { _, new in new }

        // Apply document frontmatter (highest priority)
        result.merge(documentFrontmatter) { _, new in new }

        return result
    }
}
