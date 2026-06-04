# Performance

Optimize RhoeMarkdownKit for blazing-fast parsing and rendering with SIMD acceleration.

## Overview

RhoeMarkdownKit is engineered for exceptional performance, utilizing SIMD operations, parallel processing, streaming parsers, and intelligent caching. This guide covers optimization strategies, benchmarks, and best practices for achieving maximum performance.

## Performance Metrics

### Parsing Benchmarks

| Document Size | Parse Time | Memory Usage | Throughput |
|--------------|------------|--------------|------------|
| Small (< 10KB) | < 2ms | < 1MB | 5MB/s |
| Medium (< 100KB) | < 20ms | < 5MB | 5MB/s |
| Large (< 1MB) | < 200ms | < 50MB | 5MB/s |
| Huge (< 10MB) | < 2s | < 500MB | 5MB/s |

### Feature Performance

| Feature | Operation Time | Memory Overhead |
|---------|---------------|-----------------|
| Syntax Highlighting | < 1ms/KB | Minimal |
| Slide Parsing | < 5ms/slide | < 100KB/slide |
| Grid Evaluation | < 10ms/100 cells | < 1MB |
| Shape Rendering | < 1ms/shape | < 10KB/shape |
| Icon Loading | < 0.1ms (cached) | < 5KB/icon |

## SIMD Optimization

### Vectorized Operations

RhoeMarkdownKit leverages SIMD for parallel text processing:

```swift
import RhoePerformanceKit

// SIMD-accelerated character scanning
let optimizer = SIMDOptimizer()

// Process 16 characters simultaneously
let result = optimizer.scanForDelimiters(
    text: markdown,
    delimiters: ["#", "*", "_", "[", "]", "`"]
)

// 4x faster than sequential scanning
```

### SIMD String Operations

```swift
// Vectorized string comparison
let matcher = SIMDStringMatcher()
let matches = matcher.findAll(
    pattern: "```",
    in: markdown,
    options: .parallel
)

// Parallel whitespace trimming
let trimmed = optimizer.trimWhitespace(
    lines: markdownLines,
    mode: .simd
)
```

### Memory Alignment

```swift
// Ensure SIMD-friendly memory alignment
let alignedBuffer = AlignedBuffer(
    size: markdown.count,
    alignment: 64 // Cache line size
)

// Copy data to aligned buffer for SIMD processing
alignedBuffer.copy(from: markdown)
let processed = optimizer.process(alignedBuffer)
```

## Streaming Parser

### Large Document Handling

For documents > 1MB, use streaming:

```swift
// Stream parse large documents
let stream = RhoeMarkdownKit.createStream(from: largeMarkdown)

for await chunk in stream {
    // Process chunk (typically 64KB)
    let partialResult = await processChunk(chunk)
    
    // Merge results incrementally
    accumulator.merge(partialResult)
}

// Final document assembly
let document = accumulator.finalize()
```

### Progressive Rendering

```swift
// Render as you parse
let renderStream = RhoeMarkdownKit.streamRender(markdown) { chunk in
    // Update UI progressively
    await MainActor.run {
        contentView.append(chunk)
    }
}

// User sees content immediately
await renderStream.start()
```

## Parallel Processing

### Concurrent Parsing

```swift
// Parse multiple sections in parallel
let sections = markdown.split(by: "%%%") // Slide delimiters

let results = await withTaskGroup(of: ParseResult.self) { group in
    for section in sections {
        group.addTask {
            await parseSection(section)
        }
    }
    
    var results: [ParseResult] = []
    for await result in group {
        results.append(result)
    }
    return results
}
```

### Parallel Feature Extraction

```swift
// Extract features concurrently
async let slides = SlideEnhancedParser().parseEnhanced(markdown)
async let grids = GridLayoutEngine().findAllGrids(markdown)
async let shapes = ShapeSystemRenderer().findAllShapes(markdown)
async let icons = IconSystemManager.shared.findAllIcons(markdown)

// Await all results
let (slidesResult, gridsResult, shapesResult, iconsResult) = 
    await (slides, grids, shapes, icons)
```

## Caching Strategies

### Multi-Level Cache

```swift
// L1: In-memory cache (fastest)
let memoryCache = MemoryCache<String, ParseResult>(
    maxSize: 100_000_000, // 100MB
    ttl: 300 // 5 minutes
)

