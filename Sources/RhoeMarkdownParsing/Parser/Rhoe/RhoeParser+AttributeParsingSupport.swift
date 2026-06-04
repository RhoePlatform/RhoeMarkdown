import Foundation
import RhoeMarkdownModel

extension RhoeParser {
    func parseAttributes(from content: String) -> RhoeMarkdownKit.Attributes {
        var id: String? = nil
        var classes: [String] = []
        var keyValues: [String: String] = [:]

        for part in splitAttributeParts(content) {
            if part.hasPrefix("#") {
                id = String(part.dropFirst())
            } else if part.hasPrefix(".") {
                classes.append(String(part.dropFirst()))
            } else if part.contains("=") {
                let components = part.split(separator: "=", maxSplits: 1)
                if components.count == 2 {
                    let rawKey = String(components[0])
                    let value = unquotedAttributeValue(String(components[1]))
                    // Case-normalize recognized attribute keys and enumerated values.
                    let key = canonicalizeAttributeKey(rawKey)
                    let canonicalValue = canonicalizeAttributeValue(key: key, value: value)
                    keyValues[key] = canonicalValue
                }
            } else if !part.isEmpty && !part.hasPrefix("#") && !part.hasPrefix(".") {
                // Bare flag: e.g., "collapsed", "decorative", "required"
                let canonicalFlag = canonicalizeAttributeKey(part)
                keyValues[canonicalFlag] = "true"
            }
        }

        return RhoeMarkdownKit.Attributes(id: id, classes: classes, keyValues: keyValues)
    }

    func splitAttributeParts(_ content: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var inQuotes = false
        var quoteCharacter: Character? = nil

        for character in content {
            if !inQuotes && (character == "\"" || character == "'") {
                inQuotes = true
                quoteCharacter = character
                current.append(character)
            } else if inQuotes && character == quoteCharacter {
                inQuotes = false
                quoteCharacter = nil
                current.append(character)
            } else if !inQuotes && character == " " {
                if !current.isEmpty {
                    parts.append(current)
                    current = ""
                }
            } else {
                current.append(character)
            }
        }

        if !current.isEmpty {
            parts.append(current)
        }

        return parts
    }

    func consumeAttributeList(_ state: inout RhoeParserState) -> RhoeMarkdownKit.Attributes? {
        while let token = state.current, case .space = token.type {
            state.advance()
        }

        if let token = state.current,
           case .attributeList(let content) = token.type {
            state.advance()
            return parseAttributes(from: content)
        }

        return nil
    }

    /// Parse inline attributes `{.class #id key=value}` from a text position.
    ///
    /// If the text at position starts with `{`, scans for the matching `}` and
    /// parses the content as Pandoc-style attributes. Advances position past `}`.
    /// Returns empty attributes if no `{` is found.
    func parseInlineAttributesFromText(_ text: String, at position: inout String.Index) -> RhoeMarkdownKit.Attributes {
        guard position < text.endIndex && text[position] == "{" else {
            return RhoeMarkdownKit.Attributes()
        }

        let start = position
        var scanPos = text.index(after: position)
        var depth = 1

        while scanPos < text.endIndex {
            let ch = text[scanPos]
            if ch == "{" {
                depth += 1
            } else if ch == "}" {
                depth -= 1
                if depth == 0 {
                    let content = String(text[text.index(after: start)..<scanPos])
                    position = text.index(after: scanPos) // consume closing }
                    return parseAttributes(from: content)
                }
            }
            scanPos = text.index(after: scanPos)
        }

        // No matching } found — don't consume anything
        return RhoeMarkdownKit.Attributes()
    }

    // MARK: - Case Canonicalization

    /// Recognized language-owned attribute keys that should be lowercased
    private static let recognizedKeys: Set<String> = [
        "visible", "hidden", "role", "kind", "scope", "decorative",
        "collapsed", "open", "required", "placeholder", "label",
        "alt", "longdesc", "summary", "reading-order", "assistive-only",
        "projection", "handout", "short", "nav", "responsive",
        "export", "format", "align", "min-columns", "priority-columns",
        "row-label-column", "compact-summary", "mode", "optional",
        "fallback", "unwrap", "runtime", "timeout", "persist", "history",
        "language", "memory", "validate", "profile",
        // Writer hints (second-class but still recognized)
        "html-tag", "typst-kind", "latex-env", "swiftui-style", "pdf-bookmark",
        // Presentational
        "color", "bg", "width", "height", "border", "opacity",
        "rotation", "radius", "transition", "layout", "weight",
        // Interaction
        "min", "max", "step", "action", "method", "target",
        // Identity
        "name", "key", "ref",
    ]

    /// Recognized enumerated values that should be lowercased (by key)
    private static let keysWithEnumeratedValues: Set<String> = [
        "visible", "hidden", "projection", "kind", "role", "scope",
        "responsive", "mode", "format", "runtime", "persist", "history",
        "reading-order", "align", "export",
    ]

    func canonicalizeAttributeKey(_ key: String) -> String {
        let lower = key.lowercased()
        if Self.recognizedKeys.contains(lower) {
            return lower
        }
        return key // Preserve case for unknown keys
    }

    func canonicalizeAttributeValue(key: String, value: String) -> String {
        if Self.keysWithEnumeratedValues.contains(key) {
            return value.lowercased()
        }
        return value // Preserve case for non-enumerated values
    }

    fileprivate func unquotedAttributeValue(_ value: String) -> String {
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
           (value.hasPrefix("'") && value.hasSuffix("'")) {
            return String(value.dropFirst().dropLast())
        }

        return value
    }
}
