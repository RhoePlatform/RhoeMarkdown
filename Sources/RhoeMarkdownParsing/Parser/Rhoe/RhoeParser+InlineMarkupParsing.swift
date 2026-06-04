import Foundation
import RhoeMarkdownModel

extension RhoeParser {

    // MARK: - Emphasis and Strikethrough

    func parseEmphasisFromText(_ text: String, at position: inout String.Index) -> Inline? {
        let marker = text[position]
        let start = position

        var openCount = 0
        while position < text.endIndex && text[position] == marker {
            openCount += 1
            position = text.index(after: position)
        }

        if openCount > 3 {
            openCount = 3
            position = text.index(start, offsetBy: 3)
        }

        let actualStart = start

        if openCount >= 2 {
            position = text.index(start, offsetBy: 2)
            var searchPos = position

            while searchPos < text.endIndex {
                if text[searchPos] == marker {
                    let closeStart = searchPos
                    var closeCount = 0
                    var countPos = searchPos
                    while countPos < text.endIndex && text[countPos] == marker {
                        closeCount += 1
                        countPos = text.index(after: countPos)
                    }

                    if closeCount >= 2 {
                        let content = String(text[position..<closeStart])
                        guard !content.isEmpty else {
                            searchPos = countPos
                            continue
                        }
                        let innerInlines = parseInlines(content)
                        position = text.index(closeStart, offsetBy: 2)
                        return .strong(innerInlines)
                    }
                    searchPos = countPos
                } else {
                    searchPos = text.index(after: searchPos)
                }
            }
        }

        if openCount >= 1 {
            position = text.index(start, offsetBy: 1)
            var searchPos = position

            while searchPos < text.endIndex {
                if text[searchPos] == marker {
                    let content = String(text[position..<searchPos])
                    guard !content.isEmpty else {
                        searchPos = text.index(after: searchPos)
                        continue
                    }
                    let innerInlines = parseInlines(content)
                    position = text.index(after: searchPos)
                    return .emphasis(innerInlines)
                }
                searchPos = text.index(after: searchPos)
            }
        }

        position = actualStart
        return nil
    }

    func parseStrikethroughFromText(_ text: String, at position: inout String.Index) -> Inline? {
        guard position < text.index(before: text.endIndex) else { return nil }
        guard text[position] == "~" && text[text.index(after: position)] == "~" else { return nil }

        let start = position
        position = text.index(position, offsetBy: 2)

        var searchPos = position
        while searchPos < text.index(before: text.endIndex) {
            if text[searchPos] == "~" && text[text.index(after: searchPos)] == "~" {
                let content = String(text[position..<searchPos])
                let innerInlines = parseInlines(content)
                position = text.index(searchPos, offsetBy: 2)
                return .strikethrough(innerInlines)
            }
            searchPos = text.index(after: searchPos)
        }

        position = start
        return nil
    }

    // MARK: - Code Parsing

    func parseCodeFromText(_ text: String, at position: inout String.Index) -> Inline? {
        guard text[position] == "`" else { return nil }

        let start = position
        var backtickCount = 0

        while position < text.endIndex && text[position] == "`" {
            backtickCount += 1
            position = text.index(after: position)
        }

        var searchPos = position
        while searchPos < text.endIndex {
            if text[searchPos] == "`" {
                var closeCount = 0
                let closeStart = searchPos
                while searchPos < text.endIndex && text[searchPos] == "`" {
                    closeCount += 1
                    searchPos = text.index(after: searchPos)
                }

                if closeCount == backtickCount {
                    let content = String(text[position..<closeStart])
                    let trimmedCode = commonMarkTrimCodeSpan(content)

                    // Check for raw format: `code`{=format}
                    if let format = parseRawFormatAttribute(text, at: &searchPos) {
                        position = searchPos
                        return .rawInline(content: trimmedCode, format: format)
                    }

                    // Check for inline attributes: `code`{.class #id key=val}
                    let attrs = parseInlineAttributesFromText(text, at: &searchPos)
                    position = searchPos
                    return .codeSpan(trimmedCode, attributes: attrs)
                }
            } else {
                searchPos = text.index(after: searchPos)
            }
        }

        position = start
        return nil
    }

