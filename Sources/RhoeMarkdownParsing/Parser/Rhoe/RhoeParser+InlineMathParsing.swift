import Foundation
import RhoeMarkdownModel

extension RhoeParser {
    func parseMathFromText(_ text: String, at position: inout String.Index) -> Inline? {
        guard text[position] == "$" else { return nil }

        let start = position
        position = text.index(after: position)

        var isDisplay = false
        if position < text.endIndex && text[position] == "$" {
            isDisplay = true
            position = text.index(after: position)
        }

        let mathStart = position
        while position < text.endIndex {
            if text[position] == "$" {
                let mathContent = String(text[mathStart..<position])
                position = text.index(after: position)

                if isDisplay && position < text.endIndex && text[position] == "$" {
                    position = text.index(after: position)
                }

                let attributes = consumeOptionalInlineAttributes(in: text, at: &position)
                    ?? RhoeMarkdownKit.Attributes()

                return isDisplay
                    ? .mathDisplay(expression: mathContent, attributes: attributes)
                    : .inlineMath(expression: mathContent, attributes: attributes)
            }
            position = text.index(after: position)
        }

        position = start
        return nil
    }
}