// L2: Disk cache (persistent)
let diskCache = DiskCache<String, ParseResult>(
    directory: .cachesDirectory,
    maxSize: 1_000_000_000, // 1GB
    ttl: 86400 // 24 hours
)

// L3: Shared cache (across processes)
let sharedCache = SharedCache<String, ParseResult>(
    suiteName: "com.rhoe.markdown",
    maxSize: 500_000_000 // 500MB
)
```

### Cache Key Generation

```swift
// Efficient cache key generation
func cacheKey(for markdown: String) -> String {
    var hasher = Hasher()
    hasher.combine(markdown)
    hasher.combine(RhoeMarkdownKit.version)
    hasher.combine(configuration.hashValue)
    return "\(hasher.finalize())"
}

// Check cache before parsing
if let cached = memoryCache[key] {
    return cached // Instant return
}
```

### Smart Invalidation

```swift
// Invalidate only affected cache entries
cache.invalidate { entry in
    entry.markdown.contains(modifiedSection)
}

// Partial cache updates
cache.update(key: key) { oldValue in
    var updated = oldValue
    updated.applyDelta(changes)
    return updated
}
```

## Memory Management

### Efficient Memory Usage

```swift
// Use value types for small data
struct LightweightBlock {
    let type: BlockType
    let range: Range<String.Index>
    // No string copies, just references
}

// Copy-on-write for large data
struct Document {
    private var storage: Storage
    
    mutating func modify() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = storage.copy()
        }
        // Now safe to modify
    }
}
```

### Memory Pools

```swift
// Reuse memory buffers
let bufferPool = BufferPool(
    bufferSize: 65536, // 64KB
    maxBuffers: 100
)

let buffer = bufferPool.acquire()
defer { bufferPool.release(buffer) }

// Use buffer for parsing
parseIntoBuffer(markdown, buffer: buffer)
```

### Automatic Memory Pressure Handling

```swift
// Monitor memory pressure
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil,
    queue: .main
) { _ in
    // Clear caches under memory pressure
    memoryCache.clear()
    bufferPool.drain()
    
    // Switch to streaming mode
    ParserSettings.shared.useStreaming = true
}
```

## Lazy Evaluation

### Deferred Processing

```swift
// Don't process until needed
struct LazyDocument {
    private let markdown: String
    private var _blocks: [Block]?
    
    var blocks: [Block] {
        mutating get {
            if _blocks == nil {
                _blocks = parseBlocks(markdown)
            }
            return _blocks!
        }
    }
}
```

### On-Demand Feature Loading

```swift
// Load features only when accessed
class Document {
    private lazy var slides = SlideEnhancedParser().parse(markdown)
    private lazy var grids = GridLayoutEngine().parse(markdown)
    private lazy var shapes = ShapeSystemRenderer().parse(markdown)
    
    func getSlides() async -> [Slide] {
        await slides
    }
}
```

## Optimization Techniques

### String Optimization

```swift
// Use String.Index for efficient navigation
extension String {
    func fastScan(for delimiter: Character) -> [String.Index] {
        var indices: [String.Index] = []
        var currentIndex = startIndex
        
        while currentIndex < endIndex {
            if self[currentIndex] == delimiter {
                indices.append(currentIndex)
            }
            currentIndex = index(after: currentIndex)
        }
        
        return indices
    }
}

// Avoid repeated string allocations
let scanner = Scanner(string: markdown)
scanner.charactersToBeSkipped = nil // Don't create substrings
```

### Regex Optimization

```swift
// Compile regex once
let headingRegex = try! NSRegularExpression(
    pattern: "^#{1,6}\\s+(.+)$",
    options: .anchorsMatchLines
)

// Cache compiled patterns
struct RegexCache {
    static let heading = try! Regex("^#{1,6}\\s+(.+)$")
    static let bold = try! Regex("\\*\\*(.+?)\\*\\*")
    static let italic = try! Regex("\\*(.+?)\\*")
    // ... more patterns
}
```

### Algorithm Selection

```swift
// Choose optimal algorithms based on input
func selectParser(for markdown: String) -> Parser {
    let size = markdown.count
    
    if size < 1000 {
        // Small documents: simple parser
        return SimpleParser()
    } else if size < 100_000 {
        // Medium documents: optimized parser
        return OptimizedParser()
    } else {
        // Large documents: streaming parser
        return StreamingParser()
    }
}
```

## Benchmarking Tools

### Performance Measurement

```swift
// Built-in benchmarking
let benchmark = Benchmark("Parse Large Document")

