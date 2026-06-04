import Foundation

/// High-performance string builder optimized for HTML generation.
///
/// Accumulates strings in 8KB chunks to avoid O(n²) concatenation overhead.
/// Pre-allocates capacity based on estimated output size.
public struct HTMLStringBuilder {
    @usableFromInline var chunks: [String] = []
    @usableFromInline var currentChunk: String = ""
    @usableFromInline let chunkSize: Int = 8192 // 8KB chunks

    @inlinable
    public init(estimatedSize: Int = 0) {
        if estimatedSize > 0 {
            chunks.reserveCapacity((estimatedSize / chunkSize) + 1)
            currentChunk.reserveCapacity(min(estimatedSize, chunkSize))
        }
    }

    @inlinable
    public mutating func append(_ string: String) {
        // If adding this string would exceed chunk size, flush current chunk
        if currentChunk.count + string.count > chunkSize {
            if !currentChunk.isEmpty {
                chunks.append(currentChunk)
                currentChunk = ""
                currentChunk.reserveCapacity(chunkSize)
            }
        }

        // If string itself is larger than chunk size, add it directly
        if string.count > chunkSize {
            if !currentChunk.isEmpty {
                chunks.append(currentChunk)
                currentChunk = ""
            }
            chunks.append(string)
        } else {
            currentChunk.append(string)
        }
    }

    @inlinable
    public mutating func append(_ character: Character) {
        if currentChunk.count >= chunkSize {
            chunks.append(currentChunk)
            currentChunk = ""
            currentChunk.reserveCapacity(chunkSize)
        }
        currentChunk.append(character)
    }

    public mutating func appendInterpolation(_ items: Any...) {
        for item in items {
            append(String(describing: item))
        }
    }

    @inlinable
    public func build() -> String {
        var result = chunks.joined()
        if !currentChunk.isEmpty {
            result.append(currentChunk)
        }
        return result
    }
}

/// Protocol for efficient HTML escaping.
public protocol HTMLEscapable {
    func htmlEscaped() -> String
}

extension String: HTMLEscapable {
    /// Fast HTML escaping using a single pass with early-exit optimization.
    ///
    /// Returns `self` immediately if no special characters are found.
    /// Otherwise performs a single-pass replacement with 2x capacity pre-allocation.
    @inlinable
    public func htmlEscaped() -> String {
        // Early return for strings without special characters (fast path)
        var needsEscaping = false
        for char in self {
            switch char {
            case "&", "<", ">", "\"", "'":
                needsEscaping = true
                break
            default:
                continue
            }
            if needsEscaping { break }
        }

        if !needsEscaping {
            return self
        }

        // Single-pass escaping
        var result = ""
        result.reserveCapacity(self.count * 2)

        for char in self {
            switch char {
            case "&":
                result.append("&amp;")
            case "<":
                result.append("&lt;")
            case ">":
                result.append("&gt;")
            case "\"":
                result.append("&quot;")
            case "'":
                result.append("&#39;")
            default:
                result.append(char)
            }
        }

        return result
    }
}