    /// CommonMark §6.1 code span trimming:
    /// Strip exactly one leading and one trailing space, but only if
    /// both exist and the content is not entirely spaces.
    func commonMarkTrimCodeSpan(_ content: String) -> String {
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")

        if normalized.hasPrefix(" ") && normalized.hasSuffix(" ")
            && !normalized.allSatisfy({ $0 == " " }) {
            return String(normalized.dropFirst().dropLast())
        }
        return normalized
    }

    // MARK: - Link and Image Parsing

    func parseLinkFromText(_ text: String, at position: inout String.Index) -> Inline? {
        guard text[position] == "[" else { return nil }

        let start = position
        guard let linkText = consumeBalancedDelimitedContent(
            in: text,
            at: &position,
            opening: "[",
            closing: "]"
        ) else {
            position = start
            return nil
        }

        if let attributes = consumeOptionalInlineAttributes(in: text, at: &position) {
            let spanInlines = parseInlines(linkText)
            return .span(content: spanInlines, attributes: attributes)
        }

        if position < text.endIndex && text[position] == "(" {
            let destinationStart = position
            if let destinationEnd = closingParenthesisForInlineLink(in: text, openingParenthesis: destinationStart) {
                let destinationText = String(text[destinationStart...destinationEnd])
                if !containsEscapedAngleDestinationCloser(destinationText),
                   let destination = parseLinkDestination(destinationText) {
                    position = text.index(after: destinationEnd)
                    let attributes = consumeOptionalInlineAttributes(in: text, at: &position)
                        ?? RhoeMarkdownKit.Attributes()

                    let linkInlines = parseInlines(linkText)
                    return .link(text: linkInlines, url: destination.url, title: destination.title, attributes: attributes)
                }
            }
        }

        position = start
        return nil
    }

    func containsEscapedAngleDestinationCloser(_ text: String) -> Bool {
        guard text.hasPrefix("(") else { return false }
        var index = text.index(after: text.startIndex)
        consumeInlineSpaces(in: text, at: &index)
        guard index < text.endIndex, text[index] == "<" else { return false }
        return text[index...].range(of: "\\>") != nil ||
            text[index...].range(of: "\u{E000}>") != nil
    }

    func parseImageFromText(_ text: String, at position: inout String.Index) -> Inline? {
        guard position < text.index(before: text.endIndex),
              text[position] == "!",
              text[text.index(after: position)] == "[" else { return nil }

        let start = position
        position = text.index(after: position)

        if let link = parseLinkFromText(text, at: &position) {
            if case .link(let altTextInlines, let url, let title, let attributes) = link {
                return .image(alt: altTextInlines, url: url, title: title, attributes: attributes)
            }
        }

        position = start
        return nil
    }

    // MARK: - Token Link and Media Support

    func appendTokenLinkInline(
        state: inout RhoeParserState,
        inlines: inout [Inline],
        until predicate: (RhoeLexer.Token) -> Bool
    ) {
        state.advance()
        let linkText = parseInlines(&state, until: { token in
            token.type == .linkEnd || predicate(token)
        })

        if let token = state.current, token.type == .linkEnd {
            state.advance()

            if let destination = consumeParenthesizedLinkDestination(&state) {
                if containsLinkInline(linkText) {
                    inlines.append(.text("["))
                    inlines.append(contentsOf: linkText)
                    inlines.append(.text("]"))
                    inlines.append(.text(destination.rawText))
                } else {
                    let attributes = consumeAttributeList(&state) ?? RhoeMarkdownKit.Attributes()
                    inlines.append(.link(text: linkText, url: destination.url, title: destination.title, attributes: attributes))
                }
            } else if let token = state.current, case .attributeList(let content) = token.type {
                state.advance()
                let attributes = parseAttributes(from: content)
                inlines.append(.span(content: linkText, attributes: attributes))
            } else {
                inlines.append(.text("["))
                inlines.append(contentsOf: linkText)
                inlines.append(.text("]"))
            }
        } else {
            inlines.append(.text("["))
            inlines.append(contentsOf: linkText)
        }
    }

