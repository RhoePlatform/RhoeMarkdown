import Foundation
import RhoeMarkdownModel

/// Block-level render cache for near-instant re-rendering.
///
/// Caches rendered HTML (or other format output) per block, keyed by a
/// lightweight hash of the block's AST structure. On re-render, unchanged
/// blocks (typically 90-95% of the document per edit) serve cached output
/// instead of re-rendering.
///
/// Designed for the "fast full re-parse + render caching" architecture:
/// 1. Full parallel re-parse on every edit (fast: <30ms for 10K lines)
/// 2. Re-render with cache: only changed blocks are re-rendered
/// 3. Cache hit rate: ~95% for typical single-paragraph edits
///
/// Thread-safe via Swift's value semantics (struct with dictionary).
public struct RenderCache: Sendable {

    /// Cached render entries keyed by block content hash.
    private var cache: [UInt64: CacheEntry] = [:]

    /// Number of cache hits since last reset.
    public private(set) var hitCount: Int = 0

    /// Number of cache misses since last reset.
    public private(set) var missCount: Int = 0

    /// Cache hit rate (0.0 to 1.0).
    public var hitRate: Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0 }
        return Double(hitCount) / Double(total)
    }

    public init() {}

    // MARK: - Cache Operations

    /// Look up cached HTML for a block. Returns nil on cache miss.
    public mutating func lookup(_ block: Block) -> String? {
        let hash = hashBlock(block)
        if let entry = cache[hash] {
            hitCount += 1
            return entry.html
        }
        missCount += 1
        return nil
    }

    /// Store rendered HTML for a block.
    public mutating func store(_ block: Block, html: String) {
        let hash = hashBlock(block)
        cache[hash] = CacheEntry(html: html, timestamp: Date())
    }

    /// Render a block, using cache if available, otherwise rendering and caching.
    public mutating func renderOrCache(
        _ block: Block,
        render: (Block) -> String
    ) -> String {
        if let cached = lookup(block) {
            return cached
        }
        let html = render(block)
        store(block, html: html)
        return html
    }

    /// Clear all cached entries.
    public mutating func clear() {
        cache.removeAll()
        hitCount = 0
        missCount = 0
    }

    /// Number of entries in the cache.
    public var count: Int { cache.count }

    /// Reset hit/miss counters without clearing the cache.
    public mutating func resetCounters() {
        hitCount = 0
        missCount = 0
    }

    // MARK: - Block Hashing

    /// Compute a lightweight hash of a block's structure for cache keying.
    /// Uses FNV-1a hash for speed (no cryptographic strength needed).
    private func hashBlock(_ block: Block) -> UInt64 {
        var hasher = FNV1aHasher()
        hashBlockInto(block, hasher: &hasher)
        return hasher.finalize()
    }

    private func hashBlockInto(_ block: Block, hasher: inout FNV1aHasher) {
        switch block {
        case .paragraph(let inlines, let attrs):
            hasher.combine(1)
            hashInlinesInto(inlines, hasher: &hasher)
            hashAttrsInto(attrs, hasher: &hasher)

        case .heading(let level, let content, let attrs):
            hasher.combine(2)
            hasher.combine(UInt64(level))
            hashInlinesInto(content, hasher: &hasher)
            hashAttrsInto(attrs, hasher: &hasher)

        case .section(let level, let title, let children, let attrs):
            hasher.combine(3)
            hasher.combine(UInt64(level))
            hashInlinesInto(title, hasher: &hasher)
            for child in children { hashBlockInto(child, hasher: &hasher) }
            hashAttrsInto(attrs, hasher: &hasher)

        case .codeBlock(let lang, let content, let attrs):
            hasher.combine(4)
            hasher.combine(lang ?? "")
            hasher.combine(content)
            hashAttrsInto(attrs, hasher: &hasher)

        case .blockQuote(let children, let attrs):
            hasher.combine(5)
            for child in children { hashBlockInto(child, hasher: &hasher) }
            hashAttrsInto(attrs, hasher: &hasher)

        case .list(_, let items, let attrs):
            hasher.combine(6)
            hasher.combine(UInt64(items.count))
            for item in items {
                for child in item.content { hashBlockInto(child, hasher: &hasher) }
            }
            hashAttrsInto(attrs, hasher: &hasher)

        case .table(let headers, let rows, _, let attrs):
            hasher.combine(7)
            hasher.combine(UInt64(headers.count))
            hasher.combine(UInt64(rows.count))
            hashAttrsInto(attrs, hasher: &hasher)

        case .admonition(let type, let title, let content, _, let attrs):
            hasher.combine(8)
            hasher.combine(type)
            hasher.combine(title ?? "")
            for child in content { hashBlockInto(child, hasher: &hasher) }
            hashAttrsInto(attrs, hasher: &hasher)

        case .formalBlock(let family, let title, let number, let content, let attrs):
            hasher.combine(9)
            hasher.combine(family)
            hasher.combine(number ?? "")
            if let title { hashInlinesInto(title, hasher: &hasher) }
            for child in content { hashBlockInto(child, hasher: &hasher) }
            hashAttrsInto(attrs, hasher: &hasher)

        case .mathBlock(let expr, let attrs):
            hasher.combine(10)
            hasher.combine(expr)
            hashAttrsInto(attrs, hasher: &hasher)

        case .div(let content, let attrs):
            hasher.combine(11)
            for child in content { hashBlockInto(child, hasher: &hasher) }
            hashAttrsInto(attrs, hasher: &hasher)

        default:
            // For all other block types, use a simple discriminator + description
            hasher.combine(99)
            hasher.combine(String(describing: block).hashValue)
        }
    }

    private func hashInlinesInto(_ inlines: [Inline], hasher: inout FNV1aHasher) {
        for inline in inlines {
            switch inline {
            case .text(let t):
                hasher.combine(1)
                hasher.combine(t)
            case .emphasis(let c):
                hasher.combine(2)
                hashInlinesInto(c, hasher: &hasher)
            case .strong(let c):
                hasher.combine(3)
                hashInlinesInto(c, hasher: &hasher)
            case .codeSpan(let c, _):
                hasher.combine(4)
                hasher.combine(c)
            case .link(let text, let url, _, _):
                hasher.combine(5)
                hashInlinesInto(text, hasher: &hasher)
                hasher.combine(url)
            case .inlineMath(let expr, _):
                hasher.combine(6)
                hasher.combine(expr)
            default:
                hasher.combine(99)
                hasher.combine(String(describing: inline).hashValue)
            }
        }
    }

    private func hashAttrsInto(_ attrs: RhoeMarkdownKit.Attributes, hasher: inout FNV1aHasher) {
        if let id = attrs.id { hasher.combine(id) }
        for cls in attrs.classes { hasher.combine(cls) }
        for (k, v) in attrs.keyValues.sorted(by: { $0.key < $1.key }) {
            hasher.combine(k)
            hasher.combine(v)
        }
    }
}

// MARK: - Cache Entry

private struct CacheEntry: Sendable {
    let html: String
    let timestamp: Date
}

// MARK: - FNV-1a Hasher (Fast, non-cryptographic)

/// Lightweight FNV-1a hash for render cache keys.
/// Fast and well-distributed for cache indexing.
private struct FNV1aHasher {
    private var hash: UInt64 = 14695981039346656037 // FNV offset basis

    mutating func combine(_ value: UInt64) {
        hash ^= value
        hash &*= 1099511628211 // FNV prime
    }

    mutating func combine(_ value: Int) {
        combine(UInt64(bitPattern: Int64(value)))
    }

    mutating func combine(_ string: String) {
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
    }

    func finalize() -> UInt64 { hash }
}
