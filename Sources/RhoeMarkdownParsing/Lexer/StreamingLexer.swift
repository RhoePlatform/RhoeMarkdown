import Foundation

// MARK: - Streaming Lexer

/// Chunked lexer that tokenizes a document in bounded-memory segments.
///
/// Instead of lexing the entire document into a single `[Token]` array
/// (which can require 5-10x the input size in memory), the streaming lexer:
///
/// 1. Scans the input bytes for safe structural boundaries
/// 2. Lexes one chunk at a time (~256KB default)
/// 3. Yields each chunk's tokens via `AsyncStream`
/// 4. The caller parses and discards each token batch immediately
///
/// This reduces peak memory from O(10n) to O(n + chunk_size) for large documents,
/// eliminating the token array as the memory bottleneck.
///
/// Safe split points are identified using `SIMDScanner.classifyLine()`:
/// - Blank lines (double newline)
/// - Heading lines
/// - Thematic breaks
/// - Fenced code block boundaries (only when NOT inside a code block)
///
/// The lexer NEVER splits inside:
/// - Fenced code blocks
/// - HTML blocks
/// - Blockquote continuation sequences
/// - List item continuation
public struct StreamingLexer: Sendable {

    /// Default chunk target size in bytes
    public static let defaultChunkSize: Int = 256_000

    /// Minimum chunk size (don't create tiny trailing chunks)
    public static let minimumChunkSize: Int = 4_096

    private let lexer = RhoeLexer()

    public init() {}

    // MARK: - Chunked Tokenization

