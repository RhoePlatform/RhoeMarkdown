import Foundation
import RhoeMarkdownModel

/// The complete document graph for a project — all collections, all documents, fully resolved.
public struct ProjectGraph: Sendable {
    public let configuration: ProjectConfiguration
    public let collections: [String: DocumentCollection]

    public init(configuration: ProjectConfiguration, collections: [String: DocumentCollection]) {
        self.configuration = configuration
        self.collections = collections
    }

    /// All documents across all collections.
    public var allDocuments: [CollectionDocument] {
        collections.values.flatMap(\.documents)
    }

    /// Documents participating in a specific target (by target role matching).
    public func documents(for targetName: String) -> [CollectionDocument] {
        guard let target = configuration.targets[targetName] else { return [] }

        if target.collections.isEmpty {
            // No explicit collection filter — include all
            return allDocuments
        }

        return target.collections.flatMap { colName -> [CollectionDocument] in
            collections[colName]?.publishableDocuments ?? []
        }
    }
}

/// Builds a ProjectGraph by scanning collections, extracting frontmatter, and applying defaults.
public struct ProjectGraphBuilder: Sendable {

    private let scanner = CollectionScanner()
    private let extractor = FrontmatterExtractor()
    private let defaultsResolver = DefaultsResolver()

    public init() {}

    /// Build the complete project graph.
    public func build(
        configuration: ProjectConfiguration,
        projectRoot: URL
    ) throws -> ProjectGraph {
        var collections: [String: DocumentCollection] = [:]

        for (name, definition) in configuration.collections {
            let discovered = try scanner.scan(
                collectionPath: definition.path,
                collectionName: name,
                projectRoot: projectRoot
            )

            let documents = discovered.map { disc -> CollectionDocument in
                let frontmatter = (try? extractor.extract(from: disc.url)) ?? [:]
                let effective = defaultsResolver.resolve(
                    documentFrontmatter: frontmatter,
                    documentPath: disc.relativePath,
                    collectionName: name,
                    collectionDefaults: definition.defaults,
                    globalDefaults: configuration.defaults
                )
                return CollectionDocument(
                    id: disc.relativePath.replacingOccurrences(of: ".md", with: "").replacingOccurrences(of: "/", with: "-"),
                    url: disc.url,
                    relativePath: disc.relativePath,
                    collectionName: name,
                    frontmatter: effective
                )
            }

            collections[name] = DocumentCollection(
                name: name,
                definition: definition,
                documents: documents
            )
        }

        return ProjectGraph(configuration: configuration, collections: collections)
    }
}
