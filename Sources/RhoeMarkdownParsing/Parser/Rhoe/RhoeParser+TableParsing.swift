import Foundation
import RhoeMarkdownModel

// MARK: - Table Candidate Probe

struct TableCandidateProbe {
    let pipeCount: Int
    let hasContent: Bool
    let isDivider: Bool
    let dashCount: Int
    let delimiterPipeCount: Int

    var isValidTableStart: Bool {
        pipeCount >= 2 &&
            hasContent &&
            isDivider &&
            dashCount >= 3 &&
            delimiterPipeCount >= 2
    }
}

// MARK: - Parsed Table Content

struct ParsedTableContent {
    var headers: [TableCell]
    var rows: [[TableCell]]
    var alignments: [TableAlignment]
}

extension RhoeParser {

    // MARK: - Table Entry Points

    func parseTable(_ state: inout RhoeParserState) -> Block {
        let parsedTable = parseExplicitTableContent(&state)
        return makeTableBlock(from: parsedTable, state: &state)
    }

    func parseTableFromTokens(_ state: inout RhoeParserState) -> Block {
        let parsedTable = parseSimpleTableContent(&state)
        return makeTableBlock(from: parsedTable, state: &state)
    }

    // MARK: - Table Block Support

    func makeTableBlock(
        from parsedTable: ParsedTableContent,
        state: inout RhoeParserState
    ) -> Block {
        var headers = parsedTable.headers
        var rows = parsedTable.rows
        applyTableAlignments(parsedTable.alignments, to: &headers, rows: &rows)
        return makeTableBlock(headers: headers, rows: rows, state: &state)
    }

    func applyTableAlignments(
        _ alignments: [TableAlignment],
        to headers: inout [TableCell],
        rows: inout [[TableCell]]
    ) {
        for index in 0..<headers.count {
            headers[index] = TableCell(
                content: headers[index].content,
                alignment: index < alignments.count ? alignments[index] : .none
            )
        }

        for rowIndex in 0..<rows.count {
            for cellIndex in 0..<rows[rowIndex].count {
                rows[rowIndex][cellIndex] = TableCell(
                    content: rows[rowIndex][cellIndex].content,
                    alignment: cellIndex < alignments.count ? alignments[cellIndex] : .none
                )
            }
        }
    }

    func makeTableBlock(
        headers: [TableCell],
        rows: [[TableCell]],
        state: inout RhoeParserState
    ) -> Block {
        let attributes = consumeAttributeList(&state) ?? RhoeMarkdownKit.Attributes()
        return .table(headers: headers, rows: rows, attributes: attributes)
    }

    // MARK: - Table Block Start Policy Support

    func probeTableBlockStart(_ state: inout RhoeParserState) -> TableCandidateProbe {
        let savedIndex = state.currentIndex
        let probe = probeSimpleTableCandidate(&state)
        state.currentIndex = savedIndex
        return probe
    }

    func isAtTableBlockStart(_ state: inout RhoeParserState) -> Bool {
        probeTableBlockStart(&state).isValidTableStart
    }

    func shouldStopParagraphStyleFlowAfterNewline(
        in state: inout RhoeParserState
    ) -> Bool {
        // Stop at table starts
        if isAtTableBlockStart(&state) { return true }

        // Stop at fenced div boundaries (:::)
        if let token = state.current {
            switch token.type {
            case .fencedDivStart, .fencedDivEnd:
                return true
            default:
                break
            }
        }

        return false
    }

    // MARK: - Table Block Entry Support

    func parseTableBlockIfPresent(_ state: inout RhoeParserState) -> Block? {
        guard isAtTableBlockStart(&state) else {
            return nil
        }

        return parseTableFromTokens(&state)
    }

    // MARK: - Table Detection Support

    func tryParseTable(_ state: inout RhoeParserState) -> Block? {
        DebugLogger.log("tryParseTable: checking if current line is a table")

        let probe = probeTableBlockStart(&state)

        if !probe.isValidTableStart {
            DebugLogger.log("tryParseTable: not enough pipes or no content, not a table")
            return nil
        }

        return parseTableFromTokens(&state)
    }

    // MARK: - Table Candidate Support

    func collectFirstTableCandidateLine(
        _ state: inout RhoeParserState
    ) -> (pipeCount: Int, hasContent: Bool) {
        var pipeCount = 0
        var hasContent = false

        while let token = state.current {
            switch token.type {
            case .newline, .eof:
                return (pipeCount, hasContent)
            case .text(let content) where content == "|":
                pipeCount += 1
            case .text:
                hasContent = true
            default:
                break
            }

            state.advance()
        }

        return (pipeCount, hasContent)
    }

