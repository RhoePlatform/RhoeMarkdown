import Foundation
import RhoeMarkdownModel

struct SourceLineMap: Sendable {
    private let lineStartOffsets: [Int]
    private let sourceLength: Int

    init(source: String) {
        var starts = [0]
        var offset = 0

        for character in source {
            offset += 1
            if character == "\n" {
                starts.append(offset)
            }
        }

        self.lineStartOffsets = starts
        self.sourceLength = offset
    }

    func collapsedRange(line: Int?, column: Int?) -> SourceRange? {
        guard let line, let column else { return nil }
        guard let location = location(line: line, column: column) else { return nil }
        return SourceRange(start: location, end: location)
    }

    private func location(line: Int, column: Int) -> SourceLocation? {
        guard line > 0, column > 0, line <= lineStartOffsets.count else { return nil }

        let lineStart = lineStartOffsets[line - 1]
        let nextLineStart = line < lineStartOffsets.count ? lineStartOffsets[line] : sourceLength
        let lineEnd = max(lineStart, nextLineStart - 1)
        let requestedOffset = lineStart + (column - 1)
        let boundedOffset = min(max(requestedOffset, lineStart), lineEnd)
        let boundedColumn = max(1, boundedOffset - lineStart + 1)

        return SourceLocation(line: line, column: boundedColumn, offset: boundedOffset)
    }
}
