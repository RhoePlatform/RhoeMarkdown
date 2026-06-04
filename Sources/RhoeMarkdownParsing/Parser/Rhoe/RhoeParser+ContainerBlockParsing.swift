import Foundation
import RhoeMarkdownModel

fileprivate enum BlockQuoteLineBreakDecision {
    case continueCollecting
    case continueAfterLazyLine
    case stopCollecting
}

extension RhoeParser {

    // MARK: - Footnote Blocks

    func parseFootnoteDefinition(_ state: inout RhoeParserState) -> Block? {
        guard let token = state.current, case .footnoteDefinition = token.type else { return nil }

        let refId = token.content
        state.advance()

        return .footnoteDefinition(
            id: refId,
            content: collectFootnoteDefinitionBlocks(&state)
        )
    }

    // MARK: - Footnote Collection Support

    func collectFootnoteDefinitionBlocks(_ state: inout RhoeParserState) -> [Block] {
        collectBlocks(&state, until: { token, snapshot in
            shouldStopFootnoteDefinitionBlockCollection(before: token, snapshot: snapshot)
        })
    }

    func shouldStopFootnoteDefinitionBlockCollection(
        before token: RhoeLexer.Token,
        snapshot: RhoeParserState
    ) -> Bool {
        if case .footnoteDefinition = token.type { return true }
        if case .eof = token.type { return true }
        if shouldStopIndentedContinuation(before: token, snapshot: snapshot) { return true }
        return false
    }

    // MARK: - Block Quote Support

    func parseBlockQuote(
        _ state: inout RhoeParserState,
        depth: Int,
        parentDepth: Int = 0
    ) -> Block {
        guard consumeBlockQuoteMarker(&state, depth: depth) else {
            return .paragraph([])
        }
        let collected = collectBlockQuote(&state, currentDepth: depth)
        var quotedBlocks = collected.nestedBlocks
        appendParsedBlockQuoteTokens(collected.quoteTokens, into: &quotedBlocks)
        let attributes = consumeAttributeList(&state) ?? RhoeMarkdownKit.Attributes()
        return makeBlockQuoteBlock(
            quotedBlocks,
            depth: max(1, depth - parentDepth),
            attributes: attributes
        )
    }

    func consumeBlockQuoteMarker(
        _ state: inout RhoeParserState,
        depth: Int
    ) -> Bool {
        guard let token = state.current, case .blockQuoteMarker(let currentDepth) = token.type else {
            return false
        }

        guard currentDepth == depth else {
            return false
        }

        state.advance()
        return true
    }

    func appendParsedBlockQuoteTokens(
        _ tokens: [RhoeLexer.Token],
        into quotedBlocks: inout [Block]
    ) {
        guard !tokens.isEmpty else { return }

        let rawQuoteSource = tokens.map(\.content).joined()
        var quoteSource = trimTrailingBlockQuoteReparseWhitespace(rawQuoteSource)
        if shouldRestoreTrailingNewlineForUnclosedFence(rawQuoteSource),
           !quoteSource.hasSuffix("\n") {
            quoteSource += "\n"
        }
        guard !quoteSource.isEmpty else { return }
        let reparsedTokens = lexer.tokenize(quoteSource)
        var subState = RhoeParserState(tokens: reparsedTokens, source: quoteSource)
        while subState.currentIndex < subState.tokens.count {
            if let block = parseBlock(&subState) {
                quotedBlocks.append(block)
            } else {
                subState.advance()
            }
        }
    }

    func trimTrailingBlockQuoteReparseWhitespace(_ source: String) -> String {
        var trimmed = source
        while let last = trimmed.last, last == " " || last == "\t" || last == "\n" || last == "\r" {
            trimmed.removeLast()
        }
        return trimmed
    }

    func shouldRestoreTrailingNewlineForUnclosedFence(_ source: String) -> Bool {
        guard source.hasSuffix("\n") else { return false }

        var openFence: (marker: Character, length: Int)?
        for line in source.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let marker = trimmed.first,
                  marker == "`" || marker == "~"
            else {
                continue
            }

            let fenceLength = trimmed.prefix { $0 == marker }.count
            guard fenceLength >= 3 else { continue }

            if let open = openFence {
                if marker == open.marker, fenceLength >= open.length {
                    openFence = nil
                }
            } else {
                openFence = (marker, fenceLength)
            }
        }

