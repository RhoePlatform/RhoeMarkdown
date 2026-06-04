import Foundation
import RhoeMarkdownModel

extension RhoeParser {
    /// Parse a fenced div block from `:::` delimiters.
    ///
    /// The opening `:::` may be followed by a class name or attribute list.
    /// The closing `:::` must have at least as many colons as the opener.
    /// Content between the fences is parsed as nested blocks.
    func parseFencedDiv(
        _ state: inout RhoeParserState,
        name: String?,
        colons: Int
    ) -> Block {
        state.advance() // consume the fencedDivStart token

        let contentBlocks = collectFencedDivBlocks(&state, openColons: colons)
        consumeFencedDivEndIfPresent(&state, openColons: colons)

        // Build attributes from the name and/or the opening fence content
        var attributes = consumeAttributeList(&state) ?? RhoeMarkdownKit.Attributes()

        if let name = name, !name.isEmpty {
            if name.hasPrefix("{") && name.hasSuffix("}") {
                // Full attribute block as name: {.class #id key=val}
                let attrContent = String(name.dropFirst().dropLast())
                let parsed = parseAttributes(from: attrContent)
                attributes = RhoeMarkdownKit.Attributes(
                    id: parsed.id ?? attributes.id,
                    classes: parsed.classes + attributes.classes,
                    keyValues: parsed.keyValues.merging(attributes.keyValues) { a, _ in a }
                )
            } else if name.lowercased() == "component" {
                // Visual component declaration: ::: component {name=card ...}
                // Extract inline attributes from the fencedDivStart token's content
                var componentAttrs = attributes
                for i in stride(from: state.currentIndex - 1, through: 0, by: -1) {
                    if case .fencedDivStart = state.tokens[i].type {
                        let lineNum = state.tokens[i].line
                        if lineNum > 0 && lineNum <= state.sourceLines.count {
                            let sourceLine = state.sourceLines[lineNum - 1]
                            if let braceStart = sourceLine.firstIndex(of: "{"),
                               let braceEnd = sourceLine.lastIndex(of: "}") {
                                let attrContent = String(sourceLine[sourceLine.index(after: braceStart)..<braceEnd])
                                let parsed = parseAttributes(from: attrContent)
                                componentAttrs = RhoeMarkdownKit.Attributes(
                                    id: parsed.id ?? attributes.id,
                                    classes: parsed.classes + attributes.classes,
                                    keyValues: parsed.keyValues.merging(attributes.keyValues) { a, _ in a }
                                )
                            }
                        }
                        break
                    }
                }
                return parseVisualComponentDeclaration(
                    contentBlocks: contentBlocks,
                    attributes: componentAttrs
                )
            } else if name.hasPrefix("@") {
                let canonicalName = name.lowercased()
                let extensionName = String(canonicalName.dropFirst())
                let parts = extensionName.split(separator: ".", maxSplits: 1)
                if parts.count == 2 {
                    return .extension_(
                        vendor: String(parts[0]),
                        name: String(parts[1]),
                        content: contentBlocks,
                        attributes: attributes
                    )
                }
                return .visualBlock(name: canonicalName, content: contentBlocks, attributes: attributes)
            } else if name.first?.isLetter == true && !name.contains("#") {
                // Named visual block: ::: Circle, ::: Mermaid — block family doctrine.
                let canonicalName = name.lowercased()
                // NB-4: Stage execution syntax: ::: stage.rack, ::: stage.case, etc.
                if canonicalName.hasPrefix("stage.") {
                    let kindStr = String(canonicalName.dropFirst(6))
                    let kind = StageKind(rawValue: kindStr) ?? .rack
                    return .stage(kind: kind, content: contentBlocks, attributes: attributes)
                }
                // NB-4: Module execution syntax: ::: module.transform.map, etc.
                if canonicalName.hasPrefix("module.") {
                    let parts = canonicalName.dropFirst(7).split(separator: ".", maxSplits: 1)
                    let family = String(parts.first ?? "")
                    let moduleName = parts.count > 1 ? String(parts[1]) : ""
                    return .module(family: family, name: moduleName, content: contentBlocks, attributes: attributes)
                }
                // NB-4: Lane container: ::: lane
                if canonicalName == "lane" {
                    return .lane(content: contentBlocks, attributes: attributes)
                }
                if canonicalName == "widget" {
                    let title = attributes.keyValues["title"] ?? canonicalName
                    return .widget(title: title, content: contentBlocks, attributes: attributes)
                }
                if canonicalName == "tab" {
                    let title = attributes.keyValues["title"] ?? canonicalName
                    return .tab(title: title, content: contentBlocks, attributes: attributes)
                }
                if configuration.enableVisualBlocks {
                    return .visualBlock(name: canonicalName, content: contentBlocks, attributes: attributes)
                } else {
                    // Fallback: treat as class on a generic div
                    let merged = RhoeMarkdownKit.Attributes(
                        id: attributes.id,
                        classes: [name] + attributes.classes,
                        keyValues: attributes.keyValues
                    )
                    attributes = merged
                }
            } else {
                // Other patterns — treat the bare name as a class (legacy compat)
                let merged = RhoeMarkdownKit.Attributes(
                    id: attributes.id,
                    classes: [name] + attributes.classes,
                    keyValues: attributes.keyValues
                )
                attributes = merged
            }
        } else {
            // No name — check if the opening fence token's content has attributes
            // This handles `::: {.class}` where name is nil but content has { }
            let fencedDivToken = state.tokens[max(0, state.currentIndex - 1)]
            if case .fencedDivEnd = fencedDivToken.type {
                // Look backwards to find the fencedDivStart token
            }
            // Check the start token's content for embedded attributes
            for i in stride(from: state.currentIndex - 1, through: 0, by: -1) {
                if case .fencedDivStart(_, _) = state.tokens[i].type {
                    let content = state.tokens[i].content
                    // Extract {…} from content like "::: {.theorem}"
                    if let braceStart = content.firstIndex(of: "{"),
                       let braceEnd = content.lastIndex(of: "}") {
                        let attrContent = String(content[content.index(after: braceStart)..<braceEnd])
                        let parsed = parseAttributes(from: attrContent)
                        attributes = RhoeMarkdownKit.Attributes(
                            id: parsed.id ?? attributes.id,
                            classes: parsed.classes + attributes.classes,
                            keyValues: parsed.keyValues.merging(attributes.keyValues) { a, _ in a }
                        )
                    }
                    break
                }
            }
        }

        return .div(content: contentBlocks, attributes: attributes)
    }

