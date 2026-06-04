import Foundation
import RhoeMarkdownModel

extension RhoeParser {
    /// Parse parenthetical citation from `[@key]` syntax.
    ///
    /// Supported patterns:
    /// - `[@key]`              → single citation
    /// - `[@key, p. 42]`      → citation with locator
    /// - `[@a; @b; @c]`       → multiple citations
    /// - `[-@key]`            → suppress-author citation
    ///
    /// Disambiguation:
    /// - `[@key]`  → citation (bracket + at-sign)
    /// - `[^id]`   → footnote reference (bracket + caret, handled by lexer)
    /// - `[text]`  → link text (bracket + non-special)
    func parseCitationFromText(_ text: String, at position: inout String.Index) -> Inline? {
        guard configuration.enableCitations else { return nil }
        guard text[position] == "[" else { return nil }

        let start = position
        let afterBracket = text.index(after: position)

        // Must have content after bracket
        guard afterBracket < text.endIndex else { return nil }

        // Check for citation trigger: `[@` or `[-@`
        let firstChar = text[afterBracket]
        let isCitation: Bool
        if firstChar == "@" {
            isCitation = true
        } else if firstChar == "-" {
            let afterDash = text.index(after: afterBracket)
            isCitation = afterDash < text.endIndex && text[afterDash] == "@"
        } else {
            return nil
        }

        guard isCitation else { return nil }

        // Find the closing bracket
        var scanPos = afterBracket
        var depth = 1

        while scanPos < text.endIndex {
            let ch = text[scanPos]

            if ch == "\\" && text.index(after: scanPos) < text.endIndex {
                scanPos = text.index(scanPos, offsetBy: 2)
                continue
            }

            if ch == "[" {
                depth += 1
            } else if ch == "]" {
                depth -= 1
                if depth == 0 {
                    let content = String(text[afterBracket..<scanPos])
                    guard !content.isEmpty else {
                        position = start
                        return nil
                    }

                    let items = parseCitationItems(content)
                    guard !items.isEmpty else {
                        position = start
                        return nil
                    }

                    position = text.index(after: scanPos) // consume closing ]

                    // Determine mode from items
                    let mode: CitationMode
                    if items.allSatisfy({ $0.suppressAuthor }) {
                        mode = .suppressAuthor
                    } else {
                        mode = .parenthetical
                    }

                    return .citation(items: items, mode: mode)
                }
            }

            scanPos = text.index(after: scanPos)
        }

        position = start
        return nil
    }

    /// Parse in-text citation from bare `@key` syntax.
    ///
    /// An in-text citation is a bare `@key` that appears outside brackets.
    /// The key must start with a letter and can contain letters, digits,
    /// underscores, hyphens, colons, and periods.
    ///
    /// Disambiguation:
    /// - `@fig-name` → cross-reference (recognized prefix + hyphen + id)
    /// - `@username` → mention (no recognized prefix pattern)
    /// - `@key`      → in-text citation (after cross-ref check fails)
    ///
    /// Note: In-text citations are handled by the cross-reference/mention
    /// pipeline in `InlineStringDetectorSupport`. This method is called
    /// only when a bare `@key` doesn't match a cross-reference prefix.
    func parseInTextCitationFromText(_ text: String, at position: inout String.Index) -> Inline? {
        guard configuration.enableCitations else { return nil }
        guard text[position] == "@" else { return nil }

        let start = position
        let afterAt = text.index(after: position)
        guard afterAt < text.endIndex else { return nil }

        // Key must start with a letter
        guard text[afterAt].isLetter else { return nil }

        // Consume the key
        var scanPos = afterAt
        while scanPos < text.endIndex && isCitationKeyCharacter(text[scanPos]) {
            scanPos = text.index(after: scanPos)
        }

        let key = String(text[afterAt..<scanPos])
        guard !key.isEmpty else {
            position = start
            return nil
        }

        position = scanPos
        let item = CitationItem(key: key)
        return .citation(items: [item], mode: .inText)
    }

    // MARK: - Private Helpers

    /// Parse semicolon-separated citation items from bracket content.
    ///
    /// Example: `@smith2024, p. 42; -@jones2023; @doe2025`
    private func parseCitationItems(_ content: String) -> [CitationItem] {
        let parts = content.split(separator: ";", omittingEmptySubsequences: true)
        var items: [CitationItem] = []

        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if let item = parseSingleCitationItem(trimmed) {
                items.append(item)
            }
        }

        return items
    }

    /// Parse a single citation item like `@key`, `@key, p. 42`, or `-@key`.
    private func parseSingleCitationItem(_ text: String) -> CitationItem? {
        var remaining = text[text.startIndex...]
        var suppressAuthor = false

        // Check for suppress-author prefix `-@`
        if remaining.hasPrefix("-@") {
            suppressAuthor = true
            remaining = remaining.dropFirst(2)
        } else if remaining.hasPrefix("@") {
            remaining = remaining.dropFirst()
        } else {
            return nil
        }

        // Extract key: letters, digits, underscores, hyphens, colons, periods
        var keyEnd = remaining.startIndex
        while keyEnd < remaining.endIndex && isCitationKeyCharacter(remaining[keyEnd]) {
            keyEnd = remaining.index(after: keyEnd)
        }

        let key = String(remaining[remaining.startIndex..<keyEnd])
        guard !key.isEmpty else { return nil }

        // Check for locator after comma
        let afterKey = remaining[keyEnd...]
        var locator: String? = nil

        if afterKey.hasPrefix(",") {
            let locatorText = afterKey.dropFirst().trimmingCharacters(in: .whitespaces)
            if !locatorText.isEmpty {
                locator = locatorText
            }
        }

        return CitationItem(key: key, locator: locator, suppressAuthor: suppressAuthor)
    }

    /// Check if a character is valid in a citation key.
    ///
    /// Valid characters: letters, digits, `_`, `-`, `:`, `.`
    private func isCitationKeyCharacter(_ ch: Character) -> Bool {
        ch.isLetter || ch.isNumber || ch == "_" || ch == "-" || ch == ":" || ch == "."
    }
}
