import Foundation
import RhoeMarkdownModel

extension RhoeParser {

    /// Check if a code inline followed by `{=format}` should be a raw inline.
    ///
    /// Pattern: `` `content`{=html} `` → `.rawInline(content: "content", format: "html")`
    ///
    /// This is called after the closing backtick of inline code. If the attributes
    /// contain a `=format` key (no value, starts with `=`), the code is promoted
    /// to a raw inline instead.
    func checkForRawInline(
        code: String,
        attributes: RhoeMarkdownKit.Attributes
    ) -> Inline? {
        guard configuration.enableRawInlines else { return nil }

        // Check for `{=format}` pattern — a single key-value where key starts with "="
        // or a class that starts with "=" (misparse of `{=html}`)
        for cls in attributes.classes {
            if cls.hasPrefix("=") {
                let format = String(cls.dropFirst())
                guard !format.isEmpty else { continue }
                return .rawInline(content: code, format: format)
            }
        }

        // Also check key-values for bare `=format`
        for (key, _) in attributes.keyValues {
            if key.hasPrefix("=") {
                let format = String(key.dropFirst())
                guard !format.isEmpty else { continue }
                return .rawInline(content: code, format: format)
            }
        }

        return nil
    }

    /// Parse a raw format attribute from text at position.
    ///
    /// Detects `{=format}` after inline code's closing backtick.
    /// Returns the format string if found, nil otherwise.
    func parseRawFormatAttribute(
        _ text: String,
        at position: inout String.Index
    ) -> String? {
        guard configuration.enableRawInlines else { return nil }
        guard position < text.endIndex && text[position] == "{" else { return nil }

        let nextIndex = text.index(after: position)
        guard nextIndex < text.endIndex && text[nextIndex] == "=" else { return nil }

        // Scan for closing }
        var scanPos = text.index(after: nextIndex) // past the =
        let formatStart = scanPos

        while scanPos < text.endIndex && text[scanPos] != "}" {
            scanPos = text.index(after: scanPos)
        }

        guard scanPos < text.endIndex && text[scanPos] == "}" else { return nil }

        let format = String(text[formatStart..<scanPos])
        guard !format.isEmpty else { return nil }

        position = text.index(after: scanPos) // consume closing }
        return format
    }
}
