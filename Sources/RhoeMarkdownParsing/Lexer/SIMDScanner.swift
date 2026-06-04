import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Glibc)
import Glibc
#endif
#if canImport(simd)
import simd
#endif

// MARK: - SIMD Character Scanner

/// SIMD-accelerated byte scanning for the RhoeMarkdown lexer.
///
/// Uses 64-byte SIMD vectors to scan for markdown delimiter characters
/// in bulk, processing 64 bytes per comparison instead of 1.
/// Falls back to scalar scanning when SIMD is unavailable or for
/// short buffers.
///
/// Primary operations:
/// - `findNextDelimiter`: Skip plain text bytes at SIMD speed
/// - `countLeading`: Count runs of identical characters (e.g., `###`, `:::`)
/// - `findNewline`: Jump to next line boundary
/// - `classifyLine`: Batch-classify a line's structural role
enum SIMDScanner {

    // MARK: - Delimiter Detection

    /// Markdown delimiter bytes that trigger structural parsing.
    /// When scanning text content, we can skip everything EXCEPT these bytes.
    private static let delimiterSet: Set<UInt8> = [
        ASCII.HASH,      // # heading
        ASCII.STAR,      // * emphasis, list
        ASCII.UNDER,     // _ emphasis
        ASCII.BACKTICK,  // ` code
        ASCII.TILDE,     // ~ strikethrough, subscript
        ASCII.LBRACKET,  // [ link, footnote, citation
        ASCII.RBRACKET,  // ] close bracket
        ASCII.BANG,      // ! image, admonition
        ASCII.PIPE,      // | table
        ASCII.GT,        // > blockquote
        ASCII.LT,        // < HTML, autolink, composition
        ASCII.DASH,      // - list, thematic break
        ASCII.PLUS,      // + list
        ASCII.EQ,        // = highlight
        ASCII.CARET,     // ^ superscript, inline footnote
        ASCII.COLON,     // : fenced div, definition
        ASCII.PERCENT,   // % slide
        ASCII.DOLLAR,    // $ math
        ASCII.LBRACE,    // { attribute, Phase 2
        ASCII.AT,        // @ cross-ref, extension
        ASCII.BACKSLASH, // \ escape
        ASCII.LF,        // newline
    ]

    /// Pre-computed 256-bit lookup table: 1 = delimiter, 0 = plain text.
    /// Array index is the byte value; the value is whether it's a delimiter.
    @usableFromInline static let isDelimiterTable: [Bool] = {
        var table = [Bool](repeating: false, count: 256)
        for byte in delimiterSet {
            table[Int(byte)] = true
        }
        return table
    }()

    /// Find the next delimiter byte starting from `offset` in `bytes`.
    /// Returns the offset of the first delimiter, or `bytes.count` if none found.
    ///
    /// Uses native Swift SIMD64<UInt8> broadcast comparison to check 64 bytes
    /// against the 12 most common markdown delimiters simultaneously.
    /// Each SIMD comparison compiles to a single ARM64 NEON CMEQ instruction.
    @inline(__always)
    static func findNextDelimiter(in bytes: [UInt8], from offset: Int) -> Int {
        let count = bytes.count
        guard offset < count else { return count }

        return bytes.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return count }
            var i = offset

