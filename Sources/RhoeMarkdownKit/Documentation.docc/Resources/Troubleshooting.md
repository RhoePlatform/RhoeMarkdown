# Troubleshooting

Common issues and solutions for RhoeMarkdownKit.

## Overview

This guide helps you diagnose and resolve common issues when using RhoeMarkdownKit. Each section includes symptoms, causes, and step-by-step solutions.

## Installation Issues

### Swift Package Manager Fails

**Symptoms:**
- `Package.resolved` file conflicts
- Missing dependencies
- Version incompatibilities

**Solution:**
```bash
# Clean and reset
rm -rf .build
rm Package.resolved
swift package clean
swift package resolve
swift build
```

### Xcode Integration Issues

**Symptoms:**
- Package not appearing in Xcode
- Build errors in Xcode but not CLI
- Missing module errors

**Solution:**
1. Close Xcode
2. Delete derived data:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```
3. Reset package caches:
```bash
xcodebuild -resolvePackageDependencies
```
4. Reopen Xcode and wait for indexing

## Parsing Issues

### Document Not Parsing

**Symptoms:**
```swift
let result = await RhoeMarkdownKit.parse(markdown)
// result.document.blocks is empty
```

**Common Causes:**
1. **Not initialized:**
```swift
// ❌ Wrong
let result = await RhoeMarkdownKit.parse(markdown)

// ✅ Correct
try await RhoeMarkdownKit.initialize()
let result = await RhoeMarkdownKit.parse(markdown)
```

2. **Invalid encoding:**
```swift
// Check encoding
let data = markdown.data(using: .utf8)!
let string = String(data: data, encoding: .utf8)!
```

3. **Hidden characters:**
```swift
// Remove zero-width spaces and other invisible characters
let cleaned = markdown.replacingOccurrences(
    of: "\u{200B}\u{200C}\u{200D}\u{FEFF}",
    with: "",
    options: .regularExpression
)
```

### Incorrect Parse Results

**Symptoms:**
- Missing blocks
- Wrong nesting
- Broken lists

**Debugging:**
```swift
// Enable verbose parsing
let config = Configuration(
    debugMode: true,
    verboseLogging: true
)

let result = await RhoeMarkdownKit.parse(markdown, configuration: config)

// Check diagnostics
for diagnostic in result.diagnostics {
    print("\(diagnostic.severity): \(diagnostic.message)")
    if let location = diagnostic.location {
        print("  at line \(location.line), column \(location.column)")
    }
}

// Inspect AST
func printAST(_ node: ASTNode, depth: Int = 0) {
    let indent = String(repeating: "  ", count: depth)
    switch node {
    case .block(let block):
        print("\(indent)Block: \(block)")
    case .inline(let inline):
        print("\(indent)Inline: \(inline)")
    default:
        print("\(indent)Node: \(node)")
    }
}
```

### Performance Issues

**Symptoms:**
- Slow parsing for large documents
- High memory usage
- UI freezing

**Solutions:**

1. **Use streaming for large documents:**
```swift
// Instead of parsing all at once
let stream = RhoeMarkdownKit.streamParse(largeMarkdown)

for await chunk in stream {
    // Process incrementally
    updateUI(with: chunk)
}
```

2. **Enable caching:**
```swift
let cache = DocumentCache()
await cache.setLimit(100_000_000) // 100MB

if let cached = await cache.get(key) {
    return cached
}

let result = await RhoeMarkdownKit.parse(markdown)
await cache.cache(key, document: result.document)
```

3. **Use concurrent parsing:**
```swift
await withTaskGroup(of: Document.self) { group in
    for section in markdownSections {
        group.addTask {
            let result = await RhoeMarkdownKit.parse(section)
            return result.document
        }
    }
    
    var documents: [Document] = []
    for await doc in group {
        documents.append(doc)
    }
}
```

## Rendering Issues

### HTML Not Rendering Correctly

**Symptoms:**
- Missing styles
- Broken layout
- XSS vulnerabilities

**Solutions:**

1. **Check sanitization settings:**
```swift
let htmlConfig = HTMLConfiguration(
    sanitizeHTML: true,  // Enable for user content
    enableCSP: true,     // Add security headers
    prettyPrint: true    // For debugging
)

let html = RhoeMarkdownKit.renderHTML(document, configuration: htmlConfig)
```

2. **Add missing CSS:**
```swift
let css = """
<style>
    .markdown-body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
        line-height: 1.6;
        color: #333;
    }
    pre {
        background-color: #f6f8fa;
        padding: 16px;
        overflow: auto;
    }
    code {
        background-color: rgba(175, 184, 193, 0.2);
        padding: 0.2em 0.4em;
    }
</style>
"""

