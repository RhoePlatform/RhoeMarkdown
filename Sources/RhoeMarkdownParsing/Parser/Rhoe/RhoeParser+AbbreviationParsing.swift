import Foundation
import RhoeMarkdownModel

extension RhoeParser {

    /// Try to parse an abbreviation definition from a text line.
    ///
    /// Abbreviation definitions follow the PHP Markdown Extra syntax:
    /// ```
    /// *[HTML]: Hyper Text Markup Language
    /// *[CSS]: Cascading Style Sheets
    /// ```
    ///
    /// These are block-level elements that define abbreviations for later expansion.
    func parseAbbreviationDefinition(from text: String) -> Block? {
        guard configuration.enableAbbreviations else { return nil }

        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("*[") else { return nil }

        // Find the closing bracket
        guard let closeBracket = trimmed.firstIndex(of: "]") else { return nil }

        let abbreviation = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<closeBracket])
        guard !abbreviation.isEmpty else { return nil }

        // Must be followed by ": "
        let afterBracket = trimmed.index(after: closeBracket)
        guard afterBracket < trimmed.endIndex && trimmed[afterBracket] == ":" else { return nil }

        let expansionStart = trimmed.index(after: afterBracket)
        let expansion = String(trimmed[expansionStart...]).trimmingCharacters(in: .whitespaces)
        guard !expansion.isEmpty else { return nil }

        return .abbreviationDefinition(abbreviation: abbreviation, expansion: expansion)
    }

    /// Post-processing pass: scan paragraphs for abbreviation definition patterns
    /// in the original source text and promote matching paragraphs to `.abbreviationDefinition` blocks.
    ///
    /// This works by checking each paragraph's original source line(s) for the `*[ABBR]: expansion`
    /// pattern. Since the lexer tokenizes `*` as emphasis, we can't detect abbreviation definitions
    /// at the token level — instead, we match paragraphs by line number to the original source.
    func promoteAbbreviationDefinitions(_ blocks: [Block], sourceLines: [String]) -> [Block] {
        blocks.compactMap { block -> Block? in
            // Only check single-line paragraphs
            guard case .paragraph(_, _) = block else { return block }

            // Try to find a matching source line for this paragraph
            // Walk sourceLines looking for *[ prefix lines that haven't been consumed
            // Since we don't have line number info on blocks, reconstruct from inline text
            let plainText = extractParagraphPlainText(block)
            let trimmed = plainText.trimmingCharacters(in: .whitespaces)

            // Check if the plain text looks like an abbreviation definition
            guard trimmed.hasPrefix("*[") || trimmed.contains("*[") else { return block }

            // Try to find the matching source line
            for sourceLine in sourceLines {
                let sourceLineTrimmed = sourceLine.trimmingCharacters(in: .whitespaces)
                guard sourceLineTrimmed.hasPrefix("*[") else { continue }
                if let abbrBlock = parseAbbreviationDefinition(from: sourceLineTrimmed) {
                    return abbrBlock
                }
            }

            return block
        }
    }

    /// Extract plain text from a paragraph block for matching purposes.
    fileprivate func extractParagraphPlainText(_ block: Block) -> String {
        guard case .paragraph(let inlines, _) = block else { return "" }
        return inlinesToPlainTextForAbbreviations(inlines)
    }

    fileprivate func inlinesToPlainTextForAbbreviations(_ inlines: [Inline]) -> String {
        inlines.map { inline -> String in
            switch inline {
            case .text(let text): return text
            case .emphasis(let content), .strong(let content), .strikethrough(let content):
                return inlinesToPlainTextForAbbreviations(content)
            case .codeSpan(let text, _): return text
            case .link(let text, _, _, _): return inlinesToPlainTextForAbbreviations(text)
            default: return ""
            }
        }.joined()
    }

    /// Post-processing: expand abbreviations in all text inlines throughout the document.
    ///
    /// Collects all `.abbreviationDefinition` blocks, then walks through all inline
    /// content replacing matching text with `<abbr>` spans.
    func expandAbbreviations(in blocks: [Block]) -> [Block] {
        // Collect abbreviation definitions
        var definitions: [String: String] = [:]
        for block in blocks {
            if case .abbreviationDefinition(let abbr, let expansion) = block {
                definitions[abbr] = expansion
            }
        }

        guard !definitions.isEmpty else { return blocks }

        // Walk blocks and expand abbreviations in inline content
        return blocks.map { expandAbbreviationsInBlock($0, definitions: definitions) }
    }

    fileprivate func expandAbbreviationsInBlock(
        _ block: Block,
        definitions: [String: String]
    ) -> Block {
        switch block {
        case .paragraph(let inlines, let attrs):
            return .paragraph(expandAbbreviationsInInlines(inlines, definitions: definitions), attributes: attrs)
        case .heading(let level, let content, let attrs):
            return .heading(level: level, content: expandAbbreviationsInInlines(content, definitions: definitions), attributes: attrs)
        case .blockQuote(let blocks, let attrs):
            return .blockQuote(blocks.map { expandAbbreviationsInBlock($0, definitions: definitions) }, attributes: attrs)
        case .list(let type, let items, let attrs):
            let expandedItems = items.map { item in
                ListItem(
                    content: item.content.map { expandAbbreviationsInBlock($0, definitions: definitions) },
                    checked: item.checked,
                    isLoose: item.isLoose
                )
            }
            return .list(type: type, items: expandedItems, attributes: attrs)
        case .div(let content, let attrs):
            return .div(content: content.map { expandAbbreviationsInBlock($0, definitions: definitions) }, attributes: attrs)
        default:
            return block
        }
    }

    fileprivate func expandAbbreviationsInInlines(
        _ inlines: [Inline],
        definitions: [String: String]
    ) -> [Inline] {
        inlines.flatMap { inline -> [Inline] in
            switch inline {
            case .text(let text):
                return expandAbbreviationsInText(text, definitions: definitions)
            case .emphasis(let content):
                return [.emphasis(expandAbbreviationsInInlines(content, definitions: definitions))]
            case .strong(let content):
                return [.strong(expandAbbreviationsInInlines(content, definitions: definitions))]
            default:
                return [inline]
            }
        }
    }

    fileprivate func expandAbbreviationsInText(
        _ text: String,
        definitions: [String: String]
    ) -> [Inline] {
        // Sort by length (longest first) to prevent partial matches
        let sortedAbbrs = definitions.keys.sorted { $0.count > $1.count }

        var result: [Inline] = []
        var remaining = text

        while !remaining.isEmpty {
            var matched = false

            for abbr in sortedAbbrs {
                if let range = remaining.range(of: abbr) {
                    // Check word boundaries
                    let beforeOK = range.lowerBound == remaining.startIndex ||
                        !remaining[remaining.index(before: range.lowerBound)].isLetter
                    let afterOK = range.upperBound == remaining.endIndex ||
                        !remaining[range.upperBound].isLetter

                    if beforeOK && afterOK {
                        // Add text before the match
                        let before = String(remaining[..<range.lowerBound])
                        if !before.isEmpty {
                            result.append(.text(before))
                        }

                        // Add the abbreviation as an HTML abbr tag
                        let expansion = definitions[abbr]!
                        result.append(.html("<abbr title=\"\(expansion)\">\(abbr)</abbr>"))

                        remaining = String(remaining[range.upperBound...])
                        matched = true
                        break
                    }
                }
            }

            if !matched {
                // No abbreviation matched — advance one character
                result.append(.text(String(remaining.prefix(1))))
                remaining = String(remaining.dropFirst())
            }
        }

        // Coalesce adjacent text inlines
        return coalesceTextInlines(result)
    }

    fileprivate func coalesceTextInlines(_ inlines: [Inline]) -> [Inline] {
        var result: [Inline] = []
        var currentText = ""

        for inline in inlines {
            if case .text(let text) = inline {
                currentText += text
            } else {
                if !currentText.isEmpty {
                    result.append(.text(currentText))
                    currentText = ""
                }
                result.append(inline)
            }
        }

        if !currentText.isEmpty {
            result.append(.text(currentText))
        }

        return result
    }
}
