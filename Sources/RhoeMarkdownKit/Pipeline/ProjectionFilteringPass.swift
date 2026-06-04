import Foundation
import RhoeMarkdownModel
import RhoeMarkdownRendering

/// Filters the AST based on a target projection domain.
///
/// Nodes hidden in the target domain are removed from the tree
/// before the writer receives it. This is a Tier C (Projection) pass.
public struct ProjectionFilteringPass: DocumentPass, Sendable {
    public let domain: ProjectionVisibility.Domain

    public init(domain: ProjectionVisibility.Domain) {
        self.domain = domain
    }

    public func process(_ document: RhoeMarkdownKit.Document) -> RhoeMarkdownKit.Document {
        let filtered = filterBlocks(document.blocks)
        return RhoeMarkdownKit.Document(blocks: filtered, metadata: document.metadata)
    }

    private func filterBlocks(_ blocks: [Block]) -> [Block] {
        blocks.compactMap { filterBlock($0) }
    }

    private func filterBlock(_ block: Block) -> Block? {
        // Check visibility on blocks that carry attributes
        if let attrs = blockAttributes(block),
           !ProjectionVisibility.isVisible(attributes: attrs, in: domain) {
            return nil
        }

        // Recursively filter nested blocks
        switch block {
        case .blockQuote(let nested, let attrs):
            let filtered = filterBlocks(nested)
            return filtered.isEmpty ? nil : .blockQuote(filtered, attributes: attrs)

        case .list(let type, let items, let attrs):
            let filteredItems = items.compactMap { item -> ListItem? in
                let filtered = filterBlocks(item.content)
                return filtered.isEmpty ? nil : ListItem(
                    content: filtered,
                    checked: item.checked,
                    isLoose: item.isLoose
                )
            }
            return filteredItems.isEmpty ? nil : .list(type: type, items: filteredItems, attributes: attrs)

        case .div(let nested, let attrs):
            let filtered = filterBlocks(nested)
            return filtered.isEmpty ? nil : .div(content: filtered, attributes: attrs)

        case .admonition(let type, let title, let content, let collapsible, let attrs):
            let filtered = filterBlocks(content)
            return filtered.isEmpty ? nil : .admonition(type: type, title: title, content: filtered, collapsible: collapsible, attributes: attrs)

        case .widget(let title, let content, let attrs):
            let filtered = filterBlocks(content)
            return filtered.isEmpty ? nil : .widget(title: title, content: filtered, attributes: attrs)

        case .tab(let title, let content, let attrs):
            let filtered = filterBlocks(content)
            return filtered.isEmpty ? nil : .tab(title: title, content: filtered, attributes: attrs)

        case .stage(let kind, let content, let attrs):
            let filtered = filterBlocks(content)
            return filtered.isEmpty ? nil : .stage(kind: kind, content: filtered, attributes: attrs)

        case .lane(let content, let attrs):
            let filtered = filterBlocks(content)
            return filtered.isEmpty ? nil : .lane(content: filtered, attributes: attrs)

        case .module(let family, let name, let content, let attrs):
            let filtered = filterBlocks(content)
            return filtered.isEmpty ? nil : .module(family: family, name: name, content: filtered, attributes: attrs)

        default:
            return block
        }
    }

    private func blockAttributes(_ block: Block) -> RhoeMarkdownKit.Attributes? {
        switch block {
        case .heading(_, _, let a): return a
        case .paragraph(_, let a): return a
        case .blockQuote(_, let a): return a
        case .list(_, _, let a): return a
        case .codeBlock(_, _, let a): return a
        case .table(_, _, _, let a): return a
        case .admonition(_, _, _, _, let a): return a
        case .div(_, let a): return a
        case .visualBlock(_, _, let a): return a
        case .transclusion(_, _, _, let a): return a
        case .schemaIsland(_, _, let a): return a
        case .placeholder(_, let a): return a
        case .widget(_, _, let a): return a
        case .tab(_, _, let a): return a
        case .stage(_, _, let a): return a
        case .lane(_, let a): return a
        case .module(_, _, _, let a): return a
        case .contractDirective(_, _, let a): return a
        default: return nil
        }
    }
}