    func appendTokenImageInline(
        state: inout RhoeParserState,
        inlines: inout [Inline],
        until predicate: (RhoeLexer.Token) -> Bool
    ) {
        state.advance()
        let altTextTokens = parseLiteralInlineImageAlt(&state, until: predicate)

        if let token = state.current, token.type == .linkEnd {
            state.advance()

            if let destination = consumeParenthesizedLinkDestination(&state) {
                inlines.append(.image(alt: altTextTokens, url: destination.url, title: destination.title))
            } else {
                inlines.append(.text("!["))
                inlines.append(contentsOf: altTextTokens)
                inlines.append(.text("]"))
            }
        } else {
            inlines.append(.text("!["))
            inlines.append(contentsOf: altTextTokens)
        }
    }

    func appendLiteralLinkEndInline(
        state: inout RhoeParserState,
        inlines: inout [Inline]
    ) {
        inlines.append(.text("]"))
        state.advance()
    }

    // MARK: - Token Destination Support

    func consumeParenthesizedLinkDestination(
        _ state: inout RhoeParserState
    ) -> (url: String, title: String?, rawText: String)? {
        guard let token = state.current, case .text(let text) = token.type, text.hasPrefix("(") else {
            return nil
        }

        let startIndex = state.currentIndex
        var fullLinkContent = ""

        while let nextToken = state.current {
            let segment: String
            let canSplitCurrentToken: Bool

            switch nextToken.type {
            case .text(let moreText):
                segment = moreText
                canSplitCurrentToken = true
            case .emphasis, .strikethrough, .code, .linkStart, .linkEnd, .imageStart, .autolink:
                segment = nextToken.content
                canSplitCurrentToken = false
            case .htmlTag:
                segment = nextToken.content
                canSplitCurrentToken = false
            case .escape:
                segment = nextToken.content
                canSplitCurrentToken = false
            case .space(let count):
                segment = String(repeating: " ", count: count)
                canSplitCurrentToken = false
            case .newline:
                segment = "\n"
                canSplitCurrentToken = false
            case .paragraph:
                state.advance()
                continue
            default:
                state.currentIndex = startIndex
                return nil
            }

            let segmentStart = fullLinkContent.endIndex
            fullLinkContent += segment

            if let parsed = parseLinkDestinationPrefix(fullLinkContent) {
                let rawText = String(fullLinkContent[..<parsed.endIndex])
                if containsEscapedAngleDestinationCloser(rawText) {
                    state.currentIndex = startIndex
                    return nil
                }

                if parsed.endIndex == fullLinkContent.endIndex {
                    state.advance()
                } else if canSplitCurrentToken, parsed.endIndex >= segmentStart {
                    let consumedInSegment = fullLinkContent.distance(from: segmentStart, to: parsed.endIndex)
                    let splitIndex = segment.index(segment.startIndex, offsetBy: consumedInSegment)
                    let leftover = String(segment[splitIndex...])
                    state.tokens[state.currentIndex] = RhoeLexer.Token(
                        type: .text(leftover),
                        range: nextToken.range,
                        content: leftover,
                        line: nextToken.line,
                        column: nextToken.column + consumedInSegment
                    )
                } else {
                    state.advance()
                }
                return (parsed.url, parsed.title, rawText)
            }

            state.advance()
        }

        state.currentIndex = startIndex
        return nil
    }

    func closingParenthesisForInlineLink(
        in text: String,
        openingParenthesis: String.Index
    ) -> String.Index? {
        guard openingParenthesis < text.endIndex, text[openingParenthesis] == "(" else {
            return nil
        }

        var probe = text.index(after: openingParenthesis)
        consumeInlineSpaces(in: text, at: &probe)
        let startsWithAngleDestination = probe < text.endIndex && text[probe] == "<"

        var index = text.index(after: openingParenthesis)
        var escaped = false
        var inAngleDestination = false
        var bareParenthesisDepth = 0

        while index < text.endIndex {
            let character = text[index]

            if escaped {
                escaped = false
                index = text.index(after: index)
                continue
            }

            if character == "\\" {
                escaped = true
                index = text.index(after: index)
                continue
            }

            if startsWithAngleDestination {
                if character == "<" && index == probe {
                    inAngleDestination = true
                    index = text.index(after: index)
                    continue
                }
                if inAngleDestination {
                    if character == ">" {
                        inAngleDestination = false
                    }
                    index = text.index(after: index)
                    continue
                }
                if character == ")" {
                    return index
                }
            } else {
                if character == "(" {
                    bareParenthesisDepth += 1
                } else if character == ")" {
                    if bareParenthesisDepth == 0 {
                        return index
                    }
                    bareParenthesisDepth -= 1
                }
            }

            index = text.index(after: index)
        }

        return nil
    }

