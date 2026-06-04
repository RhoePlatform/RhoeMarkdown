import Foundation
import RhoeMarkdownModel

/// Converts a canonical AST (parsed from RhoeMarkdown) to RhoeDSL source text.
///
/// Produces well-formatted DSL source with consistent indentation. Semantic fidelity
/// is mandatory — the converted DSL must produce the same canonical AST when re-parsed.
/// Exact whitespace preservation is NOT guaranteed.
public struct MarkdownToDSLConverter: Sendable {

    private let indentWidth: Int

    public init(indentWidth: Int = 4) {
        self.indentWidth = indentWidth
    }

    /// Convert a full document to DSL source.
    public func convert(_ document: RhoeMarkdownKit.Document) -> String {
        var output = ""
        for block in document.blocks {
            output += convertBlock(block, depth: 0)
        }
        return output
    }

    // MARK: - Block Conversion

    private func convertBlock(_ block: Block, depth: Int) -> String {
        let indent = String(repeating: " ", count: depth * indentWidth)

        switch block {
        case .heading(let level, let content, let attrs):
            let name = "H\(level)"
            let params = attributeParams(attrs)
            let body = inlinesToText(content)
            return "\(indent)\(name)\(params) { \(body) }\n"

        case .section(let level, let title, let children, let attrs):
            let name = "H\(level)"
            let params = attributeParams(attrs)
            let body = inlinesToText(title)
            var result = "\(indent)\(name)\(params) { \(body) }\n"
            for child in children {
                result += convertBlock(child, depth: depth)
            }
            return result

        case .paragraph(let inlines, let attrs):
            // Check for lone image → Image node
            if inlines.count == 1, case .image(let alt, let url, let title, let imgAttrs) = inlines[0] {
                var params: [String: String] = ["src": url]
                let altText = inlinesToText(alt)
                if !altText.isEmpty { params["alt"] = altText }
                if let t = title { params["title"] = t }
                let mergedAttrs = mergeAttributes(attrs, imgAttrs)
                let paramStr = formatParams(params, attrs: mergedAttrs)
                return "\(indent)Image\(paramStr)\n"
            }

            let body = inlinesToText(inlines)
            let params = attributeParams(attrs)
            return "\(indent)Paragraph\(params) { \(body) }\n"

        case .blockQuote(let blocks, let attrs):
            let params = attributeParams(attrs)
            var result = "\(indent)Quote\(params) {\n"
            for b in blocks { result += convertBlock(b, depth: depth + 1) }
            result += "\(indent)}\n"
            return result

        case .list(let type, let items, let attrs):
            var params: [String: String] = [:]
            switch type {
            case .ordered(let start, _):
                params["ordered"] = "true"
                if start != 1 { params["start"] = "\(start)" }
            case .unordered: break
            case .task: break
            }
            let paramStr = formatParams(params, attrs: attrs)
            var result = "\(indent)List\(paramStr) {\n"
            for item in items {
                result += convertListItem(item, depth: depth + 1)
            }
            result += "\(indent)}\n"
            return result

        case .codeBlock(let language, let content, let attrs):
            var params: [String: String] = [:]
            if let lang = language { params["language"] = lang }
            let paramStr = formatParams(params, attrs: attrs)
            var result = "\(indent)Code\(paramStr) {\n"
            for line in content.components(separatedBy: "\n") {
                result += "\(indent)\(String(repeating: " ", count: indentWidth))\(line)\n"
            }
            result += "\(indent)}\n"
            return result

        case .horizontalRule:
            return "\(indent)HorizontalRule\n"

        case .table(let headers, let rows, let caption, let attrs):
            var params: [String: String] = [:]
            if let cap = caption { params["caption"] = inlinesToText(cap) }
            let paramStr = formatParams(params, attrs: attrs)
            var result = "\(indent)Table\(paramStr) {\n"
            let inner = String(repeating: " ", count: (depth + 1) * indentWidth)
            let cellIndent = String(repeating: " ", count: (depth + 2) * indentWidth)
            // Header row
            result += "\(inner)TableRow {\n"
            for cell in headers {
                result += "\(cellIndent)TableCell { \(inlinesToText(cell.content)) }\n"
            }
            result += "\(inner)}\n"
            // Data rows
            for row in rows {
                result += "\(inner)TableRow {\n"
                for cell in row {
                    result += "\(cellIndent)TableCell { \(inlinesToText(cell.content)) }\n"
                }
                result += "\(inner)}\n"
            }
            result += "\(indent)}\n"
            return result

        case .definitionList(let items, let attrs):
            let params = attributeParams(attrs)
            var result = "\(indent)DefinitionList\(params) {\n"
            let inner = String(repeating: " ", count: (depth + 1) * indentWidth)
            for item in items {
                result += "\(inner)// Term: \(inlinesToText(item.term))\n"
                for def in item.definitions {
                    for b in def { result += convertBlock(b, depth: depth + 1) }
                }
            }
            result += "\(indent)}\n"
            return result

        case .footnoteDefinition(let id, let content):
            var result = "\(indent)// Footnote [\(id)]\n"
            for b in content { result += convertBlock(b, depth: depth) }
            return result

        case .admonition(let type, let title, let content, let collapsible, let attrs):
            // Theorem-family and admonition types
            let nodeName = DSLNodeRegistry.isTheoremType(type) ? type.capitalized :
                           DSLNodeRegistry.isAdmonitionType(type) ? "Admonition" : type.capitalized
            var params: [String: String] = [:]
            if nodeName == "Admonition" { params["kind"] = type }
            if let t = title { params["title"] = t }
            if let c = collapsible {
                params["collapsed"] = c == .collapsed ? "true" : "false"
            }
            let paramStr = formatParams(params, attrs: attrs)
            if content.isEmpty {
                return "\(indent)\(nodeName)\(paramStr)\n"
            }
            var result = "\(indent)\(nodeName)\(paramStr) {\n"
            for b in content { result += convertBlock(b, depth: depth + 1) }
            result += "\(indent)}\n"
            return result

        case .html(let rawHTML):
            return "\(indent)// Raw HTML: \(rawHTML.prefix(60))...\n"

        case .div(let content, let attrs):
            let params = attributeParams(attrs)
            var result = "\(indent)Div\(params) {\n"
            for b in content { result += convertBlock(b, depth: depth + 1) }
            result += "\(indent)}\n"
            return result

        case .lineBlock(let lines):
            var result = "\(indent)LineBlock {\n"
            let inner = String(repeating: " ", count: (depth + 1) * indentWidth)
            for line in lines {
                result += "\(inner)Paragraph { \(inlinesToText(line)) }\n"
            }
            result += "\(indent)}\n"
            return result

        case .abbreviationDefinition(let abbr, let expansion):
            return "\(indent)AbbreviationDefinition(abbr: \"\(abbr)\", expansion: \"\(expansion)\")\n"

        case .visualBlock(let name, let content, let attrs):
            let params = attributeParams(attrs)
            if content.isEmpty {
                return "\(indent)Shape(type: \"\(name)\")\(params)\n"
            }
            var result = "\(indent)Diagram(engine: \"\(name)\")\(params) {\n"
            for b in content { result += convertBlock(b, depth: depth + 1) }
            result += "\(indent)}\n"
            return result

        case .authorAnnotation(let kind, let text, _):
            return "\(indent)// \(kind): \(text)\n"

        case .transclusion(let target, let fragment, _, let attrs):
            let frag = fragment.map { "#\($0)" } ?? ""
            let params = attributeParams(attrs)
            return "\(indent)// <<include \"\(target)\(frag)\">>\(params)\n"

        case .schemaIsland(let schema, let body, _):
            return "\(indent)// Schema(\"\(schema)\"): \(body.prefix(60))...\n"

        case .componentDeclaration:
            return "\(indent)// Component declaration\n"

        case .phase2Directive(let cmd, let args, _, _):
            let argStr = args.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            return "\(indent)// {@ \(cmd) \(argStr) @}\n"

        case .placeholder(let fields, _):
            let fieldStr = fields.map { "\($0.key): \"\($0.value)\"" }.joined(separator: ", ")
            return "\(indent)Field(\(fieldStr))\n"

        case .expression(let expr, let attrs):
            let params = attributeParams(attrs)
            return "\(indent)Expression\(params) { \(expr) }\n"

        case .field(let name, let fieldType, let attrs):
            let p: [String: String] = ["name": name, "type": fieldType]
            let paramStr = formatParams(p, attrs: attrs)
            return "\(indent)InputField\(paramStr)\n"

        case .form(let name, let content, let attrs):
            var p: [String: String] = [:]
            if let name { p["name"] = name }
            let paramStr = formatParams(p, attrs: attrs)
            var result = "\(indent)InputForm\(paramStr) {\n"
            for b in content { result += convertBlock(b, depth: depth + 1) }
            result += "\(indent)}\n"
            return result

        case .widget(let title, let content, let attrs):
            let p: [String: String] = ["title": title]
            let paramStr = formatParams(p, attrs: attrs)
            var result = "\(indent)Widget\(paramStr) {\n"
            for b in content { result += convertBlock(b, depth: depth + 1) }
            result += "\(indent)}\n"
            return result

        case .tab(let title, let content, let attrs):
            let p: [String: String] = ["title": title]
            let paramStr = formatParams(p, attrs: attrs)
            var result = "\(indent)Tab\(paramStr) {\n"
            for b in content { result += convertBlock(b, depth: depth + 1) }
            result += "\(indent)}\n"
            return result

        case .stage(let kind, let content, let attrs):
            let p: [String: String] = ["kind": kind.rawValue]
            let paramStr = formatParams(p, attrs: attrs)
            var result = "\(indent)Stage\(paramStr) {\n"
            for b in content { result += convertBlock(b, depth: depth + 1) }
            result += "\(indent)}\n"
            return result

        case .lane(let content, let attrs):
            let p: [String: String] = [:]
            let paramStr = formatParams(p, attrs: attrs)
            var result = "\(indent)Lane\(paramStr) {\n"
            for b in content { result += convertBlock(b, depth: depth + 1) }
            result += "\(indent)}\n"
            return result

        case .module(let family, let name, let content, let attrs):
            let p: [String: String] = ["family": family, "name": name]
            let paramStr = formatParams(p, attrs: attrs)
            var result = "\(indent)Module\(paramStr) {\n"
            for b in content { result += convertBlock(b, depth: depth + 1) }
            result += "\(indent)}\n"
            return result

        case .contractDirective(let kind, let content, let attrs):
            let p: [String: String] = ["kind": kind.rawValue]
            let paramStr = formatParams(p, attrs: attrs)
            return "\(indent)Contract\(paramStr) \"\(content)\"\n"

        default:
            return "\(indent)// unsupported block\n"
        }
    }

