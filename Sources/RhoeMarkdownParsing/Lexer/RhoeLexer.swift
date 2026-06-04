import Foundation
import RhoeMarkdownModel

/// GitHub Flavored Markdown Lexer - World-class tokenization engine 🚀
public struct RhoeLexer: Sendable {

    // MARK: - Token Types

    public enum TokenType: Sendable, Equatable {
        // Block-level tokens
        case heading(level: Int)
        case paragraph
        case blockQuoteMarker(depth: Int)
        case listMarker(type: ListMarkerType, indent: Int)
        case codeBlockDelimiter(language: String?)
        case codeBlockContent
        case horizontalRule
        case tableDelimiter
        case tableSeparator

        // Pandoc-style extensions
        case yamlFrontmatterStart  // ---
        case yamlFrontmatterEnd    // --- or ...
        case yamlFrontmatterContent(String)
        case definitionTerm        // Term (followed by definition)
        case definitionMarker      // : or ~ (definition marker)
        case footnoteReference     // [^ref]
        case footnoteDefinition    // [^ref]: definition
        case mathInline            // $...$
        case mathDisplay           // $$...$$
        case admonitionStart(type: String, title: String?, collapsible: AdmonitionCollapsible?)  // !!!
        case admonitionEnd         // !!!
        case fencedDivStart(name: String?, colons: Int)  // ::: or :::+ colons
        case fencedDivEnd(colons: Int)                   // :::
        case compositionDirectiveOpen(keyword: String, argument: String?)  // <<keyword ...>>
        case compositionDirectiveClose(keyword: String)                    // <</keyword>>
        case phase2DirectiveOpen(command: String, arguments: String?)      // {@ command args @}
        case phase2DirectiveClose(command: String)                         // {@ endcommand @}
        case placeholderToken(fields: String)                              // {? name: "Field", type: text ?}
        case attributeList(String) // {#id .class key=value}

        // Slide presentation tokens
        case slideDelimiter        // %%%
        case gridLayout(columns: Int, rows: Int) // %% D3
        case gridCell(column: Int, row: Int)     // % A1

        // Inline tokens
        case text(String)
        case emphasis(level: Int) // 1 = *, 2 = **, 3 = ***
        case code
        case strikethrough
        case linkStart
        case linkEnd
        case linkText
        case linkUrl
        case linkTitle
        case imageStart
        case autolink
        case htmlTag
        case escape

        // Special tokens
        case newline
        case space(count: Int)
        case eof
    }

    public enum ListMarkerType: Sendable, Equatable {
        case unordered(Character) // -, *, +
        case ordered(Int)
        case task(checked: Bool)
    }

    public struct Token: Sendable {
        public let type: TokenType
        public let range: Range<String.Index>
        public let content: String
        public let line: Int
        public let column: Int

        public init(type: TokenType, range: Range<String.Index>, content: String, line: Int, column: Int) {
            self.type = type
            self.range = range
            self.content = content
            self.line = line
            self.column = column
        }
    }

    // MARK: - Public API

    public var enableFancyLists: Bool = true
    public var enableYAMLFrontmatter: Bool = true

    public init() {}

    /// Tokenize RhoeMarkdown input into a stream of tokens
    public func tokenize(_ input: String) -> [Token] {
        var state = ByteScanner(source: input)

        while state.hasMore {

            if state.isStartOfLine {
                lexBlockLevel(&state)
            } else {
                lexInline(&state)
            }
        }

        // Add EOF token
        let eofIdx = state.source.utf8.index(state.source.utf8.startIndex, offsetBy: state.offset)
        state.tokens.append(Token(
            type: .eof,
            range: eofIdx..<eofIdx,
            content: "",
            line: state.line,
            column: state.column
        ))

        return state.tokens
    }

    // MARK: - Block-level Lexing

    @inline(__always)
    private func lexBlockLevel(_ state: inout ByteScanner) {
        // Count indentation instead of skipping
        var indentCount = 0
        while let byte = state.peek(at: 0), byte == ASCII.SPACE || byte == ASCII.TAB {
            indentCount += (byte == ASCII.TAB) ? 4 : 1  // Tab counts as 4 spaces
            state.advance()
        }

        guard let byte = state.peek(at: 0) else {
            // A final whitespace-only tail has no block meaning; leave it consumed
            // so the tokenizer can terminate instead of re-reading the same bytes.
            return
        }

        switch byte {
        case ASCII.HASH:
            // Check for hash auto-number list marker: #. or #)
            if enableFancyLists
                && (state.peek(at: 1) == ASCII.DOT || state.peek(at: 1) == ASCII.RPAREN)
                && state.peek(at: 2) == ASCII.SPACE {
                lexFancyListMarker(&state, indent: indentCount)
            } else {
                lexHeading(&state)
            }
        case ASCII.GT:
            lexBlockQuote(&state)
        case ASCII.DASH:
            if state.isStartOfLine && state.line == 1 && state.peekMatch(ASCII.DASH, count: 3) {
                // Check if this is YAML frontmatter at document start
                if enableYAMLFrontmatter && isYAMLFrontmatter(&state) {
                    lexYAMLFrontmatter(&state)
                } else if isHorizontalRule(&state) {
                    lexHorizontalRule(&state)
                } else {
                    lexListMarker(&state, indent: indentCount)
                }
            } else if isHorizontalRule(&state) {
                lexHorizontalRule(&state)
            } else {
                lexListMarker(&state, indent: indentCount)
            }
        case ASCII.STAR:
            if isHorizontalRule(&state) {
                lexHorizontalRule(&state)
            } else {
                lexListMarker(&state, indent: indentCount)
            }
        case ASCII.PLUS:
            lexListMarker(&state, indent: indentCount)
        case ASCII.UNDER:
            if isHorizontalRule(&state) {
                lexHorizontalRule(&state)
            } else {
                lexParagraph(&state)
            }
        case 0x30...0x39: // "0"..."9"
            lexOrderedListMarker(&state, indent: indentCount)
        case ASCII.BACKTICK:
            if isFencedCodeBlockStart(state, indent: indentCount) {
                lexCodeBlock(&state, openingIndent: min(indentCount, 3))
            } else {
                lexInline(&state)
            }
        case ASCII.TILDE:
            if isFencedCodeBlockStart(state, indent: indentCount) {
                lexCodeBlock(&state, openingIndent: min(indentCount, 3))
            } else if isDefinitionMarker(&state) {
                lexDefinitionMarker(&state)
            } else {
                lexInline(&state)
            }
        case ASCII.PIPE:
            lexTable(&state)
        case ASCII.BANG:
            if state.peekMatch(ASCII.BANG, count: 3) {
                lexAdmonition(&state)
            } else {
                lexParagraph(&state)
            }
        case ASCII.LF:
            lexNewline(&state)
        case ASCII.COLON:
            // Check for fenced div ::: (three or more colons)
            if state.peekMatch(ASCII.COLON, count: 3) {
                lexFencedDiv(&state)
            } else if isDefinitionMarker(&state) {
                lexDefinitionMarker(&state)
            } else {
                lexInline(&state)
            }
        case ASCII.LBRACKET:
            // Check for footnote definition [^ref]:
            if state.peek(at: 1) == ASCII.CARET && isFootnoteDefinition(&state) {
                lexFootnoteDefinition(&state)
            } else {
                lexParagraph(&state)
            }
        case ASCII.PERCENT:
            // Check for slide tokens
            if state.peekMatch(ASCII.PERCENT, count: 3) {
                lexSlideDelimiter(&state)
            } else if state.peek(at: 0) == ASCII.PERCENT && state.peek(at: 1) == ASCII.PERCENT {
                lexGridLayout(&state)
            } else if let nextByte = state.peek(at: 1), ASCII.isLetter(nextByte) {
                lexGridCell(&state, indent: indentCount)
            } else {
                lexParagraph(&state)
            }
        case ASCII.LBRACE:
            // Check for placeholder {? or Phase 2 directive {@ at block level
            if state.peek(at: 1) == ASCII.QUESTION {
                lexPlaceholder(&state)
            } else if state.peek(at: 1) == ASCII.AT {
                lexPhase2Directive(&state)
            } else {
                lexParagraph(&state)
            }
        case ASCII.LT:
            // Check for composition directive << at block level
            if state.peekString("<<") && state.peek(at: 2) != ASCII.LT {
                lexCompositionDirective(&state)
            } else {
                lexParagraph(&state)
            }
        default:
            // Check for fancy list markers (a., A., i., iv., I., IV.)
            if enableFancyLists && ASCII.isLetter(byte) && isFancyListMarkerStart(&state) {
                lexFancyListMarker(&state, indent: indentCount)
            } else if isDefinitionTerm(&state) {
                // Check if this could be a definition term
                lexDefinitionTerm(&state)
            } else {
                lexParagraph(&state)
            }
        }
    }