    func collectTableDelimiterCandidate(
        _ state: inout RhoeParserState
    ) -> (isDivider: Bool, dashCount: Int, delimiterPipeCount: Int) {
        var isDivider = false
        var dashCount = 0
        var delimiterPipeCount = 0

        while let token = state.current {
            DebugLogger.log("tryParseTable: delimiter token - \(token.type)")

            switch token.type {
            case .text(let content):
                DebugLogger.log("tryParseTable: delimiter text content='\(content)'")
                if content == "|" {
                    delimiterPipeCount += 1
                } else if content.allSatisfy({ $0 == "-" || $0 == ":" }) {
                    dashCount += content.count
                    isDivider = true
                } else if content.contains("|") && content.contains("-") {
                    delimiterPipeCount += content.filter({ $0 == "|" }).count
                    dashCount += content.filter({ $0 == "-" }).count
                    if dashCount >= 3 {
                        isDivider = true
                    }
                } else {
                    DebugLogger.log("tryParseTable: invalid delimiter content")
                    return (isDivider, dashCount, delimiterPipeCount)
                }
            case .space:
                break
            case .newline, .eof:
                return (isDivider, dashCount, delimiterPipeCount)
            default:
                return (isDivider, dashCount, delimiterPipeCount)
            }

            state.advance()
        }

        return (isDivider, dashCount, delimiterPipeCount)
    }

    // MARK: - Table Candidate Probe Support

    func probeSimpleTableCandidate(
        _ state: inout RhoeParserState
    ) -> TableCandidateProbe {
        let firstLine = collectFirstTableCandidateLine(&state)

        DebugLogger.log("tryParseTable: pipeCount=\(firstLine.pipeCount), hasContent=\(firstLine.hasContent)")

        guard firstLine.pipeCount >= 2, firstLine.hasContent else {
            return TableCandidateProbe(
                pipeCount: firstLine.pipeCount,
                hasContent: firstLine.hasContent,
                isDivider: false,
                dashCount: 0,
                delimiterPipeCount: 0
            )
        }

        guard let token = state.current, case .newline = token.type else {
            return TableCandidateProbe(
                pipeCount: firstLine.pipeCount,
                hasContent: firstLine.hasContent,
                isDivider: false,
                dashCount: 0,
                delimiterPipeCount: 0
            )
        }

        state.advance()
        let delimiter = collectTableDelimiterCandidate(&state)

        DebugLogger.log(
            "tryParseTable: delimiter check - isDivider=\(delimiter.isDivider), " +
            "dashCount=\(delimiter.dashCount), delimiterPipeCount=\(delimiter.delimiterPipeCount)"
        )

        return TableCandidateProbe(
            pipeCount: firstLine.pipeCount,
            hasContent: firstLine.hasContent,
            isDivider: delimiter.isDivider,
            dashCount: delimiter.dashCount,
            delimiterPipeCount: delimiter.delimiterPipeCount
        )
    }

    // MARK: - Table Alignment Support

    func parseTableAlignments(_ delimiterContent: String) -> [TableAlignment] {
        let columns = delimiterContent.split(separator: "|")
        return columns.map { column in
            tableAlignment(for: column.trimmingCharacters(in: .whitespaces))
        }
    }

    func tableAlignment(for trimmed: String) -> TableAlignment {
        if trimmed.hasPrefix(":") && trimmed.hasSuffix(":") {
            return .center
        } else if trimmed.hasPrefix(":") {
            return .left
        } else if trimmed.hasSuffix(":") {
            return .right
        } else {
            return .none
        }
    }

    // MARK: - Table Content Parsing Support

    func parseExplicitTableContent(_ state: inout RhoeParserState) -> ParsedTableContent {
        let headers = parseTableRow(&state)
        var alignments: [TableAlignment] = []

        if let token = state.current, case .tableDelimiter = token.type {
            alignments = parseTableAlignments(token.content)
            state.advance()
        }

        let rows = collectExplicitTableRows(&state)
        return ParsedTableContent(headers: headers, rows: rows, alignments: alignments)
    }

    func parseSimpleTableContent(_ state: inout RhoeParserState) -> ParsedTableContent {
        let headers = parseSimpleTableRow(&state)
        consumeTableNewlineIfPresent(&state)
        let alignments = parseDelimiterRow(&state)
        consumeTableNewlineIfPresent(&state)
        let rows = collectSimpleTableRows(&state)
        return ParsedTableContent(headers: headers, rows: rows, alignments: alignments)
    }

    // MARK: - Simple Table Row Support

