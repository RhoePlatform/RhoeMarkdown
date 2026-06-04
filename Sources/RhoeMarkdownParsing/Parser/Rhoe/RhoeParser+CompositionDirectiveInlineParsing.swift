import Foundation
import RhoeMarkdownModel

extension RhoeParser {

    /// Parse an inline composition directive `<<keyword ...>>` from text.
    ///
    /// Called when `<` is encountered in inline text. Checks for `<<` and
    /// scans for matching `>>`. Routes by keyword to the appropriate inline type.
    func parseCompositionDirectiveInline(
        _ text: String,
        at position: inout String.Index
    ) -> Inline? {
        guard position < text.endIndex && text[position] == "<" else { return nil }

        let nextIndex = text.index(after: position)
        guard nextIndex < text.endIndex && text[nextIndex] == "<" else { return nil }

        // Don't match <<< (triple angle)
        let afterNext = text.index(after: nextIndex)
        if afterNext < text.endIndex && text[afterNext] == "<" { return nil }

        // Scan for closing >>
        var scanPos = afterNext
        var content = ""
        while scanPos < text.endIndex {
            let ch = text[scanPos]
            if ch == ">" {
                let next = text.index(after: scanPos)
                if next < text.endIndex && text[next] == ">" {
                    // Found >>
                    let result = parseDirectiveContent(content.trimmingCharacters(in: .whitespaces))
                    if let result = result {
                        position = text.index(after: next) // consume >>
                        return result
                    }
                    return nil
                }
            }
            if ch == "\n" { return nil } // No multi-line inline directives
            content.append(ch)
            scanPos = text.index(after: scanPos)
        }

        return nil // No closing >>
    }

    /// Parse the content between `<<` and `>>` and route by keyword.
    private func parseDirectiveContent(_ content: String) -> Inline? {
        let trimmed = content.trimmingCharacters(in: .whitespaces)

        // Check for expression form: <<= expr >>
        if trimmed.hasPrefix("=") {
            let expr = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            return .expressionInline(expr: expr)
        }

        // Extract keyword (first word)
        let parts = trimmed.split(separator: " ", maxSplits: 1)
        guard let keywordPart = parts.first else { return nil }
        let keyword = String(keywordPart).lowercased()
        let remainder = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : nil

        switch keyword {
        case "include":
            return parseInlineTransclusion(remainder)

        case "todo", "doc", "info", "comment":
            return parseInlineAnnotation(keyword: keyword, argument: remainder)

        case "param":
            return .paramRef(name: (remainder ?? "").trimmingCharacters(in: .whitespaces))

        case "slot":
            let slotName = remainder?.trimmingCharacters(in: .whitespaces)
            return .slotRef(name: slotName?.isEmpty == true ? nil : slotName)

        case "field":
            return parseInlineField(remainder)

        default:
            // Could be a bare path (transclusion without keyword)
            if content.contains(".") || content.contains("/") {
                return parseInlineTransclusion(content)
            }
            return nil
        }
    }

    /// Parse inline `<<field name {type=text}>>`.
    private func parseInlineField(_ remainder: String?) -> Inline? {
        guard let remainder, !remainder.isEmpty else {
            return .inputFieldInline(name: "unnamed", fieldType: "text")
        }
        let parts = remainder.split(separator: " ", maxSplits: 1)
        let name = String(parts[0])
        var fieldType = "text"
        var attrs = RhoeMarkdownKit.Attributes()
        if parts.count > 1 {
            let attrStr = String(parts[1]).trimmingCharacters(in: .whitespaces)
            if attrStr.hasPrefix("{") && attrStr.hasSuffix("}") {
                attrs = parseAttributes(from: String(attrStr.dropFirst().dropLast()))
            }
            fieldType = attrs.keyValues["type"] ?? "text"
        }
        return .inputFieldInline(name: name, fieldType: fieldType, attributes: attrs)
    }

    /// Parse `<<include "path">>` or `<<include "path#frag" {mode=inline}>>`.
    private func parseInlineTransclusion(_ argument: String?) -> Inline? {
        guard let arg = argument, !arg.isEmpty else { return nil }

        let trimmed = arg.trimmingCharacters(in: .whitespacesAndNewlines)
        var path = trimmed
        var mode: TransclusionMode? = .inline

        if let attributeStart = trimmed.lastIndex(of: "{"),
           trimmed.hasSuffix("}") {
            let rawPath = trimmed[..<attributeStart].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawAttributes = trimmed[trimmed.index(after: attributeStart)..<trimmed.index(before: trimmed.endIndex)]
            path = String(rawPath)
            let attributes = parseAttributes(from: String(rawAttributes))
            mode = attributes.keyValues["mode"].flatMap(TransclusionMode.init(rawValue:))
                ?? .inline
        }

        // Strip quotes if present.
        if path.hasPrefix("\"") && path.contains("\"") {
            let unquoted = path.dropFirst()
            if let endQuote = unquoted.firstIndex(of: "\"") {
                path = String(unquoted[..<endQuote])
            }
        }

        // Split path#fragment
        let pathParts = path.split(separator: "#", maxSplits: 1)
        let target = String(pathParts[0])
        let fragment = pathParts.count > 1 ? String(pathParts[1]) : nil

        return .transclusionInline(
            target: target,
            fragment: fragment,
            mode: mode,
            attributes: RhoeMarkdownKit.Attributes()
        )
    }

    /// Parse `<<todo "text">>` or `<<doc "text">>` inline.
    private func parseInlineAnnotation(keyword: String, argument: String?) -> Inline? {
        guard let kind = AnnotationKind(rawValue: keyword) else { return nil }

        // Extract quoted text
        var text = argument ?? ""
        if text.hasPrefix("\"") {
            let unquoted = text.dropFirst()
            if let endQuote = unquoted.firstIndex(of: "\"") {
                text = String(unquoted[..<endQuote])
            } else {
                text = String(unquoted)
            }
        }

        return .annotationInline(kind: kind, text: text)
    }
}