    @inline(__always)
    private func lexHeading(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        var level = 0
        while let byte = state.peek(at: 0), byte == ASCII.HASH && level < 6 {
            level += 1
            state.advance()
        }

        // Require space/tab after opening #s, except an end-of-line marker is
        // also a valid empty ATX heading.
        if let byte = state.peek(at: 0), byte == ASCII.SPACE || byte == ASCII.TAB || byte == ASCII.LF {
            if byte == ASCII.SPACE || byte == ASCII.TAB {
                state.advance()
            }

            state.addToken(
                type: .heading(level: level),
                start: start,
                content: String(repeating: "#", count: level),
                startLine: startLine,
                startColumn: startColumn
            )

            // Lex the rest of the line as inline content
            lexInline(&state)

            if state.peek(at: 0) == ASCII.LF {
                lexNewline(&state)
            }
        } else {
            // Not a valid heading, treat as text
            state.offset = start
            lexParagraph(&state)
        }
    }

    @inline(__always)
    private func lexBlockQuote(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        // Count consecutive > markers for depth tracking
        var depth = 0
        var tempOffset = state.offset

        while tempOffset < state.bytes.count && state.bytes[tempOffset] == ASCII.GT {
            depth += 1
            tempOffset += 1

            // Skip optional space after each >
            if tempOffset < state.bytes.count && state.bytes[tempOffset] == ASCII.SPACE {
                tempOffset += 1
            }
        }

        // Advance scanner to the end of all > markers and spaces
        // We need to use advance() to keep line/column tracking correct
        while state.offset < tempOffset {
            state.advance()
        }

        state.addToken(
            type: .blockQuoteMarker(depth: depth),
            start: start,
            content: String(repeating: "> ", count: depth).trimmingCharacters(in: .whitespaces),
            startLine: startLine,
            startColumn: startColumn
        )

        // Keep isStartOfLine = true to allow block elements within blockquotes
        // state.isStartOfLine = false
    }

    @inline(__always)
    private func lexListMarker(_ state: inout ByteScanner, indent: Int) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column
        let markerByte = state.peek(at: 0)!
        let marker = Character(UnicodeScalar(markerByte))

        state.advance() // consume marker

        if state.peek(at: 0) == ASCII.LF {
            state.addToken(
                type: .listMarker(type: .unordered(marker), indent: indent),
                start: start,
                content: state.substring(from: start, to: state.offset),
                startLine: startLine,
                startColumn: startColumn
            )
            state.isStartOfLine = false
            return
        }

        // Check for task list
        var isTask = false
        var isChecked = false