    // MARK: - List Items

    private func convertListItem(_ item: ListItem, depth: Int) -> String {
        let indent = String(repeating: " ", count: depth * indentWidth)
        var params: [String: String] = [:]
        if let checked = item.checked {
            params["checked"] = checked ? "true" : "false"
        }
        let paramStr = params.isEmpty ? "" : formatParams(params, attrs: .init())

        if item.content.count == 1, case .paragraph(let inlines, _) = item.content[0] {
            return "\(indent)ListItem\(paramStr) { \(inlinesToText(inlines)) }\n"
        }

        var result = "\(indent)ListItem\(paramStr) {\n"
        for b in item.content { result += convertBlock(b, depth: depth + 1) }
        result += "\(indent)}\n"
        return result
    }

    // MARK: - Inline to Text

    private func inlinesToText(_ inlines: [Inline]) -> String {
        inlines.map { inlineToText($0) }.joined()
    }

    private func inlineToText(_ inline: Inline) -> String {
        switch inline {
        case .text(let t): return t
        case .emphasis(let c): return "*\(inlinesToText(c))*"
        case .strong(let c): return "**\(inlinesToText(c))**"
        case .strikethrough(let c): return "~~\(inlinesToText(c))~~"
        case .codeSpan(let t, _): return "`\(t)`"
        case .link(let text, let url, let title, _):
            let titlePart = title.map { " \"\($0)\"" } ?? ""
            return "[\(inlinesToText(text))](\(url)\(titlePart))"
        case .image(let alt, let url, let title, _):
            let titlePart = title.map { " \"\($0)\"" } ?? ""
            return "![\(inlinesToText(alt))](\(url)\(titlePart))"
        case .footnoteRef(let id): return "[^\(id)]"
        case .inlineMath(let expr, _): return "$\(expr)$"
        case .mathDisplay(let expr, _): return "$$\(expr)$$"
        case .html(let h): return h
        case .hardBreak: return "\\\n"
        case .softBreak: return " "
        case .superscript(let c): return "^\(inlinesToText(c))^"
        case .subscript(let c): return "~\(inlinesToText(c))~"
        case .highlight(let c): return "==\(inlinesToText(c))=="
        case .span(let c, _): return inlinesToText(c)
        case .inlineFootnote(let c): return "^[\(inlinesToText(c))]"
        case .citation(let items, _):
            let keys = items.map { "[@\($0.key)]" }.joined(separator: " ")
            return keys
        case .crossReference(let prefix, let id): return "@\(prefix.rawValue)-\(id)"
        case .resolvedCitation(let text, _, _): return text
        case .resolvedCrossReference(let text, _): return text
        case .rawInline(let content, let format): return "`\(content)`{=\(format)}"
        case .wikilink(let target, let display):
            if let d = display { return "[[" + inlinesToText(d) + "|" + target + "]]" }
            return "[[\(target)]]"
        case .emoji(let name, let unicode): return unicode ?? ":\(name):"
        case .transclusionInline(let target, let fragment, _, _):
            let fragmentPart = fragment.map { "#\($0)" } ?? ""
            return "{{> \(target)\(fragmentPart) }}"
        case .annotationInline(_, let text): return text
        case .paramRef(let name): return "<<param \(name)>>"
        case .slotRef(let name):
            if let name, !name.isEmpty { return "<<slot \(name)>>" }
            return "<<slot>>"
        case .placeholderInline(let fields):
            return fields
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
        case .expressionInline(let expr): return expr
        case .inputFieldInline(let name, _, _): return name
        @unknown default: return ""
        }
    }

