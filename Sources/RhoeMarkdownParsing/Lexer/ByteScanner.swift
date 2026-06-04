import Foundation

// MARK: - ASCII Constants

/// ASCII byte constants for O(1) character classification in the lexer.
///
/// All Markdown delimiters and structural characters are single-byte ASCII.
/// Using byte-level comparison (UInt8) instead of Character comparison
/// eliminates grapheme cluster overhead and enables SIMD-friendly scanning.
enum ASCII {
    static let LF: UInt8 = 0x0A       // \n
    static let CR: UInt8 = 0x0D       // \r
    static let SPACE: UInt8 = 0x20    // space
    static let TAB: UInt8 = 0x09      // tab
    static let HASH: UInt8 = 0x23     // #
    static let STAR: UInt8 = 0x2A     // *
    static let UNDER: UInt8 = 0x5F    // _
    static let BACKTICK: UInt8 = 0x60 // `
    static let TILDE: UInt8 = 0x7E    // ~
    static let LBRACKET: UInt8 = 0x5B // [
    static let RBRACKET: UInt8 = 0x5D // ]
    static let LPAREN: UInt8 = 0x28   // (
    static let RPAREN: UInt8 = 0x29   // )
    static let BANG: UInt8 = 0x21     // !
    static let PIPE: UInt8 = 0x7C    // |
    static let GT: UInt8 = 0x3E      // >
    static let LT: UInt8 = 0x3C      // <
    static let DASH: UInt8 = 0x2D    // -
    static let PLUS: UInt8 = 0x2B    // +
    static let EQ: UInt8 = 0x3D     // =
    static let CARET: UInt8 = 0x5E   // ^
    static let COLON: UInt8 = 0x3A   // :
    static let PERCENT: UInt8 = 0x25  // %
    static let DOT: UInt8 = 0x2E    // .
    static let DOLLAR: UInt8 = 0x24  // $
    static let LBRACE: UInt8 = 0x7B  // {
    static let RBRACE: UInt8 = 0x7D  // }
    static let AT: UInt8 = 0x40     // @
    static let BACKSLASH: UInt8 = 0x5C // \
    static let SLASH: UInt8 = 0x2F   // /
    static let DQUOTE: UInt8 = 0x22  // "
    static let SQUOTE: UInt8 = 0x27  // '
    static let QUESTION: UInt8 = 0x3F // ?
    static let SEMICOLON: UInt8 = 0x3B // ;
    static let COMMA: UInt8 = 0x2C   // ,
    static let AMPERSAND: UInt8 = 0x26 // &

    /// A-Z or a-z
    @inline(__always)
    static func isLetter(_ b: UInt8) -> Bool {
        (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A)
    }

    /// 0-9
    @inline(__always)
    static func isDigit(_ b: UInt8) -> Bool {
        b >= 0x30 && b <= 0x39
    }

    /// Letter or digit
    @inline(__always)
    static func isAlphanumeric(_ b: UInt8) -> Bool {
        isLetter(b) || isDigit(b)
    }

    /// Space or tab (NOT newline)
    @inline(__always)
    static func isHorizontalWhitespace(_ b: UInt8) -> Bool {
        b == SPACE || b == TAB
    }

    /// Any whitespace including newline
    @inline(__always)
    static func isWhitespace(_ b: UInt8) -> Bool {
        b == SPACE || b == TAB || b == LF || b == CR
    }

    /// Is this byte a UTF-8 continuation byte? (10xxxxxx)
    @inline(__always)
    static func isContinuation(_ b: UInt8) -> Bool {
        b & 0xC0 == 0x80
    }

    /// Is this byte ASCII? (< 128)
    @inline(__always)
    static func isASCII(_ b: UInt8) -> Bool {
        b < 0x80
    }

    /// Lowercase an ASCII letter
    @inline(__always)
    static func toLower(_ b: UInt8) -> UInt8 {
        (b >= 0x41 && b <= 0x5A) ? b + 0x20 : b
    }
}

// MARK: - ByteScanner

/// High-performance byte-level scanner for the RhoeMarkdown lexer.
///
/// Replaces `String.Index`-based scanning with direct `[UInt8]` array indexing.
/// All peek/advance operations are O(1) instead of O(n).
///
/// Markdown syntax characters are all single-byte ASCII, so byte-level scanning
/// is correct for delimiter detection. Unicode content (text nodes, headings, etc.)
/// is extracted as String substrings only when creating tokens.
struct ByteScanner {
    let bytes: [UInt8]
    let source: String
    var offset: Int = 0
    var line: Int = 1
    var column: Int = 1
    var tokens: [RhoeLexer.Token] = []
    var isStartOfLine: Bool = true
    var insideAdmonition: Bool = false

    init(source: String) {
        self.source = source
        self.bytes = Array(source.utf8)
        self.tokens.reserveCapacity(max(bytes.count / 10, 64))
    }

    /// Is there more input to scan?
    @inline(__always)
    var hasMore: Bool { offset < bytes.count }

    /// Current byte (nil if at end).
    @inline(__always)
    var current: UInt8? { offset < bytes.count ? bytes[offset] : nil }

