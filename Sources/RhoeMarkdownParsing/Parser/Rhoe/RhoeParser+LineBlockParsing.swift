import Foundation
import RhoeMarkdownModel

extension RhoeParser {

    /// Try to parse a line block from the token stream.
    ///
    /// Line blocks are consecutive lines starting with `| `:
    /// ```
    /// | The limerick packs laughs anatomical
    /// | In space that is quite economical.
    /// |    But the good ones I've seen
    /// |    So seldom are clean
    /// | And the clean ones so seldom are comical.
    /// ```
    ///
    /// Leading whitespace after `| ` is preserved for indentation.
    /// Disambiguated from tables: single `|` at line start with no other `|` → line block.
    func parseLineBlockFromText(_ text: String, lines: [String], at index: inout Int) -> Block? {
        guard configuration.enableLineBlocks else { return nil }

        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard isLineBlockLine(trimmed) else { return nil }

        var lineBlockLines: [[Inline]] = []

        // Parse the first line
        lineBlockLines.append(parseLineBlockContent(trimmed))
        index += 1

        // Continue collecting consecutive line block lines
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                break
            }

            if isLineBlockLine(line) {
                lineBlockLines.append(parseLineBlockContent(line))
                index += 1
            } else {
                break
            }
        }

        guard !lineBlockLines.isEmpty else { return nil }
        return .lineBlock(lines: lineBlockLines)
    }

    /// Post-processing pass: detect consecutive paragraphs whose source lines
    /// start with `| ` (line block pattern) and merge them into `.lineBlock` blocks.
    ///
    /// This operates on the original source lines since the lexer tokenizes `|` as
    /// text, making token-level detection complex. Instead, we match paragraphs by
    /// checking whether the source text for each block matches the line block pattern.
    func promoteLineBlocks(_ blocks: [Block], sourceLines: [String]) -> [Block] {
        var result: [Block] = []

        // Build a set of line block source line indices
        var lineBlockRanges: [(start: Int, end: Int)] = []
        var i = 0
        while i < sourceLines.count {
            let trimmed = sourceLines[i].trimmingCharacters(in: .whitespaces)
            if isLineBlockLine(trimmed) {
                let start = i
                while i < sourceLines.count {
                    let line = sourceLines[i].trimmingCharacters(in: .whitespaces)
                    if isLineBlockLine(line) {
                        i += 1
                    } else {
                        break
                    }
                }
                lineBlockRanges.append((start: start, end: i))
            } else {
                i += 1
            }
        }

        guard !lineBlockRanges.isEmpty else { return blocks }

        // Now check each block — if it's a paragraph containing pipe text, it might be a line block
        var blockIndex = 0
        while blockIndex < blocks.count {
            let block = blocks[blockIndex]

            // Check if this paragraph matches a line block range
            if case .paragraph(let inlines, _) = block {
                let plainText = inlines.map { extractLineBlockText(from: $0) }.joined()
                let trimmedPlain = plainText.trimmingCharacters(in: .whitespaces)

                // Check if this paragraph's text starts with | (suggesting it's a line block line)
                if trimmedPlain.hasPrefix("|") {
                    // Find matching source line range
                    for range in lineBlockRanges {
                        let firstLine = sourceLines[range.start].trimmingCharacters(in: .whitespaces)
                        if isLineBlockLine(firstLine) {
                            // Build line block from source lines
                            var lineBlockLines: [[Inline]] = []
                            for lineIdx in range.start..<range.end {
                                let sourceLine = sourceLines[lineIdx].trimmingCharacters(in: .whitespaces)
                                lineBlockLines.append(parseLineBlockContent(sourceLine))
                            }
                            if !lineBlockLines.isEmpty {
                                result.append(.lineBlock(lines: lineBlockLines))
                                // Skip only this paragraph block (pipe lines form a single paragraph)
                                blockIndex += 1
                                break
                            }
                        }
                    }
                    // If we already handled it, continue
                    if blockIndex > blocks.count { break }
                    if result.last != nil, case .lineBlock = result.last! {
                        continue
                    }
                }
            }

            result.append(block)
            blockIndex += 1
        }

        return result
    }

    fileprivate func extractLineBlockText(from inline: Inline) -> String {
        switch inline {
        case .text(let text): return text
        case .emphasis(let content), .strong(let content), .strikethrough(let content):
            return content.map { extractLineBlockText(from: $0) }.joined()
        default: return ""
        }
    }

    /// Check if a line is a line block line (starts with `| ` or is just `|`).
    ///
    /// Disambiguation: A line block line has `|` followed by a space or end-of-line,
    /// with NO other `|` characters in the rest of the line (which would indicate a table).
    fileprivate func isLineBlockLine(_ line: String) -> Bool {
        guard line.hasPrefix("| ") || line == "|" else { return false }

        // Check for additional pipe characters (would indicate a table row)
        let afterPipe = line.hasPrefix("| ") ? String(line.dropFirst(2)) : ""
        return !afterPipe.contains("|")
    }

    /// Parse the content after the `| ` prefix, preserving leading whitespace.
    fileprivate func parseLineBlockContent(_ line: String) -> [Inline] {
        let content: String
        if line == "|" {
            content = ""
        } else {
            content = String(line.dropFirst(2)) // Drop "| "
        }

        if content.isEmpty {
            return [.text("")]
        }

        return collectStringInlines(from: content)
    }
}
