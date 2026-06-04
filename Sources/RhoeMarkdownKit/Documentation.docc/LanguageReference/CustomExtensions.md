# Custom Extensions

Create powerful markdown extensions with RhoeMarkdownKit's plugin architecture.

## Overview

RhoeMarkdownKit's extensible architecture allows you to create custom block types, inline elements, renderers, and processing pipelines. This guide covers everything from simple custom blocks to complex multi-phase extensions.

## Extension Architecture

### Extension Protocol

```swift
// Core extension protocol
public protocol MarkdownExtension: Sendable {
    /// Unique identifier for the extension
    var identifier: String { get }
    
    /// Display name
    var name: String { get }
    
    /// Processing priority (higher = earlier)
    var priority: Int { get }
    
    /// Supported markdown flavors
    var supportedFlavors: Set<MarkdownFlavor> { get }
    
    /// Pre-process raw markdown
    func preprocess(_ markdown: String) async throws -> String
    
    /// Transform AST nodes
    func transform(_ node: ASTNode, context: TransformContext) async throws -> ASTNode
    
    /// Post-process rendered output
    func postprocess(_ output: String, format: OutputFormat) async throws -> String
}

// Default implementation
extension MarkdownExtension {
    public var priority: Int { 100 }
    public var supportedFlavors: Set<MarkdownFlavor> { [.commonMark, .gfm] }
    
    public func preprocess(_ markdown: String) async throws -> String {
        markdown // No preprocessing by default
    }
    
    public func postprocess(_ output: String, format: OutputFormat) async throws -> String {
        output // No postprocessing by default
    }
}
```

## Creating Custom Blocks

### Simple Custom Block

```swift
// Define a custom alert block
struct AlertBlock: CustomBlock {
    enum AlertType: String {
        case info, warning, error, success
    }
    
    let type: AlertType
    let title: String?
    let content: [Block]
    
    static var identifier: String { "alert" }
    
    // Parse from markdown syntax
    static func parse(from markdown: String) -> AlertBlock? {
        // Format: :::alert{type="warning" title="Important"}
        let pattern = #"^:::alert\{([^}]+)\}$"#
        guard let match = markdown.firstMatch(of: try! Regex(pattern)) else {
            return nil
        }
        
        let attributes = parseAttributes(String(match.1))
        let type = AlertType(rawValue: attributes["type"] ?? "info") ?? .info
        let title = attributes["title"]
        
        return AlertBlock(type: type, title: title, content: [])
    }
    
    // Render to HTML
    func renderHTML() -> String {
        let typeClass = "alert-\(type.rawValue)"
        var html = "<div class=\"alert \(typeClass)\">"
        
        if let title = title {
            html += "<h4>\(escapeHTML(title))</h4>"
        }
        
        html += "<div class=\"alert-content\">"
        for block in content {
            html += HTMLRenderer().renderBlock(block)
        }
        html += "</div></div>"
        
        return html
    }
    
    // Render to SwiftUI
    func renderSwiftUI() -> some View {
        AlertView(type: type, title: title, content: content)
    }
}

// SwiftUI view for the alert
struct AlertView: View {
    let type: AlertBlock.AlertType
    let title: String?
    let content: [Block]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                HStack {
                    Image(systemName: iconName)
                        .foregroundColor(color)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(color)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(content.enumerated()), id: \.offset) { _, block in
                    BlockView(block: block)
                }
            }
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private var iconName: String {
        switch type {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }
    
    private var color: Color {
        switch type {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
}
```

### Complex Custom Block

```swift
// Video embed block with advanced features
struct VideoBlock: CustomBlock {
    let url: URL
    let title: String?
    let autoplay: Bool
    let loop: Bool
    let muted: Bool
    let controls: Bool
    let poster: URL?
    let startTime: TimeInterval?
    let endTime: TimeInterval?
    
    static var identifier: String { "video" }
    
    static func parse(from markdown: String) -> VideoBlock? {
        // Format: @[video](url){autoplay loop muted start=10 end=30}
        let pattern = #"@\[video\]\(([^)]+)\)(?:\{([^}]+)\})?"#
        guard let match = markdown.firstMatch(of: try! Regex(pattern)),
              let url = URL(string: String(match.1)) else {
            return nil
        }
        
        var attributes: [String: String] = [:]
        if match.count > 2 {
            attributes = parseAttributes(String(match.2))
        }
        
        return VideoBlock(
            url: url,
            title: attributes["title"],
            autoplay: attributes["autoplay"] != nil,
            loop: attributes["loop"] != nil,
            muted: attributes["muted"] != nil,
            controls: attributes["controls"] != "false",
            poster: attributes["poster"].flatMap(URL.init),
            startTime: attributes["start"].flatMap(TimeInterval.init),
            endTime: attributes["end"].flatMap(TimeInterval.init)
        )
    }
    
    func renderHTML() -> String {
        var html = "<video"
        
        if autoplay { html += " autoplay" }
        if loop { html += " loop" }
        if muted { html += " muted" }
        if controls { html += " controls" }
        
        if let poster = poster {
            html += " poster=\"\(poster.absoluteString)\""
        }
        
        html += ">"
        html += "<source src=\"\(url.absoluteString)\" type=\"video/mp4\">"
        html += "Your browser does not support the video tag."
        html += "</video>"
        
        return html
    }
}
```

