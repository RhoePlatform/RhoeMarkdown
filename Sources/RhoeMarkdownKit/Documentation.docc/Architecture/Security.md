# Security

Comprehensive security guide for safe markdown processing and rendering.

## Overview

RhoeMarkdownKit implements defense-in-depth security measures to protect against common markdown-related vulnerabilities including XSS attacks, resource exhaustion, malicious content injection, and denial of service. This guide covers security best practices, threat mitigation, and secure configuration.

## Threat Model

### Common Attack Vectors

| Threat | Risk Level | Mitigation |
|--------|------------|------------|
| XSS (Cross-Site Scripting) | High | HTML sanitization, CSP headers |
| Resource Exhaustion | Medium | Parse limits, timeouts |
| Malicious Links | Medium | URL validation, allowlisting |
| Code Injection | High | Sandboxed execution |
| DoS (Denial of Service) | Medium | Rate limiting, size limits |
| Data Exfiltration | Low | Secure renderer, no external requests |
| Path Traversal | Medium | Path sanitization |
| Unicode Exploits | Low | Unicode normalization |

## Input Sanitization

### HTML Sanitization

```swift
// Secure HTML sanitizer
public struct HTMLSanitizer {
    private let allowedTags = Set([
        "p", "br", "strong", "em", "u", "s", "blockquote",
        "h1", "h2", "h3", "h4", "h5", "h6",
        "ul", "ol", "li", "a", "img", "code", "pre",
        "table", "thead", "tbody", "tr", "th", "td"
    ])
    
    private let allowedAttributes: [String: Set<String>] = [
        "a": ["href", "title"],
        "img": ["src", "alt", "title", "width", "height"],
        "code": ["class"],
        "pre": ["class"],
        "*": ["id", "class"] // Global attributes
    ]
    
    private let urlSchemeAllowlist = Set([
        "http", "https", "mailto", "tel"
    ])
    
    public func sanitize(_ html: String) -> String {
        var sanitized = html
        
        // Remove dangerous tags
        sanitized = removeDangerousTags(sanitized)
        
        // Sanitize attributes
        sanitized = sanitizeAttributes(sanitized)
        
        // Validate URLs
        sanitized = validateURLs(sanitized)
        
        // Escape special characters
        sanitized = escapeSpecialCharacters(sanitized)
        
        return sanitized
    }
    
    private func removeDangerousTags(_ html: String) -> String {
        // Remove script tags completely
        var result = html.replacingOccurrences(
            of: #"<script[^>]*>.*?</script>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Remove style tags
        result = result.replacingOccurrences(
            of: #"<style[^>]*>.*?</style>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Remove iframe tags
        result = result.replacingOccurrences(
            of: #"<iframe[^>]*>.*?</iframe>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Remove object/embed tags
        result = result.replacingOccurrences(
            of: #"<(object|embed)[^>]*>.*?</\1>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        return result
    }
    
    private func sanitizeAttributes(_ html: String) -> String {
        var result = html
        
        // Remove event handlers
        let eventHandlers = [
            "onclick", "onload", "onerror", "onmouseover",
            "onmouseout", "onkeydown", "onkeyup", "onfocus",
            "onblur", "onchange", "onsubmit"
        ]
        
        for handler in eventHandlers {
            result = result.replacingOccurrences(
                of: #"\s*\#(handler)\s*=\s*["'][^"']*["']"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Remove javascript: protocol
        result = result.replacingOccurrences(
            of: #"javascript\s*:"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Remove data: URLs except for images
        result = result.replacingOccurrences(
            of: #"(?<!img\s+[^>]*src\s*=\s*["'])data:[^"'\s]*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        return result
    }
    
    private func validateURLs(_ html: String) -> String {
        // Validate and sanitize URLs
        let urlPattern = #"(href|src)\s*=\s*["']([^"']+)["']"#
        let regex = try! NSRegularExpression(pattern: urlPattern)
        
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        var result = html
        
        for match in matches.reversed() {
            guard let urlRange = Range(match.range(at: 2), in: html) else { continue }
            let url = String(html[urlRange])
            
            if !isValidURL(url) {
                // Replace with safe placeholder
                result.replaceSubrange(urlRange, with: "#invalid-url")
            }
        }
        
        return result
    }
    
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        // Check scheme
        if let scheme = url.scheme?.lowercased() {
            return urlSchemeAllowlist.contains(scheme)
        }
        
        // Allow relative URLs
        return urlString.hasPrefix("/") || urlString.hasPrefix("#")
    }
}
```

