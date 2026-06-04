import Foundation
import RhoeMarkdownModel

extension RhoeParser {

    /// Parse a composition directive block from `<<keyword ...>>` tokens.
    ///
    /// Routes by keyword to the appropriate handler:
    /// - `include` → transclusion block
    /// - `group` → grouped content block (for component slot binding)
    /// - `todo/doc/info/comment` → author annotation (opaque body)
    /// - `schema` → schema island (raw body)
    /// - `param/slot` → no-op at block level (resolved during component expansion)
    func parseCompositionDirective(
        _ state: inout RhoeParserState,
        keyword: String,
        argument: String?
    ) -> Block {
        let canonicalKeyword = keyword.lowercased()
        state.advance() // consume the compositionDirectiveOpen token

        switch canonicalKeyword {
        case "include":
            guard configuration.enableTransclusions else {
                return .paragraph([.text("<<include \(argument ?? "")>>")], attributes: .init())
            }
            return parseBlockTransclusion(&state, argument: argument)

        case "group":
            guard configuration.enableComponents else {
                return .paragraph([], attributes: .init())
            }
            return parseGroupBlock(&state, name: argument)

        case "todo", "doc", "info", "comment":
            guard configuration.enableAnnotations else {
                return .paragraph([], attributes: .init())
            }
            return parseAnnotationBlock(&state, keyword: canonicalKeyword, argument: argument)

        case "schema":
            guard configuration.enableSchemaIslands else {
                return .paragraph([], attributes: .init())
            }
            return parseSchemaIslandBlock(&state, schemaName: argument)

        case "param", "slot":
            // Self-contained at block level — skip
            return .paragraph([], attributes: RhoeMarkdownKit.Attributes())

        case "=":
            guard configuration.enableCoreExpressions else {
                return .paragraph([.text("<<= \(argument ?? "") >>")], attributes: .init())
            }
            return .expression(expr: argument ?? "")

        case "field":
            guard configuration.enableInputBindings else {
                return .paragraph([.text("<<field \(argument ?? "")>>")], attributes: .init())
            }
            return parseFieldDirective(argument: argument)

        case "form":
            guard configuration.enableInputBindings else {
                return .paragraph([], attributes: .init())
            }
            return parseFormBlock(&state, argument: argument)

        default:
            // Unknown directive keyword — produce empty paragraph
            return .paragraph([.text("<<\(keyword)>>")], attributes: RhoeMarkdownKit.Attributes())
        }
    }

    // MARK: - Transclusion

    /// Parse `<<include "path">>` or `<<include "path#fragment">>` at block level.
    private func parseBlockTransclusion(
        _ state: inout RhoeParserState,
        argument: String?
    ) -> Block {
        let attributes = consumeAttributeList(&state) ?? RhoeMarkdownKit.Attributes()

        guard let path = argument else {
            return .transclusion(target: "", fragment: nil, mode: .block, attributes: attributes)
        }

        // Split path#fragment
        let parts = path.split(separator: "#", maxSplits: 1)
        let target = String(parts[0])
        let fragment = parts.count > 1 ? String(parts[1]) : nil

        // Extract mode from attributes
        let mode: TransclusionMode? = attributes.keyValues["mode"].flatMap { TransclusionMode(rawValue: $0) }

        return .transclusion(target: target, fragment: fragment, mode: mode ?? .block, attributes: attributes)
    }

    // MARK: - Group

    /// Parse `<<group>>...<</group>>` or `<<group name>>...<</group>>`.
    private func parseGroupBlock(
        _ state: inout RhoeParserState,
        name: String?
    ) -> Block {
        let contentBlocks = collectCompositionContent(&state, closingKeyword: "group")
        consumeCompositionCloseIfPresent(&state, keyword: "group")

        var attributes = RhoeMarkdownKit.Attributes()
        if let name = name {
            attributes = RhoeMarkdownKit.Attributes(
                id: nil,
                classes: [],
                keyValues: ["slot-name": name.lowercased()]
            )
        }

        return .div(content: contentBlocks, attributes: attributes)
    }

    // MARK: - Author Annotations