    func collectFencedDivBlocks(
        _ state: inout RhoeParserState,
        openColons: Int
    ) -> [Block] {
        collectBlocks(
            &state,
            until: { token, _ in
                if case .fencedDivEnd(let closeColons) = token.type,
                   closeColons >= openColons {
                    return true
                }
                if case .eof = token.type { return true }
                return false
            },
            using: { state, blocks in
                let startIndex = state.currentIndex
                if let block = parseBlock(&state) {
                    blocks.append(block)
                } else if state.currentIndex == startIndex {
                    state.advance()
                }
            }
        )
    }

    /// Parse a visual component declaration from `::: component {name=card args=... slots=...}`.
    private func parseVisualComponentDeclaration(
        contentBlocks: [Block],
        attributes: RhoeMarkdownKit.Attributes
    ) -> Block {
        let name = (attributes.keyValues["name"] ?? "").lowercased()
        let args = attributes.keyValues["args"]
        let slots = attributes.keyValues["slots"]

        let cleanKV = attributes.keyValues.filter { $0.key != "name" && $0.key != "args" && $0.key != "slots" }
        let cleanAttrs = RhoeMarkdownKit.Attributes(id: attributes.id, classes: attributes.classes, keyValues: cleanKV)

        return .componentDeclaration(
            family: .visual,
            name: name,
            args: args,
            slots: slots,
            body: contentBlocks,
            attributes: cleanAttrs
        )
    }

    func consumeFencedDivEndIfPresent(
        _ state: inout RhoeParserState,
        openColons: Int
    ) {
        if let token = state.current,
           case .fencedDivEnd(let closeColons) = token.type,
           closeColons >= openColons {
            state.advance()
        }
    }
}