    /// Peek at byte at current position + delta. O(1).
    @inline(__always)
    func peek(at delta: Int = 0) -> UInt8? {
        let idx = offset + delta
        return idx >= 0 && idx < bytes.count ? bytes[idx] : nil
    }

    /// Advance one byte, updating line/column tracking. O(1).
    @inline(__always)
    mutating func advance() {
        guard offset < bytes.count else { return }
        let b = bytes[offset]
        if b == ASCII.LF {
            line += 1
            column = 1
            isStartOfLine = true
        } else {
            column += 1
            if b != ASCII.SPACE && b != ASCII.TAB {
                isStartOfLine = false
            }
        }
        offset += 1
    }

    /// Advance by count bytes. O(count).
    @inline(__always)
    mutating func advance(by count: Int) {
        for _ in 0..<count { advance() }
    }

    /// Advance over one UTF-8 scalar, preserving a single visual column step.
    mutating func advanceScalar() {
        guard offset < bytes.count else { return }
        let first = bytes[offset]
        if ASCII.isASCII(first) {
            advance()
            return
        }

        let byteCount: Int
        if first & 0b1110_0000 == 0b1100_0000 {
            byteCount = 2
        } else if first & 0b1111_0000 == 0b1110_0000 {
            byteCount = 3
        } else if first & 0b1111_1000 == 0b1111_0000 {
            byteCount = 4
        } else {
            byteCount = 1
        }

        offset = min(offset + byteCount, bytes.count)
        column += 1
        isStartOfLine = false
    }

    /// Check if the next `count` bytes match a pattern. O(count).
    @inline(__always)
    func peekMatch(_ pattern: UInt8, count: Int) -> Bool {
        guard offset + count <= bytes.count else { return false }
        for i in 0..<count {
            if bytes[offset + i] != pattern { return false }
        }
        return true
    }

    /// Check if the next bytes match a string pattern (ASCII only). O(pattern.count).
    func peekString(_ expected: String) -> Bool {
        let patternBytes = Array(expected.utf8)
        guard offset + patternBytes.count <= bytes.count else { return false }
        for (i, b) in patternBytes.enumerated() {
            if bytes[offset + i] != b { return false }
        }
        return true
    }

    /// Skip horizontal whitespace (space + tab, NOT newline).
    @inline(__always)
    mutating func skipWhitespace() {
        while offset < bytes.count && ASCII.isHorizontalWhitespace(bytes[offset]) {
            advance()
        }
    }

    /// Consume bytes until a specific byte is found. Returns consumed content as String.
    mutating func consumeUntil(byte target: UInt8) -> String {
        let start = offset
        while offset < bytes.count && bytes[offset] != target {
            advance()
        }
        return substring(from: start, to: offset)
    }

    /// Consume bytes until a predicate is true. Returns consumed content as String.
    mutating func consumeUntil(predicate: (UInt8) -> Bool) -> String {
        let start = offset
        while offset < bytes.count && !predicate(bytes[offset]) {
            advance()
        }
        return substring(from: start, to: offset)
    }

    /// Consume the rest of the current line (up to and including newline).
    mutating func consumeLine() -> String {
        let content = consumeUntil(byte: ASCII.LF)
        if offset < bytes.count && bytes[offset] == ASCII.LF {
            advance()
        }
        return content
    }

    /// Extract a substring from byte offsets. Uses String.UTF8View for correct Unicode handling.
    func substring(from start: Int, to end: Int) -> String {
        guard start < end && end <= bytes.count else { return "" }
        let startIdx = source.utf8.index(source.utf8.startIndex, offsetBy: start)
        let endIdx = source.utf8.index(source.utf8.startIndex, offsetBy: end)
        return String(source.utf8[startIdx..<endIdx]) ?? ""
    }

    /// Create a token with byte-offset-to-String.Index bridging.
    mutating func addToken(
        type: RhoeLexer.TokenType,
        start: Int,
        content: String,
        startLine: Int,
        startColumn: Int
    ) {
        let startIdx = source.utf8.index(source.utf8.startIndex, offsetBy: start)
        let endIdx = source.utf8.index(source.utf8.startIndex, offsetBy: offset)
        tokens.append(RhoeLexer.Token(
            type: type,
            range: startIdx..<endIdx,
            content: content,
            line: startLine,
            column: startColumn
        ))
    }

    /// Peek at next N bytes as a String (for compatibility with existing code patterns).
    func peekStringValue(count: Int) -> String? {
        guard offset + count <= bytes.count else { return nil }
        return substring(from: offset, to: offset + count)
    }

    /// Peek a single character (for compatibility — returns Character).
    func peekChar(at delta: Int = 0) -> Character? {
        guard let byte = peek(at: delta) else { return nil }
        if ASCII.isASCII(byte) {
            return Character(UnicodeScalar(byte))
        }
        // Multi-byte UTF-8: fall back to String indexing
        let stringIdx = source.utf8.index(source.utf8.startIndex, offsetBy: offset + delta)
        guard stringIdx < source.endIndex else { return nil }
        return source[stringIdx]
    }
}
