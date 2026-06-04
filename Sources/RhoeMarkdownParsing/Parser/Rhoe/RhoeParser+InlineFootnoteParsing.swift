import Foundation
import RhoeMarkdownModel

extension RhoeParser {
    /// Parse inline footnote from `^[content]` syntax.
    ///
    /// Inline footnotes contain their content directly rather than
    /// referencing a separate definition. The content between brackets
    /// can contain any inline elements.
    ///
    /// Disambiguation:
    /// - `^[content]` → inline footnote (caret + bracket)
    /// - `^text^`     → superscript (caret + non-bracket)
    /// - `[^id]`      → footnote reference (bracket + caret, handled by lexer)
    func parseInlineFootnoteFromText(_ text: String, at position: inout String.Index) -> Inline? {
        guard configuration.enableInlineFootnotes else { return nil }
        guard text[position] == "^" else { return nil }

        let start = position
        let afterCaret = text.index(after: position)

        // Must have content after caret
        guard afterCaret < text.endIndex else { return nil }

        // Must be followed by `[`
        guard text[afterCaret] == "[" else { return nil }

        // Advance past `^[`
        var scanPos = text.index(after: afterCaret)
        var depth = 1

        // Scan for matching closing `]`, respecting bracket nesting
        while scanPos < text.endIndex {
            let ch = text[scanPos]

            if ch == "\\" && text.index(after: scanPos) < text.endIndex {
                // Skip escaped characters
                scanPos = text.index(scanPos, offsetBy: 2)
                continue
            }

            if ch == "[" {
                depth += 1
            } else if ch == "]" {
                depth -= 1
                if depth == 0 {
                    // Found matching close bracket
                    let content = String(text[text.index(after: afterCaret)..<scanPos])
                    guard !content.isEmpty else {
                        position = start
                        return nil
                    }
                    position = text.index(after: scanPos) // consume closing ]
                    let innerInlines = parseInlines(content)
                    return .inlineFootnote(content: innerInlines)
                }
            }

            scanPos = text.index(after: scanPos)
        }

        // No matching close bracket found
        position = start
        return nil
    }
}
