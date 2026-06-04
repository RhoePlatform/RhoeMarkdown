import Foundation

/// Generates navigation trees for project targets based on the configured navigation mode.
public struct NavigationGenerator: Sendable {

    public init() {}

    /// Generate a navigation tree for a target.
    public func generate(
        mode: NavigationMode,
        documents: [CollectionDocument],
        projectRoot: URL
    ) -> NavigationTree {
        switch mode {
        case .auto:
            return AutoNavigationBuilder().build(documents: documents)
        case .explicit:
            // Explicit mode requires YAML tree config — fall back to auto for now
            return AutoNavigationBuilder().build(documents: documents)
        case .summary:
            // Summary mode requires SUMMARY.md — fall back to auto for now
            return AutoNavigationBuilder().build(documents: documents)
        case .sidebar:
            return AutoNavigationBuilder().build(documents: documents)
        case .tree:
            return AutoNavigationBuilder().build(documents: documents)
        }
    }
}

/// Builds navigation from filesystem hierarchy.
public struct AutoNavigationBuilder: Sendable {

    public init() {}

    /// Build a navigation tree from document paths.
    public func build(documents: [CollectionDocument]) -> NavigationTree {
        // Group documents by directory
        var directories: [String: [CollectionDocument]] = [:]

        for doc in documents {
            let dir = (doc.relativePath as NSString).deletingLastPathComponent
            let dirKey = dir.isEmpty ? "/" : dir
            directories[dirKey, default: []].append(doc)
        }

        // Build tree: root-level docs first, then subdirectories
        var items: [NavigationItem] = []

        // Root-level documents
        if let rootDocs = directories["/"] {
            let sorted = rootDocs.sorted { ($0.weight ?? 999) < ($1.weight ?? 999) }
            for doc in sorted {
                items.append(NavigationItem(
                    title: doc.title ?? doc.id,
                    url: doc.relativePath.replacingOccurrences(of: ".md", with: ".html"),
                    documentId: doc.id,
                    weight: doc.weight
                ))
            }
        }

        // Subdirectory sections
        for (dir, docs) in directories.sorted(by: { $0.key < $1.key }) where dir != "/" {
            let sectionTitle = dir
                .components(separatedBy: "/").last?
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized ?? dir

            let sorted = docs.sorted { ($0.weight ?? 999) < ($1.weight ?? 999) }
            let children = sorted.map { doc in
                NavigationItem(
                    title: doc.title ?? doc.id,
                    url: doc.relativePath.replacingOccurrences(of: ".md", with: ".html"),
                    documentId: doc.id,
                    weight: doc.weight
                )
            }

            items.append(NavigationItem(
                title: sectionTitle,
                children: children
            ))
        }

        return NavigationTree(items: items)
    }
}