    func parseLinkDestination(_ text: String) -> (url: String, title: String?)? {
        guard let parsed = parseLinkDestinationPrefix(text),
              parsed.endIndex == text.endIndex else {
            return nil
        }
        return (parsed.url, parsed.title)
    }

    func parseLinkDestinationPrefix(_ text: String) -> (url: String, title: String?, endIndex: String.Index)? {
        guard text.first == "(" else { return nil }

        var index = text.index(after: text.startIndex)
        consumeInlineSpaces(in: text, at: &index)

        let rawURL: String
        let percentEncodeSpaces: Bool
        if index < text.endIndex, text[index] == "<" {
            guard let angleDestination = consumeAngleBracketLinkDestination(in: text, at: &index) else {
                return nil
            }
            rawURL = angleDestination
            percentEncodeSpaces = true
        } else {
            guard let bareDestination = consumeBareLinkDestination(in: text, at: &index) else {
                return nil
            }
            rawURL = bareDestination
            percentEncodeSpaces = false
        }

        consumeInlineSpaces(in: text, at: &index)

        var title: String?
        if index < text.endIndex, text[index] != ")" {
            guard let parsedTitle = consumeCommonMarkLinkTitle(in: text, at: &index) else {
                return nil
            }
            title = parsedTitle
            consumeInlineSpaces(in: text, at: &index)
        }

        guard index < text.endIndex, text[index] == ")" else {
            return nil
        }

        let endIndex = text.index(after: index)
        let url = normalizeCommonMarkLinkDestination(rawURL, percentEncodeSpaces: percentEncodeSpaces)
        return (url, title, endIndex)
    }

    func consumeAngleBracketLinkDestination(
        in text: String,
        at index: inout String.Index
    ) -> String? {
        guard index < text.endIndex, text[index] == "<" else { return nil }
        index = text.index(after: index)

        var destination = ""
        while index < text.endIndex {
            let character = text[index]
            if character == "\n" || character == "<" {
                return nil
            }
            if character == "\\" {
                let next = text.index(after: index)
                guard next < text.endIndex else { return nil }
                if text[next] == ">" {
                    return nil
                }
            }
            if character == ">" {
                index = text.index(after: index)
                return destination
            }

            destination.append(character)
            index = text.index(after: index)
        }

        return nil
    }

    func consumeBareLinkDestination(
        in text: String,
        at index: inout String.Index
    ) -> String? {
        var destination = ""
        var parenthesisDepth = 0

        while index < text.endIndex {
            let character = text[index]
            if character == " " || character == "\t" || character == "\n" {
                break
            }
            if character == "\\" {
                let next = text.index(after: index)
                guard next < text.endIndex else { return nil }
                destination.append(character)
                destination.append(text[next])
                index = text.index(after: next)
                continue
            }
            if character == "(" {
                parenthesisDepth += 1
                destination.append(character)
                index = text.index(after: index)
                continue
            }
            if character == ")" {
                if parenthesisDepth == 0 {
                    break
                }
                parenthesisDepth -= 1
                destination.append(character)
                index = text.index(after: index)
                continue
            }

            destination.append(character)
            index = text.index(after: index)
        }

        guard parenthesisDepth == 0 else { return nil }
        return destination
    }