### Markdown Input Validation

```swift
// Input validation for markdown
public struct MarkdownValidator {
    public struct ValidationOptions {
        let maxSize: Int = 10_000_000 // 10MB
        let maxNestingDepth: Int = 100
        let maxLinkLength: Int = 2048
        let allowHTML: Bool = false
        let allowJavaScript: Bool = false
        let strictMode: Bool = true
    }
    
    public func validate(_ markdown: String, options: ValidationOptions = ValidationOptions()) throws {
        // Check size limits
        guard markdown.count <= options.maxSize else {
            throw SecurityError.inputTooLarge(size: markdown.count, limit: options.maxSize)
        }
        
        // Check for malicious patterns
        try checkForMaliciousPatterns(markdown, options: options)
        
        // Validate nesting depth
        try validateNestingDepth(markdown, maxDepth: options.maxNestingDepth)
        
        // Validate URLs
        try validateURLs(in: markdown, maxLength: options.maxLinkLength)
        
        // Check for HTML if not allowed
        if !options.allowHTML {
            try checkForHTML(markdown)
        }
    }
    
    private func checkForMaliciousPatterns(_ markdown: String, options: ValidationOptions) throws {
        let dangerousPatterns = [
            #"<script[^>]*>"#,
            #"javascript\s*:"#,
            #"on\w+\s*="#,
            #"<iframe[^>]*>"#,
            #"<object[^>]*>"#,
            #"<embed[^>]*>"#
        ]
        
        for pattern in dangerousPatterns {
            if markdown.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                throw SecurityError.maliciousPattern(pattern: pattern)
            }
        }
        
        // Check for Unicode exploits
        try checkUnicodeExploits(markdown)
    }
    
    private func checkUnicodeExploits(_ text: String) throws {
        // Check for dangerous Unicode characters
        let dangerousCharacters: Set<Character> = [
            "\u{202E}", // Right-to-left override
            "\u{202D}", // Left-to-right override
            "\u{202C}", // Pop directional formatting
            "\u{2066}", // Left-to-right isolate
            "\u{2067}", // Right-to-left isolate
            "\u{2068}", // First strong isolate
            "\u{2069}"  // Pop directional isolate
        ]
        
        for char in text {
            if dangerousCharacters.contains(char) {
                throw SecurityError.dangerousUnicode(character: char)
            }
        }
        
        // Check for homograph attacks
        try checkHomographs(text)
    }
    
    private func checkHomographs(_ text: String) throws {
        // Detect potential homograph attacks in URLs
        let urlPattern = #"\[([^\]]+)\]\(([^)]+)\)"#
        let regex = try! NSRegularExpression(pattern: urlPattern)
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        for match in matches {
            guard let urlRange = Range(match.range(at: 2), in: text) else { continue }
            let url = String(text[urlRange])
            
            if containsSuspiciousHomographs(url) {
                throw SecurityError.homographAttack(url: url)
            }
        }
    }
    
    private func containsSuspiciousHomographs(_ url: String) -> Bool {
        // Check for mixed scripts that could be homograph attacks
        let scripts = url.unicodeScalars.compactMap { scalar in
            Unicode.Script(rawValue: scalar.properties.script)
        }
        
        let uniqueScripts = Set(scripts)
        
        // Suspicious if mixing Latin with Cyrillic or Greek
        return uniqueScripts.contains(.latin) && 
               (uniqueScripts.contains(.cyrillic) || uniqueScripts.contains(.greek))
    }
}
```

## Resource Protection

### Parse Limits