## Creating Custom Inline Elements

### Custom Inline Extension

```swift
// Spoiler text that reveals on hover/tap
struct SpoilerInline: CustomInline {
    let content: String
    let hint: String?
    
    static var identifier: String { "spoiler" }
    
    // Parse ||spoiler text|| or ||hint:spoiler text||
    static func parse(from markdown: String) -> SpoilerInline? {
        let pattern = #"\|\|(?:([^:]+):)?([^|]+)\|\|"#
        guard let match = markdown.firstMatch(of: try! Regex(pattern)) else {
            return nil
        }
        
        let hint = match.count > 2 ? String(match.1) : nil
        let content = String(match[match.count - 1])
        
        return SpoilerInline(content: content, hint: hint)
    }
    
    func renderHTML() -> String {
        let hintAttr = hint.map { " title=\"\(escapeHTML($0))\"" } ?? ""
        return "<span class=\"spoiler\"\(hintAttr)>\(escapeHTML(content))</span>"
    }
    
    func renderSwiftUI() -> some View {
        SpoilerView(content: content, hint: hint)
    }
}

struct SpoilerView: View {
    let content: String
    let hint: String?
    @State private var isRevealed = false
    
    var body: some View {
        Text(isRevealed ? content : hint ?? "•••")
            .foregroundColor(isRevealed ? .primary : .secondary)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isRevealed ? Color.clear : Color.gray.opacity(0.2))
            )
            .onTapGesture {
                withAnimation {
                    isRevealed.toggle()
                }
            }
    }
}
```

## Advanced Extension Example

### Mermaid Diagram Extension

```swift
// Full Mermaid diagram support
struct MermaidExtension: MarkdownExtension {
    let identifier = "mermaid"
    let name = "Mermaid Diagrams"
    let priority = 200 // High priority
    
    func transform(_ node: ASTNode, context: TransformContext) async throws -> ASTNode {
        guard case .block(let block) = node,
              case .codeBlock(let language, let content, let attrs) = block,
              language == "mermaid" else {
            return node
        }
        
        // Parse Mermaid syntax
        let diagram = try await parseMermaid(content)
        
        // Convert to custom block
        return .custom(MermaidBlock(
            diagram: diagram,
            content: content,
            attributes: attrs
        ))
    }
    
    private func parseMermaid(_ content: String) async throws -> MermaidDiagram {
        let parser = MermaidParser()
        return try await parser.parse(content)
    }
}

struct MermaidBlock: CustomBlock {
    let diagram: MermaidDiagram
    let content: String
    let attributes: Attributes
    
    static var identifier: String { "mermaid-diagram" }
    
    func renderHTML() -> String {
        // Generate SVG from diagram
        let svg = diagram.toSVG()
        
        return """
        <div class="mermaid-diagram">
            \(svg)
            <details>
                <summary>View source</summary>
                <pre><code>\(escapeHTML(content))</code></pre>
            </details>
        </div>
        """
    }
    
    func renderSwiftUI() -> some View {
        MermaidDiagramView(diagram: diagram)
    }
}
```

## Creating Custom Renderers

### JSON Renderer

```swift
// Render markdown to JSON
struct JSONRenderer: Renderer {
    func render(_ document: Document) async throws -> String {
        let jsonDocument = JSONDocument(from: document)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(jsonDocument)
        return String(data: data, encoding: .utf8)!
    }
}

struct JSONDocument: Codable {
    let version: String = "1.0"
    let blocks: [JSONBlock]
    let metadata: DocumentMetadata
    
    init(from document: Document) {
        self.blocks = document.blocks.map(JSONBlock.from)
        self.metadata = document.metadata
    }
}

struct JSONBlock: Codable {
    let type: String
    let content: JSONContent
    
    static func from(_ block: Block) -> JSONBlock {
        switch block {
        case .paragraph(let inlines, _):
            return JSONBlock(
                type: "paragraph",
                content: .inlines(inlines.map(JSONInline.from))
            )
        case .heading(let level, let content, _):
            return JSONBlock(
                type: "heading",
                content: .heading(level: level, text: plainText(from: content))
            )
        // ... more cases
        default:
            return JSONBlock(type: "unknown", content: .text(""))
        }
    }
}
```

