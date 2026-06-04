import Foundation
import RhoeMarkdownModel

/// Definition of a document collection within a project.
public struct CollectionDefinition: Sendable, Equatable {
    public let path: String
    public let output: Bool
    public let permalink: String?
    public let sortBy: String?
    public let reverse: Bool
    public let defaults: [String: RhoeMarkdownKit.YAMLValue]
    public let targetRoles: [String]

    public init(
        path: String,
        output: Bool = true,
        permalink: String? = nil,
        sortBy: String? = nil,
        reverse: Bool = false,
        defaults: [String: RhoeMarkdownKit.YAMLValue] = [:],
        targetRoles: [String] = []
    ) {
        self.path = path
        self.output = output
        self.permalink = permalink
        self.sortBy = sortBy
        self.reverse = reverse
        self.defaults = defaults
        self.targetRoles = targetRoles
    }
}