```swift
// Resource-limited parser
public actor SecureParser {
    private let limits: ParseLimits
    
    public struct ParseLimits {
        let maxExecutionTime: TimeInterval = 5.0
        let maxMemory: Int = 100_000_000 // 100MB
        let maxNestingDepth: Int = 100
        let maxBlocks: Int = 10_000
        let maxInlines: Int = 100_000
        let maxTableCells: Int = 10_000
    }
    
    public func parse(_ markdown: String) async throws -> Document {
        // Start resource monitoring
        let monitor = ResourceMonitor()
        monitor.start()
        
        // Parse with timeout
        let parseTask = Task {
            try await parseWithLimits(markdown)
        }
        
        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(limits.maxExecutionTime))
            parseTask.cancel()
            throw SecurityError.timeout
        }
        
        // Race between parsing and timeout
        let result = try await withTaskGroup(of: Document?.self) { group in
            group.addTask { try await parseTask.value }
            group.addTask { try await timeoutTask.value; return nil }
            
            for try await value in group {
                if let document = value {
                    group.cancelAll()
                    return document
                }
            }
            
            throw SecurityError.timeout
        }
        
        // Check resource usage
        let usage = monitor.stop()
        
        if usage.memory > limits.maxMemory {
            throw SecurityError.memoryExceeded(used: usage.memory, limit: limits.maxMemory)
        }
        
        return result
    }
    
    private func parseWithLimits(_ markdown: String) async throws -> Document {
        var blockCount = 0
        var inlineCount = 0
        var nestingDepth = 0
        
        let parser = CommonMarkParser()
        
        // Custom visitor that enforces limits
        let visitor = LimitedVisitor(
            maxBlocks: limits.maxBlocks,
            maxInlines: limits.maxInlines,
            maxDepth: limits.maxNestingDepth,
            onBlock: { blockCount += 1 },
            onInline: { inlineCount += 1 },
            onNesting: { depth in nestingDepth = max(nestingDepth, depth) }
        )
        
        let document = try await parser.parse(markdown, visitor: visitor)
        
        // Validate counts
        if blockCount > limits.maxBlocks {
            throw SecurityError.limitExceeded(type: "blocks", count: blockCount, limit: limits.maxBlocks)
        }
        
        if inlineCount > limits.maxInlines {
            throw SecurityError.limitExceeded(type: "inlines", count: inlineCount, limit: limits.maxInlines)
        }
        
        if nestingDepth > limits.maxNestingDepth {
            throw SecurityError.nestingTooDeep(depth: nestingDepth, limit: limits.maxNestingDepth)
        }
        
        return document
    }
}
```

### Memory Management

```swift
// Memory-safe operations
public struct MemorySafeOperations {
    
    // Chunked processing for large documents
    public static func processInChunks(_ markdown: String, chunkSize: Int = 65536) async -> AsyncStream<ProcessedChunk> {
        AsyncStream { continuation in
            Task {
                var offset = 0
                let length = markdown.count
                
                while offset < length {
                    autoreleasepool {
                        let end = min(offset + chunkSize, length)
                        let chunk = String(markdown[markdown.index(markdown.startIndex, offsetBy: offset)..<markdown.index(markdown.startIndex, offsetBy: end)])
                        
                        let processed = processChunk(chunk, offset: offset)
                        continuation.yield(processed)
                        
                        offset = end
                    }
                    
                    // Yield to prevent blocking
                    await Task.yield()
                }
                
                continuation.finish()
            }
        }
    }
    
    // Copy-on-write for efficient memory usage
    public struct COWDocument {
        private var storage: Storage
        
        private class Storage {
            var blocks: [Block]
            var refCount: Int = 1
            
            init(blocks: [Block]) {
                self.blocks = blocks
            }
            
            func copy() -> Storage {
                Storage(blocks: blocks)
            }
        }
        
        public mutating func modify() {
            if storage.refCount > 1 {
                storage.refCount -= 1
                storage = storage.copy()
            }
        }
    }
}
```

## Secure Rendering

### Content Security Policy