    func consumeCommonMarkLinkTitle(
        in text: String,
        at index: inout String.Index
    ) -> String? {
        guard index < text.endIndex else { return nil }

        let opener = text[index]
        let closer: Character
        if opener == "\"" || opener == "'" {
            closer = opener
        } else if opener == "(" {
            closer = ")"
        } else {
            return nil
        }

        index = text.index(after: index)
        var title = ""
        while index < text.endIndex {
            let character = text[index]
            if character == closer {
                index = text.index(after: index)
                return decodeCommonMarkCharacterReferences(unescapeCommonMarkBackslashEscapes(title))
            }
            if character == "\\" {
                let next = text.index(after: index)
                guard next < text.endIndex else {
                    title.append(character)
                    index = next
                    continue
                }
                title.append(character)
                title.append(text[next])
                index = text.index(after: next)
                continue
            }
            if character == "\n" {
                title.append("\n")
                index = text.index(after: index)
                continue
            }
            title.append(character)
            index = text.index(after: index)
        }

        return nil
    }

    func normalizeCommonMarkLinkDestination(
        _ raw: String,
        percentEncodeSpaces: Bool
    ) -> String {
        let unescaped = decodeCommonMarkCharacterReferences(unescapeCommonMarkBackslashEscapes(raw))
        var encoded = ""

        for scalar in unescaped.unicodeScalars {
            if shouldPreserveCommonMarkURLScalar(scalar) {
                encoded += String(scalar)
            } else {
                for byte in String(scalar).utf8 {
                    encoded += String(format: "%%%02X", byte)
                }
            }
        }

        return encoded
    }

    func shouldPreserveCommonMarkURLScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x30...0x39, 0x41...0x5A, 0x61...0x7A:
            return true
        case 0x2D, 0x2E, 0x5F, 0x7E, // - . _ ~
             0x3A, 0x2F, 0x3F, 0x23, 0x5B, 0x5D, 0x40, // : / ? # [ ] @
             0x21, 0x24, 0x26, 0x27, 0x28, 0x29, 0x2A, // ! $ & ' ( ) *
             0x2B, 0x2C, 0x3B, 0x3D, 0x25: // + , ; = %
            return true
        default:
            return false
        }
    }

    // MARK: - Superscript Parsing

    /// Parse superscript from `^text^` syntax.
    ///
    /// Superscript content cannot contain unescaped spaces. Use `\ ` for
    /// multi-word content: `^multi\ word^`.
    ///
    /// Disambiguation:
    /// - `^[text]` → inline footnote (caret + bracket, Sprint 2)
    /// - `^text^`  → superscript (caret + non-bracket + closing caret)
    func parseSuperscriptFromText(_ text: String, at position: inout String.Index) -> Inline? {
        guard configuration.enableSuperscript else { return nil }
        guard text[position] == "^" else { return nil }

        let start = position
        let afterCaret = text.index(after: position)

        // Guard: must have content after the caret
        guard afterCaret < text.endIndex else {
            return nil
        }

        // Disambiguate from inline footnote `^[`
        if text[afterCaret] == "[" {
            return nil
        }

        position = afterCaret

        // Scan for closing `^`, disallowing unescaped spaces
        while position < text.endIndex {
            let ch = text[position]

            if ch == "^" {
                let content = String(text[afterCaret..<position])
                guard !content.isEmpty else {
                    position = start
                    return nil
                }
                position = text.index(after: position) // consume closing ^
                let innerInlines = parseInlines(content)
                return .superscript(innerInlines)
            }

            // Allow escaped spaces `\ `
            if ch == "\\" && text.index(after: position) < text.endIndex {
                position = text.index(position, offsetBy: 2)
                continue
            }

            // Unescaped space terminates (not a valid superscript)
            if ch == " " || ch == "\n" {
                position = start
                return nil
            }

            position = text.index(after: position)
        }

        position = start
        return nil
    }

    // MARK: - Subscript Parsing

    /// Parse subscript from `~text~` syntax.
    ///
    /// Disambiguation from strikethrough:
    /// - `~~text~~` (double tilde) → strikethrough
    /// - `~text~`  (single tilde) → subscript
    ///
    /// Subscript content cannot contain unescaped spaces.
    func parseSubscriptFromText(_ text: String, at position: inout String.Index) -> Inline? {
        guard configuration.enableSubscript else { return nil }
        guard text[position] == "~" else { return nil }

        let start = position
        let afterTilde = text.index(after: position)

        // Guard: must have content after the tilde
        guard afterTilde < text.endIndex else {
            return nil
        }

        // Disambiguate from strikethrough: double tilde is NOT subscript
        if text[afterTilde] == "~" {
            return nil
        }

        position = afterTilde

        // Scan for closing single `~`, disallowing unescaped spaces
        while position < text.endIndex {
            let ch = text[position]

            if ch == "~" {
                let content = String(text[afterTilde..<position])
                guard !content.isEmpty else {
                    position = start
                    return nil
                }
                position = text.index(after: position) // consume closing ~
                let innerInlines = parseInlines(content)
                return .subscript(innerInlines)
            }

            // Allow escaped spaces
            if ch == "\\" && text.index(after: position) < text.endIndex {
                position = text.index(position, offsetBy: 2)
                continue
            }

            // Unescaped space terminates
            if ch == " " || ch == "\n" {
                position = start
                return nil
            }

            position = text.index(after: position)
        }

        position = start
        return nil
    }

    // MARK: - Highlight Parsing

    /// Parse highlight/mark from `==text==` syntax.
    ///
    /// No disambiguation needed: `==` is not used by any other
    /// RhoeMarkdown construct.
    func parseHighlightFromText(_ text: String, at position: inout String.Index) -> Inline? {
        guard configuration.enableHighlight else { return nil }
        guard text[position] == "=" else { return nil }

        let start = position
        let next = text.index(after: position)

        // Require double `==`
        guard next < text.endIndex && text[next] == "=" else {
            return nil
        }

        let afterOpen = text.index(after: next)
        guard afterOpen < text.endIndex else {
            return nil
        }

        position = afterOpen

        // Scan for closing `==`
        while position < text.endIndex {
            if text[position] == "=" {
                let closeNext = text.index(after: position)
                if closeNext < text.endIndex && text[closeNext] == "=" {
                    let content = String(text[afterOpen..<position])
                    guard !content.isEmpty else {
                        position = start
                        return nil
                    }
                    position = text.index(after: closeNext) // consume closing ==
                    let innerInlines = parseInlines(content)
                    return .highlight(innerInlines)
                }
            }
            position = text.index(after: position)
        }

        position = start
        return nil
    }

    // MARK: - Delimiter Support

    func consumeBalancedDelimitedContent(
        in text: String,
        at position: inout String.Index,
        opening: Character,
        closing: Character
    ) -> String? {
        guard position < text.endIndex, text[position] == opening else { return nil }

        let start = position
        position = text.index(after: position)

        var depth = 1
        var content = ""

        while position < text.endIndex && depth > 0 {
            if text[position] == opening {
                depth += 1
            } else if text[position] == closing {
                depth -= 1
                if depth == 0 {
                    position = text.index(after: position)
                    return content
                }
            }

            content.append(text[position])
            position = text.index(after: position)
        }

        position = start
        return nil
    }

    func consumeInlineSpaces(
        in text: String,
        at position: inout String.Index
    ) {
        while position < text.endIndex && isCommonMarkInlineSpace(text[position]) {
            position = text.index(after: position)
        }
    }

    func isCommonMarkInlineSpace(_ character: Character) -> Bool {
        character == " " || character == "\t" || character == "\n" || character == "\r"
    }

    func consumeOptionalQuotedInlineText(
        in text: String,
        at position: inout String.Index
    ) -> String? {
        guard position < text.endIndex,
              text[position] == "\"" || text[position] == "'" else {
            return nil
        }

        let quote = text[position]
        let start = position
        position = text.index(after: position)
        let contentStart = position

        while position < text.endIndex && text[position] != quote {
            position = text.index(after: position)
        }

        guard position < text.endIndex else {
            position = start
            return nil
        }

        let content = String(text[contentStart..<position])
        position = text.index(after: position)
        return content
    }

    func consumeOptionalInlineAttributes(
        in text: String,
        at position: inout String.Index
    ) -> RhoeMarkdownKit.Attributes? {
        let start = position
        guard let content = consumeBalancedDelimitedContent(
            in: text,
            at: &position,
            opening: "{",
            closing: "}"
        ) else {
            position = start
            return nil
        }

        return parseAttributes(from: content)
    }
}
