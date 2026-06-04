import Foundation
import RhoeMarkdownModel

// MARK: - Paragraph Inline Mode

enum ParagraphInlineMode {
    case paragraph
    case listItem
}

// MARK: - Paragraph Style Flow Control

enum ParagraphStyleFlowControl {
    case parseInlineToken
    case tokenHandled
    case stopParsing
}

extension RhoeParser {

    // MARK: - Paragraph Block Support

    func parsePromotedTopLevelParagraphBlock(_ state: inout RhoeParserState) -> Block {
        switch parsePromotedTopLevelParagraphEntry(&state) {
        case .table(let block):
            return block
        case .html(let block):
            return block
        case .paragraph(let inlines, let attributes):
            if let level = consumeSetextHeadingUnderlineIfPresent(&state) {
                return makeHeadingBlock(level: level, content: trimSetextHeadingInlines(inlines), attributes: attributes)
            }
            return makeParagraphBlock(from: inlines, attributes: attributes)
        }
    }

    // MARK: - Paragraph Block Assembly Support

    func makeParagraphBlocksIfNeeded(from inlines: [Inline]) -> [Block] {
        inlines.isEmpty ? [] : [makeParagraphBlock(from: inlines)]
    }

    func makeParagraphBlock(
        from inlines: [Inline],
        attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes()
    ) -> Block {
        .paragraph(inlines, attributes: attributes)
    }

    // MARK: - Paragraph Style Flow Support

    func parseParagraphStyleInlineRun(
        _ state: inout RhoeParserState,
        mode: ParagraphInlineMode
    ) -> [Inline] {
        var inlines: [Inline] = []
        var emphasisStack: [EmphasisDelimiterRun] = []
        var loopCount = 0

        parseLoop: while let token = state.current {
            loopCount += 1
            if shouldStopParagraphStyleInlineRun(
                before: token,
                loopCount: loopCount,
                mode: mode
            ) {
                break parseLoop
            }

            switch handleParagraphStyleFlowStep(
                token,
                state: &state,
                inlines: &inlines,
                emphasisStack: &emphasisStack,
                mode: mode
            ) {
            case .tokenHandled:
                continue parseLoop
            case .stopParsing:
                break parseLoop
            case .parseInlineToken:
                break parseLoop
            }
        }

        appendPendingEmphasisMarkers(from: emphasisStack, to: &inlines)
        return rewriteInlinesForExtendedSyntax(inlines)
    }

    // MARK: - Paragraph Style Dispatch Support