```swift
// CSP header generation
public struct ContentSecurityPolicy {
    public enum Directive: String {
        case defaultSrc = "default-src"
        case scriptSrc = "script-src"
        case styleSrc = "style-src"
        case imgSrc = "img-src"
        case fontSrc = "font-src"
        case connectSrc = "connect-src"
        case frameSrc = "frame-src"
        case objectSrc = "object-src"
        case mediaSrc = "media-src"
        case workerSrc = "worker-src"
    }
    
    private var directives: [Directive: [String]] = [:]
    
    public init(strict: Bool = true) {
        if strict {
            // Strict CSP for maximum security
            directives[.defaultSrc] = ["'self'"]
            directives[.scriptSrc] = ["'self'", "'unsafe-inline'"] // For inline code highlighting
            directives[.styleSrc] = ["'self'", "'unsafe-inline'"] // For inline styles
            directives[.imgSrc] = ["'self'", "data:", "https:"]
            directives[.fontSrc] = ["'self'", "data:"]
            directives[.connectSrc] = ["'self'"]
            directives[.frameSrc] = ["'none'"]
            directives[.objectSrc] = ["'none'"]
        }
    }
    
    public mutating func add(_ directive: Directive, sources: String...) {
        directives[directive] = (directives[directive] ?? []) + sources
    }
    
    public func headerValue() -> String {
        directives.map { directive, sources in
            "\(directive.rawValue) \(sources.joined(separator: " "))"
        }.joined(separator: "; ")
    }
}

// Secure HTML renderer
public struct SecureHTMLRenderer {
    private let sanitizer = HTMLSanitizer()
    private let csp = ContentSecurityPolicy(strict: true)
    
    public func render(_ document: Document) -> SecureHTML {
        let rawHTML = HTMLRenderer().render(document)
        let sanitized = sanitizer.sanitize(rawHTML)
        
        return SecureHTML(
            content: sanitized,
            cspHeader: csp.headerValue(),
            nonce: generateNonce()
        )
    }
    
    private func generateNonce() -> String {
        // Generate cryptographically secure nonce
        let data = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        return data.base64EncodedString()
    }
}

public struct SecureHTML {
    public let content: String
    public let cspHeader: String
    public let nonce: String
    
    public func httpResponse() -> (body: String, headers: [String: String]) {
        let headers = [
            "Content-Type": "text/html; charset=utf-8",
            "Content-Security-Policy": cspHeader,
            "X-Content-Type-Options": "nosniff",
            "X-Frame-Options": "DENY",
            "X-XSS-Protection": "1; mode=block",
            "Referrer-Policy": "strict-origin-when-cross-origin"
        ]
        
        let body = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta http-equiv="Content-Security-Policy" content="\(cspHeader)">
        </head>
        <body>
            \(content)
        </body>
        </html>
        """
        
        return (body, headers)
    }
}
```

## Sandboxed Execution

### Code Block Execution

```swift
// Sandboxed code execution for interactive examples
public actor CodeSandbox {
    
    public struct SandboxOptions {
        let allowNetworkAccess: Bool = false
        let allowFileSystemAccess: Bool = false
        let maxExecutionTime: TimeInterval = 1.0
        let maxMemory: Int = 50_000_000 // 50MB
        let allowedImports: Set<String> = ["Foundation", "Swift"]
    }
    
    public func execute(_ code: String, language: String, options: SandboxOptions = SandboxOptions()) async throws -> ExecutionResult {
        // Validate code before execution
        try validateCode(code, language: language, options: options)
        
        // Create isolated execution environment
        let sandbox = createSandbox(options: options)
        
        // Execute with resource limits
        let result = try await sandbox.execute(code, timeout: options.maxExecutionTime)
        
        // Sanitize output
        return sanitizeResult(result)
    }
    
    private func validateCode(_ code: String, language: String, options: SandboxOptions) throws {
        // Check for dangerous patterns
        let dangerousPatterns = [
            "Process", "NSTask", "Runtime.exec",
            "FileManager", "URL(fileURLWithPath:",
            "URLSession", "Network", "Socket"
        ]
        
        if !options.allowNetworkAccess {
            for pattern in dangerousPatterns {
                if code.contains(pattern) {
                    throw SecurityError.forbiddenAPI(api: pattern)
                }
            }
        }
        
        // Validate imports
        let imports = extractImports(from: code)
        for imp in imports {
            if !options.allowedImports.contains(imp) {
                throw SecurityError.forbiddenImport(module: imp)
            }
        }
    }
    
    private func createSandbox(options: SandboxOptions) -> ExecutionSandbox {
        ExecutionSandbox(
            memoryLimit: options.maxMemory,
            cpuLimit: 1.0,
            networkAccess: options.allowNetworkAccess,
            fileSystemAccess: options.allowFileSystemAccess
        )
    }
}
```