    func parseSimpleTableRow(_ state: inout RhoeParserState) -> [TableCell] {
        var cells: [TableCell] = []
        let peekedRow = peekSimpleTableRow(at: state.currentIndex, in: state.tokens)

        if peekedRow.isCompleteRow && peekedRow.rowContent.contains("|") {
            appendSimpleTableCells(from: peekedRow.rowContent, into: &cells)
            while state.currentIndex < peekedRow.endIndex {
                state.advance()
            }
            return cells
        }

        var currentCell: [Inline] = []
        var cellStarted = false
        var tokenLoopGuard = 0

        while let token = state.current {
            tokenLoopGuard += 1
            if tokenLoopGuard > 200 {
                DebugLogger.log("WARNING: parseSimpleTableRow token loop guard hit!")
                break
            }

            switch token.type {
            case .text(let content) where content == "|":
                if cellStarted {
                    appendSimpleTableCell(currentCell, to: &cells)
                    currentCell = []
                }
                cellStarted = true
                state.advance()
            case .newline, .eof:
                if cellStarted && (!currentCell.isEmpty || !cells.isEmpty) {
                    appendSimpleTableCell(currentCell, to: &cells)
                }
                return cells
            case .text(let content):
                if cellStarted {
                    currentCell.append(.text(content))
                    state.advance()
                } else {
                    state.advance()
                    return []
                }
            case .space(let count):
                if cellStarted && !currentCell.isEmpty {
                    currentCell.append(.text(String(repeating: " ", count: count)))
                }
                state.advance()
            default:
                if cellStarted {
                    currentCell.append(.text(token.content))
                }
                state.advance()
            }
        }

        return cells
    }

    fileprivate func peekSimpleTableRow(
        at startIndex: Int,
        in tokens: [RhoeLexer.Token]
    ) -> (rowContent: String, isCompleteRow: Bool, endIndex: Int) {
        var rowContent = ""
        var isCompleteRow = false
        var tempIndex = startIndex

        peekLoop: while tempIndex < tokens.count {
            let token = tokens[tempIndex]
            switch token.type {
            case .text(let content):
                rowContent += content
                if content.contains("|") {
                    isCompleteRow = true
                }
            case .space(let count):
                rowContent += String(repeating: " ", count: count)
            case .newline, .eof:
                break peekLoop
            case .escape:
                if token.content.count > 1 {
                    rowContent += String(token.content.dropFirst())
                }
            case .mathInline:
                DebugLogger.log("Found mathInline token: '\(token.content)'")
                rowContent += "$\(token.content)$"
            case .mathDisplay:
                DebugLogger.log("Found mathDisplay token: '\(token.content)'")
                rowContent += "$$\(token.content)$$"
            default:
                rowContent += token.content
            }

            tempIndex += 1
        }

        return (rowContent, isCompleteRow, tempIndex)
    }

    fileprivate func appendSimpleTableCells(
        from rowContent: String,
        into cells: inout [TableCell]
    ) {
        let cellContents = rowContent.split(separator: "|").map(String.init)
        for content in cellContents {
            let trimmed = content.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty || !cells.isEmpty {
                cells.append(TableCell(content: parseInlines(trimmed)))
            }
        }
    }

    fileprivate func appendSimpleTableCell(_ currentCell: [Inline], to cells: inout [TableCell]) {
        let cellText = currentCell.map { inline -> String in
            if case .text(let text) = inline { return text }
            return ""
        }.joined()
        cells.append(TableCell(content: parseInlines(cellText)))
    }

    // MARK: - Explicit Table Row Support

    func parseTableRow(_ state: inout RhoeParserState) -> [TableCell] {
        var cells: [TableCell] = []
        var currentCellContent: [Inline] = []
        var loopCount = 0

        if let token = state.current, case .tableSeparator = token.type {
            state.advance()
        }

        parseRowLoop: while let token = state.current {
            loopCount += 1
            if loopCount > 1000 {
                break parseRowLoop
            }

            switch token.type {
            case .tableSeparator:
                cells.append(TableCell(content: currentCellContent))
                currentCellContent = []
                state.advance()
            case .newline:
                if !currentCellContent.isEmpty {
                    cells.append(TableCell(content: currentCellContent))
                }
                state.advance()
                break parseRowLoop
            case .text(let content):
                currentCellContent.append(contentsOf: parseInlines(content))
                state.advance()
            case .eof:
                if !currentCellContent.isEmpty {
                    cells.append(TableCell(content: currentCellContent))
                }
                break parseRowLoop
            default:
                if !appendSpecialTableRowToken(
                    token,
                    state: &state,
                    currentCellContent: &currentCellContent
                ) {
                    break parseRowLoop
                }
            }
        }

        return cells
    }

    func isTableRowStart(_ token: RhoeLexer.Token) -> Bool {
        switch token.type {
        case .text, .emphasis, .code, .linkStart, .imageStart:
            return true
        default:
            return false
        }
    }