    // MARK: - Attribute Formatting

    private func attributeParams(_ attrs: RhoeMarkdownKit.Attributes) -> String {
        formatParams([:], attrs: attrs)
    }

    private func formatParams(_ params: [String: String], attrs: RhoeMarkdownKit.Attributes) -> String {
        var allParams: [(String, String)] = []

        if let id = attrs.id { allParams.append(("id", id)) }
        if !attrs.classes.isEmpty { allParams.append(("class", attrs.classes.joined(separator: " "))) }
        for (k, v) in params.sorted(by: { $0.key < $1.key }) { allParams.append((k, v)) }
        for (k, v) in attrs.keyValues.sorted(by: { $0.key < $1.key }) {
            if !params.keys.contains(k) { allParams.append((k, v)) }
        }

        guard !allParams.isEmpty else { return "" }
        let formatted = allParams.map { "\($0.0): \"\($0.1)\"" }.joined(separator: ", ")
        return "(\(formatted))"
    }

    private func mergeAttributes(_ a: RhoeMarkdownKit.Attributes, _ b: RhoeMarkdownKit.Attributes) -> RhoeMarkdownKit.Attributes {
        RhoeMarkdownKit.Attributes(
            id: a.id ?? b.id,
            classes: a.classes + b.classes,
            keyValues: a.keyValues.merging(b.keyValues) { old, _ in old }
        )
    }
}