## Authentication & Authorization

### API Security

```swift
// Secure API access
public struct APISecurityManager {
    
    public func validateAPIKey(_ key: String) async throws -> APIPermissions {
        // Validate API key format
        guard isValidKeyFormat(key) else {
            throw SecurityError.invalidAPIKey
        }
        
        // Rate limiting
        try await checkRateLimit(for: key)
        
        // Verify key signature
        guard await verifyKeySignature(key) else {
            throw SecurityError.invalidSignature
        }
        
        // Get permissions
        return await getPermissions(for: key)
    }
    
    private func isValidKeyFormat(_ key: String) -> Bool {
        // API key format: rhoe_[env]_[random]_[checksum]
        let pattern = #"^rhoe_(prod|dev|test)_[a-zA-Z0-9]{32}_[a-f0-9]{8}$"#
        return key.range(of: pattern, options: .regularExpression) != nil
    }
    
    private func checkRateLimit(for key: String) async throws {
        let limiter = RateLimiter.shared
        let allowed = await limiter.checkLimit(
            key: key,
            limit: 1000, // 1000 requests per hour
            window: .hour
        )
        
        if !allowed {
            throw SecurityError.rateLimitExceeded
        }
    }
}

// Rate limiting
public actor RateLimiter {
    static let shared = RateLimiter()
    
    private var buckets: [String: TokenBucket] = [:]
    
    struct TokenBucket {
        var tokens: Int
        var lastRefill: Date
        let capacity: Int
        let refillRate: TimeInterval
    }
    
    public func checkLimit(key: String, limit: Int, window: Window) async -> Bool {
        let now = Date()
        
        if var bucket = buckets[key] {
            // Refill tokens
            let elapsed = now.timeIntervalSince(bucket.lastRefill)
            let tokensToAdd = Int(elapsed / bucket.refillRate)
            bucket.tokens = min(bucket.capacity, bucket.tokens + tokensToAdd)
            bucket.lastRefill = now
            
            // Check if we have tokens
            if bucket.tokens > 0 {
                bucket.tokens -= 1
                buckets[key] = bucket
                return true
            }
            
            return false
        } else {
            // New bucket
            buckets[key] = TokenBucket(
                tokens: limit - 1,
                lastRefill: now,
                capacity: limit,
                refillRate: window.seconds / Double(limit)
            )
            return true
        }
    }
    
    enum Window {
        case second, minute, hour, day
        
        var seconds: TimeInterval {
            switch self {
            case .second: return 1
            case .minute: return 60
            case .hour: return 3600
            case .day: return 86400
            }
        }
    }
}
```

## Security Configuration

### Secure Defaults