        return openFence != nil
    }

    func makeBlockQuoteBlock(
        _ quotedBlocks: [Block],
        depth: Int,
        attributes: RhoeMarkdownKit.Attributes
    ) -> Block {
        var block = Block.blockQuote(quotedBlocks, attributes: attributes)
        guard depth > 1 else { return block }

        for _ in 1..<depth {
            block = .blockQuote([block], attributes: RhoeMarkdownKit.Attributes())
        }
        return block
    }

    // MARK: - Block Quote Collection Support

    func collectBlockQuote(
        _ state: inout RhoeParserState,
        currentDepth: Int
    ) -> (nestedBlocks: [Block], quoteTokens: [RhoeLexer.Token]) {
        var quotedBlocks: [Block] = []
        var blockquoteTokens: [RhoeLexer.Token] = []
        var expectsContinuationStart = false

        collectionLoop: while true {
            guard let token = state.current else { break }

            if expectsContinuationStart {
                if handleNestedBlockQuoteToken(
                    token,
                    state: &state,
                    currentDepth: currentDepth,
                    quotedBlocks: &quotedBlocks,
                    blockquoteTokens: &blockquoteTokens
                ) {
                    expectsContinuationStart = false
                    continue
                }

                if shouldContinueBlockQuoteWithPartialMarkerLazyLine(
                    token,
                    currentDepth: currentDepth,
                    quoteTokens: blockquoteTokens
                ) {
                    appendLazyBlockQuoteContinuationLine(
                        token,
                        newlineToken: token,
                        state: &state,
                        into: &blockquoteTokens,
                        markerDepthToStrip: currentDepth
                    )
                    expectsContinuationStart = true
                    continue
                }

                guard shouldContinueBlockQuoteWithLazyLine(
                    token,
                    quoteTokens: blockquoteTokens,
                    state: state
                ) else {
                    break
                }

                appendLazyBlockQuoteContinuationLine(
                    token,
                    newlineToken: token,
                    state: &state,
                    into: &blockquoteTokens
                )
                expectsContinuationStart = true
                continue
            }

            if handleNestedBlockQuoteToken(
                token,
                state: &state,
                currentDepth: currentDepth,
                quotedBlocks: &quotedBlocks,
                blockquoteTokens: &blockquoteTokens
            ) {
                expectsContinuationStart = false
                continue
            }

            collectBlockQuoteLineTokens(&state, into: &blockquoteTokens)

            switch consumeBlockQuoteLineBreakIfNeeded(
                &state,
                currentDepth: currentDepth,
                blockquoteTokens: &blockquoteTokens
            ) {
            case .continueCollecting:
                expectsContinuationStart = false
                continue
            case .continueAfterLazyLine:
                expectsContinuationStart = true
                continue
            case .stopCollecting:
                break collectionLoop
            }
        }

        return (quotedBlocks, blockquoteTokens)
    }

    fileprivate func handleNestedBlockQuoteToken(
        _ token: RhoeLexer.Token,
        state: inout RhoeParserState,
        currentDepth: Int,
        quotedBlocks: inout [Block],
        blockquoteTokens: inout [RhoeLexer.Token]
    ) -> Bool {
        guard case .blockQuoteMarker(let nestedDepth) = token.type else {
            return false
        }

        if nestedDepth > currentDepth {
            let nestedBlock = parseBlockQuote(&state, depth: nestedDepth, parentDepth: currentDepth)
            quotedBlocks.append(nestedBlock)
            return true
        }

        if nestedDepth == currentDepth {
            state.advance()
            appendBlockQuoteSoftBreakIfNeeded(from: token, into: &blockquoteTokens)
            return true
        }

        return false
    }

    fileprivate func collectBlockQuoteLineTokens(
        _ state: inout RhoeParserState,
        into blockquoteTokens: inout [RhoeLexer.Token]
    ) {
        var isAtQuotedLineStart = blockquoteTokens.isEmpty || blockquoteTokens.last?.type == .newline
        while let token = state.current, token.type != .newline {
            blockquoteTokens.append(normalizedBlockQuoteLineStartToken(token, isAtLineStart: isAtQuotedLineStart))
            isAtQuotedLineStart = false
            state.advance()
        }
    }

    func normalizedBlockQuoteLineStartToken(
        _ token: RhoeLexer.Token,
        isAtLineStart: Bool
    ) -> RhoeLexer.Token {
        guard isAtLineStart,
              case .text(let text) = token.type,
              text.hasPrefix("\t")
        else {
            return token
        }

        let normalized = normalizedLeadingBlockQuoteTabContent(text)
        return RhoeLexer.Token(
            type: .text(normalized),
            range: token.range,
            content: normalized,
            line: token.line,
            column: token.column
        )
    }

    func normalizedLeadingBlockQuoteTabContent(_ content: String) -> String {
        var index = content.startIndex
        var column = 1
        var preservedColumns = 0

        guard index < content.endIndex, content[index] == "\t" else {
            return content
        }

        let firstWidth = 4 - (column % 4)
        preservedColumns += max(0, firstWidth - 1)
        column += firstWidth
        index = content.index(after: index)

        while index < content.endIndex {
            if content[index] == " " {
                preservedColumns += 1
                column += 1
                index = content.index(after: index)
            } else if content[index] == "\t" {
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

    fileprivate func consumeBlockQuoteLineBreakIfNeeded(
        _ state: inout RhoeParserState,
        currentDepth: Int,
        blockquoteTokens: inout [RhoeLexer.Token]
    ) -> BlockQuoteLineBreakDecision {
        guard let token = state.current, token.type == .newline else {
            return .stopCollecting
        }

        state.advance()

        guard let next = state.current else {
            return .stopCollecting
        }

        if case .blockQuoteMarker(let nextDepth) = next.type,
           nextDepth >= currentDepth {
            return .continueCollecting
        }

        if blockQuoteTokensEndWithBlankLine(blockquoteTokens),
           shouldContinueBlockQuoteWithBlankPartialMarkerLine(next, currentDepth: currentDepth) {
            appendLazyBlockQuoteContinuationLine(
                next,
                newlineToken: token,
                state: &state,
                into: &blockquoteTokens,
                markerDepthToStrip: currentDepth
            )
            return .continueAfterLazyLine
        }

        if !blockQuoteTokensEndWithBlankLine(blockquoteTokens),
           shouldContinueBlockQuoteWithPartialMarkerLazyLine(
               next,
               currentDepth: currentDepth,
               quoteTokens: blockquoteTokens
           ) {
            appendLazyBlockQuoteContinuationLine(
                next,
                newlineToken: token,
                state: &state,
                into: &blockquoteTokens,
                markerDepthToStrip: currentDepth
            )
            return .continueAfterLazyLine
        }

        if !blockQuoteTokensEndWithBlankLine(blockquoteTokens),
           shouldContinueBlockQuoteWithLazyLine(next, quoteTokens: blockquoteTokens, state: state) {
            appendLazyBlockQuoteContinuationLine(next, newlineToken: token, state: &state, into: &blockquoteTokens)
            return .continueAfterLazyLine
        }

        let candidateSource = blockquoteTokens.map(\.content).joined() + "\n"
        if shouldRestoreTrailingNewlineForUnclosedFence(candidateSource) {
            appendBlockQuoteSoftBreakIfNeeded(from: token, into: &blockquoteTokens)
        }

        return .stopCollecting
    }

    func shouldContinueBlockQuoteWithPartialMarkerLazyLine(
        _ next: RhoeLexer.Token,
        currentDepth: Int,
        quoteTokens: [RhoeLexer.Token]
    ) -> Bool {
        guard case .blockQuoteMarker(let nextDepth) = next.type,
              nextDepth > 0,
              nextDepth < currentDepth,
              blockQuoteTokensEndInParagraph(quoteTokens)
        else {
            return false
        }

        return true
    }

    func shouldContinueBlockQuoteWithBlankPartialMarkerLine(
        _ next: RhoeLexer.Token,
        currentDepth: Int
    ) -> Bool {
        guard case .blockQuoteMarker(let nextDepth) = next.type else {
            return false
        }
        return nextDepth > 0 && nextDepth < currentDepth
    }

    func shouldContinueBlockQuoteWithLazyLine(
        _ next: RhoeLexer.Token,
        quoteTokens: [RhoeLexer.Token],
        state: RhoeParserState
    ) -> Bool {
        guard blockQuoteTokensEndInParagraph(quoteTokens) else {
            return false
        }

        switch next.type {
        case .paragraph, .text, .space:
            return true
        case .listMarker(_, let indent):
            return indent >= 4
        default:
            _ = state
            return false
        }
    }

    func blockQuoteTokensEndInParagraph(_ tokens: [RhoeLexer.Token]) -> Bool {
        let source = trimTrailingBlockQuoteReparseWhitespace(tokens.map(\.content).joined())
        guard !source.isEmpty else { return false }

        let reparsedTokens = lexer.tokenize(source)
        var subState = RhoeParserState(tokens: reparsedTokens, source: source)
        var lastBlock: Block?

        while let token = subState.current, token.type != .eof {
            if let block = parseBlock(&subState) {
                lastBlock = block
            } else {
                subState.advance()
            }
        }

        guard let lastBlock else { return false }
        return blockCanAcceptLazyBlockQuoteContinuation(lastBlock)
    }

    func blockCanAcceptLazyBlockQuoteContinuation(_ block: Block) -> Bool {
        switch block {
        case .paragraph:
            return true
        case .blockQuote(let content, _),
             .div(let content, _):
            guard let last = content.last else { return false }
            return blockCanAcceptLazyBlockQuoteContinuation(last)
        case .list(_, let items, _):
            guard let lastItem = items.last,
                  let last = lastItem.content.last
            else {
                return false
            }
            return blockCanAcceptLazyBlockQuoteContinuation(last)
        default:
            return false
        }
    }

    func blockQuoteTokensEndWithBlankLine(_ tokens: [RhoeLexer.Token]) -> Bool {
        guard let last = tokens.last else { return false }
        return last.type == .newline
    }

    func appendLazyBlockQuoteContinuationLine(
        _ next: RhoeLexer.Token,
        newlineToken: RhoeLexer.Token,
        state: inout RhoeParserState,
        into blockquoteTokens: inout [RhoeLexer.Token],
        markerDepthToStrip: Int = 0
    ) {
        appendBlockQuoteSoftBreakIfNeeded(from: newlineToken, into: &blockquoteTokens)

        guard next.line > 0, next.line <= state.sourceLines.count else {
            return
        }

        let sourceLine = state.sourceLines[next.line - 1]
        let markerStripped = removingBlockQuoteMarkers(markerDepthToStrip, from: sourceLine)
        let stripped = removingIndentColumns(min(4, indentationColumns(in: markerStripped)), from: markerStripped)
        let literal = neutralizedLazyBlockQuoteContinuationLine(stripped)
        blockquoteTokens.append(RhoeLexer.Token(
            type: .text(literal),
            range: next.range,
            content: literal,
            line: next.line,
            column: next.column
        ))
        advance(&state, throughSourceLine: next.line)
    }

    func removingBlockQuoteMarkers(_ count: Int, from line: String) -> String {
        guard count > 0 else { return line }

        var index = line.startIndex
        var removed = 0
        var columns = 0
        var preservedIndentColumns = 0
        while removed < count, index < line.endIndex {
            while index < line.endIndex, line[index] == " " || line[index] == "\t" {
                if line[index] == " " {
                    columns += 1
                } else {
                    columns += 4 - (columns % 4)
                }
                index = line.index(after: index)
            }
            guard index < line.endIndex, line[index] == ">" else {
                break
            }

            index = line.index(after: index)
            columns += 1
            removed += 1
            if index < line.endIndex, line[index] == " " {
                index = line.index(after: index)
                columns += 1
            } else if index < line.endIndex, line[index] == "\t" {
                let width = 4 - (columns % 4)
                preservedIndentColumns += max(0, width - 1)
                columns += width
                index = line.index(after: index)
            }
        }

        while index < line.endIndex {
            if line[index] == " " {
                preservedIndentColumns += 1
                columns += 1
                index = line.index(after: index)
            } else if line[index] == "\t" {
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

    func neutralizedLazyBlockQuoteContinuationLine(_ line: String) -> String {
        guard shouldNeutralizeLazyBlockQuoteContinuationLine(line),
              let firstNonWhitespace = line.firstIndex(where: { $0 != " " && $0 != "\t" })
        else {
            return line
        }

        let character = line[firstNonWhitespace]
        let replacement = "&#\(character.unicodeScalars.first?.value ?? 0);"
        let prefix = String(line[..<firstNonWhitespace])
        let suffix = String(line[line.index(after: firstNonWhitespace)...])
        return prefix + replacement + suffix
    }

    func shouldNeutralizeLazyBlockQuoteContinuationLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }

        return startsThematicBreakLine(trimmed)
            || setextHeadingLevel(forSourceLine: trimmed) != nil
            || startsATXHeadingLine(trimmed)
            || startsFencedCodeLine(trimmed)
            || parseCommonMarkListMarkerLine(trimmed) != nil
            || trimmed.hasPrefix(">")
    }

    fileprivate func appendBlockQuoteSoftBreakIfNeeded(
        from token: RhoeLexer.Token,
        into blockquoteTokens: inout [RhoeLexer.Token]
    ) {
        guard !blockquoteTokens.isEmpty else { return }

        blockquoteTokens.append(RhoeLexer.Token(
            type: .newline,
            range: token.range,
            content: "\n",
            line: token.line,
            column: token.column
        ))
    }

    // MARK: - Heading Block Support

    func parseHeading(_ state: inout RhoeParserState, level: Int) -> Block {
        state.advance()
        consumeHeadingLeadingSpaces(&state)
        let parsedHeading = parseHeadingInlineContent(&state)
        let trailingAttributes = consumeAttributeList(&state) ?? RhoeMarkdownKit.Attributes()
        let attributes = mergeAttributes(parsedHeading.attributes, trailingAttributes)
        consumeHeadingTrailingNewlineIfPresent(&state)
        return makeHeadingBlock(level: level, content: parsedHeading.inlines, attributes: attributes)
    }

    func consumeHeadingLeadingSpaces(_ state: inout RhoeParserState) {
        while let token = state.current, case .space = token.type {
            state.advance()
        }
    }

    func parseHeadingInlines(_ state: inout RhoeParserState) -> [Inline] {
        parseHeadingInlineContent(&state).inlines
    }

    func parseHeadingInlineContent(_ state: inout RhoeParserState) -> (inlines: [Inline], attributes: RhoeMarkdownKit.Attributes) {
        let tokens = stripClosingATXMarkerTokens(from: collectHeadingInlineTokens(&state))
        let split = splitTrailingHeadingAttributeList(from: tokens)
        var inlineState = RhoeParserState(tokens: split.tokens)
        let inlines = parseInlines(&inlineState, until: { _ in false })
        return (normalizeATXHeadingInlines(inlines), split.attributes)
    }

    func splitTrailingHeadingAttributeList(
        from tokens: [RhoeLexer.Token]
    ) -> (tokens: [RhoeLexer.Token], attributes: RhoeMarkdownKit.Attributes) {
        var result = tokens

        while let last = result.last, case .space = last.type {
            result.removeLast()
        }

        guard let last = result.last, case .attributeList(let content) = last.type else {
            return (tokens, RhoeMarkdownKit.Attributes())
        }

        result.removeLast()
        while let last = result.last, case .space = last.type {
            result.removeLast()
        }

        return (result, parseAttributes(from: content))
    }

    func collectHeadingInlineTokens(_ state: inout RhoeParserState) -> [RhoeLexer.Token] {
        var tokens: [RhoeLexer.Token] = []

        while let token = state.current {
            if token.type == .newline || token.type == .eof {
                break
            }
            tokens.append(token)
            state.advance()
        }

        return tokens
    }

    func stripClosingATXMarkerTokens(from tokens: [RhoeLexer.Token]) -> [RhoeLexer.Token] {
        var result = tokens

        while let last = result.last, case .space = last.type {
            result.removeLast()
        }

        guard let last = result.last, isATXClosingHashRun(last) else {
            return result
        }

        let markerIndex = result.index(before: result.endIndex)
        if markerIndex == result.startIndex {
            result.removeSubrange(markerIndex..<result.endIndex)
            return result
        }

        var separatorStart = markerIndex
        while separatorStart > result.startIndex {
            let previous = result.index(before: separatorStart)
            if case .space = result[previous].type {
                separatorStart = previous
            } else {
                break
            }
        }

        guard separatorStart < markerIndex else {
            return result
        }

        result.removeSubrange(separatorStart..<result.endIndex)
        return result
    }

    func isATXClosingHashRun(_ token: RhoeLexer.Token) -> Bool {
        guard case .text(let content) = token.type, !content.isEmpty else {
            return false
        }
        return content.allSatisfy { $0 == "#" }
    }

    func normalizeATXHeadingInlines(_ inlines: [Inline]) -> [Inline] {
        var normalized = inlines
        while let last = normalized.last {
            switch last {
            case .hardBreak, .softBreak:
                normalized.removeLast()
            default:
                trimTrailingSpaces(in: &normalized)
                return normalized
            }
        }
        return normalized
    }

    func stripClosingATXMarker(from inlines: [Inline]) -> [Inline] {
        var prefixEnd = inlines.endIndex
        while prefixEnd > inlines.startIndex {
            let previous = inlines.index(before: prefixEnd)
            if case .text = inlines[previous] {
                prefixEnd = previous
            } else {
                break
            }
        }

        guard prefixEnd < inlines.endIndex else {
            return inlines
        }

        let prefix = Array(inlines[..<prefixEnd])
        let textTail = inlines[prefixEnd...].compactMap { inline -> String? in
            if case .text(let text) = inline { return text }
            return nil
        }.joined()

        guard let strippedTail = textTail.strippingCommonMarkATXClosingSequence() else {
            return inlines
        }

        if strippedTail.isEmpty {
            return prefix
        }

        return prefix + [.text(strippedTail)]
    }

    func consumeHeadingTrailingNewlineIfPresent(_ state: inout RhoeParserState) {
        if let token = state.current, token.type == .newline {
            state.advance()
        }
    }

    func makeHeadingBlock(
        level: Int,
        content: [Inline],
        attributes: RhoeMarkdownKit.Attributes
    ) -> Block {
        .heading(level: level, content: content, attributes: attributes)
    }

    // MARK: - Code Block Support

    func parseCodeBlock(_ state: inout RhoeParserState, language: String?) -> Block {
        let openingInfo = splitCodeFenceInfo(language)
        state.advance()
        consumeCodeBlockLeadingNewlineIfPresent(&state)
        let collected = collectCodeBlockContent(&state)
        let normalizedContent = normalizedCodeBlockContent(collected.content)

        if collected.wasClosed {
            let trailingAttributes = consumeAttributeList(&state) ?? RhoeMarkdownKit.Attributes()
            let attributes = mergeCodeBlockAttributes(openingInfo.attributes, trailingAttributes)
            return makeCodeBlock(
                language: openingInfo.language,
                content: normalizedContent,
                attributes: attributes
            )
        }

        return makeUnclosedCodeBlock(
            &state,
            language: openingInfo.language,
            content: normalizedContent,
            attributes: openingInfo.attributes
        )
    }

    func consumeCodeBlockLeadingNewlineIfPresent(_ state: inout RhoeParserState) {
        if let token = state.current, token.type == .newline {
            state.advance()
        }
    }

    func collectCodeBlockContent(
        _ state: inout RhoeParserState
    ) -> (content: String, wasClosed: Bool) {
        var content = ""

        while let token = state.current {
            switch token.type {
            case .codeBlockDelimiter:
                state.advance()
                return (content, true)
            case .codeBlockContent:
                content = token.content
                state.advance()
            default:
                state.advance()
            }
        }

        return (content, false)
    }

    func makeCodeBlock(
        language: String?,
        content: String,
        attributes: RhoeMarkdownKit.Attributes
    ) -> Block {
        if shouldPromoteToExecutableCodeBlock(language: language, attributes: attributes) {
            return .executableCodeBlock(language: language, content: content, attributes: attributes)
        }
        return .codeBlock(language: language, content: content, attributes: attributes)
    }

    func makeUnclosedCodeBlock(
        _ state: inout RhoeParserState,
        language: String?,
        content: String,
        attributes: RhoeMarkdownKit.Attributes
    ) -> Block {
        state.addDiagnostic(RhoeMarkdownKit.Diagnostic(
            severity: .warning,
            message: "Unclosed code block"
        ))

        return makeCodeBlock(
            language: language,
            content: content,
            attributes: attributes
        )
    }

    func splitCodeFenceInfo(_ rawInfo: String?) -> (language: String?, attributes: RhoeMarkdownKit.Attributes) {
        guard let rawInfo else {
            return (nil, RhoeMarkdownKit.Attributes())
        }

        let trimmed = rawInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return (nil, RhoeMarkdownKit.Attributes())
        }

        guard let openBrace = trimmed.firstIndex(of: "{"),
              let closeBrace = trimmed.lastIndex(of: "}"),
              openBrace < closeBrace,
              trimmed[trimmed.index(after: closeBrace)...].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return (firstCodeFenceLanguageIdentifier(in: trimmed), RhoeMarkdownKit.Attributes())
        }

        let languageSlice = trimmed[..<openBrace].trimmingCharacters(in: .whitespacesAndNewlines)
        let attributesSlice = trimmed[trimmed.index(after: openBrace)..<closeBrace]
        return (
            firstCodeFenceLanguageIdentifier(in: languageSlice),
            parseAttributes(from: String(attributesSlice))
        )
    }

    func firstCodeFenceLanguageIdentifier(in rawInfo: String) -> String? {
        let unescaped = unescapeCommonMarkBackslashEscapes(rawInfo.trimmingCharacters(in: .whitespacesAndNewlines))
        let decoded = decodeCommonMarkCharacterReferences(unescaped)
        guard let first = decoded.split(whereSeparator: { $0 == " " || $0 == "\t" }).first else {
            return nil
        }
        return String(first)
    }

    func unescapeCommonMarkBackslashEscapes(_ text: String) -> String {
        var result = ""
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if character == "\\" {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, isCommonMarkEscapableASCII(text[nextIndex]) {
                    result.append(text[nextIndex])
                    index = text.index(after: nextIndex)
                    continue
                }
            }

            result.append(character)
            index = text.index(after: index)
        }

        return result
    }

    func mergeCodeBlockAttributes(
        _ openingAttributes: RhoeMarkdownKit.Attributes,
        _ trailingAttributes: RhoeMarkdownKit.Attributes
    ) -> RhoeMarkdownKit.Attributes {
        mergeAttributes(openingAttributes, trailingAttributes)
    }

    func mergeAttributes(
        _ leadingAttributes: RhoeMarkdownKit.Attributes,
        _ trailingAttributes: RhoeMarkdownKit.Attributes
    ) -> RhoeMarkdownKit.Attributes {
        let id = trailingAttributes.id ?? leadingAttributes.id
        let classes = leadingAttributes.classes + trailingAttributes.classes.filter { !leadingAttributes.classes.contains($0) }
        let keyValues = leadingAttributes.keyValues.merging(trailingAttributes.keyValues) { _, new in new }
        return RhoeMarkdownKit.Attributes(id: id, classes: classes, keyValues: keyValues)
    }

    func normalizedCodeBlockContent(_ content: String) -> String {
        return content
    }

    func shouldPromoteToExecutableCodeBlock(
        language: String?,
        attributes: RhoeMarkdownKit.Attributes
    ) -> Bool {
        guard let normalizedLanguage = language?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              executableCodeLanguages.contains(normalizedLanguage)
        else {
            return false
        }

        return attributes.keyValues.keys.contains(where: { executableCodeAttributeKeys.contains($0.lowercased()) })
    }
}