let fullHTML = css + html
```

### SwiftUI Rendering Issues

**Symptoms:**
- Views not updating
- Layout problems
- Memory leaks

**Solutions:**

1. **Use proper state management:**
```swift
struct MarkdownView: View {
    @State private var document: Document?
    let markdown: String
    
    var body: some View {
        Group {
            if let document = document {
                DocumentView(document: document)
            } else {
                ProgressView()
            }
        }
        .task {
            // Parse in background
            document = await parseMarkdown(markdown)
        }
    }
    
    @MainActor
    func parseMarkdown(_ text: String) async -> Document {
        let result = await RhoeMarkdownKit.parse(text)
        return result.document
    }
}
```

2. **Fix memory leaks:**
```swift
class ViewModel: ObservableObject {
    @Published var document: Document?
    private var parseTask: Task<Void, Never>?
    
    func parse(_ markdown: String) {
        // Cancel previous task
        parseTask?.cancel()
        
        parseTask = Task { @MainActor in
            let result = await RhoeMarkdownKit.parse(markdown)
            guard !Task.isCancelled else { return }
            self.document = result.document
        }
    }
    
    deinit {
        parseTask?.cancel()
    }
}
```

## Extension Issues

### Extension Not Loading

**Symptoms:**
- Custom blocks not recognized
- Extension not in pipeline
- No effect on output

**Debugging:**
```swift
// Check if extension is registered
let extensions = RhoeMarkdownKit.registeredExtensions()
print("Registered extensions: \(extensions.map { $0.identifier })")

// Verify extension priority
let order = RhoeMarkdownKit.extensionOrder()
print("Extension order: \(order)")

// Test extension directly
let extension = MyCustomExtension()
let transformed = try await extension.transform(node, context: context)
```

### Extension Conflicts

**Symptoms:**
- Extensions interfering with each other
- Unexpected transformations
- Parse errors

**Solutions:**

1. **Adjust priorities:**
```swift
struct HighPriorityExtension: MarkdownExtension {
    var priority: Int { 200 } // Higher = earlier
}

struct LowPriorityExtension: MarkdownExtension {
    var priority: Int { 50 } // Lower = later
}
```

2. **Check for conflicts:**
```swift
func detectConflicts() {
    let extensions = RhoeMarkdownKit.registeredExtensions()
    
    for ext1 in extensions {
        for ext2 in extensions where ext1.identifier != ext2.identifier {
            if ext1.priority == ext2.priority {
                print("⚠️ Priority conflict: \(ext1.identifier) and \(ext2.identifier)")
            }
        }
    }
}
```

## Security Issues

### XSS Vulnerabilities

**Symptoms:**
- JavaScript executing in rendered HTML
- Malicious content not filtered
- Security scanner warnings

**Solutions:**

```swift
// Validate input in the host application
let validator = MarkdownValidator()
try validator.validate(userInput, options: ValidationOptions(
    allowHTML: false,
    allowJavaScript: false,
    strictMode: true
))

// Sanitize rendered output before display
let sanitizer = HTMLSanitizer()
let safeHTML = sanitizer.sanitize(html)
```

### Resource Exhaustion

**Symptoms:**
- Parser hanging
- Memory exhaustion
- CPU spikes

**Solutions:**

```swift
// Set resource limits
let parser = SecureParser(
    limits: ParseLimits(
        maxExecutionTime: 5.0,
        maxMemory: 100_000_000,
        maxNestingDepth: 100,
        maxBlocks: 10_000
    )
)

do {
    let document = try await parser.parse(markdown)
} catch SecurityError.timeout {
    print("Parse timeout - document too complex")
} catch SecurityError.memoryExceeded(let used, let limit) {
    print("Memory limit exceeded: \(used) > \(limit)")
}
```

## Memory Issues

### Memory Leaks

**Detection:**
```swift
// Use Instruments or built-in monitoring
class MemoryMonitor {
    static func checkForLeaks() {
        let info = ProcessInfo.processInfo
        let memory = info.physicalMemory
        
        print("Memory usage: \(memory / 1024 / 1024) MB")
        
        // Force cleanup
        autoreleasepool {
            // Your code here
        }
    }
}
```

**Common causes and fixes:**

1. **Retain cycles in extensions:**
```swift
// ❌ Wrong - creates retain cycle
class MyExtension: MarkdownExtension {
    var callback: (() -> Void)?
    
    func setup() {
        callback = { [self] in  // Strong reference
            self.doSomething()
        }
    }
}

// ✅ Correct - weak reference
class MyExtension: MarkdownExtension {
    var callback: (() -> Void)?
    
