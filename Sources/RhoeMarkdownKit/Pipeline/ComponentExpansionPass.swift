import Foundation
import RhoeMarkdownModel

/// Pipeline pass that collects component declarations, removes them from the
/// document, and expands component invocations (`x.name`) by substituting
/// parameters and binding slot content.
///
/// This pass runs BEFORE numbering and cross-reference resolution so that
/// expanded content (headings, theorems, figures) participates in numbering.
public struct ComponentExpansionPass: DocumentPass, Sendable {

    public init() {}

    public func process(_ document: RhoeMarkdownKit.Document) -> RhoeMarkdownKit.Document {
        // Phase 1: Collect all component declarations into a registry
        var registry: [String: ComponentEntry] = [:]
        collectDeclarations(from: document.blocks, into: &registry)

        guard !registry.isEmpty else { return document }

        // Phase 2: Remove declarations and expand invocations
        let expandedBlocks = expandBlocks(document.blocks, registry: registry)

        return RhoeMarkdownKit.Document(
            blocks: expandedBlocks,
            metadata: document.metadata
        )
    }

    // MARK: - Declaration Collection

    private func collectDeclarations(
        from blocks: [Block],
        into registry: inout [String: ComponentEntry]
    ) {
        for block in blocks {
            if case .componentDeclaration(let family, let name, let args, let slots, let body, _) = block {
                let canonicalName = "x.\(name.lowercased())"
                registry[canonicalName] = ComponentEntry(
                    family: family,
                    name: name,
                    args: parseArgSignature(args),
                    slots: parseSlotSpec(slots),
                    body: body
                )
            }
        }
    }

    // MARK: - Block Expansion

    private func expandBlocks(
        _ blocks: [Block],
        registry: [String: ComponentEntry]
    ) -> [Block] {
        var result: [Block] = []

        for block in blocks {
            switch block {
            case .componentDeclaration:
                continue

            case .admonition(let type, _, let content, _, let attrs):
                if let entry = resolveInvocation(type, registry: registry) {
                    let expanded = expandComponent(entry, invocationAttrs: attrs, invocationContent: content)
                    result.append(contentsOf: expanded)
                } else {
                    result.append(.admonition(
                        type: type, title: nil,
                        content: expandBlocks(content, registry: registry),
                        collapsible: nil, attributes: attrs
                    ))
                }

            case .visualBlock(let name, let content, let attrs):
                if let entry = resolveInvocation(name, registry: registry) {
                    let expanded = expandComponent(entry, invocationAttrs: attrs, invocationContent: content)
                    result.append(contentsOf: expanded)
                } else {
                    result.append(.visualBlock(
                        name: name,
                        content: expandBlocks(content, registry: registry),
                        attributes: attrs
                    ))
                }

            case .blockQuote(let content, let attrs):
                result.append(.blockQuote(expandBlocks(content, registry: registry), attributes: attrs))

            case .list(let type, let items, let attrs):
                let expandedItems = items.map { item in
                    ListItem(
                        content: expandBlocks(item.content, registry: registry),
                        checked: item.checked,
                        isLoose: item.isLoose
                    )
                }
                result.append(.list(type: type, items: expandedItems, attributes: attrs))

            case .div(let content, let attrs):
                result.append(.div(content: expandBlocks(content, registry: registry), attributes: attrs))

            case .widget(let title, let content, let attrs):
                result.append(.widget(title: title, content: expandBlocks(content, registry: registry), attributes: attrs))

            case .tab(let title, let content, let attrs):
                result.append(.tab(title: title, content: expandBlocks(content, registry: registry), attributes: attrs))

            case .stage(let kind, let content, let attrs):
                result.append(.stage(kind: kind, content: expandBlocks(content, registry: registry), attributes: attrs))

            case .lane(let content, let attrs):
                result.append(.lane(content: expandBlocks(content, registry: registry), attributes: attrs))

            case .module(let family, let name, let content, let attrs):
                result.append(.module(family: family, name: name, content: expandBlocks(content, registry: registry), attributes: attrs))

            default:
                result.append(block)
            }
        }

        return result
    }

    // MARK: - Invocation Resolution

    private func resolveInvocation(
        _ name: String,
        registry: [String: ComponentEntry]
    ) -> ComponentEntry? {
        let canonical = name.lowercased()
        if let entry = registry[canonical] { return entry }
        if !canonical.hasPrefix("x.") && !canonical.hasPrefix("x-") { return nil }
        let normalized = canonical.replacingOccurrences(of: "x-", with: "x.")
        return registry[normalized]
    }

    // MARK: - Component Expansion

    private func expandComponent(
        _ entry: ComponentEntry,
        invocationAttrs: RhoeMarkdownKit.Attributes,
        invocationContent: [Block]
    ) -> [Block] {
        let params = resolveParams(entry.args, from: invocationAttrs)
        let slots = resolveSlots(entry.slots, from: invocationContent)
        return substituteBody(entry.body, params: params, slots: slots)
    }

