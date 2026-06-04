import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Musl)
import Musl
#elseif canImport(Glibc)
import Glibc
#endif

#if canImport(Darwin) || canImport(Musl) || canImport(Glibc)

// MARK: - Memory-Mapped File Reader

/// Zero-copy file reader using mmap(2).
///
/// Maps a file's pages directly into virtual memory, avoiding the double-copy
/// of `String(contentsOf:)` (kernel buffer → heap allocation).
/// The kernel manages page-in/page-out transparently.
///
/// With `MADV_SEQUENTIAL`, the kernel prefetches pages ahead for linear scanning —
/// ideal for the lexer's sequential byte-scanning access pattern.
///
/// Usage:
/// ```swift
/// let mapped = try MMapFileReader.map(url: fileURL)
/// let markdown = mapped.string  // Zero-copy from mmap'd pages
/// // mapped is automatically munmap'd when it goes out of scope
/// ```
public enum MMapFileReader {

    /// Memory-map a file for zero-copy reading.
    ///
    /// - Parameter url: File URL to map
    /// - Returns: A `MappedFile` that stays valid until deallocated
    /// - Throws: If the file cannot be opened or mapped
    public static func map(url: URL) throws -> MappedFile {
        let fd = open(url.path, O_RDONLY)
        guard fd >= 0 else {
            throw MMapError.cannotOpen(url.path, errno: errno)
        }

        var statBuf = stat()
        guard fstat(fd, &statBuf) == 0 else {
            close(fd)
            throw MMapError.cannotStat(url.path, errno: errno)
        }

        let size = Int(statBuf.st_size)
        guard size > 0 else {
            close(fd)
            return MappedFile(pointer: nil, size: 0, fd: -1)
        }

        let ptr = mmap(nil, size, PROT_READ, MAP_PRIVATE, fd, 0)
        close(fd) // fd can be closed after mmap — mapping stays valid

        guard ptr != MAP_FAILED else {
            throw MMapError.mmapFailed(url.path, errno: errno)
        }

        // Advise kernel: sequential access pattern, prefetch ahead
        madvise(ptr, size, MADV_SEQUENTIAL)

        return MappedFile(pointer: ptr!, size: size, fd: -1)
    }

    /// Check if a file is large enough to benefit from mmap (>64KB).
    /// Below this threshold, `String(contentsOf:)` is faster due to mmap setup overhead.
    public static func shouldMMap(url: URL, threshold: Int = 65_536) -> Bool {
        var statBuf = stat()
        guard stat(url.path, &statBuf) == 0 else { return false }
        return Int(statBuf.st_size) > threshold
    }
}

/// A memory-mapped file that automatically unmaps on deallocation.
///
/// The mapped pages are valid for the lifetime of this object.
/// Access bytes via the `bytes` property or convert to `String` via `string`.
public final class MappedFile: @unchecked Sendable {
    private let pointer: UnsafeMutableRawPointer?
    public let size: Int
    private let fd: Int32

    init(pointer: UnsafeMutableRawPointer?, size: Int, fd: Int32) {
        self.pointer = pointer
        self.size = size
        self.fd = fd
    }

    deinit {
        if let pointer, size > 0 {
            munmap(pointer, size)
        }
    }

    /// Access the mapped bytes as an UnsafeBufferPointer.
    /// Valid for the lifetime of this MappedFile.
    public var bytes: UnsafeBufferPointer<UInt8> {
        guard let pointer, size > 0 else {
            return UnsafeBufferPointer(start: nil, count: 0)
        }
        return UnsafeBufferPointer(
            start: pointer.assumingMemoryBound(to: UInt8.self),
            count: size
        )
    }

    /// Convert mapped bytes to a String (uses UTF-8 decoding).
    /// This creates a String that references the mapped memory where possible.
    public var string: String {
        guard size > 0 else { return "" }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// Whether this mapping is empty (zero-size file).
    public var isEmpty: Bool { size == 0 }
}

/// Errors from mmap operations.
public enum MMapError: Error, LocalizedError, Sendable {
    case cannotOpen(String, errno: Int32)
    case cannotStat(String, errno: Int32)
    case mmapFailed(String, errno: Int32)

    public var errorDescription: String? {
        switch self {
        case .cannotOpen(let path, let err):
            return "Cannot open file '\(path)': \(String(cString: strerror(err)))"
        case .cannotStat(let path, let err):
            return "Cannot stat file '\(path)': \(String(cString: strerror(err)))"
        case .mmapFailed(let path, let err):
            return "mmap failed for '\(path)': \(String(cString: strerror(err)))"
        }
    }
}

#endif // canImport(Darwin) || canImport(Musl) || canImport(Glibc)