    func setup() {
        callback = { [weak self] in
            self?.doSomething()
        }
    }
}
```

2. **Large document caching:**
```swift
// Implement cache eviction
actor DocumentCache {
    private var cache: [String: Document] = []
    private var accessTimes: [String: Date] = []
    
    func evictOldEntries() {
        let cutoff = Date().addingTimeInterval(-300) // 5 minutes
        
        for (key, time) in accessTimes {
            if time < cutoff {
                cache.removeValue(forKey: key)
                accessTimes.removeValue(forKey: key)
            }
        }
    }
}
```

## Concurrency Issues

### Data Races

**Symptoms:**
- Crashes in release builds
- Inconsistent results
- Thread sanitizer warnings

**Solutions:**

```swift
// Use actors for shared state
actor SharedState {
    private var documents: [String: Document] = [:]
    
    func add(_ key: String, document: Document) {
        documents[key] = document
    }
    
    func get(_ key: String) -> Document? {
        documents[key]
    }
}

// Use Sendable for thread safety
struct SafeConfiguration: Sendable {
    let options: [String: String]
}
```

### Deadlocks

**Prevention:**
```swift
// Avoid nested async calls on same actor
actor DocumentProcessor {
    // ❌ Can deadlock
    func process() async {
        await doStep1()
    }
    
    func doStep1() async {
        await self.doStep2() // Deadlock risk
    }
    
    // ✅ Better approach
    func process() async {
        let step1Result = await doStep1()
        let step2Result = await doStep2(step1Result)
    }
}
```

## Platform-Specific Issues

### macOS Issues

```swift
#if os(macOS)
// Handle macOS-specific paths
let documentsPath = FileManager.default.urls(
    for: .documentDirectory,
    in: .userDomainMask
).first!

// Use AppKit for clipboard
import AppKit
NSPasteboard.general.clearContents()
NSPasteboard.general.setString(text, forType: .string)
#endif
```

### iOS Issues

```swift
#if os(iOS)
// Handle iOS memory warnings
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleMemoryWarning),
    name: UIApplication.didReceiveMemoryWarningNotification,
    object: nil
)

@objc func handleMemoryWarning() {
    // Clear caches
    DocumentCache.shared.clear()
}
#endif
```

## Debug Techniques

### Enable Logging

```swift
// Set up debug logging
RhoeMarkdownKit.enableLogging(level: .debug)

// Custom logger
struct DebugLogger: LogHandler {
    func log(_ level: LogLevel, _ message: String, metadata: [String: Any]?) {
        print("[\(level)] \(message)")
        if let metadata = metadata {
            print("  Metadata: \(metadata)")
        }
    }
}

RhoeMarkdownKit.setLogHandler(DebugLogger())
```

### Profiling

```swift
// Measure performance
func profileParsing(_ markdown: String) async {
    let start = Date().timeIntervalSinceReferenceDate
    
    let result = await RhoeMarkdownKit.parse(markdown)
    
    let duration = Date().timeIntervalSinceReferenceDate - start
    print("Parse time: \(duration * 1000)ms")
    print("Blocks: \(result.document.blocks.count)")
    print("Memory: \(memoryUsage())MB")
}
```

## Common Error Messages

### "Module 'RhoeMarkdownKit' not found"

```bash
# Verify installation
swift package show-dependencies

# Clean build
swift package clean
swift build
```

### "Type does not conform to protocol 'Sendable'"

```swift
// Make types Sendable
struct MyData: Sendable {
    let value: String // Immutable = Sendable
}

// For classes, use @unchecked if thread-safe
final class MyCache: @unchecked Sendable {
    private let queue = DispatchQueue(label: "cache")
    private var data: [String: Any] = [:]
}
```

### "Actor-isolated property cannot be referenced"

```swift
// Use await for actor properties
actor MyActor {
    var value: String = ""
}

// ❌ Wrong
let actor = MyActor()
print(actor.value)

// ✅ Correct
let actor = MyActor()
print(await actor.value)
```

## Getting Help

### Resources

1. **GitHub Issues:** Report bugs at github.com/rhoesuite/rhoemarkdownkit/issues
2. **Discord:** Join our community at discord.gg/rhoesuite
3. **Stack Overflow:** Tag questions with `rhoemarkdownkit`
4. **Documentation:** Check docs.rhoesuite.com

### Diagnostic Information

When reporting issues, include:

```swift
// System info
print("RhoeMarkdownKit version: \(RhoeMarkdownKit.version)")
print("Swift version: \(getSwiftVersion())")
print("Platform: \(getPlatform())")

// Minimal reproduction
let markdown = "Your markdown here"
let config = Configuration(/* your config */)
let result = await RhoeMarkdownKit.parse(markdown, configuration: config)

// Error details
if let error = result.error {
    print("Error: \(error)")
    print("Stack trace: \(Thread.callStackSymbols)")
}
```

## Next Steps

- Explore <doc:Performance> for optimization
- Learn about <doc:Security> for safety
- See <doc:Testing> for debugging
- Check <doc:APIReference> for details
