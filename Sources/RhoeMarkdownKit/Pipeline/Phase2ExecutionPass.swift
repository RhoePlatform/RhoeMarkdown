import Foundation
import RhoeMarkdownModel

/// Executes Phase 2 semantic transform directives on the AST.
///
/// Collects all `.phase2Directive` nodes in source order, executes each
/// sequentially (each sees the AST state from all previous directives),
/// removes the directive nodes, and returns the transformed document.
///
/// Supports eight v1 commands: select, set, hide, show, collect, clone, move, annotate.
public struct Phase2ExecutionPass: DocumentPass, Sendable {
    public init() {}

    public func process(_ document: RhoeMarkdownKit.Document) -> RhoeMarkdownKit.Document {
        // 1. Collect directives in source order (depth-first)
        let directives = collectDirectives(from: document.blocks)
        guard !directives.isEmpty else { return document }

        // 2. Build scope tracker for ancestor matching
        var currentBlocks = document.blocks
        var namedSelections: [String: [Block]] = [:]

        // 3. Execute each directive sequentially
        for directive in directives {
            // Rebuild scope tracker after each mutation (ancestry may change)
            let scopeTracker = Phase2ScopeTracker(blocks: currentBlocks)
            currentBlocks = executeDirective(
                directive,
                on: currentBlocks,
                namedSelections: &namedSelections,
                scopeTracker: scopeTracker
            )
        }

        // 4. Remove directive nodes from the tree
        currentBlocks = removeDirectives(from: currentBlocks)

        return RhoeMarkdownKit.Document(blocks: currentBlocks, metadata: document.metadata)
    }

    // MARK: - Directive Collection

    private func collectDirectives(from blocks: [Block]) -> [(command: String, arguments: [String: String], body: String?)] {
        var result: [(command: String, arguments: [String: String], body: String?)] = []
        for block in blocks {
            if case .phase2Directive(let command, var arguments, let body, _) = block {
                // If we have a block form body, parse its clauses into arguments
                if let body, arguments.isEmpty {
                    arguments = parseBlockFormClauses(body)
                }
                result.append((command: command, arguments: arguments, body: body))
            }
            // Recurse into nested blocks
            for nested in nestedBlocks(block) {
                if case .phase2Directive(let command, var arguments, let body, _) = nested {
                    if let body, arguments.isEmpty {
                        arguments = parseBlockFormClauses(body)
                    }
                    result.append((command: command, arguments: arguments, body: body))
                }
            }
        }
        return result
    }

