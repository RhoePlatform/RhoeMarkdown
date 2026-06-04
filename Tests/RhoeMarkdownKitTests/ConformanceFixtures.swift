import Foundation
import RhoeMarkdownKit

enum ConformanceFixtures {
    static let repositoryRoot: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }()

    static func loadText(relativePath: String) throws -> String {
        let url = repositoryRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func normalizeHTML(_ html: String) -> String {
        html
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

func inlinePlainText(_ inlines: [Inline]) -> String {
    inlines.map {
        switch $0 {
        case .text(let text):
            return text
        case .emphasis(let nested),
             .strong(let nested),
             .strikethrough(let nested),
             .superscript(let nested),
             .subscript(let nested),
             .highlight(let nested),
             .span(let nested, _),
             .inlineFootnote(let nested):
            return inlinePlainText(nested)
        case .codeSpan(let code, _):
            return code
        case .link(let text, _, _, _):
            return inlinePlainText(text)
        case .image(let alt, _, _, _):
            return inlinePlainText(alt)
        case .footnoteRef(let id):
            return "[^\(id)]"
        case .inlineMath(let expression, _),
             .mathDisplay(let expression, _):
            return expression
        case .html(let html):
            return html
        case .hardBreak:
            return "\n"
        case .softBreak:
            return " "
        case .citation(let items, _):
            return items.map { "@\($0.key)" }.joined(separator: "; ")
        case .crossReference(let prefix, let id):
            return "\(prefix.rawValue)-\(id)"
        case .rawInline(let content, _):
            return content
        case .wikilink(let target, let display):
            return display.map { inlinePlainText($0) } ?? target
        case .resolvedCitation(let text, _, _):
            return text
        case .resolvedCrossReference(let text, _):
            return text
        case .transclusionInline:
            return ""
        case .annotationInline:
            return ""
        case .paramRef(let name):
            return "<<param \(name)>>"
        case .slotRef(let name):
            return "<<slot \(name ?? "default")>>"
        case .placeholderInline(let fields):
            return "{? \(fields.map { "\($0.key): \($0.value)" }.joined(separator: ", ")) ?}"
        case .expressionInline(let expr):
            return "<<= \(expr) >>"
        case .inputFieldInline(let name, _, _):
            return "<<field \(name)>>"
        case .emoji(let name, let unicode):
            return unicode ?? ":\(name):"
        }
    }
    .joined()
}

func paragraphPlainText(_ block: Block) -> String? {
    guard case .paragraph(let inlines, _) = block else { return nil }
    return inlinePlainText(inlines)
}
