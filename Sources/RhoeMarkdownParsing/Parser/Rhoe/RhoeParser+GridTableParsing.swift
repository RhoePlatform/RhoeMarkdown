import Foundation
import RhoeMarkdownModel

extension RhoeParser {

    /// Try to parse a grid table at the current position.
    ///
    /// Grid tables use `+---+` borders with `|` cell delimiters:
    /// ```
    /// +------+------+
    /// | Head | Head |
    /// +======+======+
    /// | Cell | Cell |
    /// +------+------+
    /// ```
    func parseGridTableBlockIfPresent(_ state: inout RhoeParserState) -> Block? {
        guard configuration.enableGridTables else { return nil }

        let savedIndex = state.currentIndex

        // Collect the raw text lines that form the potential grid table
        guard let rawLines = collectGridTableLines(state: &state) else {
            state.currentIndex = savedIndex
            return nil
        }

        guard rawLines.count >= 3 else {
            state.currentIndex = savedIndex
            return nil
        }

        guard let gridTable = parseGridStructure(from: rawLines) else {
            state.currentIndex = savedIndex
            return nil
        }

        let attributes = consumeAttributeList(&state) ?? RhoeMarkdownKit.Attributes()
        return .table(
            headers: gridTable.headers,
            rows: gridTable.rows,
            attributes: attributes
        )
    }

    /// Collect raw text lines from the token stream that form a grid table.
    ///
    /// Collects lines starting with `+` (border) and `|` (content) until the
    /// final border line is reached. Returns nil if the first line doesn't match
    /// a grid table border pattern.
    fileprivate func collectGridTableLines(state: inout RhoeParserState) -> [String]? {
        var lines: [String] = []
        var currentLine = ""
        let savedIndex = state.currentIndex

        // The first text token must start a grid border
        guard let firstToken = state.current,
              case .text(let firstContent) = firstToken.type else {
            return nil
        }

        let trimmedFirst = firstContent.trimmingCharacters(in: .whitespaces)
        guard isGridBorderLine(trimmedFirst) else {
            return nil
        }

        // Collect tokens line by line
        while let token = state.current {
            switch token.type {
            case .text(let content):
                currentLine += content
                state.advance()

            case .newline:
                let trimmedLine = currentLine.trimmingCharacters(in: .whitespaces)
                if !trimmedLine.isEmpty {
                    lines.append(trimmedLine)
                }
                currentLine = ""
                state.advance()

                // If we just collected a border line after content lines, check if done
                if lines.count >= 3 && isGridBorderLine(trimmedLine) {
                    // Check if the next line is NOT a grid content/border line
                    let peekSaved = state.currentIndex
                    var peekText = ""
                    // Consume optional paragraph token
                    if let pToken = state.current, case .paragraph = pToken.type {
                        state.advance()
                    }
                    if let next = state.current, case .text(let nc) = next.type {
                        peekText = nc.trimmingCharacters(in: .whitespaces)
                    }
                    state.currentIndex = peekSaved

                    if !peekText.hasPrefix("|") && !peekText.hasPrefix("+") {
                        return lines
                    }
                }

            case .paragraph:
                // Paragraph marker between lines — skip it
                state.advance()

            case .emphasis(let level):
                // Inside grid table cells, * could appear as emphasis markers
                currentLine += String(repeating: "*", count: level)
                state.advance()

            case .code:
                currentLine += "`"
                state.advance()

            case .strikethrough:
                currentLine += "~~"
                state.advance()

            case .space(let count):
                currentLine += String(repeating: " ", count: count)
                state.advance()

            case .eof:
                if !currentLine.isEmpty {
                    let trimmedLine = currentLine.trimmingCharacters(in: .whitespaces)
                    if !trimmedLine.isEmpty {
                        lines.append(trimmedLine)
                    }
                }
                return lines.count >= 3 ? lines : nil

            default:
                // Non-grid token — end collection
                if !currentLine.isEmpty {
                    let trimmedLine = currentLine.trimmingCharacters(in: .whitespaces)
                    if !trimmedLine.isEmpty {
                        lines.append(trimmedLine)
                    }
                }

                if lines.count >= 3 && isGridBorderLine(lines.last ?? "") {
                    return lines
                }

                state.currentIndex = savedIndex
                return nil
            }
        }

        // EOF reached
        if !currentLine.isEmpty {
            let trimmedLine = currentLine.trimmingCharacters(in: .whitespaces)
            if !trimmedLine.isEmpty {
                lines.append(trimmedLine)
            }
        }

        return lines.count >= 3 ? lines : nil
    }
}
