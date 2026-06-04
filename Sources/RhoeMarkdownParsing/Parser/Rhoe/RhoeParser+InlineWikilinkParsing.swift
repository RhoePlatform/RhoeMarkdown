import Foundation
import RhoeMarkdownModel

extension RhoeParser {

    /// Parse a wikilink from text at the current position.
    ///
    /// Wikilinks use `[[target]]` or `[[target|display text]]` syntax:
    /// ```
    /// [[Page Name]]           → link to "Page Name" with display "Page Name"
    /// [[Page Name|Click Me]]  → link to "Page Name" with display "Click Me"
    /// ```
    func parseWikilinkFromText(_ text: String, at position: inout String.Index) -> Inline? {
        guard configuration.enableWikilinks else { return nil }
        guard position < text.endIndex && text[position] == "[" else { return nil }

        // Must be [[
        let nextIndex = text.index(after: position)
        guard nextIndex < text.endIndex && text[nextIndex] == "[" else { return nil }

        // Scan for closing ]]
        var scanPos = text.index(after: nextIndex)
        let contentStart = scanPos
        var depth = 0

        while scanPos < text.endIndex {
            let ch = text[scanPos]

            if ch == "[" {
                depth += 1
            } else if ch == "]" {
                if depth > 0 {
                    depth -= 1
                } else {
                    // Check for second ]
                    let nextPos = text.index(after: scanPos)
                    guard nextPos < text.endIndex && text[nextPos] == "]" else {
                        scanPos = text.index(after: scanPos)
                        continue
                    }

                    let content = String(text[contentStart..<scanPos])
                    guard !content.isEmpty else {
                        return nil
                    }

                    position = text.index(after: nextPos) // consume closing ]]

                    // Split on | for display text
                    if let pipeIndex = content.firstIndex(of: "|") {
                        let target = String(content[..<pipeIndex]).trimmingCharacters(in: .whitespaces)
                        let displayText = String(content[content.index(after: pipeIndex)...])
                            .trimmingCharacters(in: .whitespaces)

                        let displayInlines = displayText.isEmpty ? nil : collectStringInlines(from: displayText)
                        return .wikilink(target: target, display: displayInlines)
                    }

                    return .wikilink(target: content, display: nil)
                }
            }

            scanPos = text.index(after: scanPos)
        }

        // No closing ]] found
        return nil
    }
}
