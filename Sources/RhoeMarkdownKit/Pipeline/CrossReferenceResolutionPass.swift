import Foundation
import RhoeMarkdownModel

/// Resolves cross-reference inlines against the element numbering index.
///
/// Transforms `Inline.crossReference` nodes into `Inline.resolvedCrossReference`
/// with formatted text like "Figure 1", "Table 2", etc.
public struct CrossReferenceResolutionPass: DocumentPass, Sendable {
    public init() {}

    public func process(_ document: RhoeMarkdownKit.Document) -> RhoeMarkdownKit.Document {
        let numbers = document.metadata.resolvedReferences.elementNumbers
        let resolvedBlocks = document.blocks.map { resolveInBlock($0, numbers: numbers) }
        return RhoeMarkdownKit.Document(blocks: resolvedBlocks, metadata: document.metadata)
    }

    private func resolveInBlock(
        _ block: Block,
        numbers: [String: String]
    ) -> Block {
        switch block {
        case .paragraph(let inlines, let attrs):
            return .paragraph(resolveInInlines(inlines, numbers: numbers), attributes: attrs)
        case .heading(let level, let content, let attrs):
            return .heading(level: level, content: resolveInInlines(content, numbers: numbers), attributes: attrs)
        case .blockQuote(let blocks, let attrs):
            return .blockQuote(blocks.map { resolveInBlock($0, numbers: numbers) }, attributes: attrs)
        case .list(let type, let items, let attrs):
            let resolvedItems = items.map { item in
                ListItem(
                    content: item.content.map { resolveInBlock($0, numbers: numbers) },
                    checked: item.checked,
                    isLoose: item.isLoose
                )
            }
            return .list(type: type, items: resolvedItems, attributes: attrs)
        case .div(let content, let attrs):
            return .div(content: content.map { resolveInBlock($0, numbers: numbers) }, attributes: attrs)
        default:
            return block
        }
    }

    private func resolveInInlines(
        _ inlines: [Inline],
        numbers: [String: String]
    ) -> [Inline] {
        inlines.map { inline in
            switch inline {
            case .crossReference(let prefix, let id):
                return resolveCrossRef(prefix: prefix, id: id, numbers: numbers)
            case .emphasis(let content):
                return .emphasis(resolveInInlines(content, numbers: numbers))
            case .strong(let content):
                return .strong(resolveInInlines(content, numbers: numbers))
            case .strikethrough(let content):
                return .strikethrough(resolveInInlines(content, numbers: numbers))
            default:
                return inline
            }
        }
    }

    private func resolveCrossRef(
        prefix: CrossRefPrefix,
        id: String,
        numbers: [String: String]
    ) -> Inline {
        let targetId = "\(prefix.rawValue)-\(id)"
        let number = numbers[targetId]
        let label = displayName(for: prefix)
        let text = number.map { "\(label) \($0)" } ?? "\(label) \(id)"
        return .resolvedCrossReference(text: text, targetId: targetId)
    }

    private func displayName(for prefix: CrossRefPrefix) -> String {
        switch prefix {
        case .fig: return "Figure"
        case .tbl: return "Table"
        case .eq: return "Equation"
        case .sec: return "Section"
        case .lst: return "Listing"
        case .note: return "Note"
        case .thm: return "Theorem"
        case .lem: return "Lemma"
        case .def: return "Definition"
        case .prop: return "Proposition"
        case .cor: return "Corollary"
        case .ex: return "Example"
        case .rmk: return "Remark"
        case .alg: return "Algorithm"
        case .sld: return "Slide"
        case .clm: return "Claim"
        case .assum: return "Assumption"
        case .conj: return "Conjecture"
        case .prf: return "Proof"
        }
    }
}
