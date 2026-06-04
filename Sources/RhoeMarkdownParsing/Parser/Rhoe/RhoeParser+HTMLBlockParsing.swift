import Foundation
import RhoeMarkdownModel

// MARK: - CommonMark HTML Block Parsing

enum HTMLBlockKind {
    case untilBlankLine(canInterruptParagraph: Bool)
    case untilClosingTag(String)
    case untilSequence(String, caseInsensitive: Bool)

    var canInterruptParagraph: Bool {
        switch self {
        case .untilBlankLine(let canInterruptParagraph):
            return canInterruptParagraph
        case .untilClosingTag, .untilSequence:
            return true
        }
    }
}

extension RhoeParser {

    func parseHTMLBlockIfPresent(
        _ state: inout RhoeParserState,
        requireInterruptingStart: Bool
    ) -> Block? {
        guard let start = htmlBlockStartAtCurrentParagraph(
            state,
            requireInterruptingStart: requireInterruptingStart
        ) else {
            return nil
        }

        let endLine = htmlBlockEndLine(
            from: start.line,
            kind: start.kind,
            sourceLines: state.sourceLines
        )
        let html = sourceLinesHTMLSlice(
            from: start.line,
            through: endLine,
            sourceLines: state.sourceLines
        )
        consumeHTMLBlockTokens(through: endLine, state: &state)
        return .html(html)
    }

    func startsHTMLBlockAtCurrentParagraph(
        _ state: RhoeParserState,
        requireInterruptingStart: Bool
    ) -> Bool {
        htmlBlockStartAtCurrentParagraph(
            state,
            requireInterruptingStart: requireInterruptingStart
        ) != nil
    }

    func htmlBlockStartAtCurrentParagraph(
        _ state: RhoeParserState,
        requireInterruptingStart: Bool
    ) -> (line: Int, kind: HTMLBlockKind)? {
        var tokenIndex = state.currentIndex
        if tokenIndex < state.tokens.count, case .paragraph = state.tokens[tokenIndex].type {
            tokenIndex += 1
        }

        guard tokenIndex < state.tokens.count else { return nil }
        let token = state.tokens[tokenIndex]
        guard token.line > 0, token.line <= state.sourceLines.count else { return nil }

        let line = state.sourceLines[token.line - 1]
        guard let kind = htmlBlockStartKind(forSourceLine: line) else { return nil }
        if requireInterruptingStart && !kind.canInterruptParagraph {
            return nil
        }
        return (token.line, kind)
    }

    func htmlBlockStartKind(forSourceLine line: String) -> HTMLBlockKind? {
        let indent = leadingSpaceCount(line)
        guard indent < 4 else { return nil }

        let trimmed = String(line.dropFirst(indent))
        let lowercased = trimmed.lowercased()

        if lowercased.hasPrefix("<!--") {
            return .untilSequence("-->", caseInsensitive: false)
        }
        if lowercased.hasPrefix("<?") {
            return .untilSequence("?>", caseInsensitive: false)
        }
        if lowercased.hasPrefix("<![cdata[") {
            return .untilSequence("]]>", caseInsensitive: false)
        }
        if isHTMLDeclarationStart(trimmed) {
            return .untilSequence(">", caseInsensitive: false)
        }

        guard let tag = parseLineStartingHTMLTag(trimmed) else {
            return nil
        }

        let isClosingTag = trimmed.dropFirst().first == "/"
        if !isClosingTag, commonMarkHTMLBlockClosingTags.contains(tag.name) {
            return .untilClosingTag(tag.name)
        }

        if commonMarkHTMLBlockLevelTags.contains(tag.name) {
            return .untilBlankLine(canInterruptParagraph: true)
        }

        if isCompleteCommonMarkRawHTMLTagLine(trimmed) {
            return .untilBlankLine(canInterruptParagraph: false)
        }

        return nil
    }