### LaTeX Renderer

```swift
// Render markdown to LaTeX
struct LaTeXRenderer: Renderer {
    func render(_ document: Document) async throws -> String {
        var latex = """
        \\documentclass{article}
        \\usepackage[utf8]{inputenc}
        \\usepackage{hyperref}
        \\usepackage{graphicx}
        \\usepackage{listings}
        
        \\begin{document}
        
        """
        
        for block in document.blocks {
            latex += renderBlock(block)
            latex += "\n\n"
        }
        
        latex += "\\end{document}"
        
        return latex
    }
    
    private func renderBlock(_ block: Block) -> String {
        switch block {
        case .heading(let level, let content, _):
            let command = headingCommand(for: level)
            return "\\\(command){\(renderInlines(content))}"
            
        case .paragraph(let inlines, _):
            return renderInlines(inlines)
            
        case .codeBlock(let language, let content, _):
            return """
            \\begin{lstlisting}[language=\(language ?? "text")]
            \(content)
            \\end{lstlisting}
            """
            
        case .list(let type, let items, _):
            let env = listEnvironment(for: type)
            var latex = "\\begin{\(env)}\n"
            for item in items {
                latex += "\\item "
                latex += item.content.map(renderBlock).joined(" ")
                latex += "\n"
            }
            latex += "\\end{\(env)}"
            return latex
            
        default:
            return ""
        }
    }
    
    private func headingCommand(for level: Int) -> String {
        switch level {
        case 1: return "section"
        case 2: return "subsection"
        case 3: return "subsubsection"
        case 4: return "paragraph"
        default: return "subparagraph"
        }
    }
}
```

## Extension Registration

### Registering Extensions

```swift
// Register at app startup
@main
struct MyApp: App {
    init() {
        Task {
            // Initialize RhoeMarkdownKit
            try await RhoeMarkdownKit.initialize()
            
            // Register custom extensions
            RhoeMarkdownKit.registerExtension(AlertExtension())
            RhoeMarkdownKit.registerExtension(VideoExtension())
            RhoeMarkdownKit.registerExtension(MermaidExtension())
            RhoeMarkdownKit.registerExtension(SpoilerExtension())
            
            // Register custom renderers
            RhoeMarkdownKit.registerRenderer(JSONRenderer(), for: .json)
            RhoeMarkdownKit.registerRenderer(LaTeXRenderer(), for: .latex)
        }
    }
}
```

### Extension Configuration

```swift
// Configure extension behavior
struct ExtensionConfiguration {
    var enabledExtensions: Set<String> = []
    var disabledExtensions: Set<String> = []
    var extensionSettings: [String: Any] = [:]
    
    mutating func enable(_ identifier: String) {
        enabledExtensions.insert(identifier)
        disabledExtensions.remove(identifier)
    }
    
    mutating func disable(_ identifier: String) {
        disabledExtensions.insert(identifier)
        enabledExtensions.remove(identifier)
    }
    
    mutating func configure<T>(_ identifier: String, setting: String, value: T) {
        var settings = extensionSettings[identifier] as? [String: Any] ?? [:]
        settings[setting] = value
        extensionSettings[identifier] = settings
    }
}

// Apply configuration
RhoeMarkdownKit.configure(extensions: ExtensionConfiguration(
    enabledExtensions: ["mermaid", "video", "alert"],
    extensionSettings: [
        "mermaid": ["theme": "dark", "securityLevel": "loose"],
        "video": ["maxWidth": 800, "defaultControls": true]
    ]
))
```

## Processing Pipeline Extensions

### Multi-Phase Extension

```swift
// Extension that modifies multiple phases
struct SmartQuotesExtension: MarkdownExtension {
    let identifier = "smart-quotes"
    let name = "Smart Quotes"
    
    // Phase 1: Preprocess markdown
    func preprocess(_ markdown: String) async throws -> String {
        var processed = markdown
        
        // Convert straight quotes to smart quotes
        processed = processed.replacingOccurrences(of: "\"", with: """)
        processed = processed.replacingOccurrences(of: "'", with: "'")
        
        // Fix quote pairs
        processed = fixQuotePairs(processed)
        
        return processed
    }
    
    // Phase 2: Transform AST
    func transform(_ node: ASTNode, context: TransformContext) async throws -> ASTNode {
        guard case .inline(let inline) = node,
              case .text(let text) = inline else {
            return node
        }
        
        // Apply typography improvements
        let improved = applyTypography(text)
        return .inline(.text(improved))
    }
    
    // Phase 3: Post-process output
    func postprocess(_ output: String, format: OutputFormat) async throws -> String {
        guard format == .html else { return output }
        
        // Add typography CSS
        let css = """
        <style>
        .smart-quotes { font-feature-settings: "ss01", "ss02"; }
        </style>
        """
        
        return css + output
    }
    
    private func fixQuotePairs(_ text: String) -> String {
        // Smart quote pairing logic
        var result = ""
        var inQuote = false
        
        for char in text {
            if char == """ {
                result += inQuote ? """ : """
                inQuote.toggle()
            } else {
                result.append(char)
            }
        }
        
        return result
    }
}
```

