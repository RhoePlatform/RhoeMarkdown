import Foundation
import RhoeMarkdownModel

/// Parsed grid table structure before conversion to Block.
struct ParsedGridTable {
    let headers: [TableCell]
    let rows: [[TableCell]]
}

extension RhoeParser {

    // MARK: - Grid Structure Analysis

    /// Parse collected raw lines into a grid table structure.
    ///
    /// The lines must form a valid grid pattern:
    /// ```
    /// +------+------+       ← top border
    /// | Head | Head |       ← header row(s)
    /// +======+======+       ← header separator (= signs)
    /// | Cell | Cell |       ← body row(s)
    /// +------+------+       ← bottom border (or more rows)
    /// ```
    func parseGridStructure(from lines: [String]) -> ParsedGridTable? {
        guard lines.count >= 3 else { return nil }
        guard isGridBorderLine(lines[0]) else { return nil }

        // Determine column boundaries from the first border line
        let columnBoundaries = findColumnBoundaries(in: lines[0])
        guard columnBoundaries.count >= 2 else { return nil }

        // Split lines into sections separated by border lines
        var sections: [[String]] = []
        var currentSection: [String] = []
        var headerSepIndex: Int?

        for (index, line) in lines.enumerated() {
            if isGridBorderLine(line) {
                if !currentSection.isEmpty {
                    sections.append(currentSection)
                    currentSection = []
                }
                // Check if this is a header separator (contains =)
                if index > 0 && line.contains("=") {
                    headerSepIndex = sections.count
                }
            } else if isGridContentLine(line) {
                currentSection.append(line)
            }
        }

        // Append any remaining content
        if !currentSection.isEmpty {
            sections.append(currentSection)
        }

        guard !sections.isEmpty else { return nil }

        // Parse sections into rows
        var headerRows: [[TableCell]] = []
        var bodyRows: [[TableCell]] = []

        for (sectionIndex, section) in sections.enumerated() {
            let cells = parseGridRow(
                lines: section,
                columnBoundaries: columnBoundaries
            )

            if let headerSepIndex, sectionIndex < headerSepIndex {
                headerRows.append(cells)
            } else {
                bodyRows.append(cells)
            }
        }

        // If no header separator was found, treat the first section as header
        if headerSepIndex == nil && sections.count >= 2 {
            let firstRow = bodyRows.removeFirst()
            headerRows.append(firstRow)
        }

        // Merge header rows into a single header (most common case)
        let headers: [TableCell]
        if headerRows.isEmpty {
            // No headers — use empty cells matching column count
            headers = (0..<(columnBoundaries.count - 1)).map { _ in
                TableCell(content: [])
            }
        } else if headerRows.count == 1 {
            headers = headerRows[0]
        } else {
            // Multiple header rows — concatenate content per column
            let colCount = columnBoundaries.count - 1
            headers = (0..<colCount).map { col in
                var combinedInlines: [Inline] = []
                for row in headerRows {
                    if col < row.count {
                        if !combinedInlines.isEmpty {
                            combinedInlines.append(.softBreak)
                        }
                        combinedInlines.append(contentsOf: row[col].content)
                    }
                }
                return TableCell(content: combinedInlines)
            }
        }

        return ParsedGridTable(headers: headers, rows: bodyRows)
    }

    // MARK: - Row Parsing

    /// Parse a grid row from one or more content lines.
    fileprivate func parseGridRow(
        lines: [String],
        columnBoundaries: [Int]
    ) -> [TableCell] {
        let colCount = columnBoundaries.count - 1
        guard colCount > 0 else { return [] }

        // Extract text for each column by slicing between boundaries
        var columnTexts: [[String]] = Array(repeating: [], count: colCount)

        for line in lines {
            let chars = Array(line)
            for col in 0..<colCount {
                let start = columnBoundaries[col] + 1  // Skip the | or +
                let end = col + 1 < columnBoundaries.count ? columnBoundaries[col + 1] : chars.count

                if start < chars.count && end <= chars.count && start < end {
                    let cellContent = String(chars[start..<end])
                        .trimmingCharacters(in: .whitespaces)
                    columnTexts[col].append(cellContent)
                } else {
                    columnTexts[col].append("")
                }
            }
        }

        // Convert column texts to TableCells
        return columnTexts.map { textLines in
            let content = textLines
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)

            if content.isEmpty {
                return TableCell(content: [])
            }

            // Parse inline content
            let inlines = parseGridCellInlines(content)
            return TableCell(content: inlines)
        }
    }

    // MARK: - Border Detection

    /// Check if a line is a grid table border: `+---+---+` or `+===+===+`
    func isGridBorderLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("+") && trimmed.hasSuffix("+") else { return false }
        guard trimmed.count >= 3 else { return false }

        // Must contain only +, -, =, and spaces
        for char in trimmed {
            guard char == "+" || char == "-" || char == "=" || char == " " else {
                return false
            }
        }

        // Must have at least one - or = segment
        return trimmed.contains("-") || trimmed.contains("=")
    }

    /// Check if a line is grid table content: `| ... | ... |`
    fileprivate func isGridContentLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("|") && trimmed.hasSuffix("|")
    }

    /// Find column boundary positions (indices of `+` or `|` characters in the border line).
    fileprivate func findColumnBoundaries(in borderLine: String) -> [Int] {
        var boundaries: [Int] = []
        for (index, char) in borderLine.enumerated() {
            if char == "+" {
                boundaries.append(index)
            }
        }
        return boundaries
    }
}
