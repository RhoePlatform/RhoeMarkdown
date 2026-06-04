import Foundation
import RhoeMarkdownModel

// MARK: - Top Level Paragraph Entry

enum TopLevelParagraphEntry {
    case table(Block)
    case html(Block)
    case paragraph(inlines: [Inline], attributes: RhoeMarkdownKit.Attributes)
}

// MARK: - Top Level Flow

extension RhoeParser {

    // MARK: Block Flow

    func parseBlocksWithMetadata(
        _ state: inout RhoeParserState
    ) -> ([Block], [String: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue]?) {
        let yamlFrontmatter = parseOptionalYAMLFrontmatter(&state)
        var blocks = collectTopLevelBlocks(&state)

        if configuration.enableTableCaptions {
            blocks = mergeTableCaptions(blocks)
        }

        if configuration.enableAbbreviations {
            blocks = promoteAbbreviationDefinitions(blocks, sourceLines: state.sourceLines)
            blocks = expandAbbreviations(in: blocks)
        }

        if configuration.enableLineBlocks {
            blocks = promoteLineBlocks(blocks, sourceLines: state.sourceLines)
        }

        return (blocks, yamlFrontmatter)
    }

    /// Post-processing pass: merge `Table:` or `:` caption paragraphs into adjacent table blocks.
    ///
    /// A caption paragraph is detected when:
    /// - A paragraph's text starts with `Table:` (case-insensitive) or `:` followed by a space.
    /// - The paragraph immediately precedes or follows a `.table` block.
    ///
    /// The caption text (after the prefix) is parsed as inlines and attached to the table.
    func mergeTableCaptions(_ blocks: [Block]) -> [Block] {
        guard blocks.count >= 2 else { return blocks }

        var result: [Block] = []
        var skip = false

        for index in 0..<blocks.count {
            if skip {
                skip = false
                continue
            }

            let block = blocks[index]
            let nextIndex = index + 1

            // Check: caption paragraph followed by table
            if let captionInlines = extractTableCaption(from: block),
               nextIndex < blocks.count,
               case .table(let headers, let rows, _, let attributes) = blocks[nextIndex] {
                result.append(.table(headers: headers, rows: rows, caption: captionInlines, attributes: attributes))
                skip = true
                continue
            }

            // Check: table followed by caption paragraph
            if case .table(let headers, let rows, nil, let attributes) = block,
               nextIndex < blocks.count,
               let captionInlines = extractTableCaption(from: blocks[nextIndex]) {
                result.append(.table(headers: headers, rows: rows, caption: captionInlines, attributes: attributes))
                skip = true
                continue
            }

            result.append(block)
        }

        return result
    }

    /// Extract caption inlines from a paragraph starting with `Table:`.
    ///
    /// Detects paragraphs whose plain text begins with `Table:` (case-insensitive).
    /// The caption content is the remaining inlines after the prefix is stripped.
    fileprivate func extractTableCaption(from block: Block) -> [Inline]? {
        guard case .paragraph(let inlines, _) = block else { return nil }
        guard !inlines.isEmpty else { return nil }

        // Build the full plain text to detect the prefix
        let plainText = inlinesToPlainText(inlines).trimmingCharacters(in: .whitespaces)

        // Match `Table: caption text` (case-insensitive)
        guard let range = plainText.range(of: "^[Tt]able:\\s*", options: .regularExpression) else {
            return nil
        }

        let captionPlainText = String(plainText[range.upperBound...])
            .trimmingCharacters(in: .whitespaces)
        if captionPlainText.isEmpty { return nil }

        // Reconstruct caption inlines by stripping the "Table: " prefix from the inline sequence.
        // Walk through inlines, consuming characters from the prefix length.
        let prefixLength = plainText.distance(from: plainText.startIndex, to: range.upperBound)
        return stripInlinePrefix(inlines, count: prefixLength)
    }

    /// Convert inlines to plain text for prefix detection.
    fileprivate func inlinesToPlainText(_ inlines: [Inline]) -> String {
        inlines.map { inline -> String in
            switch inline {
            case .text(let text): return text
            case .emphasis(let nested), .strong(let nested), .strikethrough(let nested):
                return inlinesToPlainText(nested)
            case .codeSpan(let text, _): return text
            case .link(let text, _, _, _): return inlinesToPlainText(text)
            case .image(let alt, _, _, _): return inlinesToPlainText(alt)
            default: return ""
            }
        }.joined()
    }

