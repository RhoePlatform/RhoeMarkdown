import Foundation

// MARK: - SIMDScanner Delimiter Lookup Extension

extension SIMDScanner {

    /// Fast delimiter check using the pre-computed lookup table.
    /// Used by ByteScanner and other components for single-byte classification.
    @inlinable @inline(__always)
    static func isDelimiterByte(_ b: UInt8) -> Bool {
        isDelimiterTable[Int(b)]
    }
}