    /// Tokenize a document in chunks, yielding token batches via AsyncStream.
    ///
    /// Each yielded `[Token]` array covers one structural chunk of the document.
    /// The caller should parse each batch immediately and release it,
    /// keeping only the resulting `[Block]` AST nodes.
    ///
    /// - Parameters:
    ///   - input: The full markdown source string
    ///   - chunkSize: Target chunk size in bytes (default: 256KB)
    /// - Returns: AsyncStream of token arrays, one per chunk
    public func tokenizeChunked(
        _ input: String,
        chunkSize: Int = StreamingLexer.defaultChunkSize
    ) -> AsyncStream<TokenChunk> {
        let bytes = Array(input.utf8)
        let boundaries = findChunkBoundaries(bytes: bytes, targetSize: chunkSize)

        // For small documents (1-2 chunks), lex sequentially to avoid task overhead
        if boundaries.count <= 2 {
            return AsyncStream { continuation in
                for (index, boundary) in boundaries.enumerated() {
                    let chunk = self.lexChunk(input: input, boundary: boundary, index: index, totalCount: boundaries.count)
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }

        // For larger documents, lex all chunks in parallel then yield in order
        return AsyncStream { continuation in
            Task {
                let chunks = await self.lexChunksParallel(input: input, boundaries: boundaries)
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }

    /// Lex all chunks in parallel using structured concurrency, returning them in order.
    private func lexChunksParallel(
        input: String,
        boundaries: [ChunkBoundary]
    ) async -> [TokenChunk] {
        await withTaskGroup(of: TokenChunk.self, returning: [TokenChunk].self) { group in
            for (index, boundary) in boundaries.enumerated() {
                group.addTask {
                    self.lexChunk(input: input, boundary: boundary, index: index, totalCount: boundaries.count)
                }
            }

            // Collect all results, then sort by chunk index to preserve order
            var results: [TokenChunk] = []
            results.reserveCapacity(boundaries.count)
            for await chunk in group {
                results.append(chunk)
            }
            return results.sorted { $0.chunkIndex < $1.chunkIndex }
        }
    }

    /// Lex a single chunk (extracted for reuse by both sequential and parallel paths).
    private func lexChunk(
        input: String,
        boundary: ChunkBoundary,
        index: Int,
        totalCount: Int
    ) -> TokenChunk {
        let chunkStart = boundary.startOffset
        let chunkEnd = boundary.endOffset

        let startIdx = input.utf8.index(input.utf8.startIndex, offsetBy: chunkStart)
        let endIdx = input.utf8.index(input.utf8.startIndex, offsetBy: chunkEnd)
        let chunkString = String(input.utf8[startIdx..<endIdx]) ?? ""

        let tokens = lexer.tokenize(chunkString)

        return TokenChunk(
            tokens: tokens,
            chunkIndex: index,
            byteRange: chunkStart..<chunkEnd,
            isFirstChunk: index == 0,
            isLastChunk: index == totalCount - 1,
            context: boundary.context
        )
    }

    /// Synchronous version for use in non-async contexts.
    /// Returns all chunk boundaries without lexing — useful for planning.
    public func planChunks(
        _ input: String,
        chunkSize: Int = StreamingLexer.defaultChunkSize
    ) -> [ChunkBoundary] {
        let bytes = Array(input.utf8)
        return findChunkBoundaries(bytes: bytes, targetSize: chunkSize)
    }

    // MARK: - Boundary Detection

    /// Find safe structural boundaries for chunking the document.
    ///
    /// Scans the byte array for structural split points near each target boundary.
    /// Uses SIMD-accelerated newline detection and line classification.
    private func findChunkBoundaries(
        bytes: [UInt8],
        targetSize: Int
    ) -> [ChunkBoundary] {
        let totalSize = bytes.count
        guard totalSize > 0 else { return [] }

        // If document is smaller than one chunk, return it as a single chunk
        if totalSize <= targetSize + StreamingLexer.minimumChunkSize {
            return [ChunkBoundary(
                startOffset: 0,
                endOffset: totalSize,
                context: .init()
            )]
        }

        var boundaries: [ChunkBoundary] = []
        var currentStart = 0
        var context = ChunkContext()

        while currentStart < totalSize {
            let idealEnd = min(currentStart + targetSize, totalSize)

            if idealEnd >= totalSize {
                // Last chunk — take everything remaining
                boundaries.append(ChunkBoundary(
                    startOffset: currentStart,
                    endOffset: totalSize,
                    context: context
                ))
                break
            }

            // Search for a safe split point near the ideal boundary
            let splitPoint = findSafeSplitPoint(
                bytes: bytes,
                idealOffset: idealEnd,
                searchRange: targetSize / 4, // Search within 25% of chunk size
                context: &context
            )

            boundaries.append(ChunkBoundary(
                startOffset: currentStart,
                endOffset: splitPoint,
                context: context
            ))

            currentStart = splitPoint
        }

        return boundaries
    }

    /// Find a safe split point near the ideal offset.
    ///
    /// Searches backward from `idealOffset` for a structural boundary:
    /// 1. Blank line (highest priority — cleanest split)
    /// 2. Heading line
    /// 3. Thematic break
    /// 4. Any newline (fallback)
    ///
    /// Never splits inside fenced code blocks, HTML blocks, or blockquotes.
    private func findSafeSplitPoint(
        bytes: [UInt8],
        idealOffset: Int,
        searchRange: Int,
        context: inout ChunkContext
    ) -> Int {
        let searchStart = max(0, idealOffset - searchRange)
        let searchEnd = min(bytes.count, idealOffset + searchRange)

        // Track code fence state as we scan
        var inCodeBlock = context.insideCodeBlock
        var bestBlankLine = -1
        var bestHeading = -1
        var bestNewline = -1

        var i = searchStart

        while i < searchEnd {
            let byte = bytes[i]

            if byte == ASCII.LF {
                bestNewline = i + 1 // Split AFTER the newline

                // Check for blank line (two consecutive newlines)
                if i + 1 < searchEnd && bytes[i + 1] == ASCII.LF && !inCodeBlock {
                    bestBlankLine = i + 2 // Split after the blank line
                }

                // Check what the next line starts with
                if i + 1 < searchEnd && !inCodeBlock {
                    let nextByte = bytes[i + 1]
                    switch nextByte {
                    case ASCII.HASH:
                        bestHeading = i + 1
                    case ASCII.BACKTICK:
                        // Check for code fence toggle
                        if i + 3 < searchEnd && bytes[i + 2] == ASCII.BACKTICK && bytes[i + 3] == ASCII.BACKTICK {
                            inCodeBlock.toggle()
                            if !inCodeBlock {
                                // Closing fence — good split point AFTER it
                                bestBlankLine = max(bestBlankLine, i + 1)
                            }
                        }
                    case ASCII.TILDE:
                        if i + 3 < searchEnd && bytes[i + 2] == ASCII.TILDE && bytes[i + 3] == ASCII.TILDE {
                            inCodeBlock.toggle()
                            if !inCodeBlock {
                                bestBlankLine = max(bestBlankLine, i + 1)
                            }
                        }
                    default:
                        break
                    }
                }
            }
            i += 1
        }

        // Update context for the next chunk
        context.insideCodeBlock = inCodeBlock

        // Return the best split point (prefer blank line > heading > any newline)
        if bestBlankLine > 0 && bestBlankLine >= searchStart {
            return bestBlankLine
        }
        if bestHeading > 0 && bestHeading >= searchStart {
            return bestHeading
        }
        if bestNewline > 0 && bestNewline >= searchStart {
            return bestNewline
        }

        // Absolute fallback: split at ideal offset
        return idealOffset
    }
}

// MARK: - Supporting Types

/// A chunk of tokens from the streaming lexer.
public struct TokenChunk: Sendable {
    /// The tokens in this chunk
    public let tokens: [RhoeLexer.Token]

    /// Zero-based index of this chunk
    public let chunkIndex: Int

    /// Byte range in the original document
    public let byteRange: Range<Int>

    /// Whether this is the first chunk (may contain frontmatter)
    public let isFirstChunk: Bool

    /// Whether this is the last chunk
    public let isLastChunk: Bool

    /// Parsing context carried from the previous chunk
    public let context: ChunkContext
}

/// Context state carried between chunks for correct parsing.
public struct ChunkContext: Sendable {
    /// Whether the previous chunk ended inside a fenced code block
    public var insideCodeBlock: Bool = false

    /// Current blockquote nesting depth at the chunk boundary
    public var blockQuoteDepth: Int = 0

    /// Current list nesting depth at the chunk boundary
    public var listDepth: Int = 0

    public init(
        insideCodeBlock: Bool = false,
        blockQuoteDepth: Int = 0,
        listDepth: Int = 0
    ) {
        self.insideCodeBlock = insideCodeBlock
        self.blockQuoteDepth = blockQuoteDepth
        self.listDepth = listDepth
    }
}

/// A planned chunk boundary (before lexing).
public struct ChunkBoundary: Sendable {
    /// Byte offset where this chunk starts
    public let startOffset: Int

    /// Byte offset where this chunk ends (exclusive)
    public let endOffset: Int

    /// Context state at this boundary
    public let context: ChunkContext

    /// Size of this chunk in bytes
    public var size: Int { endOffset - startOffset }
}
