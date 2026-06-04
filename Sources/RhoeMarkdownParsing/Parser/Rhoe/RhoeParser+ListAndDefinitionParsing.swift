import Foundation
import RhoeMarkdownModel

struct MarkdownListLineMarker {
    let markerType: RhoeLexer.ListMarkerType
    let indent: Int
    let markerText: String
    let contentIndent: Int
    let firstContent: String
}

extension RhoeParser {

    // MARK: - List Blocks

    func parseList(
        _ state: inout RhoeParserState,
        firstMarkerType: RhoeLexer.ListMarkerType,
        baseIndent: Int
    ) -> Block {
        guard let firstToken = state.current,
              firstToken.line > 0,
              firstToken.line <= state.sourceLines.count,
              let firstMarker = parseCommonMarkListMarkerLine(state.sourceLines[firstToken.line - 1]),
              firstMarker.indent == baseIndent
        else {
            return parseTokenBackedList(&state, firstMarkerType: firstMarkerType, baseIndent: baseIndent)
        }

        var listType = listType(for: firstMarker.markerType)
        if case .ordered = firstMarker.markerType {
            if let (style, start) = detectFancyListMarkerStyle(from: firstMarker.markerText) {
                listType = .ordered(start: start, style: style)
            }
        }

        var drafts: [(content: [Block], checked: Bool?, isLoose: Bool)] = []
        var lineIndex = firstToken.line - 1

        while lineIndex < state.sourceLines.count {
            let line = state.sourceLines[lineIndex]
            guard let marker = parseCommonMarkListMarkerLine(line),
                  isSiblingListMarkerIndent(marker.indent, baseIndent: baseIndent),
                  isCompatibleSourceListMarker(firstMarker, marker)
            else {
                break
            }

            let collected = collectSourceBackedListItem(
                from: state.sourceLines,
                startLineIndex: lineIndex,
                marker: marker,
                baseIndent: baseIndent
            )

            let blocks = parseListItemBlocks(from: collected.lines)
            drafts.append((blocks, checkedState(for: marker.markerType), collected.isLoose))
            lineIndex = collected.nextLineIndex
        }

        let listIsLoose = drafts.contains { $0.isLoose }
        let items = drafts.map {
            ListItem(content: $0.content, checked: $0.checked, isLoose: listIsLoose)
        }

        advance(&state, throughSourceLine: lineIndex)

        let attributes = consumeAttributeList(&state) ?? RhoeMarkdownKit.Attributes()
        return .list(type: listType, items: items, attributes: attributes)
    }

    func parseTokenBackedList(
        _ state: inout RhoeParserState,
        firstMarkerType: RhoeLexer.ListMarkerType,
        baseIndent: Int
    ) -> Block {
        var items: [ListItem] = []
        var listType = listType(for: firstMarkerType)
        if case .ordered = firstMarkerType, let token = state.current {
            if let (style, start) = detectFancyListMarkerStyle(from: token.content) {
                listType = .ordered(start: start, style: style)
            }
        }

        while let token = state.current, case .listMarker(let markerType, let indent) = token.type {
            if indent > baseIndent {
                appendNestedListIfNeeded(
                    to: &items,
                    state: &state,
                    markerType: markerType,
                    indent: indent
                )
                continue
            } else if indent < baseIndent {
                break
            }

            if !isCompatibleListMarker(firstMarkerType, markerType) {
                break
            }

            state.advance()
            appendListItem(to: &items, state: &state, markerType: markerType)
        }

        let attributes = consumeAttributeList(&state) ?? RhoeMarkdownKit.Attributes()
        return .list(type: listType, items: items, attributes: attributes)
    }

    // MARK: - Source-Backed CommonMark List Support

