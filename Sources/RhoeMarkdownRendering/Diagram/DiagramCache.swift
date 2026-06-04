import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Thread-safe in-memory cache for rendered diagram results.
///
/// Keyed by a hash of the diagram language and source code, avoiding
/// redundant external tool invocations for identical diagram source.
public final class DiagramCache: @unchecked Sendable {
    private var storage: [String: DiagramResult] = [:]
    #if !os(WASI)
    private let lock = NSLock()
    #endif

    public init() {}

    /// Look up a cached result for the given language and source.
    public func lookup(language: String, source: String) -> DiagramResult? {
        let key = cacheKey(language: language, source: source)
        #if !os(WASI)
        lock.lock()
        defer { lock.unlock() }
        #endif
        return storage[key]
    }

    /// Store a rendered result in the cache.
    public func store(language: String, source: String, result: DiagramResult) {
        let key = cacheKey(language: language, source: source)
        #if !os(WASI)
        lock.lock()
        defer { lock.unlock() }
        #endif
        storage[key] = result
    }

    /// Clear all cached results.
    public func clear() {
        #if !os(WASI)
        lock.lock()
        defer { lock.unlock() }
        #endif
        storage.removeAll()
    }

    /// Number of cached entries.
    public var count: Int {
        #if !os(WASI)
        lock.lock()
        defer { lock.unlock() }
        #endif
        return storage.count
    }

    // MARK: - Private

    private func cacheKey(language: String, source: String) -> String {
        let input = "\(language):\(source)"
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        // Simple hash fallback for platforms without CryptoKit
        return String(input.hashValue)
        #endif
    }
}
