import Foundation
import RhoeMarkdownModel

/// Post-Phase-2 normalization pass.
///
/// Runs AFTER `Phase2ExecutionPass` to repair the AST after transforms.
/// Implements the 9-step normalization spec (§16 of 06-phase-separation.md):
///
/// 1. Repair structural invariants
/// 2. Regenerate identifiers (for cloned nodes with collision)
/// 3. Rebuild scope tree (implicit via subsequent passes)
/// 4-9. Handled by existing pipeline (CrossReferenceNumberingPass, etc.)
///
/// This pass focuses on steps 1-2; steps 4-9 are handled by the normal
/// pipeline passes that run after Phase 2.
public struct Phase2NormalizationPass: DocumentPass, Sendable {
    public init() {}

    public func process(_ document: RhoeMarkdownKit.Document) -> RhoeMarkdownKit.Document {
        var blocks = document.blocks

        // Step 1: Repair structural invariants
        blocks = repairStructure(blocks)

        // Step 2: Detect and fix ID collisions (from cloned nodes)
        blocks = deduplicateIds(blocks)

        return RhoeMarkdownKit.Document(blocks: blocks, metadata: document.metadata)
    }

    // MARK: - Step 1: Structural Repair

    /// Remove empty extension-only containers, fix orphaned nodes, and keep Markdown-significant empties.
    private func repairStructure(_ blocks: [Block]) -> [Block] {
        blocks.compactMap { block in
            switch block {
            case .blockQuote(let children, let attrs):
                let repaired = repairStructure(children)
                return .blockQuote(repaired, attributes: attrs)

            case .div(let children, let attrs):
                let repaired = repairStructure(children)
                // Keep empty divs if they have an ID (may be collect targets)
                return repaired.isEmpty && attrs.id == nil ? nil : .div(content: repaired, attributes: attrs)

            case .admonition(let type, let title, let children, let collapsible, let attrs):
                let repaired = repairStructure(children)
                return .admonition(type: type, title: title, content: repaired,
                                 collapsible: collapsible, attributes: attrs)

            case .list(let type, let items, let attrs):
                let repairedItems = items.map { item in
                    ListItem(
                        content: repairStructure(item.content),
                        checked: item.checked,
                        isLoose: item.isLoose
                    )
                }
                return repairedItems.isEmpty ? nil : .list(type: type, items: repairedItems, attributes: attrs)

            case .visualBlock(let name, let children, let attrs):
                let repaired = repairStructure(children)
                return .visualBlock(name: name, content: repaired, attributes: attrs)

            case .widget(let title, let children, let attrs):
                let repaired = repairStructure(children)
                return .widget(title: title, content: repaired, attributes: attrs)

            case .tab(let title, let children, let attrs):
                let repaired = repairStructure(children)
                return .tab(title: title, content: repaired, attributes: attrs)

            case .stage(let kind, let children, let attrs):
                let repaired = repairStructure(children)
                return .stage(kind: kind, content: repaired, attributes: attrs)

            case .lane(let children, let attrs):
                let repaired = repairStructure(children)
                return .lane(content: repaired, attributes: attrs)

            case .module(let family, let name, let children, let attrs):
                let repaired = repairStructure(children)
                return .module(family: family, name: name, content: repaired, attributes: attrs)

            default:
                return block
            }
        }
    }

    // MARK: - Step 2: ID Deduplication

    /// Find and fix duplicate IDs (e.g., from clone operations).
    private func deduplicateIds(_ blocks: [Block]) -> [Block] {
        // First pass: collect all IDs and find duplicates
        var seenIds: Set<String> = []
        var duplicateIds: Set<String> = []
        collectIds(from: blocks, seen: &seenIds, duplicates: &duplicateIds)

        guard !duplicateIds.isEmpty else { return blocks }

        // Second pass: rename duplicates (keep first occurrence, rename subsequent)
        var firstSeen: Set<String> = []
        return renameDuplicates(blocks, duplicateIds: duplicateIds, firstSeen: &firstSeen)
    }

    private func collectIds(from blocks: [Block], seen: inout Set<String>, duplicates: inout Set<String>) {
        for block in blocks {
            if let id = blockId(block) {
                if seen.contains(id) {
                    duplicates.insert(id)
                }
                seen.insert(id)
            }
            for nested in nestedBlocks(block) {
                if let id = blockId(nested) {
                    if seen.contains(id) {
                        duplicates.insert(id)
                    }
                    seen.insert(id)
                }
            }
        }
    }

