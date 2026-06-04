#if !os(WASI)
//
//  ResourcePerformance.swift
//  RhoeMarkdownKit
//
//  Performance optimization for icon/emoji rendering
//

import Foundation
import RhoeMarkdownModel
#if canImport(os)
import os.log
#endif

/// Performance optimization configuration
public struct ResourcePerformanceConfig: Sendable {
    /// Maximum cache size in MB
    public let maxCacheSizeMB: Int
    
    /// Preload common resources on init
    public let preloadCommonResources: Bool
    
    /// Use concurrent loading for bulk operations
    public let useConcurrentLoading: Bool
    
    /// Cache preprocessed SVGs
    public let cacheProcessedSVGs: Bool
    
    /// Batch size for concurrent operations
    public let concurrentBatchSize: Int
    
    public init(
        maxCacheSizeMB: Int = 50,
        preloadCommonResources: Bool = true,
        useConcurrentLoading: Bool = true,
        cacheProcessedSVGs: Bool = true,
        concurrentBatchSize: Int = 10
    ) {
        self.maxCacheSizeMB = maxCacheSizeMB
        self.preloadCommonResources = preloadCommonResources
        self.useConcurrentLoading = useConcurrentLoading
        self.cacheProcessedSVGs = cacheProcessedSVGs
        self.concurrentBatchSize = concurrentBatchSize
    }
    
    public static let `default` = ResourcePerformanceConfig()
    public static let minimal = ResourcePerformanceConfig(
        maxCacheSizeMB: 10,
        preloadCommonResources: false,
        useConcurrentLoading: false,
        cacheProcessedSVGs: false
    )
    public static let aggressive = ResourcePerformanceConfig(
        maxCacheSizeMB: 100,
        preloadCommonResources: true,
        useConcurrentLoading: true,
        cacheProcessedSVGs: true,
        concurrentBatchSize: 20
    )
}

/// Optimized resource cache with size management
public final class OptimizedResourceCache: @unchecked Sendable {
    private let cache = NSCache<NSString, CacheEntry>()
    private let queue = DispatchQueue(label: "com.rhoemarkdownkit.cache", attributes: .concurrent)
    private var totalSize: Int = 0
    private let maxSize: Int
    
    private class CacheEntry: NSObject {
        let content: String
        let size: Int
        let accessCount: Int
        let lastAccessed: Date
        
        init(content: String, accessCount: Int = 1) {
            self.content = content
            self.size = content.utf8.count
            self.accessCount = accessCount
            self.lastAccessed = Date()
        }
        
        func incrementAccess() -> CacheEntry {
            return CacheEntry(content: content, accessCount: accessCount + 1)
        }
    }
    
    public init(maxSizeMB: Int) {
        self.maxSize = maxSizeMB * 1024 * 1024 // Convert to bytes
        cache.totalCostLimit = maxSize
        cache.countLimit = 5000 // Maximum number of entries
    }
    
    public func get(_ key: String) -> String? {
        queue.sync {
            let nsKey = key as NSString
            if let entry = cache.object(forKey: nsKey) {
                // Update access count and time
                let updatedEntry = entry.incrementAccess()
                cache.setObject(updatedEntry, forKey: nsKey, cost: entry.size)
                return entry.content
            }
            return nil
        }
    }
    
    public func set(_ key: String, value: String) {
        queue.async(flags: .barrier) {
            let nsKey = key as NSString
            let entry = CacheEntry(content: value)
            self.cache.setObject(entry, forKey: nsKey, cost: entry.size)
            self.totalSize += entry.size
        }
    }
    
    public func preload(_ items: [(key: String, value: String)]) {
        queue.async(flags: .barrier) {
            for (key, value) in items {
                let nsKey = key as NSString
                let entry = CacheEntry(content: value)
                self.cache.setObject(entry, forKey: nsKey, cost: entry.size)
                self.totalSize += entry.size
            }
        }
    }
    
    public func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAllObjects()
            self.totalSize = 0
        }
    }
}

/// SVG optimization utilities
public struct SVGOptimizer {
    
    /// Minify SVG by removing unnecessary whitespace and comments
    public static func minify(_ svg: String) -> String {
        var minified = svg
        
        // Remove comments
        minified = minified.replacingOccurrences(
            of: "<!--[\\s\\S]*?-->",
            with: "",
            options: .regularExpression
        )
        
        // Remove unnecessary whitespace
        minified = minified.replacingOccurrences(
            of: ">\\s+<",
            with: "><",
            options: .regularExpression
        )
        
        // Remove newlines and extra spaces
        minified = minified.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        
        // Trim
        minified = minified.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return minified
    }
    