            // SIMD16 fast path — process 16 bytes per iteration
            // Uses SIMD16<UInt8> which is always safely loadable (no alignment issues)
            // ARM64 NEON has native 128-bit (16-byte) registers
            // All 22 delimiter bytes are checked (complete coverage)
            while i + 16 <= count {
                // Safe unaligned load via element-wise construction
                let chunk = SIMD16<UInt8>(
                    base[i],    base[i+1],  base[i+2],  base[i+3],
                    base[i+4],  base[i+5],  base[i+6],  base[i+7],
                    base[i+8],  base[i+9],  base[i+10], base[i+11],
                    base[i+12], base[i+13], base[i+14], base[i+15]
                )

                // Compare against ALL delimiter bytes (complete coverage)
                var mask = chunk .== SIMD16(repeating: ASCII.LF)          // \n newline
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.HASH))       // # heading
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.STAR))       // * emphasis/list
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.UNDER))      // _ emphasis
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.BACKTICK))   // ` code
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.TILDE))      // ~ strikethrough/subscript
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.LBRACKET))   // [ link/citation
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.RBRACKET))   // ] close bracket
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.BANG))       // ! image/admonition
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.GT))         // > blockquote
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.LT))         // < HTML/composition
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.PIPE))       // | table
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.COLON))      // : fenced div/definition
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.DASH))       // - list/break
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.PLUS))       // + list
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.EQ))         // = highlight
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.CARET))      // ^ superscript/footnote
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.PERCENT))    // % slide
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.DOLLAR))     // $ math
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.LBRACE))     // { attribute/phase2
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.AT))         // @ cross-ref/extension
                mask = mask .| (chunk .== SIMD16(repeating: ASCII.BACKSLASH))  // \ escape

                if mask != SIMDMask(repeating: false) {
                    for j in 0..<16 where mask[j] { return i + j }
                }
                i += 16
            }

            // Scalar tail for remaining bytes (lookup table)
            while i < count {
                if isDelimiterTable[Int(base[i])] { return i }
                i += 1
            }
            return count
        }
    }

    // MARK: - memchr Fast Path

    /// Find a single specific byte using libc's NEON-optimized memchr.
    /// Faster than SIMD for single-byte searches (Apple's libc is hand-tuned).
    @inline(__always)
    static func findByte(_ needle: UInt8, in bytes: [UInt8], from offset: Int) -> Int {
        let count = bytes.count
        guard offset < count else { return count }

        return bytes.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return count }
            let searchLen = count - offset
            if let ptr = memchr(base + offset, Int32(needle), searchLen) {
                return base.distance(to: ptr.assumingMemoryBound(to: UInt8.self))
            }
            return count
        }
    }

    // MARK: - Run Length Counting

    /// Count consecutive identical bytes starting from `offset`.
    /// Used for counting `###`, `:::`, `!!!`, `%%%`, `---`, `***`, `` ``` ``, `~~~`.
    @inline(__always)
    static func countLeading(_ byte: UInt8, in bytes: [UInt8], from offset: Int) -> Int {
        let count = bytes.count
        guard offset < count else { return 0 }

        return bytes.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return 0 }
            var i = offset

            // Unrolled comparison: check 16 bytes at a time
            while i + 16 <= count {
                // Early exit on first mismatch within the 16-byte block
                for j in 0..<16 {
                    if base[i + j] != byte {
                        return (i - offset) + j
                    }
                }
                // All 16 bytes matched — continue to next block
                i += 16
            }

            // Scalar tail (also handles non-ARM64)
            while i < count && base[i] == byte {
                i += 1
            }
            return i - offset
        }
    }

    // MARK: - Newline Detection

    /// Find the next newline (LF) byte starting from `offset`.
    /// Returns the offset of the newline, or `bytes.count` if none found.
    /// Uses libc memchr for maximum performance (Apple's NEON-tuned implementation).
    @inline(__always)
    static func findNewline(in bytes: [UInt8], from offset: Int) -> Int {
        findByte(ASCII.LF, in: bytes, from: offset)
    }

    // MARK: - Whitespace Skipping

    /// Skip horizontal whitespace (space + tab) starting from `offset`.
    /// Returns the offset of the first non-whitespace byte.
    @inline(__always)
    static func skipWhitespace(in bytes: [UInt8], from offset: Int) -> Int {
        let count = bytes.count
        guard offset < count else { return count }

        var i = offset
        while i < count {
            let b = bytes[i]
            if b != ASCII.SPACE && b != ASCII.TAB { break }
            i += 1
        }
        return i
    }

    // MARK: - Bulk Text Extraction

    /// Extract a contiguous run of non-delimiter bytes as a String.
    /// This is the fast path for plain text content — SIMD finds the boundary,
    /// then we extract the substring once.
    @inline(__always)
    static func extractTextRun(from bytes: [UInt8], source: String, offset: Int) -> (text: String, endOffset: Int) {
        let endOffset = findNextDelimiter(in: bytes, from: offset)
        if endOffset <= offset { return ("", offset) }

        let startIdx = source.utf8.index(source.utf8.startIndex, offsetBy: offset)
        let endIdx = source.utf8.index(source.utf8.startIndex, offsetBy: endOffset)
        let text = String(source.utf8[startIdx..<endIdx]) ?? ""
        return (text, endOffset)
    }

    // MARK: - Line Classification

    /// Quickly classify what kind of line starts at `offset` by examining
    /// the first few non-whitespace bytes. Returns a hint for the block-level dispatcher.
    enum LineHint {
        case heading          // #
        case blockQuote       // >
        case unorderedList    // -, *, +
        case orderedList      // digit.
        case codeBlock        // ```, ~~~
        case thematicBreak    // ---, ***, +++
        case table            // |
        case admonition       // !!!
        case fencedDiv        // :::
        case slideDelimiter   // %%%
        case compositionDir   // <<
        case phase2Dir        // {@
        case htmlBlock        // <(not <)
        case blankLine        // empty or whitespace only
        case paragraph        // anything else
    }

    @inline(__always)
    static func classifyLine(in bytes: [UInt8], from offset: Int) -> LineHint {
        let count = bytes.count
        let i = skipWhitespace(in: bytes, from: offset)
        guard i < count else { return .blankLine }

        let b = bytes[i]
        switch b {
        case ASCII.LF: return .blankLine
        case ASCII.HASH: return .heading
        case ASCII.GT: return .blockQuote
        case ASCII.DASH, ASCII.STAR, ASCII.PLUS:
            // Could be list marker or thematic break
            if i + 2 < count && bytes[i + 1] == b && bytes[i + 2] == b {
                return .thematicBreak
            }
            return .unorderedList
        case ASCII.BACKTICK:
            if i + 2 < count && bytes[i + 1] == ASCII.BACKTICK && bytes[i + 2] == ASCII.BACKTICK {
                return .codeBlock
            }
            return .paragraph
        case ASCII.TILDE:
            if i + 2 < count && bytes[i + 1] == ASCII.TILDE && bytes[i + 2] == ASCII.TILDE {
                return .codeBlock
            }
            return .paragraph
        case ASCII.PIPE: return .table
        case ASCII.BANG:
            if i + 2 < count && bytes[i + 1] == ASCII.BANG && bytes[i + 2] == ASCII.BANG {
                return .admonition
            }
            return .paragraph
        case ASCII.COLON:
            if i + 2 < count && bytes[i + 1] == ASCII.COLON && bytes[i + 2] == ASCII.COLON {
                return .fencedDiv
            }
            return .paragraph
        case ASCII.PERCENT:
            if i + 2 < count && bytes[i + 1] == ASCII.PERCENT && bytes[i + 2] == ASCII.PERCENT {
                return .slideDelimiter
            }
            return .paragraph
        case ASCII.LT:
            if i + 1 < count && bytes[i + 1] == ASCII.LT {
                return .compositionDir
            }
            return .htmlBlock
        case ASCII.LBRACE:
            if i + 1 < count && bytes[i + 1] == ASCII.AT {
                return .phase2Dir
            }
            return .paragraph
        case 0x30...0x39: // digit
            return .orderedList
        default:
            return .paragraph
        }
    }
}

