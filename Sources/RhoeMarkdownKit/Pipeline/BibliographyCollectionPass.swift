import Foundation
import RhoeMarkdownModel

/// Collects bibliography entries from YAML frontmatter `references:` key.
///
/// Expects frontmatter in Pandoc/CSL-JSON style:
/// ```yaml
/// ---
/// references:
///   - id: smith2024
///     author: Smith, J.
///     title: A Study of Things
///     year: "2024"
///     container-title: Journal of Studies
/// ---
/// ```
public struct BibliographyCollectionPass: DocumentPass, Sendable {
    public init() {}

    public func process(_ document: RhoeMarkdownKit.Document) -> RhoeMarkdownKit.Document {
        guard let frontmatter = document.metadata.yamlFrontmatter,
              let referencesValue = frontmatter["references"],
              case .array(let entries) = referencesValue else {
            return document
        }

        var bibliography: [String: BibliographyEntry] = [:]

        for entry in entries {
            guard case .dictionary(let dict) = entry else { continue }

            guard let idValue = dict["id"],
                  case .string(let id) = idValue else { continue }

            let title = stringValue(dict["title"]) ?? id

            let bibEntry = BibliographyEntry(
                id: id,
                author: stringValue(dict["author"]),
                title: title,
                year: stringValue(dict["year"]),
                containerTitle: stringValue(dict["container-title"]),
                publisher: stringValue(dict["publisher"]),
                url: stringValue(dict["url"]) ?? stringValue(dict["URL"]),
                doi: stringValue(dict["doi"]) ?? stringValue(dict["DOI"]),
                type: stringValue(dict["type"])
            )

            bibliography[id] = bibEntry
        }

        guard !bibliography.isEmpty else { return document }

        var metadata = document.metadata
        metadata.resolvedReferences.bibliography = bibliography
        return RhoeMarkdownKit.Document(blocks: document.blocks, metadata: metadata)
    }

    private func stringValue(_ value: RhoeMarkdownKit.YAMLValue?) -> String? {
        guard let value = value else { return nil }
        switch value {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        default: return nil
        }
    }
}