benchmark.measure {
    _ = await RhoeMarkdownKit.parse(largeMarkdown)
}

print("Average: \(benchmark.average)ms")
print("Median: \(benchmark.median)ms")
print("95th percentile: \(benchmark.percentile95)ms")
```

### Profiling Integration

```swift
// Integrate with Instruments
import os.signpost

let log = OSLog(subsystem: "RhoeMarkdownKit", category: "Performance")
let signpostID = OSSignpostID(log: log)

os_signpost(.begin, log: log, name: "Parse", signpostID: signpostID)
let result = await parse(markdown)
os_signpost(.end, log: log, name: "Parse", signpostID: signpostID)
```

### Memory Profiling

```swift
// Track memory allocations
let memoryBefore = MemoryLayout<Document>.size * documentCount

autoreleasepool {
    let documents = parseDocuments(markdowns)
    
    let memoryAfter = MemoryLayout<Document>.size * documents.count
    let memoryUsed = memoryAfter - memoryBefore
    
    print("Memory used: \(memoryUsed / 1024 / 1024)MB")
}
```

## Performance Configuration

### Tuning Parameters

```swift
// Configure performance settings
RhoeMarkdownKit.configure(
    performance: PerformanceConfiguration(
        enableSIMD: true,
        parallelThreshold: 10_000, // Use parallel for > 10KB
        cacheSize: 100_000_000, // 100MB cache
        streamingThreshold: 1_000_000, // Stream > 1MB
        maxConcurrency: ProcessInfo.processInfo.processorCount
    )
)
```

### Adaptive Performance

```swift
// Automatically adjust based on device
let config = PerformanceConfiguration.adaptive()

// Detects device capabilities
if ProcessInfo.processInfo.processorCount >= 8 {
    config.maxConcurrency = 8
    config.enableParallelParsing = true
}

if ProcessInfo.processInfo.physicalMemory > 8_000_000_000 {
    config.cacheSize = 500_000_000 // 500MB on high-memory devices
}
```

## Platform-Specific Optimizations

### macOS Optimizations

```swift
#if os(macOS)
// Use Grand Central Dispatch for better performance
let queue = DispatchQueue(
    label: "markdown.parsing",
    qos: .userInitiated,
    attributes: .concurrent
)

queue.async {
    // Parallel parsing on macOS
}
#endif
```

### iOS Optimizations

```swift
#if os(iOS)
// Optimize for mobile constraints
if UIDevice.current.batteryState == .unplugged {
    // Reduce processing when on battery
    config.maxConcurrency = 2
    config.enableSIMD = false // Save battery
}
#endif
```

## Best Practices

### Do's

1. **Initialize early** - Pre-warm caches and parsers
2. **Use appropriate APIs** - Stream for large, parse for small
3. **Cache aggressively** - Cache parsed results and rendered output
4. **Batch operations** - Process multiple items together
5. **Profile regularly** - Monitor performance metrics
6. **Test on real devices** - Don't rely only on simulator
7. **Use async/await** - Leverage Swift concurrency

### Don'ts

1. **Don't parse repeatedly** - Cache parsed results
2. **Don't block main thread** - Use async operations
3. **Don't ignore memory** - Monitor and respond to pressure
4. **Don't over-optimize** - Profile first, optimize second
5. **Don't disable caching** - It's essential for performance
6. **Don't parse unnecessary** - Use lazy evaluation

## Performance Checklist

- [ ] Enable SIMD optimization
- [ ] Configure appropriate cache sizes
- [ ] Use streaming for large documents
- [ ] Implement lazy evaluation
- [ ] Profile with Instruments
- [ ] Test with real-world data
- [ ] Monitor memory usage
- [ ] Optimize regex patterns
- [ ] Use parallel processing
- [ ] Implement progressive rendering

## Troubleshooting

### Slow Parsing

- Check document size and use streaming if > 1MB
- Verify SIMD is enabled
- Profile to identify bottlenecks
- Check for complex regex patterns

### High Memory Usage

- Enable streaming mode
- Reduce cache sizes
- Use value types where possible
- Implement memory pressure handling

### UI Freezing

- Move parsing to background queue
- Use progressive rendering
- Implement chunked processing
- Add loading indicators

## Next Steps

- Explore the system design overview in this documentation catalog.
- Learn about SIMD parsing in <doc:SIMD-Optimization>.
- See <doc:Streaming-Parser> for large documents.
- Check <doc:Benchmarking-Tools> for measurement.
