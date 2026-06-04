import Foundation
import RhoeMarkdownModel

/// Selector atoms for Phase 2 semantic transforms.
///
/// Each atom matches a specific semantic property of an AST node.
/// Multiple atoms compose via conjunction (AND).
/// Spec reference: §5 Phase 2 Selector Grammar (06-phase-separation.md)
public enum SelectorAtom: Sendable, Equatable {
    case family(String)       // family=theorem
    case role(String)         // role=warning
    case id(String)           // id=#thm-fixed-point
    case className(String)    // class=.key-result
    case inContainer(String)  // in=#chapter-2
    case ancestor(String)     // ancestor=#part-1
    case kind(String)         // kind=analytic
    case visible(String)      // visible=screen
    case has(String)          // has=title
    case numbered(Bool)       // numbered=true
    case title(String)        // title="Introduction"
}

/// A selector composed of atoms. All atoms must match (conjunction).
public struct Phase2Selector: Sendable, Equatable {
    public let atoms: [SelectorAtom]

    public init(atoms: [SelectorAtom]) {
        self.atoms = atoms
    }

    /// Parse selector atoms from a key=value argument map.
    public init(from arguments: [String: String]) {
        var atoms: [SelectorAtom] = []
        for (key, value) in arguments {
            switch key {
            case "family": atoms.append(.family(value))
            case "role": atoms.append(.role(value))
            case "id": atoms.append(.id(value.hasPrefix("#") ? String(value.dropFirst()) : value))
            case "class": atoms.append(.className(value.hasPrefix(".") ? String(value.dropFirst()) : value))
            case "in": atoms.append(.inContainer(value.hasPrefix("#") ? String(value.dropFirst()) : value))
            case "ancestor": atoms.append(.ancestor(value.hasPrefix("#") ? String(value.dropFirst()) : value))
            case "kind": atoms.append(.kind(value))
            case "visible": atoms.append(.visible(value))
            case "has": atoms.append(.has(value))
            case "numbered": atoms.append(.numbered(value == "true"))
            case "title": atoms.append(.title(value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))))
            default: break // Target clauses (into, for, as, with) are not selector atoms
            }
        }
        self.atoms = atoms
    }

    /// Check if a block matches all selector atoms.
    public func matches(
        _ block: Block,
        containerId: String? = nil,
        ancestorIds: [String] = []
    ) -> Bool {
        for atom in atoms {
            if !matchesAtom(atom, block: block, containerId: containerId, ancestorIds: ancestorIds) {
                return false
            }
        }
        return !atoms.isEmpty
    }

    private func matchesAtom(
        _ atom: SelectorAtom,
        block: Block,
        containerId: String?,
        ancestorIds: [String]
    ) -> Bool {
        let attrs = blockAttributes(block)
        switch atom {
        case .family(let family):
            return matchesFamily(family, block: block)
        case .role(let role):
            return attrs?.keyValues["role"] == role
        case .id(let id):
            return attrs?.id == id
        case .className(let cls):
            return attrs?.classes.contains(cls) == true
        case .inContainer(let container):
            return containerId == container
        case .ancestor(let ancestorId):
            return ancestorIds.contains(ancestorId)
        case .kind(let kind):
            return attrs?.keyValues["kind"] == kind
        case .visible(let domain):
            return attrs?.keyValues["visible"]?.contains(domain) == true
        case .has(let property):
            return attrs?.keyValues[property] != nil ||
                   (property == "title" && blockTitle(block) != nil) ||
                   (property == "id" && attrs?.id != nil)
        case .numbered(let expected):
            let isNumbered = isBlockNumbered(block)
            return isNumbered == expected
        case .title(let titleText):
            guard let actualTitle = blockTitle(block) else { return false }
            return actualTitle.lowercased().contains(titleText.lowercased())
        }
    }

    // MARK: - Family Matching

    private func matchesFamily(_ family: String, block: Block) -> Bool {
        let lowered = family.lowercased()
        switch block {
        case .admonition(let type, _, _, _, _):
            // Admonition type matches directly (note, warning, theorem, lemma, etc.)
            return type.lowercased() == lowered
        case .heading:
            return lowered == "heading" || lowered == "section"
        case .paragraph:
            return lowered == "paragraph"
        case .table:
            return lowered == "table"
        case .codeBlock:
            return lowered == "code" || lowered == "listing" || lowered == "codeblock"
        case .blockQuote:
            return lowered == "blockquote" || lowered == "quote"
        case .list:
            return lowered == "list"
        case .definitionList:
            return lowered == "definition-list" || lowered == "definitionlist"
        case .footnoteDefinition:
            return lowered == "footnote"
        case .div(_, let attrs):
            // Div matches by class (theorem, proof, etc. stored as classes)
            return attrs.classes.contains(family)
        case .visualBlock(let name, _, _):
            return name.lowercased() == lowered || lowered == "visual"
        case .lineBlock:
            return lowered == "lineblock" || lowered == "line-block"
        case .horizontalRule:
            return lowered == "rule" || lowered == "hr"
        case .transclusion:
            return lowered == "transclusion" || lowered == "include"
        case .schemaIsland:
            return lowered == "schema"
        case .componentDeclaration:
            return lowered == "component"
        case .placeholder:
            return lowered == "placeholder" || lowered == "field"
        case .authorAnnotation:
            return lowered == "annotation"
        case .widget(_, _, _):
            return lowered == "widget"
        case .tab(_, _, _):
            return lowered == "tab"
        case .stage(_, _, _):
            return lowered == "stage"
        case .lane(_, _):
            return lowered == "lane"
        case .module(_, _, _, _):
            return lowered == "module"
        case .contractDirective(_, _, _):
            return lowered == "contract"
        default:
            return false
        }
    }

    // MARK: - Helpers

    private func blockTitle(_ block: Block) -> String? {
        switch block {
        case .admonition(_, let title, _, _, _): return title
        case .heading(_, let content, _):
            return content.compactMap { if case .text(let t) = $0 { return t } else { return nil } }.joined()
        case .visualBlock(let name, _, _): return name
        case .widget(let title, _, _): return title
        case .tab(let title, _, _): return title
        case .stage(let kind, _, _): return kind.rawValue
        default: return nil
        }
    }

    private func isBlockNumbered(_ block: Block) -> Bool {
        switch block {
        case .admonition(let type, _, _, _, _):
            let numberedTypes = ["theorem", "lemma", "corollary", "proposition",
                                 "definition", "example", "figure", "table", "equation", "listing"]
            return numberedTypes.contains(type.lowercased())
        case .heading: return true
        case .table(_, _, let caption, _): return caption != nil
        default: return false
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

// MARK: - Scope Ancestry Tracker

/// Tracks parent-child relationships in the block tree for `ancestor=` selector matching.
///
/// Built once before Phase 2 execution. Maps each node's ID to its chain of ancestor IDs.
public struct Phase2ScopeTracker: Sendable, Equatable {
    /// Maps node ID → ordered list of ancestor IDs [immediate parent, grandparent, ...]
    private let ancestorMap: [String: [String]]

    public init(blocks: [Block]) {
        var map: [String: [String]] = [:]
        Phase2ScopeTracker.buildAncestorMap(blocks: blocks, currentAncestors: [], map: &map)
        self.ancestorMap = map
    }

    /// Get all ancestor IDs for a node.
    public func ancestors(of nodeId: String) -> [String] {
        ancestorMap[nodeId] ?? []
    }

    /// Check if a node is a descendant of a specific ancestor.
    public func isDescendant(_ nodeId: String, of ancestorId: String) -> Bool {
        ancestorMap[nodeId]?.contains(ancestorId) ?? false
    }

    /// Get ancestor IDs for a block (by checking its attributes).
    public func ancestorIds(for block: Block) -> [String] {
        guard let id = blockId(block) else { return [] }
        return ancestors(of: id)
    }

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

    private static func buildAncestorMap(
        blocks: [Block],
        currentAncestors: [String],
        map: inout [String: [String]]
    ) {
        for block in blocks {
            // Record this node's ancestors
            let nodeId: String?
            switch block {
            case .heading(_, _, let a): nodeId = a.id
            case .paragraph(_, let a): nodeId = a.id
            case .admonition(_, _, _, _, let a): nodeId = a.id
            case .div(_, let a): nodeId = a.id
            case .table(_, _, _, let a): nodeId = a.id
            case .codeBlock(_, _, let a): nodeId = a.id
            case .blockQuote(_, let a): nodeId = a.id
            case .list(_, _, let a): nodeId = a.id
            case .visualBlock(_, _, let a): nodeId = a.id
            case .widget(_, _, let a): nodeId = a.id
            case .tab(_, _, let a): nodeId = a.id
            case .stage(_, _, let a): nodeId = a.id
            case .lane(_, let a): nodeId = a.id
            case .module(_, _, _, let a): nodeId = a.id
            case .contractDirective(_, _, let a): nodeId = a.id
            default: nodeId = nil
            }

            if let id = nodeId {
                map[id] = currentAncestors
            }

            // Recurse into children with updated ancestor chain
            let childAncestors = nodeId.map { [String]( [$0] + currentAncestors) } ?? currentAncestors

            switch block {
            case .blockQuote(let children, _):
                buildAncestorMap(blocks: children, currentAncestors: childAncestors, map: &map)
            case .div(let children, _):
                buildAncestorMap(blocks: children, currentAncestors: childAncestors, map: &map)
            case .admonition(_, _, let children, _, _):
                buildAncestorMap(blocks: children, currentAncestors: childAncestors, map: &map)
            case .list(_, let items, _):
                for item in items {
                    buildAncestorMap(blocks: item.content, currentAncestors: childAncestors, map: &map)
                }
            case .visualBlock(_, let children, _):
                buildAncestorMap(blocks: children, currentAncestors: childAncestors, map: &map)
            case .widget(_, let children, _):
                buildAncestorMap(blocks: children, currentAncestors: childAncestors, map: &map)
            case .tab(_, let children, _):
                buildAncestorMap(blocks: children, currentAncestors: childAncestors, map: &map)
            case .stage(_, let children, _):
                buildAncestorMap(blocks: children, currentAncestors: childAncestors, map: &map)
            case .lane(let children, _):
                buildAncestorMap(blocks: children, currentAncestors: childAncestors, map: &map)
            case .module(_, _, let children, _):
                buildAncestorMap(blocks: children, currentAncestors: childAncestors, map: &map)
            default:
                break
            }
        }
    }
}