private let executableCodeLanguages: Set<String> = [
    "python",
    "javascript",
    "julia",
    "r",
    "deno",
    "swift",
    "rust",
]

private let executableCodeAttributeKeys: Set<String> = [
    "in",
    "out",
    "runtime",
    "net",
    "gpu",
    "timeout",
    "mem",
    "maxout",
    "disk",
    "persist",
]

private extension String {
    func strippingCommonMarkATXClosingSequence() -> String? {
        var markerEnd = endIndex
        while markerEnd > startIndex {
            let previous = index(before: markerEnd)
            guard self[previous] == " " || self[previous] == "\t" else {
                break
            }
            markerEnd = previous
        }

        var markerStart = markerEnd
        while markerStart > startIndex {
            let previous = index(before: markerStart)
            guard self[previous] == "#" else {
                break
            }
            markerStart = previous
        }

        guard markerStart < markerEnd else {
            return nil
        }

        if markerStart == startIndex {
            return ""
        }

        var separatorStart = markerStart
        while separatorStart > startIndex {
            let previous = index(before: separatorStart)
            guard self[previous] == " " || self[previous] == "\t" else {
                break
            }
            separatorStart = previous
        }

        guard separatorStart < markerStart else {
            return nil
        }

        return String(self[..<separatorStart])
    }
}
