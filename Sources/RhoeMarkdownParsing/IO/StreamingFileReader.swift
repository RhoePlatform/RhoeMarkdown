import Foundation

#if !os(WASI)

/// Streaming file reader that reads large files in bounded-memory chunks.
///
/// Instead of `String(contentsOf:)` which loads the entire file into memory,
/// this reader yields chunks of ~256KB, split on newline boundaries to ensure
/// valid UTF-8 and complete lines.
///
/// For a 10MB file, peak memory is ~256KB (one chunk) instead of ~10MB (entire file).
///
/// Usage:
/// ```swift
/// let reader = StreamingFileReader()
/// for await chunk in reader.readChunked(from: fileURL) {
///     // Process each ~256KB chunk
/// }
/// ```
public struct StreamingFileReader: Sendable {

    /// Default chunk size in bytes
    public static let defaultChunkSize: Int = 256_000

    public init() {}

    /// Read a file as an async stream of String chunks.
    ///
    /// Each chunk is approximately `chunkSize` bytes, split at the nearest
    /// preceding newline boundary. This ensures:
    /// - Each chunk contains only complete lines
    /// - UTF-8 multi-byte sequences are never split
    /// - Chunks can be lexed independently
    ///
    /// - Parameters:
    ///   - url: File URL to read
    ///   - chunkSize: Target chunk size in bytes (default: 256KB)
    /// - Returns: AsyncStream of String chunks
    public func readChunked(
        from url: URL,
        chunkSize: Int = StreamingFileReader.defaultChunkSize
    ) -> AsyncStream<String> {
        AsyncStream { continuation in
            guard let fileHandle = FileHandle(forReadingAtPath: url.path) else {
                continuation.finish()
                return
            }

            defer { fileHandle.closeFile() }

            var carryover = Data()

            while true {
                var readData = fileHandle.readData(ofLength: chunkSize)

                if readData.isEmpty {
                    // End of file — yield any remaining carryover
                    if !carryover.isEmpty {
                        if let chunk = String(data: carryover, encoding: .utf8) {
                            continuation.yield(chunk)
                        }
                    }
                    break
                }

                // Prepend carryover from previous iteration
                if !carryover.isEmpty {
                    readData = carryover + readData
                    carryover = Data()
                }

                // Find the last newline in this data to ensure clean line breaks
                if let lastNewlineIndex = readData.lastIndex(of: UInt8(ascii: "\n")) {
                    let chunkData = readData[readData.startIndex...lastNewlineIndex]
                    carryover = Data(readData[readData.index(after: lastNewlineIndex)...])

                    if let chunk = String(data: chunkData, encoding: .utf8) {
                        continuation.yield(chunk)
                    }
                } else {
                    // No newline found — accumulate into carryover
                    carryover = readData
                }
            }

            continuation.finish()
        }
    }

    /// Get the file size without reading the content.
    public func fileSize(at url: URL) -> Int? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
    }

    /// Check if a file exceeds the streaming threshold.
    public func shouldStream(url: URL, threshold: Int = 1_000_000) -> Bool {
        guard let size = fileSize(at: url) else { return false }
        return size > threshold
    }
}

#endif // !os(WASI)
