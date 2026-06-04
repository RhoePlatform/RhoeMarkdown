import Foundation
import RhoeMarkdownModel

/// Converts a canonical AST back to RhoeMarkdown source text.
///
/// Produces well-formatted Markdown. Semantic fidelity is mandatory —
/// the converted Markdown must produce the same canonical AST when re-parsed.
/// Exact whitespace preservation is NOT guaranteed.
public struct DSLToMarkdownConverter: Sendable {

    public init() {}

    /// Convert a full document to Markdown source.
    public func convert(_ document: RhoeMarkdownKit.Document) -> String {
        var output = ""
        for (i, block) in document.blocks.enumerated() {
            output += convertBlock(block)
            if i < document.blocks.count - 1 { output += "\n" }
        }
        return output
    }

    // MARK: - Block Conversion

    private func convertBlock(_ block: Block) -> String {
        switch block {
        case .heading(let level, let content, let attrs):
            let hashes = String(repeating: "#", count: level)
            let text = inlinesToMarkdown(content)
            let attrStr = formatAttributes(attrs)
            return "\(hashes) \(text)\(attrStr)\n"

        case .section(let level, let title, let children, let attrs):
            let hashes = String(repeating: "#", count: level)
            let text = inlinesToMarkdown(title)
            let attrStr = formatAttributes(attrs)
            var result = "\(hashes) \(text)\(attrStr)\n"
            for child in children {
                result += "\n" + convertBlock(child)
            }
            return result

        case .paragraph(let inlines, let attrs):
            let text = inlinesToMarkdown(inlines)
            let attrStr = formatAttributes(attrs)
            return "\(text)\(attrStr)\n"

        case .blockQuote(let blocks, _):
            return blocks.map { block in
                convertBlock(block).components(separatedBy: "\n")
                    .map { $0.isEmpty ? ">" : "> \($0)" }
                    .joined(separator: "\n")
            }.joined(separator: "\n") + "\n"

        case .list(let type, let items, _):
            var result = ""
            for (i, item) in items.enumerated() {
                let marker: String
                switch type {
                case .unordered: marker = "-"
                case .ordered(let start, _): marker = "\(start + i)."
                case .task:
                    let check = item.checked == true ? "[x]" : "[ ]"
                    marker = "- \(check)"
                }

                let content = item.content.map { convertBlock($0) }.joined()
                    .trimmingCharacters(in: .newlines)
                let lines = content.components(separatedBy: "\n")
                result += "\(marker) \(lines[0])\n"
                for line in lines.dropFirst() {
                    result += "    \(line)\n"
                }
            }
            return result

        case .codeBlock(let language, let content, let attrs):
            let lang = language ?? ""
            let attrStr = formatAttributes(attrs)
            return "```\(lang)\(attrStr)\n\(content)\n```\n"

        case .horizontalRule:
            return "---\n"

        case .table(let headers, let rows, let caption, let attrs):
            var result = ""
            if let cap = caption {
                result += "Table: \(inlinesToMarkdown(cap))\n\n"
            }
            // Header row
            result += "| " + headers.map { inlinesToMarkdown($0.content) }.joined(separator: " | ") + " |\n"
            // Separator
            result += "| " + headers.map { _ in "---" }.joined(separator: " | ") + " |\n"
            // Data rows
            for row in rows {
                result += "| " + row.map { inlinesToMarkdown($0.content) }.joined(separator: " | ") + " |\n"
            }
            let attrStr = formatAttributes(attrs)
            if !attrStr.isEmpty { result += "\(attrStr)\n" }
            return result

        case .definitionList(let items, _):
            var result = ""
            for item in items {
                result += "\(inlinesToMarkdown(item.term))\n"
                for def in item.definitions {
                    for b in def {
                        let content = convertBlock(b).trimmingCharacters(in: .newlines)
                        result += ":   \(content)\n"
                    }
                }
            }
            return result

        case .footnoteDefinition(let id, let content):
            let body = content.map { convertBlock($0) }.joined().trimmingCharacters(in: .newlines)
            return "[^\(id)]: \(body)\n"

        case .admonition(let type, let title, let content, let collapsible, let attrs):
            let prefix = collapsible != nil ? "???" : "!!!"
            let titleStr = title.map { " \"\($0)\"" } ?? ""
            let attrStr = formatAttributes(attrs)
            var result = "\(prefix) \(type)\(titleStr)\(attrStr)\n"
            for b in content { result += convertBlock(b) }
            result += "\(prefix)\n"
            return result

        case .html(let rawHTML):
            return rawHTML + "\n"

        case .div(let content, let attrs):
            let attrStr = formatAttributes(attrs, forceBlock: true)
            var result = ":::\(attrStr)\n"
            for b in content { result += convertBlock(b) }
            result += ":::\n"
            return result

        case .lineBlock(let lines):
            return lines.map { "| \(inlinesToMarkdown($0))" }.joined(separator: "\n") + "\n"

        case .abbreviationDefinition(let abbr, let expansion):
            return "*[\(abbr)]: \(expansion)\n"

        case .visualBlock(let name, let content, let attrs):
            let attrStr = formatAttributes(attrs)
            var result = "::: \(name)\(attrStr)\n"
            for b in content { result += convertBlock(b) }
            result += ":::\n"
            return result

        case .authorAnnotation(let kind, let text, _):
            return "<<\(kind.rawValue) \"\(text)\">>\n"

        case .transclusion(let target, let fragment, let mode, _):
            let frag = fragment.map { "#\($0)" } ?? ""
            let modeStr = mode.map { " {mode=\($0.rawValue)}" } ?? ""
            return "<<include \"\(target)\(frag)\"\(modeStr)>>\n"

        case .schemaIsland(let schema, let body, _):
            return "<<schema \(schema)>>\n\(body)\n<</schema>>\n"

        case .componentDeclaration(let family, let name, let args, let slots, let body, _):
            let delim = family == .semantic ? "!!!" : ":::"
            var attrParts = ["name=\(name)"]
            if let a = args { attrParts.append("args=\"\(a)\"") }
            if let s = slots { attrParts.append("slots=\"\(s)\"") }
            var result = "\(delim) component {\(attrParts.joined(separator: " "))}\n"
            for b in body { result += convertBlock(b) }
            result += "\(delim)\n"
            return result

        case .phase2Directive(let cmd, let args, let body, _):
            let argStr = args.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            if let body {
                return "{@ \(cmd) @}\n\(body)\n{@ end\(cmd) @}\n"
            }
            return "{@ \(cmd) \(argStr) @}\n"

        case .placeholder(let fields, _):
            let fieldStr = fields.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            return "{? \(fieldStr) ?}\n"

        case .expression(let expr, _):
            return "{{ \(expr) }}\n"

        case .field(let name, let fieldType, _):
            return "{? name: \(name), type: \(fieldType) ?}\n"

        case .form(let name, let content, _):
            let nameStr = name.map { " name=\"\($0)\"" } ?? ""
            var result = "::: form\(nameStr)\n"
            for b in content { result += convertBlock(b) }
            result += ":::\n"
            return result

        case .widget(let title, let content, let attrs):
            let attrStr = formatAttributes(attrs)
            var result = "::: widget {title=\"\(title)\"}\(attrStr)\n"
            for b in content { result += convertBlock(b) }
            result += ":::\n"
            return result

        case .tab(let title, let content, let attrs):
            let attrStr = formatAttributes(attrs)
            var result = "::: tab {title=\"\(title)\"}\(attrStr)\n"
            for b in content { result += convertBlock(b) }
            result += ":::\n"
            return result

        case .stage(let kind, let content, let attrs):
            let attrStr = formatAttributes(attrs)
            var result = "::: stage.\(kind.rawValue)\(attrStr)\n"
            for b in content { result += convertBlock(b) }
            result += ":::\n"
            return result

        case .lane(let content, let attrs):
            let attrStr = formatAttributes(attrs)
            var result = "::: lane\(attrStr)\n"
            for b in content { result += convertBlock(b) }
            result += ":::\n"
            return result

        case .module(let family, let name, let content, let attrs):
            let attrStr = formatAttributes(attrs)
            var result = "::: module.\(family).\(name)\(attrStr)\n"
            for b in content { result += convertBlock(b) }
            result += ":::\n"
            return result

        case .contractDirective(let kind, let content, let attrs):
            let attrStr = formatAttributes(attrs)
            var result = "!!! \(kind.rawValue)\(attrStr)\n"
            result += content + "\n"
            result += "!!!\n"
            return result

        default:
            return "<!-- unsupported block -->\n"
        }
    }

