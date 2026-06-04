import Foundation
import RhoeMarkdownModel

extension RhoeParser {
    /// Post-process an inline array to parse extended inline syntax.
    ///
    /// The token-based pipeline leaves `^text^`, `~text~`, `==text==`,
    /// `^[content]`, `[@key]`, and `:emoji:` shortcodes as `.text` nodes because the lexer
    /// doesn't create tokens for these delimiters.
    /// This pass coalesces adjacent `.text` nodes into a single string, then
    /// re-parses through the string-based inline pipeline which handles them.
    func rewriteInlinesForExtendedSyntax(_ inlines: [Inline]) -> [Inline] {
        // Quick exit: if no text nodes contain trigger characters, skip.
        let hasTrigger = inlines.contains { inline in
            guard case .text(let content) = inline else { return false }
            return requiresFullStringInlineReparse(content) || content.contains(":")
        }
        guard hasTrigger else { return inlines }

        // Coalesce runs of text nodes and re-parse them.
        var result: [Inline] = []
        var textBuffer = ""

        for inline in inlines {
            if case .text(let content) = inline {
                textBuffer.append(content)
            } else {
                if !textBuffer.isEmpty {
                    let reparsed = reparseTextBufferForExtendedSyntax(textBuffer)
                    result.append(contentsOf: reparsed)
                    textBuffer = ""
                }
                // Recursively rewrite child inlines
                result.append(rewriteChildInlines(inline))
            }
        }

        if !textBuffer.isEmpty {
            let reparsed = reparseTextBufferForExtendedSyntax(textBuffer)
            result.append(contentsOf: reparsed)
        }

        return result
    }

    /// Check if text contains a potential cross-reference trigger (`@prefix-`).
    ///
    /// This is more targeted than `content.contains("@")` to avoid
    /// over-triggering the rewrite pass for mentions and other `@` uses.
    private func hasCrossRefTrigger(in content: String) -> Bool {
        guard configuration.enableCrossReferences else { return false }
        for prefix in CrossRefPrefix.allCases {
            if content.contains("@\(prefix.rawValue)-") {
                return true
            }
        }
        return false
    }

    private func requiresFullStringInlineReparse(_ content: String) -> Bool {
        (configuration.enableSuperscript && content.contains("^")) ||
        (configuration.enableSubscript && content.contains("~")) ||
        (configuration.enableHighlight && content.contains("=")) ||
        (shouldReparseBracketExtensions(in: content)) ||
        (shouldReparseBraceExtensions(in: content)) ||
        (shouldReparseAngleExtensions(in: content)) ||
        hasCrossRefTrigger(in: content) ||
        (configuration.enableSmartPunctuation &&
         (content.contains("\"") || content.contains("'") ||
          content.contains("-") || content.contains(".")))
    }

    private func shouldReparseBracketExtensions(in content: String) -> Bool {
        (configuration.enableWikilinks && content.contains("[[")) ||
        (configuration.enableCitations && (content.contains("[@") || content.contains("[-@"))) ||
        (configuration.enableInlineFootnotes && content.contains("^["))
    }

    private func shouldReparseBraceExtensions(in content: String) -> Bool {
        guard content.contains("{") else { return false }
        return configuration.enableInputBindings ||
            configuration.enablePhase2Transforms ||
            configuration.enableCoreExpressions
    }

    private func shouldReparseAngleExtensions(in content: String) -> Bool {
        guard contentContainsUnescapedProtectedCandidate("<", in: content) else { return false }
        return configuration.enableTransclusions ||
            configuration.enableComponents ||
            configuration.enableVisualBlocks
    }

    private func contentContainsUnescapedProtectedCandidate(_ candidate: Character, in content: String) -> Bool {
        var index = content.startIndex
        while index < content.endIndex {
            if content[index] == "\u{E000}" {
                let protected = content.index(after: index)
                index = protected < content.endIndex ? content.index(after: protected) : protected
                continue
            }

            if content[index] == candidate {
                return true
            }

            index = content.index(after: index)
        }

        return false
    }

    private func reparseTextBufferForExtendedSyntax(_ text: String) -> [Inline] {
        if requiresFullStringInlineReparse(text) {
            return parseInlines(text)
        }

        return rewriteEmojiShortcodes(in: text)
    }

    private func rewriteEmojiShortcodes(in text: String) -> [Inline] {
        var inlines: [Inline] = []
        var cursor = text.startIndex
        var plainTextStart = cursor

        while cursor < text.endIndex {
            if let emoji = detectEmoji(in: text, at: cursor) {
                if cursor > plainTextStart {
                    inlines.append(.text(String(text[plainTextStart..<cursor])))
                }
                inlines.append(emoji.inline)
                cursor = emoji.endIndex
                plainTextStart = cursor
                continue
            }

            cursor = text.index(after: cursor)
        }

        if plainTextStart < text.endIndex {
            inlines.append(.text(String(text[plainTextStart...])))
        }

        return inlines
    }

    /// Recursively rewrite child inlines within container inline types.
    private func rewriteChildInlines(_ inline: Inline) -> Inline {
        switch inline {
        case .emphasis(let children):
            return .emphasis(rewriteInlinesForExtendedSyntax(children))
        case .strong(let children):
            return .strong(rewriteInlinesForExtendedSyntax(children))
        case .strikethrough(let children):
            return .strikethrough(rewriteInlinesForExtendedSyntax(children))
        case .link(let text, let url, let title, let attrs):
            return .link(text: rewriteInlinesForExtendedSyntax(text), url: url, title: title, attributes: attrs)
        case .superscript(let children):
            return .superscript(rewriteInlinesForExtendedSyntax(children))
        case .subscript(let children):
            return .subscript(rewriteInlinesForExtendedSyntax(children))
        case .highlight(let children):
            return .highlight(rewriteInlinesForExtendedSyntax(children))
        case .span(let children, let attrs):
            return .span(content: rewriteInlinesForExtendedSyntax(children), attributes: attrs)
        case .inlineFootnote(let children):
            return .inlineFootnote(content: rewriteInlinesForExtendedSyntax(children))
        default:
            return inline
        }
    }
}
