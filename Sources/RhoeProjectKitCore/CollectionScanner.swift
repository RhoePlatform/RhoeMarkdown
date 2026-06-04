import Foundation

/// Scans collection directories for markdown documents.
public struct CollectionScanner: Sendable {

    public init() {}

    /// Scan a collection directory and return discovered documents.
    public func scan(
        collectionPath: String,
        collectionName: String,
        projectRoot: URL
    ) throws -> [DiscoveredDocument] {
        let collectionDir = projectRoot.appendingPathComponent(collectionPath)

        guard FileManager.default.fileExists(atPath: collectionDir.path) else {
            return []
        }

        let enumerator = FileManager.default.enumerator(
            at: collectionDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var documents: [DiscoveredDocument] = []

        while let fileURL = enumerator?.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            guard ext == "md" || ext == "markdown" else { continue }

            let relativePath = fileURL.path.replacingOccurrences(
                of: collectionDir.path + "/",
                with: ""
            )

            documents.append(DiscoveredDocument(
                url: fileURL,
                relativePath: relativePath,
                collectionName: collectionName
            ))
        }

        return documents.sorted { $0.relativePath < $1.relativePath }
    }
}

/// A document discovered during collection scanning.
public struct DiscoveredDocument: Sendable, Equatable {
    public let url: URL
    public let relativePath: String
    public let collectionName: String

    public init(url: URL, relativePath: String, collectionName: String) {
        self.url = url
        self.relativePath = relativePath
        self.collectionName = collectionName
    }
}