    func htmlBlockEndLine(
        from startLine: Int,
        kind: HTMLBlockKind,
        sourceLines: [String]
    ) -> Int {
        let lastLine = lastRealSourceLine(in: sourceLines)
        guard startLine <= lastLine else { return startLine }

        switch kind {
        case .untilBlankLine:
            var line = startLine
            while line <= lastLine {
                if line > startLine,
                   sourceLines[line - 1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return line - 1
                }
                line += 1
            }
            return lastLine

        case .untilClosingTag(let tag):
            let pattern = "</\(tag)>"
            for line in startLine...lastLine {
                if sourceLines[line - 1].lowercased().contains(pattern) {
                    return line
                }
            }
            return lastLine

        case .untilSequence(let sequence, let caseInsensitive):
            for line in startLine...lastLine {
                let haystack = caseInsensitive ? sourceLines[line - 1].lowercased() : sourceLines[line - 1]
                let needle = caseInsensitive ? sequence.lowercased() : sequence
                if haystack.contains(needle) {
                    return line
                }
            }
            return lastLine
        }
    }

    func sourceLinesHTMLSlice(
        from startLine: Int,
        through endLine: Int,
        sourceLines: [String]
    ) -> String {
        guard startLine <= endLine,
              startLine > 0,
              endLine <= sourceLines.count
        else {
            return ""
        }

        var html = ""
        for line in startLine...endLine {
            html += sourceLines[line - 1]
            if line < sourceLines.count {
                html += "\n"
            }
        }
        return html
    }

    func consumeHTMLBlockTokens(
        through endLine: Int,
        state: inout RhoeParserState
    ) {
        while let token = state.current,
              token.type != .eof,
              token.line <= endLine {
            state.advance()
        }
    }

    func isHTMLDeclarationStart(_ text: String) -> Bool {
        guard text.hasPrefix("<!"),
              let marker = text.dropFirst(2).first
        else {
            return false
        }

        return marker.isASCIIAlpha
    }

    func isCommonMarkRawHTMLInline(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        if lowercased.hasPrefix("<!--") ||
            lowercased.hasPrefix("<?") ||
            lowercased.hasPrefix("<![cdata[") ||
            isHTMLDeclarationStart(text) {
            return true
        }

        return isCompleteCommonMarkRawHTMLTagLine(text)
    }

    func parseLineStartingHTMLTag(_ text: String) -> (name: String, endIndex: String.Index)? {
        guard text.first == "<" else { return nil }
        var index = text.index(after: text.startIndex)

        if index < text.endIndex, text[index] == "/" {
            index = text.index(after: index)
        }

        guard index < text.endIndex,
              text[index].isASCIIAlpha
        else {
            return nil
        }

        let nameStart = index
        while index < text.endIndex, text[index].isHTMLTagNameCharacter {
            index = text.index(after: index)
        }

        let name = String(text[nameStart..<index]).lowercased()
        guard index < text.endIndex else {
            return (name, index)
        }

        let next = text[index]
        guard next == ">" || next == "/" || next == " " || next == "\t" || next == "\n" else {
            return nil
        }

        return (name, index)
    }

    func isCompleteCommonMarkRawHTMLTagLine(_ text: String) -> Bool {
        guard text.hasPrefix("<"),
              text.hasSuffix(">")
        else {
            return false
        }

        if text.dropFirst().first == "/" {
            return isCommonMarkClosingTag(text)
        }
        return isCommonMarkOpenTag(text)
    }

    func isCommonMarkClosingTag(_ text: String) -> Bool {
        var index = text.index(after: text.startIndex)
        guard index < text.endIndex, text[index] == "/" else { return false }
        index = text.index(after: index)

        guard parseHTMLTagName(in: text, index: &index) != nil else {
            return false
        }

        skipHTMLWhitespace(in: text, index: &index)
        guard index < text.endIndex, text[index] == ">" else { return false }
        return text.index(after: index) == text.endIndex
    }

    func isCommonMarkOpenTag(_ text: String) -> Bool {
        var index = text.index(after: text.startIndex)
        guard parseHTMLTagName(in: text, index: &index) != nil else {
            return false
        }

        while index < text.endIndex {
            let consumedWhitespace = skipHTMLWhitespace(in: text, index: &index)
            guard index < text.endIndex else { return false }

            if text[index] == ">" {
                return text.index(after: index) == text.endIndex
            }

            if text[index] == "/" {
                index = text.index(after: index)
                guard index < text.endIndex, text[index] == ">" else { return false }
                return text.index(after: index) == text.endIndex
            }

            guard consumedWhitespace else {
                return false
            }

            guard parseHTMLAttribute(in: text, index: &index) else {
                return false
            }
        }

        return false
    }