    func collectSourceBackedListItem(
        from sourceLines: [String],
        startLineIndex: Int,
        marker: MarkdownListLineMarker,
        baseIndent: Int
    ) -> (lines: [String], nextLineIndex: Int, isLoose: Bool) {
        var itemLines = [marker.firstContent]
        var lineIndex = startLineIndex + 1
        var previousLineWasBlank = false
        var looseFromTerminatingBlank = false

        while lineIndex < sourceLines.count {
            let line = sourceLines[lineIndex]

            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if lineIndex == sourceLines.count - 1, line.isEmpty {
                    break
                }
                itemLines.append("")
                previousLineWasBlank = true
                lineIndex += 1
                continue
            }

            if let nextMarker = parseCommonMarkListMarkerLine(line) {
                if nextMarker.indent < marker.contentIndent,
                   isSiblingListMarkerIndent(nextMarker.indent, baseIndent: baseIndent) {
                    if previousLineWasBlank {
                        looseFromTerminatingBlank = true
                    }
                    break
                }
            }

            let indent = indentationColumns(in: line)
            if previousLineWasBlank,
               trimTrailingBlankListItemLines(itemLines).allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }),
               indent < marker.contentIndent + 2 {
                break
            }

            if indent >= marker.contentIndent {
                itemLines.append(removingIndentColumns(marker.contentIndent, from: line))
                previousLineWasBlank = false
                lineIndex += 1
                continue
            }

            guard !previousLineWasBlank,
                  !shouldStopListItemAtLazyContinuation(line, baseIndent: baseIndent)
            else {
                break
            }

            itemLines.append(removingIndentColumns(min(baseIndent, indent), from: line))
            previousLineWasBlank = false
            lineIndex += 1
        }

        let trimmedLines = trimTrailingBlankListItemLines(itemLines)
        return (
            lines: trimmedLines,
            nextLineIndex: lineIndex,
            isLoose: looseFromTerminatingBlank || listItemLinesAreLoose(trimmedLines)
        )
    }

    func parseListItemBlocks(from lines: [String]) -> [Block] {
        let itemSource = lines.joined(separator: "\n")
        guard !itemSource.isEmpty else { return [] }
        return parseMarkdown(itemSource + "\n").document.blocks
    }

    func isSiblingListMarkerIndent(_ indent: Int, baseIndent: Int) -> Bool {
        indent < baseIndent + 4
    }

    func isCompatibleSourceListMarker(
        _ first: MarkdownListLineMarker,
        _ second: MarkdownListLineMarker
    ) -> Bool {
        guard isCompatibleListMarker(first.markerType, second.markerType) else {
            return false
        }

        if case .ordered = first.markerType,
           case .ordered = second.markerType {
            return first.markerText.last == second.markerText.last
        }

        return true
    }

    func trimTrailingBlankListItemLines(_ lines: [String]) -> [String] {
        var result = lines
        while result.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            result.removeLast()
        }
        return result
    }

    func listItemLinesAreLoose(_ lines: [String]) -> Bool {
        var fence: (marker: Character, length: Int)?
        var previousNonBlankLine: String?

        for (index, line) in lines.enumerated() {
            if let activeFence = fence {
                if closesReferenceExtractionFence(line, fence: activeFence) {
                    fence = nil
                }
                if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    previousNonBlankLine = line
                }
                continue
            }

            if let openingFence = opensReferenceExtractionFence(line) {
                fence = openingFence
                previousNonBlankLine = line
                continue
            }

            if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                previousNonBlankLine = line
                continue
            }

            guard let nextLine = lines[(index + 1)...].first(where: {
                !$0.trimmingCharacters(in: .whitespaces).isEmpty
            }) else {
                continue
            }

            guard previousNonBlankLine != nil else {
                continue
            }

            if let previousNonBlankLine,
               let previousMarker = parseCommonMarkListMarkerLine(previousNonBlankLine),
               indentationColumns(in: nextLine) >= previousMarker.contentIndent {
                continue
            }

            return true
        }

        return false
    }

    func parseCommonMarkListMarkerLine(_ line: String) -> MarkdownListLineMarker? {
        let indentation = leadingIndentInfo(in: line)
        guard indentation.index < line.endIndex else { return nil }
        let remaining = String(line[indentation.index...]).trimmingCharacters(in: .whitespaces)
        guard !startsThematicBreakLine(remaining) else { return nil }

        if let unordered = parseCommonMarkUnorderedListMarker(
            in: line,
            indent: indentation.columns,
            markerIndex: indentation.index
        ) {
            return unordered
        }

        if let ordered = parseCommonMarkOrderedListMarker(
            in: line,
            indent: indentation.columns,
            markerIndex: indentation.index
        ) {
            return ordered
        }

        if configuration.enableFancyLists {
            return parseCommonMarkFancyListMarker(
                in: line,
                indent: indentation.columns,
                markerIndex: indentation.index
            )
        }

        return nil
    }

    func parseCommonMarkUnorderedListMarker(
        in line: String,
        indent: Int,
        markerIndex: String.Index
    ) -> MarkdownListLineMarker? {
        let marker = line[markerIndex]
        guard marker == "-" || marker == "+" || marker == "*" else { return nil }

        let afterMarker = line.index(after: markerIndex)
        guard let parsed = finalizeCommonMarkListMarker(
            line: line,
            indent: indent,
            markerText: String(marker),
            markerType: .unordered(marker),
            afterMarker: afterMarker,
            markerWidth: 1
        ) else {
            return nil
        }

        guard configuration.enableTaskLists,
              let task = parseTaskListPrefix(parsed.firstContent)
        else {
            return parsed
        }

        return MarkdownListLineMarker(
            markerType: .task(checked: task.checked),
            indent: parsed.indent,
            markerText: parsed.markerText,
            contentIndent: parsed.contentIndent,
            firstContent: task.remaining
        )
    }

    func parseCommonMarkOrderedListMarker(
        in line: String,
        indent: Int,
        markerIndex: String.Index
    ) -> MarkdownListLineMarker? {
        var index = markerIndex
        var digitCount = 0
        var value = 0

        while index < line.endIndex, let digit = line[index].wholeNumberValue {
            digitCount += 1
            guard digitCount <= 9 else { return nil }
            value = value * 10 + digit
            index = line.index(after: index)
        }

        guard digitCount > 0,
              index < line.endIndex,
              line[index] == "." || line[index] == ")"
        else {
            return nil
        }

        let delimiterIndex = index
        let afterMarker = line.index(after: delimiterIndex)
        let markerText = String(line[markerIndex...delimiterIndex])
        return finalizeCommonMarkListMarker(
            line: line,
            indent: indent,
            markerText: markerText,
            markerType: .ordered(value),
            afterMarker: afterMarker,
            markerWidth: digitCount + 1
        )
    }

    func parseCommonMarkFancyListMarker(
        in line: String,
        indent: Int,
        markerIndex: String.Index
    ) -> MarkdownListLineMarker? {
        var index = markerIndex
        while index < line.endIndex, line[index].isLetter {
            index = line.index(after: index)
        }

        guard index > markerIndex,
              index < line.endIndex,
              line[index] == "." || line[index] == ")"
        else {
            return nil
        }

        let delimiterIndex = index
        let afterMarker = line.index(after: delimiterIndex)
        let markerText = String(line[markerIndex...delimiterIndex])
        guard let (_, start) = detectFancyListMarkerStyle(from: markerText) else {
            return nil
        }

        return finalizeCommonMarkListMarker(
            line: line,
            indent: indent,
            markerText: markerText,
            markerType: .ordered(start),
            afterMarker: afterMarker,
            markerWidth: markerText.count
        )
    }

    func finalizeCommonMarkListMarker(
        line: String,
        indent: Int,
        markerText: String,
        markerType: RhoeLexer.ListMarkerType,
        afterMarker: String.Index,
        markerWidth: Int
    ) -> MarkdownListLineMarker? {
        let markerEndColumn = indent + markerWidth
        guard afterMarker < line.endIndex else {
            return MarkdownListLineMarker(
                markerType: markerType,
                indent: indent,
                markerText: markerText,
                contentIndent: markerEndColumn + 1,
                firstContent: ""
            )
        }

        guard line[afterMarker] == " " || line[afterMarker] == "\t" else {
            return nil
        }

        let padding = listMarkerPaddingInfo(in: line, from: afterMarker, startingColumn: markerEndColumn)
        let consumedPadding = padding.columns > 4 ? 1 : padding.columns
        let contentIndex = padding.columns > 4 ? padding.firstWhitespaceEnd : padding.fullEnd
        let firstContent: String
        if padding.columns > 4 {
            firstContent = normalizedLeadingIndentRemainder(
                in: String(line[contentIndex...]),
                startingColumn: padding.firstWhitespaceColumn,
                preservedIndentColumns: padding.firstWhitespaceResidualColumns
            )
        } else {
            firstContent = String(line[contentIndex...])
        }
        return MarkdownListLineMarker(
            markerType: markerType,
            indent: indent,
            markerText: markerText,
            contentIndent: markerEndColumn + consumedPadding,
            firstContent: firstContent
        )
    }

    func listMarkerPaddingInfo(
        in line: String,
        from startIndex: String.Index,
        startingColumn: Int
    ) -> (
        columns: Int,
        fullEnd: String.Index,
        firstWhitespaceEnd: String.Index,
        firstWhitespaceColumn: Int,
        firstWhitespaceResidualColumns: Int
    ) {
        var index = startIndex
        var column = startingColumn
        var paddingColumns = 0
        var firstWhitespaceEnd = startIndex
        var firstWhitespaceColumn = startingColumn
        var firstWhitespaceResidualColumns = 0
        var capturedFirstWhitespace = false

        while index < line.endIndex {
            let character = line[index]
            guard character == " " || character == "\t" else { break }

            let nextIndex = line.index(after: index)
            let nextColumn = character == "\t" ? column + (4 - (column % 4)) : column + 1
            let width = nextColumn - column
            paddingColumns += width
            column = nextColumn
            index = nextIndex

            if !capturedFirstWhitespace {
                firstWhitespaceEnd = nextIndex
                firstWhitespaceColumn = nextColumn
                firstWhitespaceResidualColumns = character == "\t" ? max(0, width - 1) : 0
                capturedFirstWhitespace = true
            }
        }

        return (
            paddingColumns,
            index,
            firstWhitespaceEnd,
            firstWhitespaceColumn,
            firstWhitespaceResidualColumns
        )
    }

    func normalizedLeadingIndentRemainder(
        in content: String,
        startingColumn: Int,
        preservedIndentColumns: Int = 0
    ) -> String {
        var index = content.startIndex
        var column = startingColumn
        var preservedColumns = preservedIndentColumns

        while index < content.endIndex {
            let character = content[index]
            if character == " " {
                preservedColumns += 1
                column += 1
                index = content.index(after: index)
            } else if character == "\t" {
                let width = 4 - (column % 4)
                preservedColumns += width
                column += width
                index = content.index(after: index)
            } else {
                break
            }
        }

        return String(repeating: " ", count: preservedColumns) + String(content[index...])
    }

    func leadingIndentInfo(in line: String) -> (columns: Int, index: String.Index) {
        var columns = 0
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]
            if character == " " {
                columns += 1
            } else if character == "\t" {
                columns += 4 - (columns % 4)
            } else {
                break
            }
            index = line.index(after: index)
        }

        return (columns, index)
    }

    func parseTaskListPrefix(_ content: String) -> (checked: Bool, remaining: String)? {
        guard content.count >= 3 else { return nil }

        let start = content.startIndex
        let middle = content.index(after: start)
        let close = content.index(after: middle)
        guard content[start] == "[",
              content[close] == "]",
              content[middle] == " " || content[middle] == "x" || content[middle] == "X"
        else {
            return nil
        }

        let afterClose = content.index(after: close)
        if afterClose == content.endIndex {
            return (content[middle] != " ", "")
        }

        guard content[afterClose] == " " || content[afterClose] == "\t" else {
            return nil
        }

        return (content[middle] != " ", String(content[content.index(after: afterClose)...]))
    }

    func shouldStopListItemAtLazyContinuation(_ line: String, baseIndent: Int) -> Bool {
        let indent = indentationColumns(in: line)
        let candidate = removingIndentColumns(min(baseIndent, indent), from: line)
        let trimmed = candidate.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }

        if let marker = parseCommonMarkListMarkerLine(line),
           isSiblingListMarkerIndent(marker.indent, baseIndent: baseIndent) {
            return true
        }

        return startsThematicBreakLine(trimmed)
            || startsATXHeadingLine(trimmed)
            || startsFencedCodeLine(trimmed)
            || trimmed.hasPrefix(">")
            || startsHTMLBlockBoundaryLine(trimmed)
    }

    func startsThematicBreakLine(_ trimmed: String) -> Bool {
        let markerCharacters = trimmed.filter { $0 != " " && $0 != "\t" }
        guard markerCharacters.count >= 3,
              let marker = markerCharacters.first,
              marker == "*" || marker == "-" || marker == "_"
        else {
            return false
        }
        return markerCharacters.allSatisfy { $0 == marker }
    }

    func startsATXHeadingLine(_ trimmed: String) -> Bool {
        var count = 0
        var index = trimmed.startIndex
        while index < trimmed.endIndex, trimmed[index] == "#", count < 7 {
            count += 1
            index = trimmed.index(after: index)
        }

        guard (1...6).contains(count) else { return false }
        return index == trimmed.endIndex || trimmed[index] == " " || trimmed[index] == "\t"
    }

    func startsFencedCodeLine(_ trimmed: String) -> Bool {
        trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~")
    }

    func startsHTMLBlockBoundaryLine(_ trimmed: String) -> Bool {
        trimmed.hasPrefix("<")
    }

    // MARK: - List Item Assembly Support

    func listType(for markerType: RhoeLexer.ListMarkerType) -> ListType {
        switch markerType {
        case .unordered:
            return .unordered
        case .ordered(let start):
            return .ordered(start: start)
        case .task:
            return .task
        }
    }

    func appendListItem(
        to items: inout [ListItem],
        state: inout RhoeParserState,
        markerType: RhoeLexer.ListMarkerType
    ) {
        let checked = checkedState(for: markerType)
        let itemBlocks = collectListItemParagraphBlocks(&state)
        consumeTrailingListItemNewlineIfPresent(&state)
        items.append(makeListItem(content: itemBlocks, checked: checked))
    }

    func appendNestedListIfNeeded(
        to items: inout [ListItem],
        state: inout RhoeParserState,
        markerType: RhoeLexer.ListMarkerType,
        indent: Int
    ) {
        guard let lastItem = items.last else { return }

        let nestedList = parseList(
            &state,
            firstMarkerType: markerType,
            baseIndent: indent
        )

        items[items.count - 1] = makeListItem(
            content: lastItem.content + [nestedList],
            checked: lastItem.checked
        )
    }

    fileprivate func checkedState(for markerType: RhoeLexer.ListMarkerType) -> Bool? {
        if case .task(let isChecked) = markerType {
            return isChecked
        }

        return nil
    }

    fileprivate func consumeTrailingListItemNewlineIfPresent(_ state: inout RhoeParserState) {
        if let token = state.current, token.type == .newline {
            state.advance()
        }
    }

    fileprivate func makeListItem(content: [Block], checked: Bool?) -> ListItem {
        ListItem(content: content, checked: checked)
    }

    // MARK: - List Item Paragraph Style Support

    func listItemParagraphStyleFlowControl(
        for token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline]
    ) -> ParagraphStyleFlowControl {
        guard token.type == .newline else {
            return .parseInlineToken
        }

        return listItemNewlineFlowControl(state: &state, inlines: &inlines)
    }

    func shouldStopListItemParagraphInlineRun(
        before token: RhoeLexer.Token,
        loopCount: Int
    ) -> Bool {
        if loopCount > 10_000 {
            return true
        }

        if case .listMarker = token.type {
            return true
        }

        if token.type == .newline {
            return false
        }

        return !isInlineToken(token)
    }

    // MARK: - List Item Paragraph Block Support

    func collectListItemParagraphBlocks(_ state: inout RhoeParserState) -> [Block] {
        let inlines = parseListItemParagraphEntry(&state)
        return makeParagraphBlocksIfNeeded(from: inlines)
    }

    // MARK: - List Item Paragraph Entry Support

    func parseListItemInlineRun(_ state: inout RhoeParserState) -> [Inline] {
        parseParagraphStyleInlineRun(&state, mode: .listItem)
    }

    func parseListItemParagraphEntry(_ state: inout RhoeParserState) -> [Inline] {
        parseListItemInlineRun(&state)
    }

    // MARK: - List Marker Classification Support

    func isCompatibleListMarker(_ first: RhoeLexer.ListMarkerType, _ second: RhoeLexer.ListMarkerType) -> Bool {
        switch (first, second) {
        case (.unordered(let c1), .unordered(let c2)):
            return c1 == c2
        case (.unordered, .task), (.task, .unordered):
            return true
        case (.ordered, .ordered):
            return true
        case (.task, .task):
            return true
        default:
            return false
        }
    }

    // MARK: - Fancy List Marker Support

    /// Detect fancy list markers and return the appropriate marker style.
    ///
    /// Fancy list markers extend standard ordered lists with:
    /// - Lowercase alpha: `a.`, `b.`, `a)`, `b)`
    /// - Uppercase alpha: `A.`, `B.`, `A)`, `B)`
    /// - Lowercase Roman: `i.`, `ii.`, `iii.`
    /// - Uppercase Roman: `I.`, `II.`, `III.`
    /// - Hash auto-number: `#.`
    func detectFancyListMarkerStyle(from text: String) -> (style: ListMarkerStyle, start: Int)? {
        guard configuration.enableFancyLists else { return nil }

        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Hash auto-number: #.
        if trimmed.hasPrefix("#.") || trimmed.hasPrefix("#)") {
            return (.decimal, 1)
        }

        // Try to match letter or Roman numeral followed by . or )
        guard let dotIndex = trimmed.firstIndex(where: { $0 == "." || $0 == ")" }) else {
            return nil
        }

        let marker = String(trimmed[..<dotIndex])
        guard !marker.isEmpty else { return nil }

        // Check lowercase Roman first (i, ii, iii, iv, v, vi, vii, viii, ix, x, etc.)
        if let romanValue = parseLowerRoman(marker) {
            return (.lowerRoman, romanValue)
        }

        // Check uppercase Roman (I, II, III, IV, V, etc.)
        if let romanValue = parseUpperRoman(marker) {
            return (.upperRoman, romanValue)
        }

        // Check single lowercase alpha (a-z)
        if marker.count == 1, let ch = marker.first, ch >= "a" && ch <= "z" {
            let value = Int(ch.asciiValue! - Character("a").asciiValue!) + 1
            return (.lowerAlpha, value)
        }

        // Check single uppercase alpha (A-Z)
        if marker.count == 1, let ch = marker.first, ch >= "A" && ch <= "Z" {
            let value = Int(ch.asciiValue! - Character("A").asciiValue!) + 1
            return (.upperAlpha, value)
        }

        return nil
    }

    fileprivate func parseLowerRoman(_ text: String) -> Int? {
        guard text == text.lowercased() && text.first?.isLowercase == true else { return nil }
        return parseRomanNumeral(text)
    }

    fileprivate func parseUpperRoman(_ text: String) -> Int? {
        guard text == text.uppercased() && text.first?.isUppercase == true else { return nil }
        return parseRomanNumeral(text.lowercased())
    }

    fileprivate func parseRomanNumeral(_ text: String) -> Int? {
        let romanValues: [(String, Int)] = [
            ("m", 1000), ("cm", 900), ("d", 500), ("cd", 400),
            ("c", 100), ("xc", 90), ("l", 50), ("xl", 40),
            ("x", 10), ("ix", 9), ("v", 5), ("iv", 4), ("i", 1)
        ]

        var result = 0
        var remaining = text

        for (numeral, value) in romanValues {
            while remaining.hasPrefix(numeral) {
                result += value
                remaining = String(remaining.dropFirst(numeral.count))
            }
        }

        return remaining.isEmpty && result > 0 ? result : nil
    }

    // MARK: - Definition List Blocks

    func parseDefinitionList(_ state: inout RhoeParserState) -> Block {
        var items: [DefinitionListItem] = []

        while let token = state.current, case .definitionTerm = token.type {
            let termToken = token
            state.advance()
            consumeDefinitionTermLineBreakIfPresent(&state)

            let termInlines = parseInlines(termToken.content)
            let definitions = parseDefinitionEntries(&state)
            items.append(
                DefinitionListItem(term: termInlines, definitions: definitions)
            )
        }

        let attributes = consumeAttributeList(&state) ?? RhoeMarkdownKit.Attributes()
        return .definitionList(items: items, attributes: attributes)
    }

    // MARK: - Definition Collection Support

    func consumeDefinitionTermLineBreakIfPresent(_ state: inout RhoeParserState) {
        if let token = state.current, case .newline = token.type {
            state.advance()
        }
    }

    func parseDefinitionEntries(_ state: inout RhoeParserState) -> [[Block]] {
        var definitions: [[Block]] = []

        while let token = state.current, case .definitionMarker = token.type {
            state.advance()
            definitions.append(collectDefinitionEntryBlocks(&state))
        }

        return definitions.isEmpty ? [[.paragraph([])]] : definitions
    }

    // MARK: - Definition Entry Block Support

    func collectDefinitionEntryBlocks(_ state: inout RhoeParserState) -> [Block] {
        let definitionBlocks = collectBlocks(&state, until: { token, snapshot in
            shouldStopDefinitionEntryBlockCollection(before: token, snapshot: snapshot)
        })

        return defaultDefinitionEntryBlocksIfNeeded(definitionBlocks)
    }

    func shouldStopDefinitionEntryBlockCollection(
        before token: RhoeLexer.Token,
        snapshot: RhoeParserState
    ) -> Bool {
        _ = snapshot

        if case .definitionTerm = token.type { return true }
        if case .definitionMarker = token.type { return true }
        if case .eof = token.type { return true }
        return false
    }

    func defaultDefinitionEntryBlocksIfNeeded(_ blocks: [Block]) -> [Block] {
        blocks.isEmpty ? [.paragraph([])] : blocks
    }
}