    private func renameDuplicates(
        _ blocks: [Block],
        duplicateIds: Set<String>,
        firstSeen: inout Set<String>
    ) -> [Block] {
        blocks.map { block in
            var result = block
            if let id = blockId(block), duplicateIds.contains(id) {
                if firstSeen.contains(id) {
                    // This is a duplicate — rename it
                    result = updateId(block, newId: "\(id)-dup-\(UUID().uuidString.prefix(6))")
                } else {
                    firstSeen.insert(id)
                }
            }

            // Recurse into children
            switch result {
            case .blockQuote(let children, let attrs):
                return .blockQuote(renameDuplicates(children, duplicateIds: duplicateIds, firstSeen: &firstSeen), attributes: attrs)
            case .div(let children, let attrs):
                return .div(content: renameDuplicates(children, duplicateIds: duplicateIds, firstSeen: &firstSeen), attributes: attrs)
            case .admonition(let type, let title, let children, let collapsible, let attrs):
                return .admonition(type: type, title: title,
                                 content: renameDuplicates(children, duplicateIds: duplicateIds, firstSeen: &firstSeen),
                                 collapsible: collapsible, attributes: attrs)
            case .widget(let title, let children, let attrs):
                return .widget(title: title,
                              content: renameDuplicates(children, duplicateIds: duplicateIds, firstSeen: &firstSeen),
                              attributes: attrs)
            case .tab(let title, let children, let attrs):
                return .tab(title: title,
                           content: renameDuplicates(children, duplicateIds: duplicateIds, firstSeen: &firstSeen),
                           attributes: attrs)
            case .stage(let kind, let children, let attrs):
                return .stage(kind: kind,
                             content: renameDuplicates(children, duplicateIds: duplicateIds, firstSeen: &firstSeen),
                             attributes: attrs)
            case .lane(let children, let attrs):
                return .lane(content: renameDuplicates(children, duplicateIds: duplicateIds, firstSeen: &firstSeen),
                            attributes: attrs)
            case .module(let family, let name, let children, let attrs):
                return .module(family: family, name: name,
                              content: renameDuplicates(children, duplicateIds: duplicateIds, firstSeen: &firstSeen),
                              attributes: attrs)
            default:
                return result
            }
        }
    }

    // MARK: - Helpers

    private func blockId(_ block: Block) -> String? {
        switch block {
        case .heading(_, _, let a): return a.id
        case .paragraph(_, let a): return a.id
        case .admonition(_, _, _, _, let a): return a.id
        case .div(_, let a): return a.id
        case .table(_, _, _, let a): return a.id
        case .codeBlock(_, _, let a): return a.id
        case .blockQuote(_, let a): return a.id
        case .list(_, _, let a): return a.id
        case .visualBlock(_, _, let a): return a.id
        case .widget(_, _, let a): return a.id
        case .tab(_, _, let a): return a.id
        case .stage(_, _, let a): return a.id
        case .lane(_, let a): return a.id
        case .module(_, _, _, let a): return a.id
        case .contractDirective(_, _, let a): return a.id
        default: return nil
        }
    }

    private func updateId(_ block: Block, newId: String) -> Block {
        switch block {
        case .heading(let level, let content, let attrs):
            return .heading(level: level, content: content,
                          attributes: RhoeMarkdownKit.Attributes(id: newId, classes: attrs.classes, keyValues: attrs.keyValues))
        case .paragraph(let inlines, let attrs):
            return .paragraph(inlines,
                            attributes: RhoeMarkdownKit.Attributes(id: newId, classes: attrs.classes, keyValues: attrs.keyValues))
        case .admonition(let type, let title, let content, let collapsible, let attrs):
            return .admonition(type: type, title: title, content: content, collapsible: collapsible,
                             attributes: RhoeMarkdownKit.Attributes(id: newId, classes: attrs.classes, keyValues: attrs.keyValues))
        case .div(let content, let attrs):
            return .div(content: content,
                       attributes: RhoeMarkdownKit.Attributes(id: newId, classes: attrs.classes, keyValues: attrs.keyValues))
        default:
            return block
        }
    }

    private func nestedBlocks(_ block: Block) -> [Block] {
        switch block {
        case .blockQuote(let b, _): return b
        case .list(_, let items, _): return items.flatMap(\.content)
        case .div(let b, _): return b
        case .admonition(_, _, let b, _, _): return b
        case .visualBlock(_, let b, _): return b
        case .widget(_, let b, _): return b
        case .tab(_, let b, _): return b
        case .stage(_, let b, _): return b
        case .lane(let b, _): return b
        case .module(_, _, let b, _): return b
        default: return []
        }
    }
}