    func parseHTMLTagName(in text: String, index: inout String.Index) -> String? {
        guard index < text.endIndex, text[index].isASCIIAlpha else {
            return nil
        }

        let start = index
        while index < text.endIndex, text[index].isHTMLTagNameCharacter {
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }

    func parseHTMLAttribute(in text: String, index: inout String.Index) -> Bool {
        guard index < text.endIndex, text[index].isHTMLAttributeNameStart else {
            return false
        }

        while index < text.endIndex, text[index].isHTMLAttributeNameCharacter {
            index = text.index(after: index)
        }

        var valueIndex = index
        skipHTMLWhitespace(in: text, index: &valueIndex)
        guard valueIndex < text.endIndex, text[valueIndex] == "=" else {
            return true
        }

        index = valueIndex
        index = text.index(after: index)
        skipHTMLWhitespace(in: text, index: &index)
        return parseHTMLAttributeValue(in: text, index: &index)
    }

    func parseHTMLAttributeValue(in text: String, index: inout String.Index) -> Bool {
        guard index < text.endIndex else { return false }

        if text[index] == "\"" || text[index] == "'" {
            let quote = text[index]
            index = text.index(after: index)
            while index < text.endIndex, text[index] != quote {
                index = text.index(after: index)
            }
            guard index < text.endIndex else { return false }
            index = text.index(after: index)
            return true
        }

        let start = index
        while index < text.endIndex, text[index].isHTMLUnquotedAttributeValueCharacter {
            index = text.index(after: index)
        }
        return index > start
    }

    @discardableResult
    func skipHTMLWhitespace(in text: String, index: inout String.Index) -> Bool {
        let start = index
        while index < text.endIndex, text[index] == " " || text[index] == "\t" || text[index] == "\n" {
            index = text.index(after: index)
        }
        return index > start
    }

    func firstHTMLTagClosingBracket(
        in text: String,
        startingAt start: String.Index
    ) -> String.Index? {
        var index = start
        var quote: Character?

        while index < text.endIndex {
            let character = text[index]
            if let currentQuote = quote {
                if character == currentQuote {
                    quote = nil
                }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == ">" {
                return index
            }

            index = text.index(after: index)
        }

        return nil
    }

    func lastRealSourceLine(in sourceLines: [String]) -> Int {
        if sourceLines.last == "" {
            return max(1, sourceLines.count - 1)
        }
        return max(1, sourceLines.count)
    }

    var commonMarkHTMLBlockClosingTags: Set<String> {
        ["pre", "script", "style", "textarea"]
    }

    var commonMarkHTMLBlockLevelTags: Set<String> {
        [
            "address", "article", "aside", "base", "basefont", "blockquote",
            "body", "caption", "center", "col", "colgroup", "dd", "details",
            "dialog", "dir", "div", "dl", "dt", "fieldset", "figcaption",
            "figure", "footer", "form", "frame", "frameset", "h1", "h2",
            "h3", "h4", "h5", "h6", "head", "header", "hr", "html", "iframe",
            "legend", "li", "link", "main", "menu", "menuitem", "nav",
            "noframes", "ol", "optgroup", "option", "p", "param", "search",
            "section", "summary", "table", "tbody", "td", "tfoot", "th",
            "thead", "title", "tr", "track", "ul"
        ]
    }
}

private extension Character {
    var isASCIIAlpha: Bool {
        ("a"..."z").contains(self) || ("A"..."Z").contains(self)
    }

    var isASCIIDigit: Bool {
        ("0"..."9").contains(self)
    }

    var isHTMLTagNameCharacter: Bool {
        isASCIIAlpha || isASCIIDigit || self == "-"
    }

    var isHTMLAttributeNameStart: Bool {
        isASCIIAlpha || self == "_" || self == ":"
    }

    var isHTMLAttributeNameCharacter: Bool {
        isHTMLAttributeNameStart || isASCIIDigit || self == "." || self == "-"
    }

    var isHTMLUnquotedAttributeValueCharacter: Bool {
        !(self == " " || self == "\t" || self == "\n" ||
          self == "\"" || self == "'" || self == "=" ||
          self == "<" || self == ">" || self == "`")
    }
}
