import Foundation
import RhoeMarkdownModel

extension RhoeParser {

    /// Parse an inline placeholder from `{? fields ?}`.
    func parseInlinePlaceholderFromText(
        _ text: String,
        at position: inout String.Index
    ) -> Inline? {
        guard text[position] == "{" else { return nil }

        let start = position
        let questionMark = text.index(after: position)
        guard questionMark < text.endIndex, text[questionMark] == "?" else {
            return nil
        }

        var scan = text.index(after: questionMark)
        var rawFields = ""
        while scan < text.endIndex {
            let character = text[scan]
            if character == "\n" {
                position = start
                return nil
            }
            if character == "?" {
                let closing = text.index(after: scan)
                if closing < text.endIndex, text[closing] == "}" {
                    position = text.index(after: closing)
                    return .placeholderInline(fields: parsePlaceholderFields(rawFields.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }
            rawFields.append(character)
            scan = text.index(after: scan)
        }

        position = start
        return nil
    }

    /// Parse a placeholder from `{? fields ?}` token.
    ///
    /// Placeholders are parser-native form fields that survive Phase 1
    /// unchanged and become explicit AST nodes.
    func parsePlaceholder(
        _ state: inout RhoeParserState,
        rawFields: String
    ) -> Block {
        state.advance() // consume the placeholderToken
        let fields = parsePlaceholderFields(rawFields)
        return .placeholder(fields: fields)
    }

    /// Parse placeholder fields into key-value pairs.
    ///
    /// Input: `name: "Recipient", type: text, required`
    /// Output: `["name": "Recipient", "type": "text", "required": "true"]`
    func parsePlaceholderFields(_ raw: String) -> [String: String] {
        guard !raw.isEmpty else { return [:] }

        var result: [String: String] = [:]
        let parts = raw.components(separatedBy: ",")

        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[trimmed.startIndex..<colonIndex])
                    .trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIndex)...])
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                result[key] = value
            } else if !trimmed.isEmpty {
                // Bare keyword = flag
                result[trimmed] = "true"
            }
        }

        return result
    }
}