    /// Parse `<<todo>>...<</todo>>` (and doc, info, comment).
    /// Body is OPAQUE — not parsed as Markdown.
    private func parseAnnotationBlock(
        _ state: inout RhoeParserState,
        keyword: String,
        argument: String?
    ) -> Block {
        let attributes = consumeAttributeList(&state) ?? RhoeMarkdownKit.Attributes()

        // If we have a quoted argument from the self-contained form, use it directly
        if let text = argument {
            guard let kind = AnnotationKind(rawValue: keyword) else {
                return .paragraph([.text("<<\(keyword) \"\(text)\">>")], attributes: RhoeMarkdownKit.Attributes())
            }
            return .authorAnnotation(kind: kind, text: text, attributes: attributes)
        }

        // Paired form: collect opaque body text until <</keyword>>
        let bodyText = collectOpaqueBody(&state, closingKeyword: keyword)
        consumeCompositionCloseIfPresent(&state, keyword: keyword)

        guard let kind = AnnotationKind(rawValue: keyword) else {
            return .paragraph([.text(bodyText)], attributes: RhoeMarkdownKit.Attributes())
        }
        return .authorAnnotation(kind: kind, text: bodyText, attributes: attributes)
    }

    // MARK: - Schema Island

    /// Parse `<<schema name>>...<</schema>>`.
    /// Body is captured as raw text for delegation to the named schema parser.
    private func parseSchemaIslandBlock(
        _ state: inout RhoeParserState,
        schemaName: String?
    ) -> Block {
        let attributes = consumeAttributeList(&state) ?? RhoeMarkdownKit.Attributes()
        let schema = (schemaName ?? "rhoemd").lowercased()

        // Collect raw body until <</schema>>
        let bodyText = collectOpaqueBody(&state, closingKeyword: "schema")
        consumeCompositionCloseIfPresent(&state, keyword: "schema")

        return .schemaIsland(schema: schema, body: bodyText, attributes: attributes)
    }

    // MARK: - Content Collection Helpers

    /// Collect parsed block content until a matching composition close token.
    private func collectCompositionContent(
        _ state: inout RhoeParserState,
        closingKeyword: String
    ) -> [Block] {
        collectBlocks(
            &state,
            until: { token, _ in
                if case .compositionDirectiveClose(let kw) = token.type,
                   kw.lowercased() == closingKeyword {
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

    /// Collect opaque (unparsed) body text until a matching composition close token.
    /// Used for annotations and schema islands where the body is NOT parsed as Markdown.
    private func collectOpaqueBody(
        _ state: inout RhoeParserState,
        closingKeyword: String
    ) -> String {
        var lines: [String] = []

        while let token = state.current {
            if case .compositionDirectiveClose(let kw) = token.type,
               kw.lowercased() == closingKeyword {
                break
            }
            if case .eof = token.type { break }

            // Accumulate the raw text content of each token
            let content = token.content
            if !content.isEmpty {
                lines.append(content)
            }
            state.advance()
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Consume a composition directive close token if present.
    private func consumeCompositionCloseIfPresent(
        _ state: inout RhoeParserState,
        keyword: String
    ) {
        if let token = state.current,
           case .compositionDirectiveClose(let kw) = token.type,
           kw.lowercased() == keyword {
            state.advance()
        }
    }

    // MARK: - Field Directive

    /// Parse `<<field name {type=text required}>>`.
    private func parseFieldDirective(argument: String?) -> Block {
        guard let argument, !argument.isEmpty else {
            return .field(name: "unnamed", fieldType: "text")
        }

        // Parse: "name {type=text required}" or "name"
        let parts = argument.split(separator: " ", maxSplits: 1)
        let name = String(parts[0])

        var attrs = RhoeMarkdownKit.Attributes()
        if parts.count > 1 {
            let remaining = String(parts[1]).trimmingCharacters(in: .whitespaces)
            if remaining.hasPrefix("{") && remaining.hasSuffix("}") {
                attrs = parseAttributes(from: String(remaining.dropFirst().dropLast()))
            }
        }

        let fieldType = attrs.keyValues["type"] ?? "text"
        return .field(name: name, fieldType: fieldType, attributes: attrs)
    }

    // MARK: - Form Block

    /// Parse `<<form {name=billing}>>` ... `<</form>>`.
    private func parseFormBlock(
        _ state: inout RhoeParserState,
        argument: String?
    ) -> Block {
        var attrs = RhoeMarkdownKit.Attributes()
        if let argument, !argument.isEmpty {
            if argument.hasPrefix("{") && argument.hasSuffix("}") {
                attrs = parseAttributes(from: String(argument.dropFirst().dropLast()))
            } else {
                attrs = RhoeMarkdownKit.Attributes(keyValues: ["name": argument])
            }
        }

        let formName = attrs.keyValues["name"] ?? attrs.id

        // Collect blocks until <</form>>
        var blocks: [Block] = []
        while let token = state.current {
            if case .compositionDirectiveClose(let kw) = token.type, kw.lowercased() == "form" {
                state.advance()
                break
            }
            if let block = parseBlock(&state) {
                blocks.append(block)
            } else {
                state.advance()
            }
        }

        return .form(name: formName, content: blocks, attributes: attrs)
    }
}
