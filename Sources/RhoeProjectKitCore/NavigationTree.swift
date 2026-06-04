import Foundation

/// A tree of navigation items for a project target.
public struct NavigationTree: Sendable, Equatable {
    public let items: [NavigationItem]

    public init(items: [NavigationItem] = []) {
        self.items = items
    }

    /// Total number of items (including nested children).
    public var totalCount: Int {
        items.reduce(0) { $0 + $1.totalCount }
    }
}

/// A single navigation item (may have children for nested sections).
public struct NavigationItem: Sendable, Equatable {
    public let title: String
    public let url: String?
    public let documentId: String?
    public let children: [NavigationItem]
    public let weight: Int?

    public init(
        title: String,
        url: String? = nil,
        documentId: String? = nil,
        children: [NavigationItem] = [],
        weight: Int? = nil
    ) {
        self.title = title
        self.url = url
        self.documentId = documentId
        self.children = children
        self.weight = weight
    }

    /// Total count including self and all descendants.
    public var totalCount: Int {
        1 + children.reduce(0) { $0 + $1.totalCount }
    }
}