    fileprivate func appendSpecialTableRowToken(
        _ token: RhoeLexer.Token,
        state: inout RhoeParserState,
        currentCellContent: inout [Inline]
    ) -> Bool {
        switch token.type {
        case .emphasis(let level):
            currentCellContent.append(.text(String(repeating: "*", count: level)))
            state.advance()
            return true
        case .code:
            currentCellContent.append(.text("`"))
            state.advance()
            return true
        case .imageStart:
            currentCellContent.append(.text("!["))
            state.advance()
            return true
        case .linkStart:
            currentCellContent.append(.text("["))
            state.advance()
            return true
        case .linkEnd:
            currentCellContent.append(.text("]"))
            state.advance()
            return true
        case .space(let count):
            currentCellContent.append(.text(String(repeating: " ", count: count)))
            state.advance()
            return true
        case .mathInline:
            currentCellContent.append(.inlineMath(expression: token.content))
            state.advance()
            return true
        default:
            if isInlineToken(token) {
                currentCellContent.append(.text(token.content))
                state.advance()
                return true
            }

            return false
        }
    }

    // MARK: - Table Row Collection Support

    func collectExplicitTableRows(_ state: inout RhoeParserState) -> [[TableCell]] {
        var rows: [[TableCell]] = []

        while let token = state.current {
            let shouldParseRow: Bool
            if case .tableSeparator = token.type {
                shouldParseRow = true
            } else if isTableRowStart(token) {
                shouldParseRow = true
            } else {
                shouldParseRow = false
            }

            if shouldParseRow {
                let row = parseTableRow(&state)
                if !row.isEmpty {
                    rows.append(row)
                }
            } else {
                break
            }
        }

        return rows
    }

    func collectSimpleTableRows(_ state: inout RhoeParserState) -> [[TableCell]] {
        var rows: [[TableCell]] = []
        var dataRowLoopGuard = 0
        let startIndex = state.currentIndex

        dataRowLoop: while let token = state.current {
            dataRowLoopGuard += 1
            if dataRowLoopGuard > 100 {
                DebugLogger.log("WARNING: Table parsing loop guard hit!")
                break dataRowLoop
            }

            switch token.type {
            case .eof:
                break dataRowLoop
            case .newline:
                state.advance()
                if let nextToken = state.current {
                    switch nextToken.type {
                    case .heading, .blockQuoteMarker, .listMarker, .codeBlockDelimiter, .horizontalRule:
                        break dataRowLoop
                    case .newline:
                        break dataRowLoop
                    default:
                        appendSimpleTableRowIfPresent(&state, to: &rows)
                    }
                }
            default:
                let beforeRowIndex = state.currentIndex
                appendSimpleTableRowIfPresent(&state, to: &rows)
                if state.currentIndex == beforeRowIndex {
                    DebugLogger.log("WARNING: parseSimpleTableRow didn't advance state!")
                    state.advance()
                }
            }

            if state.current == nil {
                break
            }

            if let token = state.current, case .newline = token.type,
               let next = state.peek(), case .newline = next.type {
                break
            }

            if state.currentIndex == startIndex && dataRowLoopGuard > 1 {
                DebugLogger.log("WARNING: Table parsing stuck, forcing advance")
                state.advance()
            }
        }

        return rows
    }

    func consumeTableNewlineIfPresent(_ state: inout RhoeParserState) {
        if let token = state.current, case .newline = token.type {
            state.advance()
        }
    }

    fileprivate func appendSimpleTableRowIfPresent(
        _ state: inout RhoeParserState,
        to rows: inout [[TableCell]]
    ) {
        let row = parseSimpleTableRow(&state)
        if !row.isEmpty {
            rows.append(row)
        }
    }

    // MARK: - Table Delimiter Row Support

    func parseDelimiterRow(_ state: inout RhoeParserState) -> [TableAlignment] {
        var alignments: [TableAlignment] = []

        if let token = state.current, case .text(let content) = token.type {
            if content.contains("|") && content.contains("-") {
                let cells = content.split(separator: "|").map(String.init)
                for cell in cells {
                    let trimmed = cell.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty { continue }
                    alignments.append(tableAlignment(for: trimmed))
                }
                state.advance()
                return alignments
            }
        }

        var cellContent = ""
        var inCell = false

        while let token = state.current {
            switch token.type {
            case .text(let content) where content == "|":
                if inCell {
                    alignments.append(tableAlignment(for: cellContent.trimmingCharacters(in: .whitespaces)))
                    cellContent = ""
                }
                inCell = true
                state.advance()
            case .text(let content):
                if inCell {
                    cellContent += content
                }
                state.advance()
            case .space:
                if inCell {
                    cellContent += " "
                }
                state.advance()
            case .newline, .eof:
                if inCell && !cellContent.isEmpty {
                    alignments.append(tableAlignment(for: cellContent.trimmingCharacters(in: .whitespaces)))
                }
                return alignments
            default:
                state.advance()
            }
        }

        return alignments
    }
}