## Extension Testing

### Unit Testing Extensions

```swift
import Testing
@testable import RhoeMarkdownKit

@Test("Alert block parsing")
func testAlertBlockParsing() async throws {
    let markdown = """
    :::alert{type="warning" title="Important"}
    This is a warning message.
    :::
    """
    
    let result = await RhoeMarkdownKit.parse(markdown)
    
    guard let alertBlock = result.document.blocks.first as? AlertBlock else {
        Issue.record("Failed to parse alert block")
        return
    }
    
    #expect(alertBlock.type == .warning)
    #expect(alertBlock.title == "Important")
}

@Test("Extension priority ordering")
func testExtensionPriority() async throws {
    let ext1 = TestExtension(priority: 100)
    let ext2 = TestExtension(priority: 200)
    let ext3 = TestExtension(priority: 50)
    
    RhoeMarkdownKit.registerExtension(ext1)
    RhoeMarkdownKit.registerExtension(ext2)
    RhoeMarkdownKit.registerExtension(ext3)
    
    let order = RhoeMarkdownKit.extensionOrder()
    
    #expect(order == [ext2.identifier, ext1.identifier, ext3.identifier])
}
```

## Performance Considerations

### Lazy Extension Loading

```swift
// Load extensions on-demand
class ExtensionLoader {
    private var loadedExtensions: [String: MarkdownExtension] = [:]
    
    func loadExtension(_ identifier: String) async throws -> MarkdownExtension {
        if let cached = loadedExtensions[identifier] {
            return cached
        }
        
        let extension = try await loadFromDisk(identifier)
        loadedExtensions[identifier] = extension
        return extension
    }
    
    private func loadFromDisk(_ identifier: String) async throws -> MarkdownExtension {
        // Dynamic loading logic
    }
}
```

### Extension Caching

```swift
// Cache extension results
actor ExtensionCache {
    private var cache: [CacheKey: CacheEntry] = [:]
    
    struct CacheKey: Hashable {
        let extensionId: String
        let input: String
    }
    
    struct CacheEntry {
        let output: ASTNode
        let timestamp: Date
    }
    
    func getCached(_ key: CacheKey) -> ASTNode? {
        guard let entry = cache[key],
              Date().timeIntervalSince(entry.timestamp) < 300 else {
            return nil
        }
        return entry.output
    }
    
    func cache(_ key: CacheKey, output: ASTNode) {
        cache[key] = CacheEntry(output: output, timestamp: Date())
    }
}
```

## Extension Distribution

### Creating Extension Packages

```swift
// Package.swift for distributing extensions
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyMarkdownExtensions",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(
            name: "MyMarkdownExtensions",
            targets: ["MyMarkdownExtensions"]
        )
    ],
    dependencies: [
        .package(path: "../RhoeMarkdownKit")
    ],
    targets: [
        .target(
            name: "MyMarkdownExtensions",
            dependencies: ["RhoeMarkdownKit"]
        ),
        .testTarget(
            name: "MyMarkdownExtensionsTests",
            dependencies: ["MyMarkdownExtensions"]
        )
    ]
)
```

## Best Practices

1. **Keep extensions focused** - One feature per extension
2. **Use appropriate phases** - Preprocess, transform, or postprocess
3. **Cache when possible** - Avoid redundant processing
4. **Test thoroughly** - Cover edge cases and interactions
5. **Document behavior** - Clear usage instructions
6. **Handle errors gracefully** - Don't break the pipeline
7. **Consider performance** - Profile extension impact
8. **Version compatibility** - Support multiple RhoeMarkdownKit versions

## Extension Ideas

- **Citation Management** - Academic citations and bibliography
- **Music Notation** - ABC notation or LilyPond integration
- **Chemical Formulas** - Chemistry notation support
- **Chess Notation** - PGN chess game notation
- **Timeline Visualization** - Historical timeline rendering
- **Graph Plotting** - Mathematical function graphs
- **QR Codes** - Embedded QR code generation
- **Social Media Embeds** - Twitter, Instagram, YouTube embeds

## Next Steps

- Explore <doc:Testing> for extension testing
- Learn about <doc:Performance> for optimization
- Use the extension distribution guidance above for packaging.
- Check <doc:Security> for safe extensions