    private func resolveParams(
        _ argSpec: [ArgEntry],
        from attrs: RhoeMarkdownKit.Attributes
    ) -> [String: String] {
        var params: [String: String] = [:]
        for arg in argSpec {
            if let value = attrs.keyValues[arg.name] {
                params[arg.name] = value
            } else if let defaultValue = arg.defaultValue {
                params[arg.name] = defaultValue
            }
        }
        return params
    }

    private func resolveSlots(
        _ slotSpec: SlotSpec,
        from content: [Block]
    ) -> [String: [Block]] {
        var slots: [String: [Block]] = [:]
        var positionalIndex = 1
        var defaultContent: [Block] = []

        for block in content {
            if case .div(let divContent, let attrs) = block,
               let slotName = attrs.keyValues["slot-name"] {
                slots[slotName.lowercased()] = divContent
            } else {
                defaultContent.append(block)
                slots["\(positionalIndex)"] = [block]
                positionalIndex += 1
            }
        }

        if !defaultContent.isEmpty {
            slots["1"] = defaultContent
            slots["default"] = defaultContent
        }

        return slots
    }

    // MARK: - Body Substitution (All Block Types)

    private func substituteBody(
        _ body: [Block],
        params: [String: String],
        slots: [String: [Block]]
    ) -> [Block] {
        var result: [Block] = []

        for block in body {
            switch block {
            case .paragraph(let inlines, let attrs):
                let (substituted, insertedSlots) = substituteInlines(inlines, params: params, slots: slots)
                if !insertedSlots.isEmpty {
                    // Slot was inline — break paragraph into parts
                    if !substituted.isEmpty {
                        result.append(.paragraph(substituted, attributes: attrs))
                    }
                    result.append(contentsOf: insertedSlots)
                } else {
                    result.append(.paragraph(substituted, attributes: attrs))
                }

            case .heading(let level, let content, let attrs):
                let (substituted, _) = substituteInlines(content, params: params, slots: slots)
                result.append(.heading(level: level, content: substituted, attributes: attrs))

            case .admonition(let type, let title, let content, let collapsible, let attrs):
                let subTitle = title.map { substituteParamText($0, params: params) }
                result.append(.admonition(
                    type: substituteParamText(type, params: params),
                    title: subTitle,
                    content: substituteBody(content, params: params, slots: slots),
                    collapsible: collapsible, attributes: attrs
                ))

            case .visualBlock(let name, let content, let attrs):
                result.append(.visualBlock(
                    name: name,
                    content: substituteBody(content, params: params, slots: slots),
                    attributes: attrs
                ))

            case .widget(let title, let content, let attrs):
                result.append(.widget(
                    title: substituteParamText(title, params: params),
                    content: substituteBody(content, params: params, slots: slots),
                    attributes: attrs
                ))

            case .tab(let title, let content, let attrs):
                result.append(.tab(
                    title: substituteParamText(title, params: params),
                    content: substituteBody(content, params: params, slots: slots),
                    attributes: attrs
                ))

            case .stage(let kind, let content, let attrs):
                result.append(.stage(
                    kind: kind,
                    content: substituteBody(content, params: params, slots: slots),
                    attributes: attrs
                ))

            case .lane(let content, let attrs):
                result.append(.lane(
                    content: substituteBody(content, params: params, slots: slots),
                    attributes: attrs
                ))

            case .module(let family, let name, let content, let attrs):
                result.append(.module(
                    family: family, name: name,
                    content: substituteBody(content, params: params, slots: slots),
                    attributes: attrs
                ))

            case .blockQuote(let content, let attrs):
                result.append(.blockQuote(
                    substituteBody(content, params: params, slots: slots),
                    attributes: attrs
                ))

            case .div(let content, let attrs):
                result.append(.div(
                    content: substituteBody(content, params: params, slots: slots),
                    attributes: attrs
                ))

            case .list(let type, let items, let attrs):
                let subItems = items.map { item in
                    ListItem(
                        content: substituteBody(item.content, params: params, slots: slots),
                        checked: item.checked,
                        isLoose: item.isLoose
                    )
                }
                result.append(.list(type: type, items: subItems, attributes: attrs))

            case .definitionList(let items, let attrs):
                let subItems = items.map { item in
                    let (termSub, _) = substituteInlines(item.term, params: params, slots: slots)
                    let defSub = item.definitions.map { def in
                        substituteBody(def, params: params, slots: slots)
                    }
                    return DefinitionListItem(term: termSub, definitions: defSub)
                }
                result.append(.definitionList(items: subItems, attributes: attrs))

            case .codeBlock(let language, let content, let attrs):
                result.append(.codeBlock(
                    language: language,
                    content: substituteParamText(content, params: params),
                    attributes: attrs
                ))

            case .table(let headers, let rows, let caption, let attrs):
                let subHeaders = headers.map { cell in
                    let (inlines, _) = substituteInlines(cell.content, params: params, slots: slots)
                    return TableCell(content: inlines, alignment: cell.alignment)
                }
                let subRows = rows.map { row in
                    row.map { cell in
                        let (inlines, _) = substituteInlines(cell.content, params: params, slots: slots)
                        return TableCell(content: inlines, alignment: cell.alignment)
                    }
                }
                let subCaption = caption.map { cap -> [Inline] in
                    let (inlines, _) = substituteInlines(cap, params: params, slots: slots)
                    return inlines
                }
                result.append(.table(headers: subHeaders, rows: subRows, caption: subCaption, attributes: attrs))

            default:
                result.append(block)
            }
        }

        return result
    }