        if state.peek(at: 0) == ASCII.SPACE || state.peek(at: 0) == ASCII.TAB {
            let paddingStart = state.offset
            let paddingCount = countFollowingListPaddingColumns(from: paddingStart, in: state)
            let consumedPadding = paddingCount > 4 ? 1 : paddingCount
            for _ in 0..<consumedPadding {
                if state.peek(at: 0) == ASCII.TAB {
                    state.advance()
                    break
                } else {
                    state.advance()
                }
            }

            if state.peek(at: 0) == ASCII.LBRACKET {
                let savedOffset = state.offset
                state.advance() // consume [

                if let checkByte = state.peek(at: 0), (checkByte == ASCII.SPACE || checkByte == 0x78 /* x */ || checkByte == 0x58 /* X */) {
                    isChecked = checkByte != ASCII.SPACE
                    state.advance()

                    if state.peek(at: 0) == ASCII.RBRACKET {
                        state.advance() // consume ]
                        isTask = true

                        if state.peek(at: 0) == ASCII.SPACE || state.peek(at: 0) == ASCII.TAB {
                            state.advance()
                        }
                    } else {
                        // Not a valid task list, backtrack
                        state.offset = savedOffset
                    }
                } else {
                    // Not a valid task list, backtrack
                    state.offset = savedOffset
                }
            }

            let markerType: ListMarkerType = isTask ? .task(checked: isChecked) : .unordered(marker)

            state.addToken(
                type: .listMarker(type: markerType, indent: indent),
                start: start,
                content: state.substring(from: start, to: state.offset),
                startLine: startLine,
                startColumn: startColumn
            )

            state.isStartOfLine = false
        } else {
            // Not a valid list marker, could be emphasis
            state.offset = start
            lexInline(&state)
        }
    }

    @inline(__always)
    private func lexOrderedListMarker(_ state: inout ByteScanner, indent: Int) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        var number = 0
        var digitCount = 0
        while let byte = state.peek(at: 0), ASCII.isDigit(byte) {
            digitCount += 1
            number = number * 10 + Int(byte - 0x30)
            state.advance()
        }

        if digitCount <= 9,
           let delimiter = state.peek(at: 0),
           delimiter == ASCII.DOT || delimiter == ASCII.RPAREN {
            state.advance() // consume delimiter

            if state.peek(at: 0) == ASCII.SPACE || state.peek(at: 0) == ASCII.TAB || state.peek(at: 0) == ASCII.LF {
                let paddingStart = state.offset
                let paddingCount = countFollowingListPaddingColumns(from: paddingStart, in: state)
                let consumedPadding = paddingCount > 4 ? 1 : paddingCount
                for _ in 0..<consumedPadding {
                    if state.peek(at: 0) == ASCII.TAB {
                        state.advance()
                        break
                    } else if state.peek(at: 0) == ASCII.SPACE {
                        state.advance()
                    }
                }

                state.addToken(
                    type: .listMarker(type: .ordered(number), indent: indent),
                    start: start,
                    content: state.substring(from: start, to: state.offset),
                    startLine: startLine,
                    startColumn: startColumn
                )

                state.isStartOfLine = false
                return
            }
        }

        // Not a valid ordered list marker
        state.offset = start
        lexParagraph(&state)
    }

    private func countFollowingListPaddingColumns(from offset: Int, in state: ByteScanner) -> Int {
        var columns = 0
        var currentOffset = offset

        while currentOffset < state.bytes.count {
            let byte = state.bytes[currentOffset]
            if byte == ASCII.SPACE {
                columns += 1
            } else if byte == ASCII.TAB {
                columns += 4 - (columns % 4)
            } else {
                break
            }
            currentOffset += 1
        }

        return columns
    }

    // MARK: - Fancy List Markers

    /// Check if the current position starts a fancy list marker (a., A., i., I., #.)
    @inline(__always)
    private func isFancyListMarkerStart(_ state: inout ByteScanner) -> Bool {
        let saved = state.offset
        defer { state.offset = saved }

        guard let first = state.peek(at: 0) else { return false }

        // Hash auto-number: #. or #)
        if first == ASCII.HASH {
            guard let delim = state.peek(at: 1),
                  (delim == ASCII.DOT || delim == ASCII.RPAREN),
                  state.peek(at: 2) == ASCII.SPACE else { return false }
            return true
        }

        // Letters: collect all consecutive letters
        guard ASCII.isLetter(first) else { return false }
        var letterCount = 0
        var idx = state.offset
        while idx < state.bytes.count && ASCII.isLetter(state.bytes[idx]) {
            letterCount += 1
            idx += 1
            if letterCount > 10 { return false } // Roman numerals never exceed ~8 chars
        }
        guard idx < state.bytes.count else { return false }
        let delim = state.bytes[idx]
        guard delim == ASCII.DOT || delim == ASCII.RPAREN else { return false }
        let afterDelim = idx + 1
        guard afterDelim < state.bytes.count && state.bytes[afterDelim] == ASCII.SPACE else { return false }

        // Validate the letter sequence is a recognized marker
        let marker = state.substring(from: state.offset, to: idx)
        if marker.count == 1 { return true } // Single letter: always valid (alpha or single-char Roman)
        // Multi-letter: must be a valid Roman numeral
        return isValidRomanNumeral(marker)
    }

    /// Lex a fancy list marker (a., A., i., iv., #.) and emit a .listMarker token
    @inline(__always)
    private func lexFancyListMarker(_ state: inout ByteScanner, indent: Int) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        guard let first = state.peek(at: 0) else {
            lexParagraph(&state)
            return
        }

        var startValue = 1

        if first == ASCII.HASH {
            // Hash auto-number
            state.advance() // consume #
        } else {
            // Collect letter marker
            var marker = ""
            while let byte = state.peek(at: 0), ASCII.isLetter(byte) {
                marker.append(Character(UnicodeScalar(byte)))
                state.advance()
            }

            // Compute start value
            if marker.count == 1, let ch = marker.first {
                if ch >= "a" && ch <= "z" {
                    // Could be lowercase alpha or single-char lowercase Roman (i, v, x, l, c, d, m)
                    // For start value, use alpha position
                    startValue = Int(ch.asciiValue! - Character("a").asciiValue!) + 1
                    // But if it's a recognized single-char Roman, use Roman value
                    if let romanVal = romanValue(for: marker.lowercased()) {
                        // Lowercase Roman takes precedence for i, v, x, l, c, d, m
                        if "ivxlcdm".contains(ch) {
                            startValue = romanVal
                        }
                    }
                } else if ch >= "A" && ch <= "Z" {
                    startValue = Int(ch.asciiValue! - Character("A").asciiValue!) + 1
                    if let romanVal = romanValue(for: marker.lowercased()) {
                        if "IVXLCDM".contains(ch) {
                            startValue = romanVal
                        }
                    }
                }
            } else {
                // Multi-letter: must be Roman numeral
                if let romanVal = romanValue(for: marker.lowercased()) {
                    startValue = romanVal
                } else {
                    // Not a valid marker -- backtrack
                    state.offset = start
                    lexParagraph(&state)
                    return
                }
            }
        }

        // Expect delimiter (. or ))
        guard let delim = state.peek(at: 0), delim == ASCII.DOT || delim == ASCII.RPAREN else {
            state.offset = start
            lexParagraph(&state)
            return
        }
        state.advance() // consume delimiter

        // Require space after delimiter
        guard state.peek(at: 0) == ASCII.SPACE else {
            state.offset = start
            lexParagraph(&state)
            return
        }
        state.advance() // consume space

        state.addToken(
            type: .listMarker(type: .ordered(startValue), indent: indent),
            start: start,
            content: state.substring(from: start, to: state.offset),
            startLine: startLine,
            startColumn: startColumn
        )

        state.isStartOfLine = false
    }

    private func isValidRomanNumeral(_ text: String) -> Bool {
        romanValue(for: text.lowercased()) != nil
    }

    private func romanValue(for text: String) -> Int? {
        let romanPairs: [(String, Int)] = [
            ("m", 1000), ("cm", 900), ("d", 500), ("cd", 400),
            ("c", 100), ("xc", 90), ("l", 50), ("xl", 40),
            ("x", 10), ("ix", 9), ("v", 5), ("iv", 4), ("i", 1)
        ]
        var result = 0
        var remaining = text
        for (numeral, value) in romanPairs {
            while remaining.hasPrefix(numeral) {
                result += value
                remaining = String(remaining.dropFirst(numeral.count))
            }
        }
        return remaining.isEmpty && result > 0 ? result : nil
    }

    @inline(__always)
    private func isFencedCodeBlockStart(_ state: ByteScanner, indent: Int) -> Bool {
        guard indent <= 3,
              let delimiter = state.peek(at: 0),
              delimiter == ASCII.BACKTICK || delimiter == ASCII.TILDE,
              state.peekMatch(delimiter, count: 3)
        else {
            return false
        }

        var offset = state.offset
        while offset < state.bytes.count && state.bytes[offset] == delimiter {
            offset += 1
        }

        while offset < state.bytes.count && ASCII.isHorizontalWhitespace(state.bytes[offset]) {
            offset += 1
        }

        if delimiter == ASCII.BACKTICK {
            var probe = offset
            while probe < state.bytes.count && state.bytes[probe] != ASCII.LF {
                if state.bytes[probe] == ASCII.BACKTICK {
                    return false
                }
                probe += 1
            }
        }

        return true
    }

    @inline(__always)
    private func lexCodeBlock(_ state: inout ByteScanner, openingIndent: Int) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        // Consume delimiter (``` or ~~~)
        let delimiter = state.peek(at: 0)!
        var delimiterCount = 0
        while state.peek(at: 0) == delimiter {
            delimiterCount += 1
            state.advance()
        }

        // Get language identifier
        state.skipWhitespace()
        let language = state.consumeUntil(byte: ASCII.LF).trimmingCharacters(in: .whitespaces)

        let delimChar = Character(UnicodeScalar(delimiter))
        state.addToken(
            type: .codeBlockDelimiter(language: language.isEmpty ? nil : language),
            start: start,
            content: String(repeating: String(delimChar), count: delimiterCount),
            startLine: startLine,
            startColumn: startColumn
        )

        if state.peek(at: 0) == ASCII.LF {
            lexNewline(&state)
        }

        // Lex code content until closing delimiter
        let contentStart = state.offset
        let contentStartLine = state.line
        let contentStartColumn = state.column
        var content = ""
        var atContentLineStart = state.isStartOfLine

        while state.hasMore {
            if atContentLineStart {
                if let closingFence = closingFenceMatch(
                    in: state,
                    delimiter: delimiter,
                    delimiterCount: delimiterCount
                ) {
                    // Found closing delimiter
                    if !content.isEmpty {
                        state.addToken(
                            type: .codeBlockContent,
                            start: contentStart,
                            content: content,
                            startLine: contentStartLine,
                            startColumn: contentStartColumn
                        )
                    }

                    // Lex closing delimiter, including allowed indentation.
                    let closingStart = state.offset
                    let closingStartLine = state.line
                    let closingStartColumn = state.column

                    state.advance(by: closingFence.indent)
                    for _ in 0..<closingFence.delimiterLength {
                        state.advance()
                    }

                    state.addToken(
                        type: .codeBlockDelimiter(language: nil),
                        start: closingStart,
                        content: String(repeating: String(delimChar), count: closingFence.delimiterLength),
                        startLine: closingStartLine,
                        startColumn: closingStartColumn
                    )

                    // Consume rest of line
                    _ = state.consumeLine()
                    if state.peek(at: 0) == ASCII.LF {
                        lexNewline(&state)
                    }

                    return
                }

                stripOpeningFenceIndent(&state, openingIndent: openingIndent)
                atContentLineStart = false
            }

            if let byte = state.peek(at: 0) {
                if ASCII.isASCII(byte) {
                    content.append(Character(UnicodeScalar(byte)))
                } else {
                    // Multi-byte UTF-8: extract the character properly
                    let charStr = state.substring(from: state.offset, to: state.offset + 1)
                    content.append(contentsOf: charStr)
                }
            }
            let consumedNewline = state.peek(at: 0) == ASCII.LF
            state.advance()
            if consumedNewline {
                atContentLineStart = true
            }
        }

        // Unclosed code block
        if !content.isEmpty {
            state.addToken(
                type: .codeBlockContent,
                start: contentStart,
                content: content,
                startLine: contentStartLine,
                startColumn: contentStartColumn
            )
        }
    }

    @inline(__always)
    private func lexTable(_ state: inout ByteScanner) {
        // Just lex | as text - the parser handles table detection
        lexText(&state)
    }

    private func isTableDelimiterRow(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        // Table delimiter contains only -, :, |, and spaces
        let allowedChars = CharacterSet(charactersIn: "-:|").union(.whitespaces)
        return !trimmed.isEmpty && trimmed.unicodeScalars.allSatisfy { allowedChars.contains($0) }
    }

    @inline(__always)
    private func lexHorizontalRule(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        let ruleByte = state.peek(at: 0)!
        var count = 0

        while let current = state.peek(at: 0), current == ruleByte || ASCII.isWhitespace(current) {
            if current == ruleByte {
                count += 1
            }
            state.advance()

            if current == ASCII.LF {
                break
            }
        }

        state.addToken(
            type: .horizontalRule,
            start: start,
            content: state.substring(from: start, to: state.offset),
            startLine: startLine,
            startColumn: startColumn
        )
    }

    private func closingFenceMatch(
        in state: ByteScanner,
        delimiter: UInt8,
        delimiterCount: Int
    ) -> (indent: Int, delimiterLength: Int)? {
        var offset = state.offset
        var indent = 0

        while offset < state.bytes.count && state.bytes[offset] == ASCII.SPACE && indent < 4 {
            indent += 1
            offset += 1
        }

        guard indent <= 3 else {
            return nil
        }

        var count = 0
        while offset < state.bytes.count && state.bytes[offset] == delimiter {
            count += 1
            offset += 1
        }

        guard count >= delimiterCount else {
            return nil
        }

        while offset < state.bytes.count && ASCII.isHorizontalWhitespace(state.bytes[offset]) {
            offset += 1
        }

        guard offset >= state.bytes.count || state.bytes[offset] == ASCII.LF else {
            return nil
        }

        return (indent, count)
    }

    private func stripOpeningFenceIndent(
        _ state: inout ByteScanner,
        openingIndent: Int
    ) {
        guard openingIndent > 0 else {
            return
        }

        var stripped = 0
        while stripped < openingIndent, state.peek(at: 0) == ASCII.SPACE {
            state.advance()
            stripped += 1
        }
    }

    @inline(__always)
    private func lexParagraph(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        state.addToken(
            type: .paragraph,
            start: start,
            content: "",
            startLine: startLine,
            startColumn: startColumn
        )

        state.isStartOfLine = false
        lexInline(&state)
    }

    @inline(__always)
    private func lexNewline(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        state.advance() // consume \n

        state.addToken(
            type: .newline,
            start: start,
            content: "\n",
            startLine: startLine,
            startColumn: startColumn
        )
    }

    // MARK: - Inline Lexing

    @inline(__always)
    private func lexInline(_ state: inout ByteScanner) {
        guard let byte = state.peek(at: 0) else { return }

        switch byte {
        case ASCII.STAR, ASCII.UNDER:
            lexEmphasis(&state)
        case ASCII.TILDE:
            if state.peek(at: 0) == ASCII.TILDE && state.peek(at: 1) == ASCII.TILDE {
                lexStrikethrough(&state)
            } else {
                lexText(&state)
            }
        case ASCII.BACKTICK:
            lexInlineCode(&state)
        case ASCII.LBRACKET:
            if state.peek(at: 1) == ASCII.CARET {
                // Check if it's a footnote definition at start of line
                if state.isStartOfLine && isFootnoteDefinition(&state) {
                    // Let block-level handle it
                    return
                } else {
                    lexFootnoteReference(&state)
                }
            } else {
                lexLink(&state)
            }
        case ASCII.BANG:
            if state.peek(at: 1) == ASCII.LBRACKET {
                lexImage(&state)
            } else if state.peekMatch(ASCII.BANG, count: 3) {
                lexAdmonition(&state)
            } else {
                lexText(&state)
            }
        case ASCII.LT:
            if isAutolink(&state) {
                lexAutolink(&state)
            } else if isHTMLTag(&state) {
                lexHTMLTag(&state)
            } else {
                lexText(&state)
            }
        case ASCII.BACKSLASH:
            lexEscape(&state)
        case ASCII.LF:
            lexNewline(&state)
        case ASCII.SPACE:
            lexSpace(&state)
        case ASCII.DOLLAR:
            lexMath(&state)
        case ASCII.RBRACKET:
            lexLinkEnd(&state)
        case ASCII.PIPE:
            lexTable(&state)
        case ASCII.LBRACE:
            if state.peek(at: 1) == ASCII.QUESTION {
                lexPlaceholder(&state)
            } else if state.peek(at: 1) == ASCII.AT {
                lexPhase2Directive(&state)
            } else if isAttributeList(&state) {
                lexAttributeList(&state)
            } else {
                lexText(&state)
            }
        default:
            lexText(&state)
        }
    }

    @inline(__always)
    private func lexEmphasis(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column
        let markerByte = state.peek(at: 0)!

        var count = 0
        while state.peek(at: 0) == markerByte {
            count += 1
            state.advance()
        }

        let markerChar = Character(UnicodeScalar(markerByte))
        state.addToken(
            type: .emphasis(level: count),
            start: start,
            content: String(repeating: String(markerChar), count: count),
            startLine: startLine,
            startColumn: startColumn
        )
    }

    @inline(__always)
    private func lexStrikethrough(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        state.advance() // consume first ~
        state.advance() // consume second ~

        state.addToken(
            type: .strikethrough,
            start: start,
            content: "~~",
            startLine: startLine,
            startColumn: startColumn
        )
    }

    @inline(__always)
    private func lexInlineCode(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        var backtickCount = 0
        while state.peek(at: 0) == ASCII.BACKTICK {
            backtickCount += 1
            state.advance()
        }

        state.addToken(
            type: .code,
            start: start,
            content: String(repeating: "`", count: backtickCount),
            startLine: startLine,
            startColumn: startColumn
        )
    }

    @inline(__always)
    private func lexLink(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        state.advance() // consume [

        state.addToken(
            type: .linkStart,
            start: start,
            content: "[",
            startLine: startLine,
            startColumn: startColumn
        )
    }

    @inline(__always)
    private func lexImage(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        state.advance() // consume !
        state.advance() // consume [

        state.addToken(
            type: .imageStart,
            start: start,
            content: "![",
            startLine: startLine,
            startColumn: startColumn
        )
    }

    @inline(__always)
    private func lexLinkEnd(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        state.advance() // consume ]

        state.addToken(
            type: .linkEnd,
            start: start,
            content: "]",
            startLine: startLine,
            startColumn: startColumn
        )
    }

    @inline(__always)
    private func lexAutolink(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        state.advance() // consume <
        let content = state.consumeUntil(byte: ASCII.GT)
        if state.peek(at: 0) == ASCII.GT {
            state.advance() // consume >
        }

        state.addToken(
            type: .autolink,
            start: start,
            content: "<\(content)>",
            startLine: startLine,
            startColumn: startColumn
        )
    }

    @inline(__always)
    private func lexHTMLTag(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        let content = consumeHTMLTag(&state)

        state.addToken(
            type: .htmlTag,
            start: start,
            content: content,
            startLine: startLine,
            startColumn: startColumn
        )
    }

    @inline(__always)
    private func lexEscape(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        state.advance() // consume backslash
        if state.peek(at: 0) != nil {
            state.advanceScalar() // consume escaped character
        }

        state.addToken(
            type: .escape,
            start: start,
            content: state.substring(from: start, to: state.offset),
            startLine: startLine,
            startColumn: startColumn
        )
    }

    @inline(__always)
    private func lexSpace(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        var count = 0
        while state.peek(at: 0) == ASCII.SPACE {
            count += 1
            state.advance()
        }

        state.addToken(
            type: .space(count: count),
            start: start,
            content: String(repeating: " ", count: count),
            startLine: startLine,
            startColumn: startColumn
        )
    }

    @inline(__always)
    private func lexText(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        let content = state.consumeUntil { byte in
            switch byte {
            case ASCII.STAR, ASCII.UNDER, ASCII.TILDE, ASCII.BACKTICK, ASCII.LBRACKET, ASCII.RBRACKET, ASCII.BANG, ASCII.LT, ASCII.BACKSLASH, ASCII.LF, ASCII.SPACE, ASCII.DOLLAR, ASCII.PIPE, ASCII.LBRACE:
                return true
            default:
                return false
            }
        }

        if !content.isEmpty {
            state.addToken(
                type: .text(content),
                start: start,
                content: content,
                startLine: startLine,
                startColumn: startColumn
            )
        } else if state.offset == start {
            // No content consumed, but we need to advance to avoid infinite loop
            // This happens when we encounter a character that's not in our stop list
            if state.peek(at: 0) != nil {
                let charContent = state.substring(from: state.offset, to: state.offset + 1)
                let charStart = state.offset
                state.advance()
                state.addToken(
                    type: .text(charContent),
                    start: charStart,
                    content: charContent,
                    startLine: startLine,
                    startColumn: startColumn
                )
            }
        }
    }

    @inline(__always)
    private func lexDefinitionTerm(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        // Collect the term content until newline
        let termContent = state.consumeLine()

        state.addToken(
            type: .definitionTerm,
            start: start,
            content: termContent,
            startLine: startLine,
            startColumn: startColumn
        )

        state.isStartOfLine = true
    }

    @inline(__always)
    private func lexDefinitionMarker(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column
        let markerByte = state.peek(at: 0)! // : or ~

        state.advance() // consume marker

        // Skip optional space after marker
        if state.peek(at: 0) == ASCII.SPACE {
            state.advance()
        }

        state.addToken(
            type: .definitionMarker,
            start: start,
            content: String(Character(UnicodeScalar(markerByte))),
            startLine: startLine,
            startColumn: startColumn
        )

        state.isStartOfLine = false
    }

    @inline(__always)
    private func isDefinitionTerm(_ state: inout ByteScanner) -> Bool {
        // A definition term is a non-empty line followed by a definition marker
        guard state.isStartOfLine else { return false }

        // Don't detect definition terms inside admonitions
        guard !state.insideAdmonition else { return false }

        // Look ahead to see if next line starts with : or ~
        var tempOffset = state.offset

        // Skip to end of current line
        while tempOffset < state.bytes.count && state.bytes[tempOffset] != ASCII.LF {
            tempOffset += 1
        }

        // Skip newline
        if tempOffset < state.bytes.count && state.bytes[tempOffset] == ASCII.LF {
            tempOffset += 1
        }

        // Check if next line starts with : or ~ (with optional indentation)
        while tempOffset < state.bytes.count && state.bytes[tempOffset] == ASCII.SPACE {
            tempOffset += 1
        }

        if tempOffset < state.bytes.count {
            let nextByte = state.bytes[tempOffset]
            return nextByte == ASCII.COLON || nextByte == ASCII.TILDE
        }

        return false
    }

    @inline(__always)
    private func isDefinitionMarker(_ state: inout ByteScanner) -> Bool {
        // Check if we're at start of line with : or ~ followed by space
        guard state.isStartOfLine else { return false }
        guard let byte = state.peek(at: 0), (byte == ASCII.COLON || byte == ASCII.TILDE) else { return false }

        // Must be followed by space or end of line
        if let next = state.peek(at: 1) {
            return next == ASCII.SPACE || next == ASCII.LF
        }

        return true
    }

    @inline(__always)
    private func lexFootnoteReference(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        state.advance() // consume [
        state.advance() // consume ^

        // Collect the reference ID
        var refId = ""
        while let byte = state.peek(at: 0), byte != ASCII.RBRACKET {
            if ASCII.isASCII(byte) {
                refId.append(Character(UnicodeScalar(byte)))
            } else {
                refId.append(contentsOf: state.substring(from: state.offset, to: state.offset + 1))
            }
            state.advance()
        }

        if state.peek(at: 0) == ASCII.RBRACKET {
            state.advance() // consume ]
        }

        state.addToken(
            type: .footnoteReference,
            start: start,
            content: refId,
            startLine: startLine,
            startColumn: startColumn
        )
    }

    @inline(__always)
    private func lexFootnoteDefinition(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        state.advance() // consume [
        state.advance() // consume ^

        // Collect the reference ID
        var refId = ""
        while let byte = state.peek(at: 0), byte != ASCII.RBRACKET {
            if ASCII.isASCII(byte) {
                refId.append(Character(UnicodeScalar(byte)))
            } else {
                refId.append(contentsOf: state.substring(from: state.offset, to: state.offset + 1))
            }
            state.advance()
        }

        if state.peek(at: 0) == ASCII.RBRACKET {
            state.advance() // consume ]
        }

        // Consume the colon
        if state.peek(at: 0) == ASCII.COLON {
            state.advance()
        }

        // Skip optional space
        if state.peek(at: 0) == ASCII.SPACE {
            state.advance()
        }

        state.addToken(
            type: .footnoteDefinition,
            start: start,
            content: refId,
            startLine: startLine,
            startColumn: startColumn
        )

        state.isStartOfLine = false
    }

    @inline(__always)
    private func isFootnoteDefinition(_ state: inout ByteScanner) -> Bool {
        // Must be at start of line with [^ref]:
        guard state.isStartOfLine else { return false }
        guard state.peek(at: 0) == ASCII.LBRACKET && state.peek(at: 1) == ASCII.CARET else { return false }

        // Look for closing ]:
        var tempOffset = state.offset + 2

        while tempOffset < state.bytes.count {
            let byte = state.bytes[tempOffset]
            if byte == ASCII.RBRACKET {
                let nextOffset = tempOffset + 1
                if nextOffset < state.bytes.count && state.bytes[nextOffset] == ASCII.COLON {
                    return true
                }
                return false
            }
            if byte == ASCII.LF {
                return false
            }
            tempOffset += 1
        }

        return false
    }

    @inline(__always)
    private func lexMath(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column
        let startIsStartOfLine = state.isStartOfLine

        // Check for display math $$
        if state.peek(at: 1) == ASCII.DOLLAR {
            state.advance() // consume first $
            state.advance() // consume second $

            // Collect content until closing $$
            var mathContent = ""
            while state.hasMore {
                if state.peek(at: 0) == ASCII.DOLLAR && state.peek(at: 1) == ASCII.DOLLAR {
                    // Found closing $$
                    state.advance() // consume first $
                    state.advance() // consume second $

                    state.addToken(
                        type: .mathDisplay,
                        start: start,
                        content: mathContent,
                        startLine: startLine,
                        startColumn: startColumn
                    )
                    return
                }

                if let byte = state.peek(at: 0) {
                    if ASCII.isASCII(byte) {
                        mathContent.append(Character(UnicodeScalar(byte)))
                    } else {
                        mathContent.append(contentsOf: state.substring(from: state.offset, to: state.offset + 1))
                    }
                    state.advance()
                } else {
                    break
                }
            }

            // Unclosed display math, treat as text
            state.offset = start
            state.line = startLine
            state.column = startColumn
            state.isStartOfLine = startIsStartOfLine
            lexText(&state)
        } else {
            // Inline math $
            state.advance() // consume $

            // Collect content until closing $
            var mathContent = ""
            while state.hasMore {
                if state.peek(at: 0) == ASCII.DOLLAR {
                    // Found closing $
                    state.advance() // consume $

                    state.addToken(
                        type: .mathInline,
                        start: start,
                        content: mathContent,
                        startLine: startLine,
                        startColumn: startColumn
                    )
                    return
                }

                if let byte = state.peek(at: 0) {
                    if ASCII.isASCII(byte) {
                        mathContent.append(Character(UnicodeScalar(byte)))
                    } else {
                        mathContent.append(contentsOf: state.substring(from: state.offset, to: state.offset + 1))
                    }
                    state.advance()
                } else {
                    break
                }
            }

            // Unclosed inline math, treat as text
            state.offset = start
            state.line = startLine
            state.column = startColumn
            state.isStartOfLine = startIsStartOfLine
            lexText(&state)
        }
    }

    @inline(__always)
    private func lexYAMLFrontmatter(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        // Consume opening ---
        state.advance() // -
        state.advance() // -
        state.advance() // -

        state.addToken(
            type: .yamlFrontmatterStart,
            start: start,
            content: "---",
            startLine: startLine,
            startColumn: startColumn
        )

        // Consume newline after opening ---
        if state.peek(at: 0) == ASCII.LF {
            lexNewline(&state)
        }

        // Collect YAML content until closing --- or ...
        var yamlContent = ""
        let contentStart = state.offset

        while state.hasMore {
            if state.isStartOfLine {
                // Check for closing markers
                if state.peekMatch(ASCII.DASH, count: 3) || state.peekString("...") {
                    // Found closing marker
                    let closingStart = state.offset
                    let closingStartLine = state.line
                    let closingStartColumn = state.column

                    let closingContent = state.substring(from: state.offset, to: state.offset + 3)
                    state.advance() // first character
                    state.advance() // second character
                    state.advance() // third character

                    state.addToken(
                        type: .yamlFrontmatterEnd,
                        start: closingStart,
                        content: closingContent,
                        startLine: closingStartLine,
                        startColumn: closingStartColumn
                    )

                    // Consume rest of line
                    _ = state.consumeLine()

                    // Add YAML content token if we have any
                    if !yamlContent.isEmpty {
                        let contentStartIdx = state.source.utf8.index(state.source.utf8.startIndex, offsetBy: contentStart)
                        let closingStartIdx = state.source.utf8.index(state.source.utf8.startIndex, offsetBy: closingStart)
                        state.tokens.insert(Token(
                            type: .yamlFrontmatterContent(yamlContent),
                            range: contentStartIdx..<closingStartIdx,
                            content: yamlContent,
                            line: 2, // starts after opening ---
                            column: 1
                        ), at: state.tokens.count - 1) // insert before closing token
                    }

                    return
                }
            }

            // Collect character by character to avoid infinite loops
            if let byte = state.peek(at: 0) {
                if ASCII.isASCII(byte) {
                    yamlContent.append(Character(UnicodeScalar(byte)))
                } else {
                    yamlContent.append(contentsOf: state.substring(from: state.offset, to: state.offset + 1))
                }
                state.advance()
            } else {
                break
            }
        }

        // Unclosed YAML frontmatter (missing closing ---)
        if !yamlContent.isEmpty {
            let contentStartIdx = state.source.utf8.index(state.source.utf8.startIndex, offsetBy: contentStart)
            let currentIdx = state.source.utf8.index(state.source.utf8.startIndex, offsetBy: state.offset)
            state.tokens.append(Token(
                type: .yamlFrontmatterContent(yamlContent),
                range: contentStartIdx..<currentIdx,
                content: yamlContent,
                line: 2,
                column: 1
            ))
        }
    }

    @inline(__always)
    private func isYAMLFrontmatter(_ state: inout ByteScanner) -> Bool {
        // Must be at the very start of the document
        guard state.line == 1 && state.isStartOfLine else { return false }

        // Must start with exactly ---
        guard state.peekMatch(ASCII.DASH, count: 3) else { return false }

        // Look ahead to see if there's a matching closing --- or ...
        var tempOffset = state.offset

        // Skip opening ---
        tempOffset += 3

        // Skip to next line
        while tempOffset < state.bytes.count && state.bytes[tempOffset] != ASCII.LF {
            tempOffset += 1
        }
        if tempOffset < state.bytes.count {
            tempOffset += 1 // skip \n
        }

        // Look for closing --- or ... on its own line
        var currentLineStart = tempOffset
        while tempOffset < state.bytes.count {
            if state.bytes[tempOffset] == ASCII.LF {
                let line = state.substring(from: currentLineStart, to: tempOffset).trimmingCharacters(in: .whitespaces)
                if line == "---" || line == "..." {
                    return true
                }
                tempOffset += 1
                currentLineStart = tempOffset
            } else {
                tempOffset += 1
            }
        }

        return false
    }

    // MARK: - Helper Methods

    @inline(__always)
    private func isHorizontalRule(_ state: inout ByteScanner) -> Bool {
        let ruleByte = state.peek(at: 0)!
        guard ruleByte == ASCII.DASH || ruleByte == ASCII.STAR || ruleByte == ASCII.UNDER else {
            return false
        }

        var tempOffset = state.offset
        var count = 0

        while tempOffset < state.bytes.count {
            let current = state.bytes[tempOffset]
            if current == ruleByte {
                count += 1
            } else if current == ASCII.LF {
                break
            } else if !ASCII.isWhitespace(current) {
                return false
            }
            tempOffset += 1
        }

        return count >= 3
    }

    @inline(__always)
    private func isAutolink(_ state: inout ByteScanner) -> Bool {
        var tempOffset = state.offset
        tempOffset += 1 // skip <

        var content = ""

        while tempOffset < state.bytes.count && state.bytes[tempOffset] != ASCII.GT {
            let byte = state.bytes[tempOffset]
            if ASCII.isASCII(byte) {
                content.append(Character(UnicodeScalar(byte)))
            }
            tempOffset += 1
        }

        guard tempOffset < state.bytes.count && state.bytes[tempOffset] == ASCII.GT,
              !content.contains(where: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" })
        else {
            return false
        }

        return isCommonMarkSchemeAutolink(content) || isCommonMarkEmailAutolink(content)
    }

    private func isCommonMarkSchemeAutolink(_ content: String) -> Bool {
        guard let colon = content.firstIndex(of: ":") else {
            return false
        }

        let scheme = content[..<colon]
        guard scheme.count >= 2, scheme.count <= 32,
              let first = scheme.first,
              first.isASCIIAlpha
        else {
            return false
        }

        return scheme.dropFirst().allSatisfy { character in
            character.isASCIIAlpha || character.isASCIIDigit ||
                character == "+" || character == "." || character == "-"
        }
    }

    private func isCommonMarkEmailAutolink(_ content: String) -> Bool {
        guard content.filter({ $0 == "@" }).count == 1,
              let at = content.firstIndex(of: "@")
        else {
            return false
        }

        let local = content[..<at]
        let domain = content[content.index(after: at)...]
        guard !local.isEmpty, !domain.isEmpty,
              local.allSatisfy({ $0.isCommonMarkEmailLocalCharacter })
        else {
            return false
        }

        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else {
            return false
        }

        return labels.allSatisfy { label in
            guard let first = label.first,
                  let last = label.last,
                  first.isASCIIAlphanumeric,
                  last.isASCIIAlphanumeric
            else {
                return false
            }

            return label.allSatisfy { $0.isASCIIAlphanumeric || $0 == "-" }
        }
    }

    @inline(__always)
    private func isHTMLTag(_ state: inout ByteScanner) -> Bool {
        guard state.peek(at: 0) == ASCII.LT else { return false }

        if let next = state.peek(at: 1) {
            // Check for valid tag start
            return ASCII.isLetter(next) || next == ASCII.SLASH || next == ASCII.BANG || next == ASCII.QUESTION
        }

        return false
    }

    @inline(__always)
    private func consumeHTMLTag(_ state: inout ByteScanner) -> String {
        let start = state.offset

        if state.peekString("<!--") {
            consumeHTMLSpecialSequence("-->", in: &state)
            return state.substring(from: start, to: state.offset)
        }

        if state.peekString("<?") {
            consumeHTMLSpecialSequence("?>", in: &state)
            return state.substring(from: start, to: state.offset)
        }

        if state.peekString("<![CDATA[") {
            consumeHTMLSpecialSequence("]]>", in: &state)
            return state.substring(from: start, to: state.offset)
        }

        if state.peekString("<!"), let marker = state.peek(at: 2), ASCII.isLetter(marker) {
            consumeHTMLDeclaration(in: &state)
            return state.substring(from: start, to: state.offset)
        }

        var depth = 0
        var inQuote = false
        var quoteByte: UInt8 = 0

        while let byte = state.peek(at: 0) {
            if byte == ASCII.LF, nextLineIsSetextUnderline(after: state.offset, in: state) {
                break
            }

            if !inQuote {
                if byte == ASCII.LT {
                    depth += 1
                } else if byte == ASCII.GT {
                    state.advance()
                    depth -= 1
                    if depth == 0 {
                        break
                    }
                } else if byte == ASCII.DQUOTE || byte == ASCII.SQUOTE {
                    inQuote = true
                    quoteByte = byte
                }
            } else if byte == quoteByte {
                inQuote = false
                quoteByte = 0
            }

            state.advance()
        }

        return state.substring(from: start, to: state.offset)
    }

    @inline(__always)
    private func consumeHTMLSpecialSequence(_ sequence: String, in state: inout ByteScanner) {
        let bytes = Array(sequence.utf8)
        while state.hasMore {
            if htmlSequence(bytes, matchesAt: state.offset, in: state) {
                state.advance(by: bytes.count)
                return
            }
            state.advance()
        }
    }

    @inline(__always)
    private func consumeHTMLDeclaration(in state: inout ByteScanner) {
        while let byte = state.peek(at: 0) {
            state.advance()
            if byte == ASCII.GT {
                return
            }
        }
    }

    @inline(__always)
    private func htmlSequence(_ sequence: [UInt8], matchesAt offset: Int, in state: ByteScanner) -> Bool {
        guard offset + sequence.count <= state.bytes.count else { return false }
        for index in sequence.indices {
            if state.bytes[offset + index] != sequence[index] {
                return false
            }
        }
        return true
    }

    @inline(__always)
    private func nextLineIsSetextUnderline(after offset: Int, in state: ByteScanner) -> Bool {
        var probe = offset + 1
        var indent = 0

        while probe < state.bytes.count {
            let byte = state.bytes[probe]
            if byte == ASCII.SPACE {
                indent += 1
                guard indent < 4 else { return false }
                probe += 1
            } else if byte == ASCII.TAB {
                indent += 4
                guard indent < 4 else { return false }
                probe += 1
            } else {
                break
            }
        }

        guard probe < state.bytes.count,
              state.bytes[probe] == ASCII.DASH || state.bytes[probe] == ASCII.EQ
        else {
            return false
        }

        let marker = state.bytes[probe]
        var markerCount = 0
        while probe < state.bytes.count, state.bytes[probe] == marker {
            markerCount += 1
            probe += 1
        }

        guard markerCount > 0 else { return false }

        while probe < state.bytes.count,
              state.bytes[probe] == ASCII.SPACE || state.bytes[probe] == ASCII.TAB {
            probe += 1
        }

        return probe >= state.bytes.count || state.bytes[probe] == ASCII.LF
    }

    // MARK: - Attributes

    @inline(__always)
    private func isAttributeList(_ state: inout ByteScanner) -> Bool {
        // Check if this looks like an attribute list {#id .class key=value}
        guard state.peek(at: 0) == ASCII.LBRACE else { return false }

        var tempOffset = state.offset + 1
        var depth = 1

        // Scan for closing } with proper nesting
        while tempOffset < state.bytes.count && depth > 0 {
            let byte = state.bytes[tempOffset]
            if byte == ASCII.LBRACE {
                depth += 1
            } else if byte == ASCII.RBRACE {
                depth -= 1
            } else if byte == ASCII.LF {
                // Attributes can't span multiple lines
                return false
            }
            tempOffset += 1
        }

        return depth == 0
    }

    @inline(__always)
    private func lexAttributeList(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        state.advance() // consume {

        var content = ""
        var depth = 1

        while let byte = state.peek(at: 0), depth > 0 {
            if byte == ASCII.LBRACE {
                depth += 1
            } else if byte == ASCII.RBRACE {
                depth -= 1
                if depth == 0 {
                    state.advance() // consume closing }
                    break
                }
            }
            if ASCII.isASCII(byte) {
                content.append(Character(UnicodeScalar(byte)))
            } else {
                content.append(contentsOf: state.substring(from: state.offset, to: state.offset + 1))
            }
            state.advance()
        }

        state.addToken(
            type: .attributeList(content),
            start: start,
            content: "{\(content)}",
            startLine: startLine,
            startColumn: startColumn
        )
    }

    // MARK: - Admonitions

    @inline(__always)
    private func lexAdmonition(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        // Consume !!!
        state.advance(by: 3)

        // Check for collapsible modifier (? or ?+)
        var collapsible: AdmonitionCollapsible? = nil
        if state.peek(at: 0) == ASCII.QUESTION {
            state.advance() // consume ?
            if state.peek(at: 0) == ASCII.PLUS {
                collapsible = .expanded
                state.advance() // consume +
            } else {
                collapsible = .collapsed
            }
        }

        // Skip whitespace
        state.skipWhitespace()

        // Extract type and optional title
        var type = ""
        var title: String? = nil

        // Read the type
        while let byte = state.peek(at: 0), !ASCII.isWhitespace(byte) && byte != ASCII.LF && byte != ASCII.DQUOTE {
            if ASCII.isASCII(byte) {
                type.append(Character(UnicodeScalar(byte)))
            } else {
                type.append(contentsOf: state.substring(from: state.offset, to: state.offset + 1))
            }
            state.advance()
        }

        // Skip whitespace
        state.skipWhitespace()

        // Check for optional title in quotes
        if state.peek(at: 0) == ASCII.DQUOTE {
            state.advance() // consume opening quote
            var titleText = ""
            while let byte = state.peek(at: 0), byte != ASCII.DQUOTE && byte != ASCII.LF {
                if ASCII.isASCII(byte) {
                    titleText.append(Character(UnicodeScalar(byte)))
                } else {
                    titleText.append(contentsOf: state.substring(from: state.offset, to: state.offset + 1))
                }
                state.advance()
            }
            if state.peek(at: 0) == ASCII.DQUOTE {
                state.advance() // consume closing quote
                title = titleText
            }
        }

        // Skip whitespace before potential attribute block
        state.skipWhitespace()

        // Detect and emit inline attribute block {name=value ...} on admonition line.
        var inlineAttrContent: String? = nil
        if state.peek(at: 0) == ASCII.LBRACE {
            let attrStart = state.offset
            var depth = 0
            while let byte = state.peek(at: 0), byte != ASCII.LF {
                if byte == ASCII.LBRACE { depth += 1 }
                if byte == ASCII.RBRACE { depth -= 1; if depth == 0 { state.advance(); break } }
                state.advance()
            }
            inlineAttrContent = state.substring(from: attrStart, to: state.offset)
        }

        // Skip to end of line
        while let byte = state.peek(at: 0), byte != ASCII.LF {
            state.advance()
        }

        // Check if this is an ending marker (empty type)
        if type.isEmpty {
            state.addToken(
                type: .admonitionEnd,
                start: start,
                content: "!!!",
                startLine: startLine,
                startColumn: startColumn
            )
            state.insideAdmonition = false  // Exit admonition
        } else {
            state.addToken(
                type: .admonitionStart(type: type, title: title, collapsible: collapsible),
                start: start,
                content: "!!! \(type)\(title.map { " \"\($0)\"" } ?? "")",
                startLine: startLine,
                startColumn: startColumn
            )
            // Emit inline attribute block as separate token if present.
            if let attrContent = inlineAttrContent, !attrContent.isEmpty {
                let stripped = attrContent.hasPrefix("{") && attrContent.hasSuffix("}")
                    ? String(attrContent.dropFirst().dropLast())
                    : attrContent
                let startIdx = state.source.utf8.index(state.source.utf8.startIndex, offsetBy: start)
                let endIdx = state.source.utf8.index(state.source.utf8.startIndex, offsetBy: state.offset)
                state.tokens.append(Token(
                    type: .attributeList(stripped),
                    range: startIdx..<endIdx,
                    content: attrContent,
                    line: startLine,
                    column: startColumn
                ))
            }
            state.insideAdmonition = true  // Enter admonition
        }
    }

    // MARK: - Composition Directive Lexing

    /// Lex composition directives `<<keyword ...>>` and `<</keyword>>`.
    ///
    /// Opening: `<<keyword argument>>` or `<<keyword {attributes}>>`
    /// Closing: `<</keyword>>`
    /// Self-contained: `<<include "path">>`, `<<param name>>`, `<<slot>>`, `<<todo "text">>`
    @inline(__always)
    private func lexCompositionDirective(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        // Consume <<
        state.advance(by: 2)

        // Check for expression form: <<= expr >>
        if state.peek(at: 0) == ASCII.EQ {
            state.advance() // consume =
            // Skip whitespace
            while let byte = state.peek(at: 0), byte == ASCII.SPACE || byte == ASCII.TAB { state.advance() }
            // Collect expression until >>
            var expr = ""
            while let byte = state.peek(at: 0) {
                if byte == ASCII.GT && state.peek(at: 1) == ASCII.GT { break }
                if byte == ASCII.LF { break }
                if ASCII.isASCII(byte) {
                    expr.append(Character(UnicodeScalar(byte)))
                } else {
                    expr.append(contentsOf: state.substring(from: state.offset, to: state.offset + 1))
                }
                state.advance()
            }
            if state.peekString(">>") { state.advance(by: 2) }
            state.addToken(
                type: .compositionDirectiveOpen(keyword: "=", argument: expr.trimmingCharacters(in: .whitespaces)),
                start: start,
                content: "<<= \(expr.trimmingCharacters(in: .whitespaces)) >>",
                startLine: startLine,
                startColumn: startColumn
            )
            return
        }

        // Check for closing form: <</keyword>>
        if state.peek(at: 0) == ASCII.SLASH {
            state.advance() // consume /
            // Read keyword
            var keyword = ""
            while let byte = state.peek(at: 0), ASCII.isLetter(byte) || byte == ASCII.DASH || byte == ASCII.UNDER {
                keyword.append(Character(UnicodeScalar(byte)))
                state.advance()
            }
            // Expect >>
            if state.peekString(">>") {
                state.advance(by: 2)
            }
            // Skip to end of line
            while let byte = state.peek(at: 0), byte != ASCII.LF {
                state.advance()
            }
            state.addToken(
                type: .compositionDirectiveClose(keyword: keyword.lowercased()),
                start: start,
                content: "<</\(keyword)>>",
                startLine: startLine,
                startColumn: startColumn
            )
            return
        }

        // Opening form: extract keyword
        var keyword = ""
        while let byte = state.peek(at: 0), ASCII.isLetter(byte) || byte == ASCII.DASH || byte == ASCII.UNDER {
            keyword.append(Character(UnicodeScalar(byte)))
            state.advance()
        }

        guard !keyword.isEmpty else {
            // Not a valid directive -- fall back to paragraph
            state.offset = start
            state.line = startLine
            state.column = startColumn
            lexParagraph(&state)
            return
        }

        // Skip whitespace
        while let byte = state.peek(at: 0), byte == ASCII.SPACE || byte == ASCII.TAB {
            state.advance()
        }

        // Extract optional argument (quoted string or bare identifier)
        var argument: String? = nil
        if state.peek(at: 0) == ASCII.DQUOTE {
            state.advance() // consume opening quote
            var text = ""
            while let byte = state.peek(at: 0), byte != ASCII.DQUOTE && byte != ASCII.LF {
                if ASCII.isASCII(byte) {
                    text.append(Character(UnicodeScalar(byte)))
                } else {
                    text.append(contentsOf: state.substring(from: state.offset, to: state.offset + 1))
                }
                state.advance()
            }
            if state.peek(at: 0) == ASCII.DQUOTE {
                state.advance() // consume closing quote
            }
            argument = text
        } else if let byte = state.peek(at: 0), byte != ASCII.GT && byte != ASCII.LF && byte != ASCII.LBRACE {
            var text = ""
            while let byte = state.peek(at: 0), byte != ASCII.GT && byte != ASCII.LF && byte != ASCII.SPACE && byte != ASCII.LBRACE {
                if ASCII.isASCII(byte) {
                    text.append(Character(UnicodeScalar(byte)))
                } else {
                    text.append(contentsOf: state.substring(from: state.offset, to: state.offset + 1))
                }
                state.advance()
            }
            if !text.isEmpty {
                argument = text
            }
        }

        // Skip optional whitespace + attribute block
        while let byte = state.peek(at: 0), byte == ASCII.SPACE || byte == ASCII.TAB {
            state.advance()
        }
        // Skip {attributes} if present (will be parsed separately)
        if state.peek(at: 0) == ASCII.LBRACE {
            while let byte = state.peek(at: 0), byte != ASCII.RBRACE && byte != ASCII.LF {
                state.advance()
            }
            if state.peek(at: 0) == ASCII.RBRACE {
                state.advance()
            }
        }

        // Expect >> to close the opening directive
        if state.peekString(">>") {
            state.advance(by: 2)
        }

        // Skip to end of line
        while let byte = state.peek(at: 0), byte != ASCII.LF {
            state.advance()
        }

        state.addToken(
            type: .compositionDirectiveOpen(keyword: keyword.lowercased(), argument: argument),
            start: start,
            content: "<<\(keyword)\(argument.map { " \($0)" } ?? "")>>",
            startLine: startLine,
            startColumn: startColumn
        )
    }

    // MARK: - Phase 2 Directive Lexing

    /// Lex Phase 2 directives `{@ command args @}` and block form `{@ endcommand @}`.
    @inline(__always)
    private func lexPhase2Directive(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        // Consume {@
        state.advance(by: 2)

        // Skip whitespace
        while let byte = state.peek(at: 0), byte == ASCII.SPACE || byte == ASCII.TAB {
            state.advance()
        }

        // Read command name
        var command = ""
        while let byte = state.peek(at: 0), ASCII.isLetter(byte) || byte == ASCII.DASH || byte == ASCII.UNDER {
            command.append(Character(UnicodeScalar(byte)))
            state.advance()
        }

        // Check for close form: {@ endcommand @}
        let isClose = command.hasPrefix("end") && command.count > 3
        let actualCommand = isClose ? String(command.dropFirst(3)) : command

        // Read arguments (everything until @})
        var arguments: String? = nil
        if !isClose {
            // Skip whitespace before arguments
            while let byte = state.peek(at: 0), byte == ASCII.SPACE || byte == ASCII.TAB {
                state.advance()
            }

            // Collect arguments until @}
            var argBuffer = ""
            while let byte = state.peek(at: 0) {
                if byte == ASCII.AT && state.peek(at: 1) == ASCII.RBRACE {
                    break
                }
                if byte == ASCII.LF { break } // Inline form ends at newline
                if ASCII.isASCII(byte) {
                    argBuffer.append(Character(UnicodeScalar(byte)))
                } else {
                    argBuffer.append(contentsOf: state.substring(from: state.offset, to: state.offset + 1))
                }
                state.advance()
            }

            let trimmed = argBuffer.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { arguments = trimmed }
        }

        // Consume @} if present
        if state.peek(at: 0) == ASCII.AT && state.peek(at: 1) == ASCII.RBRACE {
            state.advance(by: 2)
        }

        if isClose {
            state.addToken(
                type: .phase2DirectiveClose(command: actualCommand.lowercased()),
                start: start,
                content: "{@ end\(actualCommand) @}",
                startLine: startLine,
                startColumn: startColumn
            )
        } else {
            state.addToken(
                type: .phase2DirectiveOpen(command: command.lowercased(), arguments: arguments),
                start: start,
                content: "{@ \(command)\(arguments.map { " \($0)" } ?? "") @}",
                startLine: startLine,
                startColumn: startColumn
            )
        }
    }

    // MARK: - Placeholder Lexing

    /// Lex parser-native placeholders `{? fields ?}`.
    @inline(__always)
    private func lexPlaceholder(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        // Consume {?
        state.advance(by: 2)

        // Skip whitespace
        while let byte = state.peek(at: 0), byte == ASCII.SPACE || byte == ASCII.TAB {
            state.advance()
        }

        // Collect content until ?}
        var fields = ""
        while let byte = state.peek(at: 0) {
            if byte == ASCII.QUESTION && state.peek(at: 1) == ASCII.RBRACE {
                break
            }
            if byte == ASCII.LF { break }
            if ASCII.isASCII(byte) {
                fields.append(Character(UnicodeScalar(byte)))
            } else {
                fields.append(contentsOf: state.substring(from: state.offset, to: state.offset + 1))
            }
            state.advance()
        }

        // Consume ?} if present
        if state.peek(at: 0) == ASCII.QUESTION && state.peek(at: 1) == ASCII.RBRACE {
            state.advance(by: 2)
        }

        let trimmed = fields.trimmingCharacters(in: .whitespaces)

        state.addToken(
            type: .placeholderToken(fields: trimmed),
            start: start,
            content: "{? \(trimmed) ?}",
            startLine: startLine,
            startColumn: startColumn
        )
    }

    // MARK: - Fenced Div Lexing

    /// Lex fenced div `:::` delimiters.
    ///
    /// Opening: `:::` + optional name or attribute list.
    /// Closing: `:::` alone on a line.
    /// The closing fence must have at least as many colons as the opening fence.
    @inline(__always)
    private func lexFencedDiv(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        // Count colons
        var colonCount = 0
        while state.peek(at: 0) == ASCII.COLON {
            colonCount += 1
            state.advance()
        }

        // Skip optional whitespace after colons
        while let byte = state.peek(at: 0), byte == ASCII.SPACE || byte == ASCII.TAB {
            state.advance()
        }

        // Read the rest of the line to determine if this is opening or closing
        var restOfLine = ""
        while let byte = state.peek(at: 0), byte != ASCII.LF {
            if ASCII.isASCII(byte) {
                restOfLine.append(Character(UnicodeScalar(byte)))
            } else {
                restOfLine.append(contentsOf: state.substring(from: state.offset, to: state.offset + 1))
            }
            state.advance()
        }

        let trimmed = restOfLine.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            // Closing fence (bare colons, nothing after)
            state.addToken(
                type: .fencedDivEnd(colons: colonCount),
                start: start,
                content: String(repeating: ":", count: colonCount),
                startLine: startLine,
                startColumn: startColumn
            )
        } else {
            // Opening fence with name and/or attributes
            // Extract name: first word (before any {)
            var name: String? = nil
            let scanner = trimmed
            if let braceIndex = scanner.firstIndex(of: "{") {
                let beforeBrace = scanner[scanner.startIndex..<braceIndex]
                    .trimmingCharacters(in: .whitespaces)
                if !beforeBrace.isEmpty {
                    name = beforeBrace
                }
            } else {
                // No attributes, entire content is the name
                name = trimmed
            }

            state.addToken(
                type: .fencedDivStart(name: name, colons: colonCount),
                start: start,
                content: String(repeating: ":", count: colonCount) + " " + trimmed,
                startLine: startLine,
                startColumn: startColumn
            )
        }
    }

    // MARK: - Slide Extension Lexing

    /// Lex slide delimiter %%%
    @inline(__always)
    private func lexSlideDelimiter(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        // Consume %%%
        state.advance(by: 3)

        // Skip whitespace
        state.skipWhitespace()

        // Check for attributes
        var attributeContent = ""
        if state.peek(at: 0) == ASCII.LBRACE {
            let attrStart = state.offset
            var braceCount = 1
            state.advance() // consume {

            while let byte = state.peek(at: 0), braceCount > 0 && byte != ASCII.LF {
                if byte == ASCII.LBRACE {
                    braceCount += 1
                } else if byte == ASCII.RBRACE {
                    braceCount -= 1
                }
                state.advance()
            }

            attributeContent = state.substring(from: attrStart, to: state.offset)
        }

        // Skip to end of line
        while let byte = state.peek(at: 0), byte != ASCII.LF {
            state.advance()
        }

        state.addToken(
            type: .slideDelimiter,
            start: start,
            content: "%%%\(attributeContent.isEmpty ? "" : " \(attributeContent)")",
            startLine: startLine,
            startColumn: startColumn
        )

        // Also emit attribute token if we found attributes
        if !attributeContent.isEmpty {
            let startIdx = state.source.utf8.index(state.source.utf8.startIndex, offsetBy: start)
            let endIdx = state.source.utf8.index(state.source.utf8.startIndex, offsetBy: state.offset)
            state.tokens.append(Token(
                type: .attributeList(attributeContent),
                range: startIdx..<endIdx,
                content: attributeContent,
                line: startLine,
                column: startColumn
            ))
        }
    }

    /// Lex grid layout %% D3
    @inline(__always)
    private func lexGridLayout(_ state: inout ByteScanner) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        // Consume %%
        state.advance(by: 2)

        // Skip whitespace
        state.skipWhitespace()

        // Read cell reference (e.g., D3)
        var cellRef = ""
        while let byte = state.peek(at: 0), ASCII.isLetter(byte) || ASCII.isDigit(byte) {
            cellRef.append(Character(UnicodeScalar(byte)))
            state.advance()
        }

        // Parse dimensions
        guard let dims = GridLayout.parseDimensions(cellRef) else {
            // Invalid grid layout, treat as text
            state.offset = start
            lexParagraph(&state)
            return
        }

        // Skip whitespace
        state.skipWhitespace()

        // Check for attributes
        var attributeContent = ""
        if state.peek(at: 0) == ASCII.LBRACE {
            let attrStart = state.offset
            var braceCount = 1
            state.advance() // consume {

            while let byte = state.peek(at: 0), braceCount > 0 && byte != ASCII.LF {
                if byte == ASCII.LBRACE {
                    braceCount += 1
                } else if byte == ASCII.RBRACE {
                    braceCount -= 1
                }
                state.advance()
            }

            attributeContent = state.substring(from: attrStart, to: state.offset)
        }

        // Skip to end of line
        while let byte = state.peek(at: 0), byte != ASCII.LF {
            state.advance()
        }

        state.addToken(
            type: .gridLayout(columns: dims.columns, rows: dims.rows),
            start: start,
            content: "%% \(cellRef)\(attributeContent.isEmpty ? "" : " \(attributeContent)")",
            startLine: startLine,
            startColumn: startColumn
        )

        // Also emit attribute token if we found attributes
        if !attributeContent.isEmpty {
            let startIdx = state.source.utf8.index(state.source.utf8.startIndex, offsetBy: start)
            let endIdx = state.source.utf8.index(state.source.utf8.startIndex, offsetBy: state.offset)
            state.tokens.append(Token(
                type: .attributeList(attributeContent),
                range: startIdx..<endIdx,
                content: attributeContent,
                line: startLine,
                column: startColumn
            ))
        }
    }

    /// Lex grid cell % A1
    @inline(__always)
    private func lexGridCell(_ state: inout ByteScanner, indent: Int) {
        let start = state.offset
        let startLine = state.line
        let startColumn = state.column

        // Consume %
        state.advance()

        // Skip optional whitespace
        state.skipWhitespace()

        // Read cell reference (e.g., A1)
        var cellRef = ""
        while let byte = state.peek(at: 0), ASCII.isLetter(byte) || ASCII.isDigit(byte) {
            cellRef.append(Character(UnicodeScalar(byte)))
            state.advance()
        }

        // Parse cell reference
        guard let ref = GridCell.parseReference(cellRef) else {
            // Invalid cell reference, treat as text
            state.offset = start
            lexParagraph(&state)
            return
        }

        // Must have whitespace after cell reference
        guard state.peek(at: 0) == ASCII.SPACE || state.peek(at: 0) == ASCII.TAB else {
            state.offset = start
            lexParagraph(&state)
            return
        }

        // Skip whitespace
        state.skipWhitespace()

        // Emit the grid cell token
        state.addToken(
            type: .gridCell(column: ref.column, row: ref.row),
            start: start,
            content: "% \(cellRef)",
            startLine: startLine,
            startColumn: startColumn
        )

        // The rest of the line is content - lex as inline
        if let byte = state.peek(at: 0), byte != ASCII.LF {
            lexInline(&state)
        }
    }
}

private extension Character {
    var isASCIIAlpha: Bool {
        guard unicodeScalars.count == 1,
              let value = unicodeScalars.first?.value
        else {
            return false
        }

        return (value >= 65 && value <= 90) || (value >= 97 && value <= 122)
    }

    var isASCIIDigit: Bool {
        guard unicodeScalars.count == 1,
              let value = unicodeScalars.first?.value
        else {
            return false
        }

        return value >= 48 && value <= 57
    }

    var isASCIIAlphanumeric: Bool {
        isASCIIAlpha || isASCIIDigit
    }

    var isCommonMarkEmailLocalCharacter: Bool {
        isASCIIAlphanumeric || ".!#$%&'*+/=?^_`{|}~-".contains(self)
    }
}