// MARK: - ByteScanner SIMD Extensions

extension ByteScanner {

    /// Skip to the next delimiter using SIMD-accelerated scanning.
    /// Returns the number of bytes skipped (plain text content).
    @inline(__always)
    mutating func skipToNextDelimiter() -> Int {
        let nextDelim = SIMDScanner.findNextDelimiter(in: bytes, from: offset)
        let skipped = nextDelim - offset
        // Advance with line/column tracking
        for _ in 0..<skipped { advance() }
        return skipped
    }

    /// Count consecutive identical bytes at current position using SIMD.
    @inline(__always)
    func countLeading(_ byte: UInt8) -> Int {
        SIMDScanner.countLeading(byte, in: bytes, from: offset)
    }

    /// Find next newline using SIMD-accelerated scanning.
    @inline(__always)
    func nextNewlineOffset() -> Int {
        SIMDScanner.findNewline(in: bytes, from: offset)
    }

    /// Classify the current line's structural role using SIMD.
    @inline(__always)
    func classifyCurrentLine() -> SIMDScanner.LineHint {
        SIMDScanner.classifyLine(in: bytes, from: offset)
    }

    /// Extract a text run (plain content) using SIMD delimiter detection.
    /// Returns the text string and advances the scanner past it.
    @inline(__always)
    mutating func extractTextRunSIMD() -> String {
        let (text, endOffset) = SIMDScanner.extractTextRun(from: bytes, source: source, offset: offset)
        while offset < endOffset { advance() }
        return text
    }
}