    // MARK: - Inline Substitution

    /// Substitute `paramRef` and `slotRef` inline nodes.
    /// Returns the substituted inlines and any slot blocks that were inserted (for block-level slot expansion).
    private func substituteInlines(
        _ inlines: [Inline],
        params: [String: String],
        slots: [String: [Block]]
    ) -> ([Inline], [Block]) {
        var resultInlines: [Inline] = []
        var insertedBlocks: [Block] = []

        for inline in inlines {
            switch inline {
            case .paramRef(let name):
                if let value = params[name.lowercased()] ?? params[name] {
                    resultInlines.append(.text(value))
                } else {
                    resultInlines.append(.text("<<param \(name)>>"))
                }

            case .slotRef(let name):
                let slotKey = name?.lowercased() ?? "default"
                if let slotContent = slots[slotKey] ?? slots["1"] {
                    insertedBlocks.append(contentsOf: slotContent)
                }

            case .emphasis(let content):
                let (sub, blocks) = substituteInlines(content, params: params, slots: slots)
                resultInlines.append(.emphasis(sub))
                insertedBlocks.append(contentsOf: blocks)

            case .strong(let content):
                let (sub, blocks) = substituteInlines(content, params: params, slots: slots)
                resultInlines.append(.strong(sub))
                insertedBlocks.append(contentsOf: blocks)

            case .strikethrough(let content):
                let (sub, blocks) = substituteInlines(content, params: params, slots: slots)
                resultInlines.append(.strikethrough(sub))
                insertedBlocks.append(contentsOf: blocks)

            case .link(let text, let url, let title, let attrs):
                let (sub, blocks) = substituteInlines(text, params: params, slots: slots)
                resultInlines.append(.link(text: sub, url: url, title: title, attributes: attrs))
                insertedBlocks.append(contentsOf: blocks)

            case .span(let content, let attrs):
                let (sub, blocks) = substituteInlines(content, params: params, slots: slots)
                resultInlines.append(.span(content: sub, attributes: attrs))
                insertedBlocks.append(contentsOf: blocks)

            case .text(let text):
                // Legacy fallback: also handle text-based <<param>> patterns
                resultInlines.append(.text(substituteParamText(text, params: params)))

            default:
                resultInlines.append(inline)
            }
        }

        return (resultInlines, insertedBlocks)
    }

    /// Substitute <<param name>> patterns in plain text (legacy/code block content).
    private func substituteParamText(
        _ text: String,
        params: [String: String]
    ) -> String {
        var result = text
        for (name, value) in params {
            result = result.replacingOccurrences(of: "<<param \(name)>>", with: value)
            result = result.replacingOccurrences(of: "<<param \(name.lowercased())>>", with: value)
        }
        return result
    }

    // MARK: - Argument Parsing

    private func parseArgSignature(_ args: String?) -> [ArgEntry] {
        guard let args = args else { return [] }
        return args.split(separator: ",").map { part in
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("=") {
                let parts = trimmed.split(separator: "=", maxSplits: 1)
                return ArgEntry(
                    name: String(parts[0]).trimmingCharacters(in: .whitespaces),
                    required: true,
                    defaultValue: String(parts[1]).trimmingCharacters(in: .whitespaces)
                )
            } else if trimmed.hasSuffix("?") {
                return ArgEntry(name: String(trimmed.dropLast()), required: false, defaultValue: nil)
            } else {
                return ArgEntry(name: trimmed, required: true, defaultValue: nil)
            }
        }
    }

    private func parseSlotSpec(_ slots: String?) -> SlotSpec {
        guard let slots = slots else { return .positional(count: 1) }
        if let count = Int(slots) { return .positional(count: count) }
        let names = slots.split(separator: ",").map {
            String($0).trimmingCharacters(in: .whitespaces).lowercased()
        }
        return .named(names)
    }
}

// MARK: - Supporting Types

private struct ComponentEntry: Sendable {
    let family: BlockFamily
    let name: String
    let args: [ArgEntry]
    let slots: SlotSpec
    let body: [Block]
}

private struct ArgEntry: Sendable {
    let name: String
    let required: Bool
    let defaultValue: String?
}

private enum SlotSpec: Sendable {
    case positional(count: Int)
    case named([String])
}