    func handleParagraphStyleFlowStep(
        _ token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline],
        emphasisStack: inout [EmphasisDelimiterRun],
        mode: ParagraphInlineMode
    ) -> ParagraphStyleFlowControl {
        switch paragraphStyleFlowControl(
            for: token,
            state: &state,
            inlines: &inlines,
            mode: mode
        ) {
        case .parseInlineToken:
            appendParagraphStyleInlineToken(
                token,
                state: &state,
                inlines: &inlines,
                emphasisStack: &emphasisStack,
                mode: mode
            )
            return .tokenHandled

        case .tokenHandled:
            return .tokenHandled

        case .stopParsing:
            return .stopParsing
        }
    }

    func paragraphStyleFlowControl(
        for token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline],
        mode: ParagraphInlineMode
    ) -> ParagraphStyleFlowControl {
        switch mode {
        case .paragraph:
            return topLevelParagraphStyleFlowControl(
                for: token,
                state: &state,
                inlines: &inlines
            )
        case .listItem:
            return listItemParagraphStyleFlowControl(
                for: token,
                state: &state,
                inlines: &inlines
            )
        }
    }

    // MARK: - Paragraph Style Stop Support

    func shouldStopParagraphStyleInlineRun(
        before token: RhoeLexer.Token,
        loopCount: Int,
        mode: ParagraphInlineMode
    ) -> Bool {
        switch mode {
        case .paragraph:
            return shouldStopTopLevelParagraphInlineRun(
                before: token,
                loopCount: loopCount
            )
        case .listItem:
            return shouldStopListItemParagraphInlineRun(
                before: token,
                loopCount: loopCount
            )
        }
    }

    // MARK: - Paragraph Style Newline Support

    func paragraphNewlineFlowControl(
        state: inout RhoeParserState,
        inlines: inout [Inline]
    ) -> ParagraphStyleFlowControl {
        let hasHardBreakMarker = consumeTrailingSpacesForHardBreak(in: &inlines)
        state.advance()
        if consumeWhitespaceOnlyParagraphTail(&state) {
            trimTrailingSpaces(in: &inlines)
            return .stopParsing
        }

        if let next = state.current, next.type == .newline {
            trimTrailingSpaces(in: &inlines)
            state.advance()
            return .stopParsing
        }

        if consumeIndentedParagraphContinuationIfPresent(
            state: &state,
            inlines: &inlines,
            hardBreak: hasHardBreakMarker
        ) {
            return .tokenHandled
        }

        if let next = state.current {
            if case .listMarker = next.type {
                if isParagraphInterruptingListMarker(next, in: state) {
                    trimTrailingSpaces(in: &inlines)
                    return .stopParsing
                }
            } else if isBlockBoundaryToken(next) {
                if !inlines.isEmpty, isSetextHeadingUnderlineLine(for: next, in: state) {
                    trimTrailingSpaces(in: &inlines)
                    return .stopParsing
                }
                trimTrailingSpaces(in: &inlines)
                return .stopParsing
            }
        }

        if let next = state.current,
           !inlines.isEmpty,
           isSetextHeadingUnderlineLine(for: next, in: state) {
            trimTrailingSpaces(in: &inlines)
            return .stopParsing
        }

        if shouldStopParagraphStyleFlowAfterNewline(in: &state) {
            trimTrailingSpaces(in: &inlines)
            return .stopParsing
        }

        if startsHTMLBlockAtCurrentParagraph(state, requireInterruptingStart: true) {
            trimTrailingSpaces(in: &inlines)
            return .stopParsing
        }

        inlines.append(hasHardBreakMarker ? .hardBreak : .softBreak)
        return .tokenHandled
    }

    func consumeIndentedParagraphContinuationIfPresent(
        state: inout RhoeParserState,
        inlines: inout [Inline],
        hardBreak: Bool
    ) -> Bool {
        guard !inlines.isEmpty else { return false }

        var consumedContinuation = false
        var firstContinuationUsesHardBreak = hardBreak

        while let token = state.current,
              token.line > 0,
              token.line <= state.sourceLines.count {
            let line = state.sourceLines[token.line - 1]
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty,
                  indentationColumns(in: line) >= 4
            else {
                break
            }

            let continuation = removingIndentColumns(indentationColumns(in: line), from: line)
            inlines.append(firstContinuationUsesHardBreak ? .hardBreak : .softBreak)
            if isThematicBreakLikeParagraphContinuation(continuation) {
                inlines.append(.text(continuation))
            } else {
                inlines.append(contentsOf: parseInlines(continuation))
            }
            advance(&state, throughSourceLine: token.line)
            firstContinuationUsesHardBreak = false
            consumedContinuation = true
        }

        return consumedContinuation
    }

    func isThematicBreakLikeParagraphContinuation(_ line: String) -> Bool {
        let markerCharacters = line.filter { $0 != " " && $0 != "\t" }
        guard markerCharacters.count >= 3,
              let marker = markerCharacters.first,
              marker == "*" || marker == "-" || marker == "_"
        else {
            return false
        }
        return markerCharacters.allSatisfy { $0 == marker }
    }

    func consumeWhitespaceOnlyParagraphTail(_ state: inout RhoeParserState) -> Bool {
        let startIndex = state.currentIndex
        var consumedWhitespace = false

        while let token = state.current {
            switch token.type {
            case .space:
                consumedWhitespace = true
                state.advance()
            case .newline:
                guard consumedWhitespace else {
                    state.currentIndex = startIndex
                    return false
                }
                state.advance()
                return true
            case .eof:
                return consumedWhitespace
            default:
                state.currentIndex = startIndex
                return false
            }
        }

        return consumedWhitespace
    }

    func isParagraphInterruptingListMarker(
        _ token: RhoeLexer.Token,
        in state: RhoeParserState
    ) -> Bool {
        guard token.line > 0,
              token.line <= state.sourceLines.count,
              let marker = parseCommonMarkListMarkerLine(state.sourceLines[token.line - 1]),
              !marker.firstContent.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            return false
        }

        if case .ordered(let start) = marker.markerType {
            return start == 1
        }

        return true
    }

    func consumeTrailingSpacesForHardBreak(in inlines: inout [Inline]) -> Bool {
        guard case .text(let text)? = inlines.last else {
            return false
        }

        let trailingSpaceCount = text.reversed().prefix(while: { $0 == " " }).count
        guard trailingSpaceCount >= 2 else {
            return false
        }

        trimTrailingSpaces(in: &inlines)
        return true
    }

    func trimTrailingSpaces(in inlines: inout [Inline]) {
        while case .text(let text)? = inlines.last {
            let trimmed = text.dropLast(text.reversed().prefix(while: { $0 == " " || $0 == "\t" }).count)
            if trimmed.isEmpty {
                inlines.removeLast()
            } else {
                inlines[inlines.count - 1] = .text(String(trimmed))
                break
            }
        }
    }

    // MARK: - Setext Heading Support

    func consumeSetextHeadingUnderlineIfPresent(_ state: inout RhoeParserState) -> Int? {
        guard let token = state.current,
              let level = setextHeadingLevel(for: token, in: state)
        else {
            return nil
        }

        consumeCurrentSourceLine(&state)
        return level
    }

    func isSetextHeadingUnderlineLine(for token: RhoeLexer.Token, in state: RhoeParserState) -> Bool {
        setextHeadingLevel(for: token, in: state) != nil
    }

    func setextHeadingLevel(for token: RhoeLexer.Token, in state: RhoeParserState) -> Int? {
        guard token.line > 0, token.line <= state.sourceLines.count else {
            return nil
        }
        guard token.line > 1,
              !state.sourceLines[token.line - 2].trimmingCharacters(in: .whitespaces).isEmpty
        else {
            return nil
        }

        let line = state.sourceLines[token.line - 1]
        return setextHeadingLevel(forSourceLine: line)
    }

    func setextHeadingLevel(forSourceLine line: String) -> Int? {
        let indent = leadingSpaceCount(line)
        guard indent < 4 else { return nil }

        let trimmed = line.dropFirst(indent).trimmingCharacters(in: .whitespaces)
        guard let marker = trimmed.first,
              marker == "=" || marker == "-",
              trimmed.allSatisfy({ $0 == marker })
        else {
            return nil
        }

        return marker == "=" ? 1 : 2
    }

    func trimSetextHeadingInlines(_ inlines: [Inline]) -> [Inline] {
        var result = inlines
        trimTrailingSpaces(in: &result)
        return result
    }

    func consumeCurrentSourceLine(_ state: inout RhoeParserState) {
        guard let line = state.current?.line else { return }

        while let token = state.current, token.line == line {
            state.advance()
        }
    }

    func leadingSpaceCount(_ line: String) -> Int {
        var count = 0
        for character in line {
            if character == " " {
                count += 1
            } else if character == "\t" {
                count += 4
            } else {
                break
            }
        }
        return count
    }

    func listItemNewlineFlowControl(
        state: inout RhoeParserState,
        inlines: inout [Inline]
    ) -> ParagraphStyleFlowControl {
        if let next = state.peek(), shouldStopListItemAfterCurrentNewline(before: next) {
            trimTrailingSpaces(in: &inlines)
            state.advance()
            return .stopParsing
        }

        inlines.append(.softBreak)
        state.advance()
        return .tokenHandled
    }

    func shouldStopListItemAfterCurrentNewline(before next: RhoeLexer.Token) -> Bool {
        switch next.type {
        case .listMarker, .newline, .eof:
            return true
        default:
            return isBlockBoundaryToken(next)
        }
    }

    // MARK: - Paragraph Inline Dispatch Support

    func appendParagraphStyleInlineToken(
        _ token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline],
        emphasisStack: inout [EmphasisDelimiterRun],
        mode: ParagraphInlineMode
    ) {
        switch token.type {
        case .text, .space, .autolink, .htmlTag, .escape, .footnoteReference, .mathInline, .mathDisplay:
            appendParagraphStyleLeafInline(
                token,
                state: &state,
                inlines: &inlines
            )

        case .emphasis:
            appendParagraphStyleEmphasisInline(
                token,
                state: &state,
                inlines: &inlines,
                emphasisStack: &emphasisStack
            )

        case .strikethrough:
            appendParagraphStyleStrikethroughInline(
                state: &state,
                inlines: &inlines
            )

        case .code:
            appendParagraphStyleCodeInline(
                state: &state,
                inlines: &inlines
            )

        case .linkStart:
            appendParagraphStyleLinkInline(
                state: &state,
                inlines: &inlines,
                mode: mode
            )

        case .imageStart:
            appendParagraphStyleImageInline(
                token,
                state: &state,
                inlines: &inlines,
                mode: mode
            )

        default:
            appendParagraphStyleLeafInline(
                token,
                state: &state,
                inlines: &inlines
            )
        }
    }

    // MARK: - Paragraph Inline Leaf Support

    func appendParagraphStyleLeafInline(
        _ token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline]
    ) {
        switch token.type {
        case .text(let content):
            appendParagraphStyleTextInline(content, to: &inlines)
            state.advance()

        case .space(let count):
            inlines.append(.text(String(repeating: " ", count: count)))
            state.advance()

        case .autolink:
            let url = String(token.content.dropFirst().dropLast())
            inlines.append(.link(text: [.text(url)], url: normalizedAutolinkDestination(url), title: nil))
            state.advance()

        case .htmlTag:
            appendTokenHTMLInline(
                token,
                state: &state,
                inlines: &inlines
            )

        case .escape:
            appendCommonMarkEscapeInline(
                token,
                state: &state,
                inlines: &inlines
            )

        case .footnoteReference:
            inlines.append(.footnoteRef(id: token.content))
            state.advance()

        case .mathInline:
            inlines.append(.inlineMath(expression: token.content))
            state.advance()

        case .mathDisplay:
            inlines.append(.mathDisplay(expression: token.content))
            state.advance()

        default:
            inlines.append(.text(token.content))
            state.advance()
        }
    }

    func appendParagraphStyleTextInline(_ content: String, to inlines: inout [Inline]) {
        let decoded = decodeCommonMarkCharacterReferences(content)
        guard decoded.contains("<"), decoded.contains(">") else {
            inlines.append(.text(decoded))
            return
        }

        let parsed = collectStringInlines(from: decoded)
        if parsed.contains(where: containsRawHTMLInline) {
            inlines.append(contentsOf: parsed)
        } else {
            inlines.append(.text(decoded))
        }
    }

    func containsRawHTMLInline(_ inline: Inline) -> Bool {
        switch inline {
        case .html:
            return true
        case .emphasis(let content),
             .strong(let content),
             .strikethrough(let content),
             .superscript(let content),
             .subscript(let content),
             .highlight(let content),
             .span(let content, _),
             .inlineFootnote(let content):
            return content.contains(where: containsRawHTMLInline)
        case .link(let text, _, _, _):
            return text.contains(where: containsRawHTMLInline)
        case .image(let alt, _, _, _):
            return alt.contains(where: containsRawHTMLInline)
        default:
            return false
        }
    }

    // MARK: - Paragraph Inline Delimiter Support

    func appendParagraphStyleEmphasisInline(
        _ token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline],
        emphasisStack: inout [EmphasisDelimiterRun]
    ) {
        appendTokenEmphasisInline(
            token,
            state: &state,
            inlines: &inlines,
            emphasisStack: &emphasisStack
        )
    }

    func appendParagraphStyleStrikethroughInline(
        state: inout RhoeParserState,
        inlines: inout [Inline]
    ) {
        state.advance()
        var strikeContent: [Inline] = []

        while let token = state.current {
            if case .strikethrough = token.type {
                state.advance()
                inlines.append(.strikethrough(strikeContent))
                break
            } else if case .text(let content) = token.type {
                strikeContent.append(.text(content))
                state.advance()
            } else if case .space(let count) = token.type {
                strikeContent.append(.text(String(repeating: " ", count: count)))
                state.advance()
            } else if case .eof = token.type {
                inlines.append(.text("~~"))
                inlines.append(contentsOf: strikeContent)
                break
            } else {
                strikeContent.append(.text(token.content))
                state.advance()
            }
        }
    }

    func appendParagraphStyleCodeInline(
        state: inout RhoeParserState,
        inlines: inout [Inline]
    ) {
        inlines.append(parseTokenCodeSpan(&state))
    }
}
