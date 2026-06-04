import Foundation

/// Serializes a NavigationTree to JSON for theme/template consumption.
public struct NavigationSerializer: Sendable {

    public init() {}

    /// Serialize a navigation tree to JSON data.
    public func serialize(_ tree: NavigationTree) -> Data {
        let jsonItems = tree.items.map { serializeItem($0) }
        let root: [String: Any] = ["items": jsonItems]

        guard let data = try? JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            return Data("{}".utf8)
        }

        return data
    }

    private func serializeItem(_ item: NavigationItem) -> [String: Any] {
        var dict: [String: Any] = ["title": item.title]
        if let url = item.url { dict["url"] = url }
        if let docId = item.documentId { dict["documentId"] = docId }
        if let weight = item.weight { dict["weight"] = weight }
        if !item.children.isEmpty {
            dict["children"] = item.children.map { serializeItem($0) }
        }
        return dict
    }
}
