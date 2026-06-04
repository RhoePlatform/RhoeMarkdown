import Foundation
import RhoeMarkdownModel

extension RhoeParser {

    // MARK: - Inline Token Parsing Entry Point

    func parseInlines(_ state: inout RhoeParserState, until predicate: (RhoeLexer.Token) -> Bool) -> [Inline] {
        collectTokenInlines(
            state: &state,
            until: predicate
        )
    }

    // MARK: - Token Collection

    func collectTokenInlines(
        state: inout RhoeParserState,
        until predicate: (RhoeLexer.Token) -> Bool
    ) -> [Inline] {
        var inlines: [Inline] = []
        var emphasisStack: [EmphasisDelimiterRun] = []

        while let token = state.current, !predicate(token) {
            guard appendNextTokenInlineOrStop(
                token,
                state: &state,
                inlines: &inlines,
                emphasisStack: &emphasisStack,
                until: predicate
            ) else {
                break
            }
        }

        appendPendingEmphasisMarkers(from: emphasisStack, to: &inlines)
        return inlines
    }

    func appendNextTokenInlineOrStop(
        _ token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline],
        emphasisStack: inout [EmphasisDelimiterRun],
        until predicate: (RhoeLexer.Token) -> Bool
    ) -> Bool {
        switch token.type {
        case .text(let content):
            inlines.append(.text(decodeCommonMarkCharacterReferences(content)))
            state.advance()

        case .emphasis:
            appendTokenEmphasisInline(
                token,
                state: &state,
                inlines: &inlines,
                emphasisStack: &emphasisStack
            )

        case .code:
            appendTokenCodeInline(
                state: &state,
                inlines: &inlines
            )

        case .strikethrough:
            appendTokenStrikethroughInline(
                token,
                state: &state,
                inlines: &inlines,
                until: predicate
            )

        case .linkStart:
            appendTokenLinkInline(
                state: &state,
                inlines: &inlines,
                until: predicate
            )

        case .linkEnd:
            appendLiteralLinkEndInline(
                state: &state,
                inlines: &inlines
            )

        case .imageStart:
            appendTokenImageInline(
                state: &state,
                inlines: &inlines,
                until: predicate
            )

        case .autolink:
            appendTokenAutolinkInline(
                token,
                state: &state,
                inlines: &inlines
            )

        case .htmlTag:
            appendTokenHTMLInline(
                token,
                state: &state,
                inlines: &inlines
            )

        case .escape:
            appendTokenEscapeInline(
                token,
                state: &state,
                inlines: &inlines
            )

        case .space, .newline:
            appendTokenWhitespaceInline(
                token,
                state: &state,
                inlines: &inlines
            )

        case .mathInline, .mathDisplay:
            appendTokenMathInline(
                token,
                state: &state,
                inlines: &inlines
            )

        case .attributeList:
            return false

        default:
            appendLiteralTokenInline(
                token,
                state: &state,
                inlines: &inlines
            )
        }

        return true
    }

    // MARK: - Token Classification

    func isInlineToken(_ token: RhoeLexer.Token) -> Bool {
        switch token.type {
        case .text, .emphasis, .code, .strikethrough, .linkStart, .imageStart, .autolink, .htmlTag, .escape, .space:
            return true
        default:
            return false
        }
    }

    // MARK: - Token Support (Emphasis, Code, Strikethrough)

    struct EmphasisDelimiterRun {
        var token: RhoeLexer.Token
        var index: Int
        let role: EmphasisDelimiterRole
    }

    func resolveParagraphStyleEmphasis(
        _ token: RhoeLexer.Token,
        in inlines: inout [Inline],
        emphasisStack: inout [EmphasisDelimiterRun]
    ) -> Bool {
        guard case .emphasis(let level) = token.type else { return false }
        let role = EmphasisDelimiterRole(canOpen: false, canClose: true)

        guard let matchIndex = findMatchingEmphasis(
            token,
            role: role,
            closeLevel: level,
            in: emphasisStack
        ) else {
            return false
        }

        resolveEmphasisMatch(
            matchIndex: matchIndex,
            closeToken: token,
            closeLevel: level,
            inlines: &inlines,
            emphasisStack: &emphasisStack
        )
        return true
    }

    func appendPendingEmphasisMarkers(
        from emphasisStack: [EmphasisDelimiterRun],
        to inlines: inout [Inline]
    ) {
        for run in emphasisStack.reversed() {
            inlines.insert(.text(run.token.content), at: min(run.index, inlines.count))
        }
    }

    func parseTokenCodeSpan(_ state: inout RhoeParserState) -> Inline {
        guard let openingToken = state.current else {
            return .text("")
        }

        let openingIndex = state.currentIndex
        let openingMarker = openingToken.content
        state.advance()
        var codeContent = ""
        var foundClosingMarker = false

        while let token = state.current {
            if case .code = token.type, token.content == openingMarker {
                state.advance()
                foundClosingMarker = true
                break
            } else if let split = codeSpanClosingMarkerSplit(in: token.content, openingMarker: openingMarker) {
                codeContent += split.prefix
                state.advance()
                insertCodeSpanResidualIfNeeded(split.residual, after: token, state: &state)
                foundClosingMarker = true
                break
            } else if token.type == .newline,
                      let next = state.peek(),
                      isSetextHeadingUnderlineLine(for: next, in: state) {
                state.currentIndex = min(openingIndex + 1, state.tokens.count)
                return .text(openingMarker)
            } else if case .code = token.type {
                codeContent += token.content
                state.advance()
            } else if case .text(let text) = token.type {
                codeContent += text
                state.advance()
            } else if case .space(let count) = token.type {
                codeContent += String(repeating: " ", count: count)
                state.advance()
            } else {
                codeContent += token.content
                state.advance()
            }
        }

        guard foundClosingMarker else {
            state.currentIndex = min(openingIndex + 1, state.tokens.count)
            return .text(openingMarker)
        }

        let trimmedCode = commonMarkTrimCodeSpan(codeContent)

        // Check for attribute list token after closing backtick
        // The lexer may have consumed {=format} or {.class} as an .attributeList token
        if let token = state.current, case .attributeList(let attrContent) = token.type {
            state.advance()

            // Parse {=format} for raw inline
            if attrContent.hasPrefix("=") {
                let format = String(attrContent.dropFirst())
                if !format.isEmpty && configuration.enableRawInlines {
                    return .rawInline(content: trimmedCode, format: format)
                }
            }

            // Parse as code attributes
            let attrs = parseAttributes(from: attrContent)
            if let rawInline = checkForRawInline(code: trimmedCode, attributes: attrs) {
                return rawInline
            }
            return .codeSpan(trimmedCode, attributes: attrs)
        }

        // Check for {=format} or {.class #id key=val} after closing backtick (text token fallback)
        if let token = state.current, case .text(let text) = token.type, text.hasPrefix("{") {
            // Collect the full attribute text (may span multiple tokens if } was not in stop list)
            var attrText = text
            state.advance()

            // If the text doesn't contain }, collect more tokens
            while !attrText.contains("}"), let next = state.current {
                if case .text(let t) = next.type {
                    attrText += t
                    state.advance()
                } else if case .space(let count) = next.type {
                    attrText += String(repeating: " ", count: count)
                    state.advance()
                } else {
                    break
                }
            }

            // Parse {=format} for raw inline
            if attrText.hasPrefix("{=") && attrText.hasSuffix("}") {
                let format = String(attrText.dropFirst(2).dropLast())
                if !format.isEmpty && configuration.enableRawInlines {
                    return .rawInline(content: trimmedCode, format: format)
                }
            }

            // Parse {.class #id key=val} for code attributes
            if attrText.hasPrefix("{") && attrText.hasSuffix("}") {
                let attrContent = String(attrText.dropFirst().dropLast())
                let attrs = parseAttributes(from: attrContent)
                // Check if this is a raw format masquerading as a class (e.g., {=html} parsed as class)
                if let rawInline = checkForRawInline(code: trimmedCode, attributes: attrs) {
                    return rawInline
                }
                return .codeSpan(trimmedCode, attributes: attrs)
            }
        }

        return .codeSpan(trimmedCode)
    }

    func codeSpanClosingMarkerSplit(
        in content: String,
        openingMarker: String
    ) -> (prefix: String, residual: String)? {
        guard !content.isEmpty,
              openingMarker.allSatisfy({ $0 == "`" })
        else {
            return nil
        }

        let expectedLength = openingMarker.count
        var index = content.startIndex

        while index < content.endIndex {
            guard content[index] == "`" else {
                index = content.index(after: index)
                continue
            }

            let runStart = index
            var runLength = 0
            while index < content.endIndex, content[index] == "`" {
                runLength += 1
                index = content.index(after: index)
            }

            if runLength == expectedLength {
                return (
                    prefix: String(content[..<runStart]),
                    residual: String(content[index...])
                )
            }
        }

        return nil
    }

    func insertCodeSpanResidualIfNeeded(
        _ residual: String,
        after token: RhoeLexer.Token,
        state: inout RhoeParserState
    ) {
        guard !residual.isEmpty else { return }

        let residualToken = RhoeLexer.Token(
            type: .text(residual),
            range: token.range.lowerBound..<token.range.lowerBound,
            content: residual,
            line: token.line,
            column: token.column + max(0, token.content.count - residual.count)
        )
        state.tokens.insert(residualToken, at: state.currentIndex)
    }

    // MARK: - Token Fallback Support

    func parseInlineTokens(_ state: inout RhoeParserState) -> [Inline] {
        var inlines: [Inline] = []
        var emphasisStack: [EmphasisDelimiterRun] = []

        while let token = state.current {
            switch token.type {
            case .text(let content):
                inlines.append(.text(content))
                state.advance()
            case .space(let count):
                inlines.append(.text(String(repeating: " ", count: count)))
                state.advance()
            case .emphasis:
                appendFallbackEmphasisInline(
                    token,
                    state: &state,
                    inlines: &inlines,
                    emphasisStack: &emphasisStack
                )
            case .code:
                inlines.append(parseTokenCodeSpan(&state))
            case .linkStart:
                inlines.append(.text("["))
                state.advance()
            case .linkEnd:
                inlines.append(.text("]"))
                state.advance()
            case .eof:
                break
            default:
                inlines.append(.text(token.content))
                state.advance()
            }
        }

        appendPendingEmphasisMarkers(from: emphasisStack, to: &inlines)
        return inlines
    }

    func findMatchingEmphasis(
        _ token: RhoeLexer.Token,
        role: EmphasisDelimiterRole,
        closeLevel: Int,
        in stack: [EmphasisDelimiterRun]
    ) -> Int? {
        guard closeLevel > 0 else { return nil }

        for (index, run) in stack.enumerated().reversed() {
            guard run.role.canOpen,
                  emphasisMarkersMatch(run.token, token),
                  let openLevel = emphasisLevel(of: run.token),
                  openLevel > 0
            else {
                continue
            }

            if emphasisDelimiterRunsCanMatch(
                opener: run,
                closer: token,
                closerRole: role,
                closeLevel: closeLevel
            ) {
                return index
            }
        }

        return nil
    }

    struct EmphasisDelimiterRole {
        let canOpen: Bool
        let canClose: Bool
    }

    func emphasisDelimiterRole(
        for token: RhoeLexer.Token,
        state: RhoeParserState
    ) -> EmphasisDelimiterRole {
        let previous = previousInlineCharacter(before: state.currentIndex, in: state.tokens)
        let next = nextInlineCharacter(after: state.currentIndex, in: state.tokens)

        let previousIsWhitespace = previous.map(isCommonMarkWhitespace) ?? true
        let nextIsWhitespace = next.map(isCommonMarkWhitespace) ?? true
        let previousIsPunctuation = previous.map(isCommonMarkPunctuationOrSymbol) ?? false
        let nextIsPunctuation = next.map(isCommonMarkPunctuationOrSymbol) ?? false

        let leftFlanking = !nextIsWhitespace && (!nextIsPunctuation || previousIsWhitespace || previousIsPunctuation)
        let rightFlanking = !previousIsWhitespace && (!previousIsPunctuation || nextIsWhitespace || nextIsPunctuation)

        let marker = token.content.first
        if marker == "_" {
            return EmphasisDelimiterRole(
                canOpen: leftFlanking && (!rightFlanking || previousIsPunctuation),
                canClose: rightFlanking && (!leftFlanking || nextIsPunctuation)
            )
        }

        return EmphasisDelimiterRole(canOpen: leftFlanking, canClose: rightFlanking)
    }

    func previousInlineCharacter(before index: Int, in tokens: [RhoeLexer.Token]) -> Character? {
        guard index > 0 else { return nil }

        var probe = index - 1
        while probe >= 0 {
            if let character = tokens[probe].content.last {
                return character
            }
            if probe == 0 { break }
            probe -= 1
        }
        return nil
    }

    func nextInlineCharacter(after index: Int, in tokens: [RhoeLexer.Token]) -> Character? {
        var probe = index + 1
        while probe < tokens.count {
            if let character = tokens[probe].content.first {
                return character
            }
            probe += 1
        }
        return nil
    }

    func isCommonMarkWhitespace(_ character: Character) -> Bool {
        character == "\u{00A0}" || String(character).rangeOfCharacter(from: .whitespacesAndNewlines) != nil
    }

    func isCommonMarkPunctuationOrSymbol(_ character: Character) -> Bool {
        let punctuationAndSymbols = CharacterSet.punctuationCharacters.union(.symbols)
        return String(character).rangeOfCharacter(from: punctuationAndSymbols) != nil
    }

    fileprivate func appendFallbackEmphasisInline(
        _ token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline],
        emphasisStack: inout [EmphasisDelimiterRun]
    ) {
        if let matchingIndex = emphasisStack.lastIndex(where: {
            if case .emphasis(let stackLevel) = $0.token.type,
               case .emphasis(let level) = token.type {
                return stackLevel == level
            }
            return false
        }) {
            let run = emphasisStack.remove(at: matchingIndex)
            let startToken = run.token
            let startIndex = run.index
            let content = Array(inlines[startIndex...])
            inlines.removeSubrange(startIndex...)

            if case .emphasis(let startLevel) = startToken.type {
                if startLevel == 1 {
                    inlines.append(.emphasis(content))
                } else if startLevel == 2 {
                    inlines.append(.strong(content))
                }
            }
        } else {
            emphasisStack.append(EmphasisDelimiterRun(
                token: token,
                index: inlines.count,
                role: EmphasisDelimiterRole(canOpen: true, canClose: true)
            ))
        }

        state.advance()
    }

    // MARK: - Token Leaf Support

    func appendTokenAutolinkInline(
        _ token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline]
    ) {
        if configuration.enableAutolinks {
            let content = token.content
            let url = String(content.dropFirst().dropLast())
            inlines.append(.link(text: [.text(url)], url: normalizedAutolinkDestination(url), title: nil))
        } else {
            inlines.append(.text(token.content))
        }
        state.advance()
    }

    func normalizedAutolinkDestination(_ raw: String) -> String {
        if raw.contains("@"), !raw.contains(":") {
            return "mailto:\(raw)"
        }
        return percentEncodeCommonMarkAutolinkDestination(raw)
    }

    func percentEncodeCommonMarkAutolinkDestination(_ raw: String) -> String {
        var encoded = ""
        for character in raw {
            switch character {
            case "\\":
                encoded += "%5C"
            case "[":
                encoded += "%5B"
            case "]":
                encoded += "%5D"
            case "`":
                encoded += "%60"
            default:
                encoded.append(character)
            }
        }
        return encoded
    }

    func appendTokenHTMLInline(
        _ token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline]
    ) {
        if case .text(let previous)? = inlines.last, previous.hasSuffix("<") {
            inlines.append(.text(token.content))
        } else if isCommonMarkRawHTMLInline(token.content) {
            inlines.append(.html(token.content))
        } else {
            let literal = stripSingleTrailingLineEnding(from: token.content)
            let escaped = unescapeCommonMarkTextPreservingInlineProvenance(literal)
            inlines.append(.text(decodeCommonMarkCharacterReferences(escaped)))
        }
        state.advance()
    }

    func stripSingleTrailingLineEnding(from text: String) -> String {
        if text.hasSuffix("\r\n") {
            return String(text.dropLast(2))
        }
        if text.hasSuffix("\n") || text.hasSuffix("\r") {
            return String(text.dropLast())
        }
        return text
    }

    func appendTokenEscapeInline(
        _ token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline]
    ) {
        appendCommonMarkEscapeInline(
            token,
            state: &state,
            inlines: &inlines
        )
    }

    func appendCommonMarkEscapeInline(
        _ token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline]
    ) {
        if isEscapedLineEnding(token.content) {
            if let next = state.peek(),
               !isParagraphTerminalAfterEscapedLineEnding(next) {
                inlines.append(.hardBreak)
            } else {
                inlines.append(.text("\\"))
            }
            state.advance()
            return
        }

        let escaped = commonMarkEscapedTextContent(token.content)
        if escaped != token.content {
            if escaped == "[" || escaped == "!" || escaped == "<" || escaped == ">" {
                inlines.append(.text("\u{E000}\(escaped)"))
            } else {
                inlines.append(.text(escaped))
            }
        } else {
            inlines.append(.text(token.content))
        }
        state.advance()
    }

    func commonMarkEscapedTextContent(_ content: String) -> String {
        let escaped = String(content.dropFirst())
        if escaped.count == 1,
           let character = escaped.first,
           isCommonMarkEscapableASCII(character) {
            return escaped
        }
        return content
    }

    func unescapeCommonMarkTextPreservingInlineProvenance(_ text: String) -> String {
        var output = ""
        var index = text.startIndex

        while index < text.endIndex {
            if text[index] == "\\" {
                let next = text.index(after: index)
                if next < text.endIndex,
                   isCommonMarkEscapableASCII(text[next]) {
                    if text[next] == "[" || text[next] == "!" || text[next] == "<" || text[next] == ">" {
                        output.append("\u{E000}")
                    }
                    output.append(text[next])
                    index = text.index(after: next)
                    continue
                }
            }

            output.append(text[index])
            index = text.index(after: index)
        }

        return output
    }

    func isEscapedLineEnding(_ content: String) -> Bool {
        content == "\\\n" || content == "\\\r\n" || content == "\\\r"
    }

    func isParagraphTerminalAfterEscapedLineEnding(_ token: RhoeLexer.Token) -> Bool {
        token.type == .eof || token.type == .newline || isBlockBoundaryToken(token)
    }

    func isCommonMarkEscapableASCII(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1,
              let scalar = character.unicodeScalars.first,
              scalar.value >= 0x21,
              scalar.value <= 0x7E
        else {
            return false
        }

        switch character {
        case "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", "/",
             ":", ";", "<", "=", ">", "?", "@", "[", "\\", "]", "^", "_", "`", "{", "|", "}", "~":
            return true
        default:
            return false
        }
    }

    func appendTokenWhitespaceInline(
        _ token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline]
    ) {
        switch token.type {
        case .space(let count):
            if count >= 2, let next = state.peek(), next.type == .newline {
                inlines.append(.hardBreak)
                state.advance()
                state.advance()
            } else {
                inlines.append(.text(String(repeating: " ", count: count)))
                state.advance()
            }

        case .newline:
            inlines.append(.softBreak)
            state.advance()

        default:
            break
        }
    }

    func appendTokenMathInline(
        _ token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline]
    ) {
        switch token.type {
        case .mathInline:
            inlines.append(.inlineMath(expression: token.content))
            state.advance()

        case .mathDisplay:
            inlines.append(.mathDisplay(expression: token.content))
            state.advance()

        default:
            break
        }
    }

    func appendLiteralTokenInline(
        _ token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline]
    ) {
        inlines.append(.text(token.content))
        state.advance()
    }

    // MARK: - Token Bracket Support

    func parseSimpleInlineImageAlt(_ state: inout RhoeParserState) -> [Inline] {
        var altTextInlines: [Inline] = []

        while let token = state.current {
            if token.type == .linkEnd {
                state.advance()
                break
            }

            switch token.type {
            case .text(let content):
                altTextInlines.append(.text(content))
                state.advance()
            case .space(let count):
                altTextInlines.append(.text(String(repeating: " ", count: count)))
                state.advance()
            default:
                state.advance()
            }
        }

        return altTextInlines
    }

    func parseSimpleInlineLinkLabel(_ state: inout RhoeParserState) -> (inlines: [Inline], literal: String, closed: Bool) {
        var linkTextInlines: [Inline] = []
        var emphasisStack: [EmphasisDelimiterRun] = []
        let labelStartIndex = state.currentIndex

        while let token = state.current {
            if token.type == .linkEnd {
                let literal = literalTokenContent(in: state, from: labelStartIndex, to: state.currentIndex)
                appendPendingEmphasisMarkers(from: emphasisStack, to: &linkTextInlines)
                state.advance()
                return (linkTextInlines, literal, true)
            }

            switch token.type {
            case .text(let content):
                linkTextInlines.append(.text(content))
                state.advance()
            case .space(let count):
                linkTextInlines.append(.text(String(repeating: " ", count: count)))
                state.advance()
            case .emphasis:
                appendTokenEmphasisInline(
                    token,
                    state: &state,
                    inlines: &linkTextInlines,
                    emphasisStack: &emphasisStack
                )
            case .code:
                linkTextInlines.append(parseTokenCodeSpan(&state))
            case .imageStart:
                state.advance()
                let altTextInlines = parseSimpleInlineImageAlt(&state)

                if let destination = consumeParenthesizedLinkDestination(&state) {
                    linkTextInlines.append(.image(alt: altTextInlines, url: destination.url, title: destination.title))
                } else {
                    linkTextInlines.append(.text("!["))
                    linkTextInlines.append(contentsOf: altTextInlines)
                    linkTextInlines.append(.text("]"))
                }
            case .escape:
                linkTextInlines.append(.text(commonMarkEscapedTextContent(token.content)))
                state.advance()
            default:
                linkTextInlines.append(.text(token.content))
                state.advance()
            }
        }

        let literal = literalTokenContent(in: state, from: labelStartIndex, to: state.currentIndex)
        appendPendingEmphasisMarkers(from: emphasisStack, to: &linkTextInlines)
        return (linkTextInlines, literal, false)
    }

    func literalTokenContent(in state: RhoeParserState, from startIndex: Int, to endIndex: Int) -> String {
        guard startIndex < endIndex, startIndex < state.tokens.count else { return "" }

        let boundedEndIndex = min(endIndex, state.tokens.count)
        return state.tokens[startIndex..<boundedEndIndex]
            .filter { $0.type != .eof }
            .map(\.content)
            .joined()
    }

    func collectBracketedInlineTokens(_ state: inout RhoeParserState) -> [RhoeLexer.Token] {
        collectBracketedInlineTokensWithClosure(&state).tokens
    }

    func collectBracketedInlineTokensWithClosure(
        _ state: inout RhoeParserState
    ) -> (tokens: [RhoeLexer.Token], closed: Bool) {
        var altTextTokens: [RhoeLexer.Token] = []
        var bracketDepth = 0
        var codeSpanMarker: String?

        while let token = state.current {
            if case .code = token.type {
                if codeSpanMarker == token.content {
                    codeSpanMarker = nil
                } else if codeSpanMarker == nil {
                    codeSpanMarker = token.content
                }

                altTextTokens.append(token)
                state.advance()
                continue
            }

            if codeSpanMarker == nil, token.type == .linkEnd && bracketDepth == 0 {
                state.advance()
                return (altTextTokens, true)
            }

            if codeSpanMarker == nil, token.type == .linkStart || token.type == .imageStart {
                bracketDepth += 1
            } else if codeSpanMarker == nil, token.type == .linkEnd {
                bracketDepth -= 1
            }

            altTextTokens.append(token)
            state.advance()

            if token.type == .eof {
                break
            }
        }

        return (altTextTokens, false)
    }

    func parseLiteralInlineImageAlt(
        _ state: inout RhoeParserState,
        until predicate: (RhoeLexer.Token) -> Bool
    ) -> [Inline] {
        var altTextTokens: [Inline] = []

        while let token = state.current {
            if token.type == .linkEnd || predicate(token) {
                break
            }

            switch token.type {
            case .text(let content):
                altTextTokens.append(.text(content))
                state.advance()
            case .space(let count):
                altTextTokens.append(.text(String(repeating: " ", count: count)))
                state.advance()
            default:
                state.advance()
            }
        }

        return altTextTokens
    }

    // MARK: - Token Delimiter Support (Emphasis, Code, Strikethrough dispatch)

    func appendTokenEmphasisInline(
        _ token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline],
        emphasisStack: inout [EmphasisDelimiterRun]
    ) {
        guard case .emphasis(let level) = token.type else { return }
        let role = emphasisDelimiterRole(for: token, state: state)
        var remainingCloseLevel = level

        if role.canClose {
            while remainingCloseLevel > 0,
                  let matchIndex = findMatchingEmphasis(
                    token,
                    role: role,
                    closeLevel: remainingCloseLevel,
                    in: emphasisStack
                  ) {
                let consumed = resolveEmphasisMatch(
                    matchIndex: matchIndex,
                    closeToken: token,
                    closeLevel: remainingCloseLevel,
                    inlines: &inlines,
                    emphasisStack: &emphasisStack
                )
                remainingCloseLevel -= consumed
            }
        }

        if remainingCloseLevel > 0, role.canOpen {
            emphasisStack.append(EmphasisDelimiterRun(
                token: residualEmphasisToken(from: token, level: remainingCloseLevel),
                index: inlines.count,
                role: role
            ))
        } else if remainingCloseLevel > 0 {
            inlines.append(.text(emphasisLiteral(from: token, level: remainingCloseLevel)))
        }

        state.advance()
    }

    @discardableResult
    func resolveEmphasisMatch(
        matchIndex: Int,
        closeToken: RhoeLexer.Token,
        closeLevel: Int,
        inlines: inout [Inline],
        emphasisStack: inout [EmphasisDelimiterRun]
    ) -> Int {
        let openRun = emphasisStack[matchIndex]
        let openToken = openRun.token
        let openIndex = min(openRun.index, inlines.count)
        let openLevel = emphasisLevel(of: openToken) ?? 0
        let consumed = emphasisConsumedLength(openLevel: openLevel, closeLevel: closeLevel)

        flushInnerPendingEmphasisMarkers(after: matchIndex, to: &inlines, emphasisStack: &emphasisStack)

        let content = openIndex < inlines.count ? Array(inlines[openIndex...]) : []
        inlines.removeSubrange(openIndex...)
        inlines.append(wrapEmphasis(content, consumedLength: consumed))

        let residualOpenLevel = max(0, openLevel - consumed)
        if residualOpenLevel > 0 {
            emphasisStack[matchIndex] = EmphasisDelimiterRun(
                token: residualEmphasisToken(from: openToken, level: residualOpenLevel),
                index: openIndex,
                role: openRun.role
            )
        } else {
            emphasisStack.remove(at: matchIndex)
        }

        return consumed
    }

    func flushInnerPendingEmphasisMarkers(
        after matchIndex: Int,
        to inlines: inout [Inline],
        emphasisStack: inout [EmphasisDelimiterRun]
    ) {
        while emphasisStack.count > matchIndex + 1 {
            let run = emphasisStack.removeLast()
            inlines.insert(.text(run.token.content), at: min(run.index, inlines.count))
        }
    }

    func emphasisDelimiterRunsCanMatch(
        opener: EmphasisDelimiterRun,
        closer: RhoeLexer.Token,
        closerRole: EmphasisDelimiterRole,
        closeLevel: Int
    ) -> Bool {
        guard let openLevel = emphasisLevel(of: opener.token),
              emphasisMarkersMatch(opener.token, closer)
        else {
            return false
        }

        if opener.role.canClose || closerRole.canOpen {
            let combinedLength = openLevel + closeLevel
            if combinedLength % 3 == 0,
               openLevel % 3 != 0 || closeLevel % 3 != 0 {
                return false
            }
        }

        return true
    }

    func emphasisMarkersMatch(_ lhs: RhoeLexer.Token, _ rhs: RhoeLexer.Token) -> Bool {
        lhs.content.first == rhs.content.first
    }

    func emphasisLevel(of token: RhoeLexer.Token) -> Int? {
        guard case .emphasis(let level) = token.type else { return nil }
        return level
    }

    func emphasisConsumedLength(openLevel: Int, closeLevel: Int) -> Int {
        openLevel >= 2 && closeLevel >= 2 ? 2 : 1
    }

    func wrapEmphasis(_ content: [Inline], consumedLength: Int) -> Inline {
        if consumedLength >= 2 {
            return .strong(githubNormalizedStrongContent(content))
        }
        return .emphasis(content)
    }

    func githubNormalizedStrongContent(_ content: [Inline]) -> [Inline] {
        guard configuration == .github else { return content }

        return content.flatMap { inline -> [Inline] in
            if case .strong(let nested) = inline {
                return nested
            }
            return [inline]
        }
    }

    func residualEmphasisToken(from token: RhoeLexer.Token, level: Int) -> RhoeLexer.Token {
        RhoeLexer.Token(
            type: .emphasis(level: level),
            range: token.range,
            content: emphasisLiteral(from: token, level: level),
            line: token.line,
            column: token.column
        )
    }

    func emphasisLiteral(from token: RhoeLexer.Token, level: Int) -> String {
        guard let marker = token.content.first else { return "" }
        return String(repeating: String(marker), count: level)
    }

    func appendTokenCodeInline(
        state: inout RhoeParserState,
        inlines: inout [Inline]
    ) {
        inlines.append(parseTokenCodeSpan(&state))
    }

    func appendTokenStrikethroughInline(
        _ token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline],
        until predicate: (RhoeLexer.Token) -> Bool
    ) {
        if configuration.enableStrikethrough {
            state.advance()
            let content = parseInlines(&state, until: { current in
                current.type == .strikethrough || predicate(current)
            })

            if let current = state.current, current.type == .strikethrough {
                state.advance()
                inlines.append(.strikethrough(content))
            } else {
                inlines.append(.text("~~"))
                inlines.append(contentsOf: content)
            }
        } else {
            inlines.append(.text(token.content))
            state.advance()
        }
    }
}