    /// Parse block form body clauses into argument key-value pairs.
    ///
    /// Input:
    /// ```
    /// select: family=theorem in=#chapter-2
    /// into: #theorem-index
    /// group-by: section
    /// sort: number
    /// label: Key Definitions
    /// ```
    /// Output: ["family": "theorem", "in": "#chapter-2", "into": "#theorem-index", "group-by": "section", "sort": "number", "label": "Key Definitions"]
    private func parseBlockFormClauses(_ body: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in body.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Parse "key: value" format
            if let colonIdx = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[trimmed.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

                if key == "select" {
                    // The select clause contains selector atoms — parse them into individual args
                    let atoms = value.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    for atom in atoms {
                        if let eqIdx = atom.firstIndex(of: "=") {
                            let atomKey = String(atom[atom.startIndex..<eqIdx])
                            let atomValue = String(atom[atom.index(after: eqIdx)...])
                                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                            result[atomKey] = atomValue
                        }
                    }
                } else if key == "with" {
                    // with clause may have "key=value" format
                    result["with"] = value
                } else {
                    result[key] = value
                }
            }
        }
        return result
    }

    // MARK: - Directive Execution

    private func executeDirective(
        _ directive: (command: String, arguments: [String: String], body: String?),
        on blocks: [Block],
        namedSelections: inout [String: [Block]],
        scopeTracker: Phase2ScopeTracker
    ) -> [Block] {
        let selector = Phase2Selector(from: directive.arguments)

        switch directive.command {
        case "select":
            let name = directive.arguments["as"] ?? "default"
            namedSelections[name] = selectMatching(selector, in: blocks, scopeTracker: scopeTracker)
            return blocks

        case "hide":
            let domain = directive.arguments["in"] ?? "all"
            // For hide/show, "in=" is the projection domain, not a container scope
            let hideSelector = Phase2Selector(from: directive.arguments.filter { $0.key != "in" })
            return transformMatching(hideSelector, in: blocks) { block in
                addHidden(block, domain: domain)
            }

        case "show":
            let domain = directive.arguments["in"] ?? "all"
            let showSelector = Phase2Selector(from: directive.arguments.filter { $0.key != "in" })
            return transformMatching(showSelector, in: blocks) { block in
                addVisible(block, domain: domain)
            }

        case "set":
            return transformMatching(selector, in: blocks) { block in
                setMetadata(block, from: directive.arguments)
            }

        case "annotate":
            return transformMatching(selector, in: blocks) { block in
                annotateBlock(block, from: directive.arguments)
            }

        case "collect":
            let targetId = directive.arguments["into"]?.replacingOccurrences(of: "#", with: "") ?? "collected"
            if let fromName = directive.arguments["from"], let named = namedSelections[fromName] {
                return insertCollected(named, at: targetId, in: blocks)
            }
            let matched = selectMatching(selector, in: blocks, scopeTracker: scopeTracker)
            return insertCollected(matched, at: targetId, in: blocks)

        case "clone":
            let targetId = directive.arguments["into"]?.replacingOccurrences(of: "#", with: "") ?? "cloned"
            let matched = selectMatching(selector, in: blocks, scopeTracker: scopeTracker)
            // Clone with new IDs to avoid collisions (spec §4.6)
            let cloned = cloneWithNewIds(matched)
            return insertCollected(cloned, at: targetId, in: blocks)

        case "move":
            let targetId = directive.arguments["into"]?.replacingOccurrences(of: "#", with: "") ?? "moved"
            let matched = selectMatching(selector, in: blocks, scopeTracker: scopeTracker)
            var remaining = removeMatching(selector, from: blocks)
            remaining = insertCollected(matched, at: targetId, in: remaining)
            return remaining

        default:
            return blocks
        }
    }

    // MARK: - Selection

    private func selectMatching(
        _ selector: Phase2Selector,
        in blocks: [Block],
        containerId: String? = nil,
        scopeTracker: Phase2ScopeTracker = Phase2ScopeTracker(blocks: [])
    ) -> [Block] {
        var result: [Block] = []
        for block in blocks {
            let blockId = blockAttributes(block)?.id
            let ancestors = scopeTracker.ancestorIds(for: block)

            if selector.matches(block, containerId: containerId, ancestorIds: ancestors) {
                result.append(block)
            }

            // Recurse into children with this block's ID as containerId
            let childContainerId = blockId ?? containerId
            let children = nestedBlocks(block)
            if !children.isEmpty {
                result += selectMatching(selector, in: children, containerId: childContainerId, scopeTracker: scopeTracker)
            }
        }
        return result
    }

    // MARK: - Transformation

    private func transformMatching(
        _ selector: Phase2Selector,
        in blocks: [Block],
        transform: (Block) -> Block
    ) -> [Block] {
        blocks.map { block in
            if selector.matches(block) {
                return transform(block)
            }
            return transformNested(block, selector: selector, transform: transform)
        }
    }

    private func transformNested(
        _ block: Block,
        selector: Phase2Selector,
        transform: (Block) -> Block
    ) -> Block {
        switch block {
        case .blockQuote(let nested, let attrs):
            return .blockQuote(transformMatching(selector, in: nested, transform: transform), attributes: attrs)
        case .list(let type, let items, let attrs):
            let transformed = items.map { item in
                ListItem(
                    content: transformMatching(selector, in: item.content, transform: transform),
                    checked: item.checked,
                    isLoose: item.isLoose
                )
            }
            return .list(type: type, items: transformed, attributes: attrs)
        case .div(let nested, let attrs):
            return .div(content: transformMatching(selector, in: nested, transform: transform), attributes: attrs)
        case .admonition(let type, let title, let content, let collapsible, let attrs):
            return .admonition(type: type, title: title,
                             content: transformMatching(selector, in: content, transform: transform),
                             collapsible: collapsible, attributes: attrs)
        case .visualBlock(let name, let content, let attrs):
            return .visualBlock(name: name,
                              content: transformMatching(selector, in: content, transform: transform),
                              attributes: attrs)
        case .widget(let title, let content, let attrs):
            return .widget(title: title,
                          content: transformMatching(selector, in: content, transform: transform),
                          attributes: attrs)
        case .tab(let title, let content, let attrs):
            return .tab(title: title,
                       content: transformMatching(selector, in: content, transform: transform),
                       attributes: attrs)
        case .stage(let kind, let content, let attrs):
            return .stage(kind: kind,
                         content: transformMatching(selector, in: content, transform: transform),
                         attributes: attrs)
        case .lane(let content, let attrs):
            return .lane(content: transformMatching(selector, in: content, transform: transform),
                        attributes: attrs)
        case .module(let family, let name, let content, let attrs):
            return .module(family: family, name: name,
                          content: transformMatching(selector, in: content, transform: transform),
                          attributes: attrs)
        default:
            return block
        }
    }

    // MARK: - Metadata Mutation

    private func addHidden(_ block: Block, domain: String) -> Block {
        updateAttributes(block) { attrs in
            var kv = attrs.keyValues
            let existing = kv["hidden"] ?? ""
            kv["hidden"] = existing.isEmpty ? domain : "\(existing),\(domain)"
            return RhoeMarkdownKit.Attributes(id: attrs.id, classes: attrs.classes, keyValues: kv)
        }
    }

    private func addVisible(_ block: Block, domain: String) -> Block {
        updateAttributes(block) { attrs in
            var kv = attrs.keyValues
            let existing = kv["visible"] ?? ""
            kv["visible"] = existing.isEmpty ? domain : "\(existing),\(domain)"
            return RhoeMarkdownKit.Attributes(id: attrs.id, classes: attrs.classes, keyValues: kv)
        }
    }

    private func setMetadata(_ block: Block, from arguments: [String: String]) -> Block {
        updateAttributes(block) { attrs in
            var kv = attrs.keyValues
            for (key, value) in arguments where key != "for" && key != "family" && key != "role" && key != "id" && key != "class" && key != "in" {
                kv[key] = value
            }
            return RhoeMarkdownKit.Attributes(id: attrs.id, classes: attrs.classes, keyValues: kv)
        }
    }

    private func annotateBlock(_ block: Block, from arguments: [String: String]) -> Block {
        updateAttributes(block) { attrs in
            var kv = attrs.keyValues
            if let withValue = arguments["with"] {
                // Parse "key=value" from with clause
                let parts = withValue.components(separatedBy: "=")
                if parts.count == 2 {
                    kv[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                }
            }
            // Also set any direct key=value arguments that aren't selector atoms
            for (key, value) in arguments where !["family", "role", "id", "class", "in", "with", "for", "from", "as"].contains(key) {
                kv[key] = value
            }
            return RhoeMarkdownKit.Attributes(id: attrs.id, classes: attrs.classes, keyValues: kv)
        }
    }

    // MARK: - Structural Operations

    private func removeMatching(_ selector: Phase2Selector, from blocks: [Block]) -> [Block] {
        blocks.compactMap { block in
            if selector.matches(block) { return nil }
            switch block {
            case .blockQuote(let nested, let attrs):
                let filtered = removeMatching(selector, from: nested)
                return filtered.isEmpty ? nil : .blockQuote(filtered, attributes: attrs)
            case .div(let nested, let attrs):
                let filtered = removeMatching(selector, from: nested)
                return filtered.isEmpty ? nil : .div(content: filtered, attributes: attrs)
            case .admonition(let type, let title, let content, let collapsible, let attrs):
                let filtered = removeMatching(selector, from: content)
                return .admonition(type: type, title: title, content: filtered, collapsible: collapsible, attributes: attrs)
            case .visualBlock(let name, let content, let attrs):
                let filtered = removeMatching(selector, from: content)
                return .visualBlock(name: name, content: filtered, attributes: attrs)
            case .widget(let title, let content, let attrs):
                let filtered = removeMatching(selector, from: content)
                return .widget(title: title, content: filtered, attributes: attrs)
            case .tab(let title, let content, let attrs):
                let filtered = removeMatching(selector, from: content)
                return .tab(title: title, content: filtered, attributes: attrs)
            case .stage(let kind, let content, let attrs):
                let filtered = removeMatching(selector, from: content)
                return .stage(kind: kind, content: filtered, attributes: attrs)
            case .lane(let content, let attrs):
                let filtered = removeMatching(selector, from: content)
                return .lane(content: filtered, attributes: attrs)
            case .module(let family, let name, let content, let attrs):
                let filtered = removeMatching(selector, from: content)
                return .module(family: family, name: name, content: filtered, attributes: attrs)
            case .list(let type, let items, let attrs):
                let filtered = items.map {
                    ListItem(
                        content: removeMatching(selector, from: $0.content),
                        checked: $0.checked,
                        isLoose: $0.isLoose
                    )
                }
                return .list(type: type, items: filtered, attributes: attrs)
            default:
                return block
            }
        }
    }

    /// Clone blocks with new unique IDs to avoid duplication conflicts (spec §4.6).
    private func cloneWithNewIds(_ blocks: [Block]) -> [Block] {
        blocks.map { block in
            updateAttributes(block) { attrs in
                RhoeMarkdownKit.Attributes(
                    id: attrs.id != nil ? "clone-\(UUID().uuidString.prefix(8))" : nil,
                    classes: attrs.classes,
                    keyValues: attrs.keyValues
                )
            }
        }
    }

    private func insertCollected(_ collected: [Block], at targetId: String, in blocks: [Block]) -> [Block] {
        blocks.flatMap { block -> [Block] in
            switch block {
            case .div(let nested, let attrs) where attrs.id == targetId:
                return [.div(content: nested + collected, attributes: attrs)]
            case .div(let nested, let attrs):
                return [.div(content: insertCollected(collected, at: targetId, in: nested), attributes: attrs)]
            case .admonition(let type, let title, let content, let collapsible, let attrs) where attrs.id == targetId:
                return [.admonition(type: type, title: title, content: content + collected, collapsible: collapsible, attributes: attrs)]
            case .admonition(let type, let title, let content, let collapsible, let attrs):
                return [.admonition(type: type, title: title, content: insertCollected(collected, at: targetId, in: content), collapsible: collapsible, attributes: attrs)]
            case .blockQuote(let nested, let attrs):
                return [.blockQuote(insertCollected(collected, at: targetId, in: nested), attributes: attrs)]
            case .visualBlock(let name, let content, let attrs) where attrs.id == targetId:
                return [.visualBlock(name: name, content: content + collected, attributes: attrs)]
            case .visualBlock(let name, let content, let attrs):
                return [.visualBlock(name: name, content: insertCollected(collected, at: targetId, in: content), attributes: attrs)]
            case .widget(let title, let content, let attrs) where attrs.id == targetId:
                return [.widget(title: title, content: content + collected, attributes: attrs)]
            case .widget(let title, let content, let attrs):
                return [.widget(title: title, content: insertCollected(collected, at: targetId, in: content), attributes: attrs)]
            case .tab(let title, let content, let attrs) where attrs.id == targetId:
                return [.tab(title: title, content: content + collected, attributes: attrs)]
            case .tab(let title, let content, let attrs):
                return [.tab(title: title, content: insertCollected(collected, at: targetId, in: content), attributes: attrs)]
            case .stage(let kind, let content, let attrs) where attrs.id == targetId:
                return [.stage(kind: kind, content: content + collected, attributes: attrs)]
            case .stage(let kind, let content, let attrs):
                return [.stage(kind: kind, content: insertCollected(collected, at: targetId, in: content), attributes: attrs)]
            case .lane(let content, let attrs) where attrs.id == targetId:
                return [.lane(content: content + collected, attributes: attrs)]
            case .lane(let content, let attrs):
                return [.lane(content: insertCollected(collected, at: targetId, in: content), attributes: attrs)]
            case .module(let family, let name, let content, let attrs) where attrs.id == targetId:
                return [.module(family: family, name: name, content: content + collected, attributes: attrs)]
            case .module(let family, let name, let content, let attrs):
                return [.module(family: family, name: name, content: insertCollected(collected, at: targetId, in: content), attributes: attrs)]
            default:
                if let attrs = blockAttributes(block), attrs.id == targetId {
                    return [block] + collected
                }
                return [block]
            }
        }
    }

    // MARK: - Cleanup

    private func removeDirectives(from blocks: [Block]) -> [Block] {
        blocks.compactMap { block in
            if case .phase2Directive = block { return nil }
            switch block {
            case .blockQuote(let nested, let attrs):
                return .blockQuote(removeDirectives(from: nested), attributes: attrs)
            case .div(let nested, let attrs):
                return .div(content: removeDirectives(from: nested), attributes: attrs)
            case .admonition(let type, let title, let content, let collapsible, let attrs):
                return .admonition(type: type, title: title, content: removeDirectives(from: content),
                                 collapsible: collapsible, attributes: attrs)
            case .list(let type, let items, let attrs):
                let cleaned = items.map {
                    ListItem(
                        content: removeDirectives(from: $0.content),
                        checked: $0.checked,
                        isLoose: $0.isLoose
                    )
                }
                return .list(type: type, items: cleaned, attributes: attrs)
            case .widget(let title, let content, let attrs):
                return .widget(title: title, content: removeDirectives(from: content), attributes: attrs)
            case .tab(let title, let content, let attrs):
                return .tab(title: title, content: removeDirectives(from: content), attributes: attrs)
            case .stage(let kind, let content, let attrs):
                return .stage(kind: kind, content: removeDirectives(from: content), attributes: attrs)
            case .lane(let content, let attrs):
                return .lane(content: removeDirectives(from: content), attributes: attrs)
            case .module(let family, let name, let content, let attrs):
                return .module(family: family, name: name, content: removeDirectives(from: content), attributes: attrs)
            default:
                return block
            }
        }
    }

    // MARK: - Helpers

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

    private func updateAttributes(_ block: Block, transform: (RhoeMarkdownKit.Attributes) -> RhoeMarkdownKit.Attributes) -> Block {
        switch block {
        case .paragraph(let inlines, let attrs):
            return .paragraph(inlines, attributes: transform(attrs))
        case .heading(let level, let content, let attrs):
            return .heading(level: level, content: content, attributes: transform(attrs))
        case .admonition(let type, let title, let content, let collapsible, let attrs):
            return .admonition(type: type, title: title, content: content, collapsible: collapsible, attributes: transform(attrs))
        case .div(let content, let attrs):
            return .div(content: content, attributes: transform(attrs))
        case .table(let headers, let rows, let caption, let attrs):
            return .table(headers: headers, rows: rows, caption: caption, attributes: transform(attrs))
        case .codeBlock(let lang, let content, let attrs):
            return .codeBlock(language: lang, content: content, attributes: transform(attrs))
        case .blockQuote(let content, let attrs):
            return .blockQuote(content, attributes: transform(attrs))
        case .list(let type, let items, let attrs):
            return .list(type: type, items: items, attributes: transform(attrs))
        case .visualBlock(let name, let content, let attrs):
            return .visualBlock(name: name, content: content, attributes: transform(attrs))
        case .placeholder(let fields, let attrs):
            return .placeholder(fields: fields, attributes: transform(attrs))
        case .widget(let title, let content, let attrs):
            return .widget(title: title, content: content, attributes: transform(attrs))
        case .tab(let title, let content, let attrs):
            return .tab(title: title, content: content, attributes: transform(attrs))
        case .stage(let kind, let content, let attrs):
            return .stage(kind: kind, content: content, attributes: transform(attrs))
        case .lane(let content, let attrs):
            return .lane(content: content, attributes: transform(attrs))
        case .module(let family, let name, let content, let attrs):
            return .module(family: family, name: name, content: content, attributes: transform(attrs))
        case .contractDirective(let kind, let content, let attrs):
            return .contractDirective(kind: kind, content: content, attributes: transform(attrs))
        default:
            return block
        }
    }

    private func blockAttributes(_ block: Block) -> RhoeMarkdownKit.Attributes? {
        switch block {
        case .heading(_, _, let a): return a
        case .paragraph(_, let a): return a
        case .admonition(_, _, _, _, let a): return a
        case .div(_, let a): return a
        case .table(_, _, _, let a): return a
        case .codeBlock(_, _, let a): return a
        case .blockQuote(_, let a): return a
        case .list(_, _, let a): return a
        case .visualBlock(_, _, let a): return a
        case .placeholder(_, let a): return a
        case .definitionList(_, let a): return a
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
