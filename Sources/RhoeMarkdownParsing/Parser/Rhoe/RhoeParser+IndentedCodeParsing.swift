import Foundation
import RhoeMarkdownModel

extension RhoeParser {
    func isAtIndentedCodeBlockStart(
        _ token: RhoeLexer.Token,
        state: RhoeParserState
    ) -> Bool {
        guard token.type != .eof else { return false }
        guard token.line > 0, token.line <= state.sourceLines.count else { return false }
        let line = state.sourceLines[token.line - 1]
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return indentationColumns(in: line) >= 4
    }

    func parseIndentedCodeBlock(_ state: inout RhoeParserState) -> Block {
        guard let token = state.current else {
            return .codeBlock(language: nil, content: "")
        }

        var lineIndex = token.line - 1
        var codeLines: [String] = []
        var lastConsumedLine = token.line

        while lineIndex < state.sourceLines.count {
            let line = state.sourceLines[lineIndex]
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                codeLines.append("")
                lastConsumedLine = lineIndex + 1
                lineIndex += 1
                continue
            }

            guard indentationColumns(in: line) >= 4 else {
                break
            }

            codeLines.append(removingIndentColumns(4, from: line))
            lastConsumedLine = lineIndex + 1
            lineIndex += 1
        }

        while codeLines.last?.isEmpty == true {
            codeLines.removeLast()
        }

        advance(&state, throughSourceLine: lastConsumedLine)

        let content = codeLines.isEmpty ? "" : codeLines.joined(separator: "\n") + "\n"
        return .codeBlock(language: nil, content: content)
    }

    func indentationColumns(in line: String) -> Int {
        var columns = 0
        for character in line {
            if character == " " {
                columns += 1
            } else if character == "\t" {
                columns += 4 - (columns % 4)
            } else {
                break
            }
        }
        return columns
    }

    func removingIndentColumns(_ targetColumns: Int, from line: String) -> String {
        var columns = 0
        var index = line.startIndex
        var preservedIndentColumns = 0

        while index < line.endIndex, columns < targetColumns {
            let character = line[index]
            if character == " " {
                columns += 1
                index = line.index(after: index)
            } else if character == "\t" {
                let width = 4 - (columns % 4)
                let nextColumns = columns + width
                if nextColumns > targetColumns {
                    preservedIndentColumns += nextColumns - targetColumns
                }
                columns = nextColumns
                index = line.index(after: index)
            } else {
                break
            }
        }

        while index < line.endIndex {
            let character = line[index]
            if character == " " {
                preservedIndentColumns += 1
                columns += 1
                index = line.index(after: index)
            } else if character == "\t" {
                let width = 4 - (columns % 4)
                preservedIndentColumns += width
                columns += width
                index = line.index(after: index)
            } else {
                break
            }
        }

        return String(repeating: " ", count: preservedIndentColumns) + String(line[index...])
    }

    func advance(_ state: inout RhoeParserState, throughSourceLine line: Int) {
        while let token = state.current, token.type != .eof, token.line <= line {
            state.advance()
        }
    }
}