    /// Strip `count` characters from the front of the inline sequence,
    /// trimming or removing `.text` inlines as needed.
    fileprivate func stripInlinePrefix(_ inlines: [Inline], count: Int) -> [Inline] {
        var remaining = count
        var result: [Inline] = []
        var started = false

        for inline in inlines {
            if remaining <= 0 {
                if !started {
                    // Trim leading whitespace from the first text inline after the prefix
                    if case .text(let text) = inline {
                        let trimmed = text.drop { $0 == " " || $0 == "\t" }
                        if !trimmed.isEmpty {
                            result.append(.text(String(trimmed)))
                        }
                        started = true
                        continue
                    }
                }
                result.append(inline)
                started = true
                continue
            }

            if case .text(let text) = inline {
                if text.count <= remaining {
                    remaining -= text.count
                } else {
                    let stripped = String(text.dropFirst(remaining))
                    let trimmed = stripped.drop { $0 == " " || $0 == "\t" }
                    if !trimmed.isEmpty {
                        result.append(.text(String(trimmed)))
                    }
                    remaining = 0
                    started = true
                }
            } else {
                // Non-text inline inside the prefix — skip it
                remaining = 0
                result.append(inline)
                started = true
            }
        }

        return result
    }

    // MARK: Block Collection

    func collectTopLevelBlocks(_ state: inout RhoeParserState) -> [Block] {
        collectBlocks(
            &state,
            until: { token, _ in token.type == .eof },
            using: { state, blocks in
                appendTopLevelParsedBlockOrAdvance(&state, into: &blocks)
            }
        )
    }

    fileprivate func appendTopLevelParsedBlockOrAdvance(
        _ state: inout RhoeParserState,
        into blocks: inout [Block]
    ) {
        let startIndex = state.currentIndex

        if let block = parseBlock(&state) {
            blocks.append(block)
        } else if state.currentIndex == startIndex {
            consumeParsedBlockOrAdvance(&state, into: &blocks)
        }
    }

    // MARK: Paragraph Promotion

    func parsePromotedTopLevelParagraphEntry(
        _ state: inout RhoeParserState
    ) -> TopLevelParagraphEntry {
        consumeParagraphLeadTokenIfPresent(&state)

        // Grid tables take priority (they start with + which wouldn't match pipe tables)
        if let gridTable = parseGridTableBlockIfPresent(&state) {
            return .table(gridTable)
        }

        if let tableBlock = parseTableBlockIfPresent(&state) {
            return .table(tableBlock)
        }

        if let htmlBlock = parseHTMLBlockIfPresent(&state, requireInterruptingStart: false) {
            return .html(htmlBlock)
        }

        let inlines = parseTopLevelParagraphInlineRun(&state)
        let attributes = consumeAttributeList(&state) ?? RhoeMarkdownKit.Attributes()
        return .paragraph(inlines: inlines, attributes: attributes)
    }

    func parseTopLevelParagraphInlineRun(_ state: inout RhoeParserState) -> [Inline] {
        parseParagraphStyleInlineRun(&state, mode: .paragraph)
    }

    func consumeParagraphLeadTokenIfPresent(_ state: inout RhoeParserState) {
        if let token = state.current, case .paragraph = token.type {
            state.advance()
        }
    }

    // MARK: Paragraph Style

    func topLevelParagraphStyleFlowControl(
        for token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline]
    ) -> ParagraphStyleFlowControl {
        guard token.type == .newline else {
            return .parseInlineToken
        }

        return paragraphNewlineFlowControl(state: &state, inlines: &inlines)
    }

    func shouldStopTopLevelParagraphInlineRun(
        before token: RhoeLexer.Token,
        loopCount: Int
    ) -> Bool {
        if loopCount > 10_000 {
            print("⚠️  Potential infinite loop in parseParagraph at token: \(token.type)")
            return true
        }

        switch token.type {
        case .heading,
             .blockQuoteMarker,
             .codeBlockDelimiter,
             .horizontalRule,
             .admonitionEnd,
             .definitionTerm,
             .definitionMarker,
             .attributeList,
             .fencedDivStart,
             .fencedDivEnd,
             .eof:
            return true
        default:
            return false
        }
    }
}