    // MARK: - Inline to Markdown

    private func inlinesToMarkdown(_ inlines: [Inline]) -> String {
        inlines.map { inlineToMarkdown($0) }.joined()
    }

    private func inlineToMarkdown(_ inline: Inline) -> String {
        switch inline {
        case .text(let t): return t
        case .emphasis(let c): return "*\(inlinesToMarkdown(c))*"
        case .strong(let c): return "**\(inlinesToMarkdown(c))**"
        case .strikethrough(let c): return "~~\(inlinesToMarkdown(c))~~"
        case .codeSpan(let t, _): return "`\(t)`"
        case .link(let text, let url, let title, _):
            let titlePart = title.map { " \"\($0)\"" } ?? ""
            return "[\(inlinesToMarkdown(text))](\(url)\(titlePart))"
        case .image(let alt, let url, let title, _):
            let titlePart = title.map { " \"\($0)\"" } ?? ""
            return "![\(inlinesToMarkdown(alt))](\(url)\(titlePart))"
        case .footnoteRef(let id): return "[^\(id)]"
        case .inlineMath(let expr, _): return "$\(expr)$"
        case .mathDisplay(let expr, _): return "$$\(expr)$$"
        case .html(let h): return h
        case .hardBreak: return "  \n"
        case .softBreak: return "\n"
        case .superscript(let c): return "^\(inlinesToMarkdown(c))^"
        case .subscript(let c): return "~\(inlinesToMarkdown(c))~"
        case .highlight(let c): return "==\(inlinesToMarkdown(c))=="
        case .span(let c, let attrs):
            return "[\(inlinesToMarkdown(c))]\(formatAttributes(attrs))"
        case .inlineFootnote(let c): return "^[\(inlinesToMarkdown(c))]"
        case .citation(let items, _):
            return items.map { "[@\($0.key)]" }.joined(separator: " ")
        case .crossReference(let prefix, let id): return "@\(prefix.rawValue)-\(id)"
        case .resolvedCitation(let text, _, _): return text
        case .resolvedCrossReference(let text, _): return text
        case .rawInline(let content, let format): return "`\(content)`{=\(format)}"
        case .wikilink(let target, let display):
            if let d = display { return "[[\(target)|\(inlinesToMarkdown(d))]]" }
            return "[[\(target)]]"
        case .emoji(let name, let unicode): return unicode ?? ":\(name):"
        case .transclusionInline(let target, let fragment, _, let attrs):
            let fragmentPart = fragment.map { "#\($0)" } ?? ""
            return "{{> \(target)\(fragmentPart) }}\(formatAttributes(attrs))"
        case .annotationInline(_, let text): return text
        case .paramRef(let name): return "<<param \(name)>>"
        case .slotRef(let name):
            if let name, !name.isEmpty { return "<<slot \(name)>>" }
            return "<<slot>>"
        case .placeholderInline(let fields):
            let fieldString = fields
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \"\($0.value)\"" }
                .joined(separator: ", ")
            return "{? \(fieldString) ?}"
        case .expressionInline(let expr): return "{{ \(expr) }}"
        case .inputFieldInline(let name, _, _): return name
        @unknown default: return ""
        }
    }

    // MARK: - Attributes

    private func formatAttributes(_ attrs: RhoeMarkdownKit.Attributes, forceBlock: Bool = false) -> String {
        var parts: [String] = []
        if let id = attrs.id { parts.append("#\(id)") }
        for cls in attrs.classes { parts.append(".\(cls)") }
        for (k, v) in attrs.keyValues.sorted(by: { $0.key < $1.key }) {
            parts.append("\(k)=\(v)")
        }
        guard !parts.isEmpty else { return forceBlock ? "" : "" }
        return " {\(parts.joined(separator: " "))}"
    }
}
