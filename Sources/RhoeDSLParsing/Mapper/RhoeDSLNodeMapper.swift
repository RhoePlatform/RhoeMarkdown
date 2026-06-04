import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing

/// Maps parsed DSL nodes to canonical RhoeMarkdown AST blocks.
public enum DSLNodeMapper {

    /// Map a DSL node declaration to an AST Block.
    public static func mapToBlock(
        name: String,
        params: [String: DSLValue],
        bodyBlocks: [Block],
        bodyText: String?,
        configuration: RhoeMarkdownKit.Configuration
    ) -> Block? {
        let canonicalName = name.lowercased()
        let attrs = buildAttributes(from: params)

        // Headings: H1-H6
        if let level = DSLNodeRegistry.headingLevel(canonicalName) {
            let inlines = parseInlineMarkdown(bodyText ?? name)
            return .heading(level: level, content: inlines, attributes: attrs)
        }

        switch canonicalName {
        // Document structure
        case "document":
            return bodyBlocks.count == 1 ? bodyBlocks[0] : .div(content: bodyBlocks, attributes: attrs)

        case "section":
            return .div(content: bodyBlocks, attributes: attrs)

        // Prose
        case "paragraph", "p":
            let inlines = parseInlineMarkdown(bodyText ?? "")
            return .paragraph(inlines, attributes: attrs)

        // Quotes
        case "quote", "blockquote":
            return .blockQuote(bodyBlocks, attributes: attrs)

        // Lists
        case "list":
            let ordered = params["ordered"]?.stringValue == "true"
            let items = bodyBlocks.compactMap { blockToListItem($0) }
            if ordered {
                let start = Int(params["start"]?.stringValue ?? "1") ?? 1
                return .list(type: .ordered(start: start, style: .decimal), items: items, attributes: attrs)
            }
            return .list(type: .unordered, items: items, attributes: attrs)

        case "listitem":
            let inlines = parseInlineMarkdown(bodyText ?? "")
            return .paragraph(inlines, attributes: attrs) // Will be wrapped as ListItem by parent

        // Code
        case "code":
            let language = params["language"]?.stringValue
            return .codeBlock(language: language, content: bodyText ?? "", attributes: attrs)

        case "executablecode":
            let language = params["language"]?.stringValue ?? "python"
            var kv = attrs.keyValues
            kv["language"] = language
            if let timeout = params["timeout"]?.stringValue { kv["timeout"] = timeout }
            if let persist = params["persist"]?.stringValue { kv["persist"] = persist }
            if let runtime = params["runtime"]?.stringValue { kv["runtime"] = runtime }
            let execAttrs = RhoeMarkdownKit.Attributes(id: attrs.id, classes: attrs.classes, keyValues: kv)
            return .visualBlock(name: "code", content: [.codeBlock(language: language, content: bodyText ?? "", attributes: .init())], attributes: execAttrs)

        // Admonitions
        case "admonition":
            let kind = params["kind"]?.stringValue ?? "note"
            let title = params["title"]?.stringValue
            let collapsible: AdmonitionCollapsible? = params["collapsed"]?.stringValue == "true" ? .collapsed :
                                                       params["collapsed"]?.stringValue == "false" ? .expanded : nil
            return .admonition(type: kind, title: title, content: bodyBlocks, collapsible: collapsible, attributes: attrs)

        // Direct admonition types (note, warning, tip, etc.)
        case _ where DSLNodeRegistry.isAdmonitionType(canonicalName):
            let title = params["title"]?.stringValue
            return .admonition(type: canonicalName, title: title, content: bodyBlocks, collapsible: nil, attributes: attrs)

        // Theorem-family aliases
        case _ where DSLNodeRegistry.isTheoremType(canonicalName):
            let title = params["title"]?.stringValue
            return .admonition(type: canonicalName, title: title, content: bodyBlocks, collapsible: nil, attributes: attrs)

        // Speaker notes
        case "speakernotes":
            var kv = attrs.keyValues
            if kv["visible"] == nil { kv["visible"] = "presenter" }
            if kv["hidden"] == nil { kv["hidden"] = "audience,print,llm" }
            let speakerAttrs = RhoeMarkdownKit.Attributes(id: attrs.id, classes: attrs.classes, keyValues: kv)
            return .admonition(type: "speakernotes", title: nil, content: bodyBlocks, collapsible: nil, attributes: speakerAttrs)

        // Tables
        case "table":
            // Build table from structured children (TableHead/TableBody/TableRow/TableCell)
            let caption = params["caption"]?.stringValue.map { parseInlineMarkdown($0) }
            return buildTable(bodyBlocks: bodyBlocks, caption: caption, attrs: attrs)

        // Figures
        case "figure":
            return .div(content: bodyBlocks, attributes: attrs)

        case "image", "img":
            let src = params["src"]?.stringValue ?? ""
            let alt = params["alt"]?.stringValue ?? ""
            let title = params["title"]?.stringValue
            let inlines: [Inline] = [.image(alt: [.text(alt)], url: src, title: title, attributes: attrs)]
            return .paragraph(inlines, attributes: .init())

        case "caption":
            let inlines = parseInlineMarkdown(bodyText ?? "")
            return .paragraph(inlines, attributes: attrs)

        // Horizontal rule
        case "horizontalrule", "hr", "thematicbreak":
            return .horizontalRule

        // Divs
        case "div":
            return .div(content: bodyBlocks, attributes: attrs)

        // Line blocks
        case "lineblock":
            let lines = bodyBlocks.compactMap { block -> [Inline]? in
                if case .paragraph(let inlines, _) = block { return inlines }
                return nil
            }
            return .lineBlock(lines: lines)

        // Diagrams and shapes
        case "diagram":
            let engine = params["engine"]?.stringValue ?? "mermaid"
            return .visualBlock(name: engine, content: bodyText.map { [.codeBlock(language: engine, content: $0, attributes: .init())] } ?? [], attributes: attrs)

        case "shape":
            let shapeType = params["type"]?.stringValue ?? "rectangle"
            return .visualBlock(name: shapeType, content: [], attributes: attrs)

        // Extensions
        case "extension":
            let extName = params["name"]?.stringValue ?? "@unknown"
            return .admonition(type: extName, title: nil, content: bodyBlocks, collapsible: nil, attributes: attrs)

        // Definition list support
        case "definitionlist":
            // Complex — defer to structured children
            return .div(content: bodyBlocks, attributes: attrs)

        // Text (raw)
        case "text":
            return .paragraph([.text(bodyText ?? "")], attributes: attrs)

        // Markdown (explicit markdown parsing)
        case "markdown":
            let inlines = parseInlineMarkdown(bodyText ?? "")
            return .paragraph(inlines, attributes: attrs)

        // Slides
        case "deck", "slide":
            return .div(content: bodyBlocks, attributes: attrs)

        // Forms
        case "form":
            return .div(content: bodyBlocks, attributes: attrs)

        case "field":
            let fieldName = params["name"]?.stringValue ?? "field"
            var fields: [String: String] = ["name": fieldName]
            if let type = params["type"]?.stringValue { fields["type"] = type }
            if params["required"]?.stringValue == "true" { fields["required"] = "true" }
            if let placeholder = params["placeholder"]?.stringValue { fields["placeholder"] = placeholder }
            return .placeholder(fields: fields, attributes: attrs)

        // Grid, Columns
        case "grid", "columns":
            return .div(content: bodyBlocks, attributes: attrs)

        // Abbreviation definition
        case "abbreviationdefinition":
            let abbr = params["abbr"]?.stringValue ?? ""
            let expansion = params["expansion"]?.stringValue ?? ""
            return .abbreviationDefinition(abbreviation: abbr, expansion: expansion)

        default:
            // Unknown node — emit as div with diagnostic
            return .div(content: bodyBlocks, attributes: attrs)
        }
    }