```swift
// Security configuration
public struct SecurityConfiguration {
    // Input security
    public var maxInputSize: Int = 10_000_000 // 10MB
    public var maxNestingDepth: Int = 100
    public var allowHTML: Bool = false
    public var allowJavaScript: Bool = false
    
    // Output security
    public var sanitizeHTML: Bool = true
    public var enableCSP: Bool = true
    public var strictMode: Bool = true
    
    // Resource limits
    public var maxParseTime: TimeInterval = 5.0
    public var maxRenderTime: TimeInterval = 2.0
    public var maxMemory: Int = 100_000_000 // 100MB
    
    // Network security
    public var allowExternalImages: Bool = false
    public var allowExternalLinks: Bool = true
    public var validateURLs: Bool = true
    
    // API security
    public var requireAuthentication: Bool = false
    public var enableRateLimiting: Bool = true
    public var maxRequestsPerHour: Int = 1000
    
    public static let `default` = SecurityConfiguration()
    
    public static let strict = SecurityConfiguration(
        allowHTML: false,
        allowJavaScript: false,
        sanitizeHTML: true,
        enableCSP: true,
        strictMode: true,
        allowExternalImages: false,
        allowExternalLinks: false,
        validateURLs: true,
        requireAuthentication: true,
        enableRateLimiting: true,
        maxRequestsPerHour: 100
    )
}

// Note:
// RhoeMarkdownKit does not currently ship a built-in security manager.
// Apply input validation and output sanitization in the host application.
```

## Security Monitoring

### Audit Logging

```swift
// Security audit logging
public actor SecurityAuditor {
    private let logger = RhoeLogger.shared
    private let category = LogCategory(name: "Security", subsystem: "RhoeMarkdownKit")
    
    public func logSecurityEvent(_ event: SecurityEvent) {
        let metadata: [String: String] = [
            "timestamp": ISO8601DateFormatter().string(from: event.timestamp),
            "severity": event.severity.rawValue,
            "type": event.type.rawValue,
            "source": event.source,
            "details": event.details
        ]
        
        switch event.severity {
        case .critical:
            logger.error("Security Event", metadata: metadata, category: category)
        case .high:
            logger.error("Security Event", metadata: metadata, category: category)
        case .medium:
            logger.warning("Security Event", metadata: metadata, category: category)
        case .low:
            logger.info("Security Event", metadata: metadata, category: category)
        }
        
        // Store for analysis
        Task {
            await storeEvent(event)
        }
    }
    
    private func storeEvent(_ event: SecurityEvent) async {
        // Store in secure audit log
    }
}

public struct SecurityEvent {
    public enum Severity: String {
        case critical, high, medium, low
    }
    
    public enum EventType: String {
        case xssAttempt = "xss_attempt"
        case injectionAttempt = "injection_attempt"
        case resourceExhaustion = "resource_exhaustion"
        case maliciousPattern = "malicious_pattern"
        case rateLimitExceeded = "rate_limit_exceeded"
        case authenticationFailure = "auth_failure"
    }
    
    let timestamp: Date
    let severity: Severity
    let type: EventType
    let source: String
    let details: String
}
```

## Security Best Practices

### For Developers

1. **Always sanitize user input** - Never trust user-provided markdown
2. **Use strict mode by default** - Enable all security features
3. **Implement rate limiting** - Prevent abuse and DoS
4. **Validate all URLs** - Check schemes and domains
5. **Escape HTML output** - Prevent XSS attacks
6. **Set resource limits** - Prevent resource exhaustion
7. **Use CSP headers** - Additional browser protection
8. **Log security events** - Monitor for attacks
9. **Keep dependencies updated** - Security patches
10. **Regular security audits** - Penetration testing

### For Users

1. **Don't disable security features** - They protect you
2. **Be cautious with external content** - Verify sources
3. **Report suspicious behavior** - Help improve security
4. **Use HTTPS only** - Encrypted connections
5. **Validate rendered output** - Check for anomalies

## Security Checklist

- [ ] Input validation enabled
- [ ] HTML sanitization active
- [ ] CSP headers configured
- [ ] Resource limits set
- [ ] Rate limiting enabled
- [ ] URL validation active
- [ ] Audit logging configured
- [ ] Security monitoring active
- [ ] Regular security updates
- [ ] Incident response plan

## Vulnerability Reporting

Report security vulnerabilities to: security@rhoesuite.com

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## Next Steps

- Explore <doc:Testing> for security testing
- Learn about <doc:Performance> for DoS prevention
- Review the security configuration guidance above for deployment settings.
- Review the monitoring guidance above for runtime security signals.