    /// Process SVG for optimal rendering
    public static func optimize(_ svg: String, for size: CGSize? = nil) -> String {
        var optimized = minify(svg)
        
        // Add default attributes if missing
        if !optimized.contains("width=") && !optimized.contains("height=") {
            if let size = size {
                optimized = optimized.replacingOccurrences(
                    of: "<svg",
                    with: "<svg width=\"\(Int(size.width))\" height=\"\(Int(size.height))\""
                )
            }
        }
        
        // Ensure currentColor for stroke/fill if not specified
        if !optimized.contains("stroke=") && optimized.contains("stroke-") {
            optimized = optimized.replacingOccurrences(
                of: "<svg",
                with: "<svg stroke=\"currentColor\""
            )
        }
        
        return optimized
    }
}

/// Performance monitoring
public final class ResourcePerformanceMonitor: @unchecked Sendable {
    #if canImport(os)
    private static let logger = OSLog(subsystem: "com.rhoemarkdownkit", category: "performance")
    #endif
    
    public struct Metrics: Sendable {
        public let cacheHits: Int
        public let cacheMisses: Int
        public let averageLoadTime: TimeInterval
        public let totalLoadTime: TimeInterval
        public let resourcesLoaded: Int
        
        public var cacheHitRate: Double {
            let total = cacheHits + cacheMisses
            return total > 0 ? Double(cacheHits) / Double(total) : 0
        }
    }
    
    private var cacheHits = 0
    private var cacheMisses = 0
    private var totalLoadTime: TimeInterval = 0
    private var resourcesLoaded = 0
    private let queue = DispatchQueue(label: "com.rhoemarkdownkit.monitor")
    
    public init() {}
    
    public func recordCacheHit() {
        queue.async {
            self.cacheHits += 1
        }
    }
    
    public func recordCacheMiss() {
        queue.async {
            self.cacheMisses += 1
        }
    }
    
    public func recordLoadTime(_ time: TimeInterval) {
        queue.async {
            self.totalLoadTime += time
            self.resourcesLoaded += 1
            
            #if DEBUG && canImport(os)
            if time > 0.1 {
                os_log(.info, log: Self.logger, "Slow resource load: %.3f seconds", time)
            }
            #endif
        }
    }
    
    public func getMetrics() -> Metrics {
        queue.sync {
            Metrics(
                cacheHits: cacheHits,
                cacheMisses: cacheMisses,
                averageLoadTime: resourcesLoaded > 0 ? totalLoadTime / Double(resourcesLoaded) : 0,
                totalLoadTime: totalLoadTime,
                resourcesLoaded: resourcesLoaded
            )
        }
    }
    
    public func reset() {
        queue.async {
            self.cacheHits = 0
            self.cacheMisses = 0
            self.totalLoadTime = 0
            self.resourcesLoaded = 0
        }
    }
}

/// Batch loading utilities
public struct ResourceBatchLoader {
    
    /// Load multiple icons concurrently
    public static func loadIcons(
        _ icons: [(set: IconSet, name: String)],
        using manager: ResourceManager,
        config: ResourcePerformanceConfig = .default
    ) async -> [String: String] {
        var results: [String: String] = [:]
        
        if config.useConcurrentLoading {
            // Process in concurrent batches
            await withTaskGroup(of: (String, String?).self) { group in
                for chunk in icons.chunked(into: config.concurrentBatchSize) {
                    for (set, name) in chunk {
                        group.addTask {
                            let key = "\(set.rawValue).\(name)"
                            let svg = manager.loadIcon(set: set, name: name)
                            return (key, svg)
                        }
                    }
                    
                    // Collect batch results
                    for await (key, svg) in group {
                        if let svg = svg {
                            results[key] = svg
                        }
                    }
                }
            }
        } else {
            // Sequential loading
            for (set, name) in icons {
                let key = "\(set.rawValue).\(name)"
                if let svg = manager.loadIcon(set: set, name: name) {
                    results[key] = svg
                }
            }
        }
        
        return results
    }
    
    /// Preload common resources
    public static func preloadCommonResources(using manager: ResourceManager) async {
        let commonIcons: [(IconSet, String)] = [
            (.lucide, "home"), (.lucide, "settings"), (.lucide, "user"),
            (.lucide, "search"), (.lucide, "menu"), (.lucide, "close"),
            (.lucide, "arrow-left"), (.lucide, "arrow-right"),
            (.lucide, "check"), (.lucide, "x"), (.lucide, "plus"),
            (.heroicons, "home"), (.heroicons, "cog"), (.heroicons, "user")
        ]
        
        let commonEmojis = ["smile", "heart", "star", "thumbs-up", "fire", "rocket"]
        
        // Load icons
        _ = await loadIcons(commonIcons, using: manager)
        
        // Load emojis
        for emoji in commonEmojis {
            _ = manager.getEmoji(for: emoji)
        }
    }
}

// MARK: - Array Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
#endif // !os(WASI)
