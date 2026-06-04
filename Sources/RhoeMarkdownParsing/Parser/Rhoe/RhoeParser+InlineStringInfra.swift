import Foundation
import RhoeMarkdownModel

private let gfmStringInlineDomainSuffixes = [".com", ".org", ".net", ".edu", ".gov", ".io", ".co"]

extension RhoeParser {

    // MARK: - Inline String Parsing Entry Point

    func parseInlines(_ text: String) -> [Inline] {
        collectStringInlines(from: text)
    }

    // MARK: - String Collection

    func collectStringInlines(from text: String) -> [Inline] {
        var inlines: [Inline] = []
        var currentPos = text.startIndex

        while currentPos < text.endIndex {
            appendNextStringInlineOrPlainText(
                from: text,
                at: &currentPos,
                to: &inlines
            )
        }

        return inlines
    }

    // MARK: - String Fallback Support

    func appendNextStringInlineOrPlainText(
        from text: String,
        at position: inout String.Index,
        to inlines: inout [Inline]
    ) {
        if let inline = parseNextStringInline(in: text, at: &position) {
            inlines.append(inline)
            return
        }

        appendStringPlainTextRun(from: text, at: &position, to: &inlines)
    }

    // MARK: - Plain Text Support

    func appendStringPlainTextRun(
        from text: String,
        at position: inout String.Index,
        to inlines: inout [Inline]
    ) {
        let textStart = position

        while position < text.endIndex && !shouldStopStringPlainTextRun(in: text, at: position) {
            position = text.index(after: position)
        }

        if position > textStart {
            let textContent = String(text[textStart..<position])
            if !textContent.isEmpty {
                inlines.append(.text(applySmartPunctuation(to: textContent)))
            }
            return
        }

        inlines.append(.text(applySmartPunctuation(to: String(text[position]))))
        position = text.index(after: position)
    }

    func shouldStopStringPlainTextRun(
        in text: String,
        at position: String.Index
    ) -> Bool {
        let character = text[position]

        if isStringInlineTriggerCharacter(character) {
            return true
        }

        return shouldStopForStringAutolinkBoundary(in: text, at: position)
    }

    func isStringInlineTriggerCharacter(_ character: Character) -> Bool {
        character == "*" ||
            character == "_" ||
            character == "~" ||
            character == "`" ||
            character == "[" ||
            character == "@" ||
            character == "#" ||
            character == ":" ||
            character == "!" ||
            character == "$" ||
            character == "^" ||
            character == "=" ||
            character == "{" ||
            character == "<"  // composition directives <<...>>
    }

    fileprivate func shouldStopForStringAutolinkBoundary(
        in text: String,
        at position: String.Index
    ) -> Bool {
        guard position > text.startIndex else { return false }

        let prefix = String(text[text.index(before: position)...position])
        if prefix == "://" {
            return true
        }

        if text[position] == ".",
           position < text.index(before: text.endIndex),
           gfmStringInlineDomainSuffixes.contains(where: { text[position...].hasPrefix($0) }) {
            return true
        }

        return false
    }

    // MARK: - Special Character Support

    func parseSpecialCharacterStringInline(
        in text: String,
        at position: inout String.Index
    ) -> Inline? {
        let character = text[position]

        if (character == "*" || character == "_"),
           let emphasis = parseEmphasisFromText(text, at: &position) {
            return emphasis
        }

        if character == "~" {
            // Single tilde = subscript, double tilde = strikethrough
            if position < text.index(before: text.endIndex) && text[text.index(after: position)] == "~" {
                // Double tilde: strikethrough
                if let strikethrough = parseStrikethroughFromText(text, at: &position) {
                    return strikethrough
                }
            } else {
                // Single tilde: subscript
                if let sub = parseSubscriptFromText(text, at: &position) {
                    return sub
                }
            }
        }

        if character == "^" {
            // Try inline footnote first: ^[content]
            if let footnote = parseInlineFootnoteFromText(text, at: &position) {
                return footnote
            }
            // Then try superscript: ^text^
            if let sup = parseSuperscriptFromText(text, at: &position) {
                return sup
            }
        }

        if character == "=",
           position < text.index(before: text.endIndex),
           text[text.index(after: position)] == "=",
           let hl = parseHighlightFromText(text, at: &position) {
            return hl
        }

        if character == "`",
           let code = parseCodeFromText(text, at: &position) {
            return code
        }

        if character == "!",
           position < text.index(before: text.endIndex),
           text[text.index(after: position)] == "[",
           let image = parseImageFromText(text, at: &position) {
            return image
        }

        if character == "[" {
            // Try wikilink first: [[target]] or [[target|display]]
            if let wikilink = parseWikilinkFromText(text, at: &position) {
                return wikilink
            }
            // Try citation: [@key] or [-@key]
            if let citation = parseCitationFromText(text, at: &position) {
                return citation
            }
            // Then try link: [text](url)
            if let link = parseLinkFromText(text, at: &position) {
                return link
            }
        }

        if character == "$",
           let math = parseMathFromText(text, at: &position) {
            return math
        }

        if character == "{",
           let placeholder = parseInlinePlaceholderFromText(text, at: &position) {
            return placeholder
        }

        // Composition directives <<keyword ...>>
        if character == "<" {
            if let directive = parseCompositionDirectiveInline(text, at: &position) {
                return directive
            }
        }

        return nil
    }

    // MARK: - Detector Support

    func parseNextStringInline(
        in text: String,
        at position: inout String.Index
    ) -> Inline? {
        // Composition directives << >> have highest priority for <
        if position < text.endIndex && text[position] == "<" {
            var tempPos = position
            if let directive = parseCompositionDirectiveInline(text, at: &tempPos) {
                position = tempPos
                return directive
            }
        }

        // Cross-reference has highest priority for @: @fig-name, @tbl-name, etc.
        if let crossRef = detectCrossReference(in: text, at: position) {
            position = crossRef.endIndex
            return crossRef.inline
        }

        if let autolink = detectExtendedAutolink(in: text, at: position) {
            position = autolink.endIndex
            return autolink.inline
        }

        if position < text.endIndex && text[position] == "<" {
            var tempPos = position
            if let html = parseHTMLInlineFromText(text, at: &tempPos) {
                position = tempPos
                return html
            }
        }

        if let mention = detectMention(in: text, at: position) {
            position = mention.endIndex
            return mention.inline
        }

        if let reference = detectIssueReference(in: text, at: position) {
            position = reference.endIndex
            return reference.inline
        }

        if let emoji = detectEmoji(in: text, at: position) {
            position = emoji.endIndex
            return emoji.inline
        }

        return parseSpecialCharacterStringInline(in: text, at: &position)
    }

    func parseHTMLInlineFromText(_ text: String, at position: inout String.Index) -> Inline? {
        guard position < text.endIndex, text[position] == "<" else {
            return nil
        }

        let suffix = String(text[position...])
        guard let closing = firstHTMLTagClosingBracket(in: suffix, startingAt: suffix.startIndex) else {
            return nil
        }

        let tag = String(suffix[...closing])
        guard isCommonMarkRawHTMLInline(tag) else {
            return nil
        }

        position = text.index(position, offsetBy: tag.count)
        return .html(tag)
    }
}