    // MARK: - Helpers

    /// Build Attributes from DSL parameter map.
    private static func buildAttributes(from params: [String: DSLValue]) -> RhoeMarkdownKit.Attributes {
        var id: String? = nil
        var classes: [String] = []
        var keyValues: [String: String] = [:]

        for (key, value) in params {
            switch key {
            case "id":
                id = value.stringValue
            case "class":
                if let arr = value.stringArrayValue {
                    classes = arr
                } else if let s = value.stringValue {
                    classes = s.components(separatedBy: " ")
                }
            // Skip node-specific params that are handled explicitly
            case "kind", "title", "language", "ordered", "start", "checked",
                 "collapsed", "src", "alt", "name", "type", "engine",
                 "timeout", "persist", "runtime", "history",
                 "abbr", "expansion", "caption", "placeholder", "required":
                // These are consumed by the mapper, not stored as generic key-values
                break
            default:
                if let s = value.stringValue {
                    keyValues[key] = s
                } else if let arr = value.stringArrayValue {
                    keyValues[key] = arr.joined(separator: ",")
                }
            }
        }

        return RhoeMarkdownKit.Attributes(id: id, classes: classes, keyValues: keyValues)
    }

    /// Parse inline Markdown text into Inline elements.
    ///
    /// Uses a lightweight inline-only parse via the RhoeMarkdown lexer and parser.
    /// For the initial implementation, applies basic formatting detection.
    private static func parseInlineMarkdown(_ text: String) -> [Inline] {
        guard !text.isEmpty else { return [] }

        // Lightweight inline parsing: detect basic Markdown formatting
        // Full inline parsing would use the existing parser's inline pipeline,
        // but that requires async context and internal access.
        // For v1: parse bold, italic, code, and links inline.
        var result: [Inline] = []
        var current = ""
        var i = text.startIndex

        while i < text.endIndex {
            let char = text[i]
            let next = text.index(after: i)

            if char == "*" && next < text.endIndex && text[next] == "*" {
                // Bold: **text**
                if !current.isEmpty { result.append(.text(current)); current = "" }
                let afterStars = text.index(next, offsetBy: 1, limitedBy: text.endIndex) ?? text.endIndex
                if let end = text[afterStars...].range(of: "**") {
                    let boldText = String(text[afterStars..<end.lowerBound])
                    result.append(.strong(parseInlineMarkdown(boldText)))
                    i = end.upperBound
                    continue
                }
            } else if char == "*" && next < text.endIndex && text[next] != "*" {
                // Italic: *text*
                if !current.isEmpty { result.append(.text(current)); current = "" }
                if let end = text[next...].firstIndex(of: "*") {
                    let italicText = String(text[next..<end])
                    result.append(.emphasis(parseInlineMarkdown(italicText)))
                    i = text.index(after: end)
                    continue
                }
            } else if char == "`" {
                // Code: `text`
                if !current.isEmpty { result.append(.text(current)); current = "" }
                if let end = text[next...].firstIndex(of: "`") {
                    let codeText = String(text[next..<end])
                    result.append(.codeSpan(codeText, attributes: .init()))
                    i = text.index(after: end)
                    continue
                }
            }

            current.append(char)
            i = next
        }

        if !current.isEmpty { result.append(.text(current)) }
        return result.isEmpty ? [.text(text)] : result
    }

    /// Convert a block to a ListItem.
    private static func blockToListItem(_ block: Block) -> ListItem? {
        if case .paragraph(let inlines, _) = block {
            return ListItem(content: [.paragraph(inlines, attributes: .init())], checked: nil)
        }
        return ListItem(content: [block], checked: nil)
    }

    /// Build a table from structured DSL children.
    private static func buildTable(bodyBlocks: [Block], caption: [Inline]?, attrs: RhoeMarkdownKit.Attributes) -> Block {
        // For now, build a simple table from the children
        // Full table structure parsing would extract TableHead/TableBody/TableRow/TableCell
        var headers: [TableCell] = []
        var rows: [[TableCell]] = []

        for block in bodyBlocks {
            if case .div(let children, _) = block {
                let cells = children.compactMap { child -> TableCell? in
                    if case .paragraph(let inlines, _) = child {
                        return TableCell(content: inlines)
                    }
                    return nil
                }
                if headers.isEmpty {
                    headers = cells
                } else {
                    rows.append(cells)
                }
            }
        }

        return .table(headers: headers, rows: rows, caption: caption, attributes: attrs)
    }
}
