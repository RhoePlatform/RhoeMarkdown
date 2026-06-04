# API Reference

Complete API documentation for RhoeMarkdownKit with detailed method signatures and examples.

## Core APIs

### RhoeMarkdownKit

The main entry point for markdown parsing and rendering.

```swift
@available(macOS 15.0, iOS 18.0, *)
public enum RhoeMarkdownKit {
    /// Initialize the markdown system
    public static func initialize() async throws
    
    /// Parse markdown to AST
    public static func parse(
        _ markdown: String,
        configuration: Configuration = .default
    ) async -> ParseResult
    
    /// Render document to HTML
    public static func renderHTML(
        _ document: Document,
        configuration: HTMLConfiguration = .default
    ) -> String
    
    /// Convert markdown directly to HTML
    public static func toHTML(
        _ markdown: String,
        configuration: Configuration = .default,
        htmlConfiguration: HTMLConfiguration = .default
    ) async -> String
    
    /// Stream parse large documents
    public static func streamParse(
        _ markdown: String,
        chunkSize: Int = 65536
    ) -> AsyncStream<ParseChunk>
    
    /// Register markdown extension
    public static func registerExtension(_ extension: MarkdownExtension)
    
    /// Register custom renderer
    public static func registerRenderer(
        _ renderer: Renderer,
        for format: OutputFormat
    )
    
    /// Configure security settings
    public static func configureSecurity(_ config: SecurityConfiguration)
}
```

## Document Model

### Document

The root AST node representing a parsed markdown document.

```swift
public struct Document: Sendable {
    /// Document blocks
    public let blocks: [Block]
    
    /// Document metadata
    public let metadata: DocumentMetadata
    
    /// Source map for debugging
    public let sourceMap: SourceMap?
    
    /// Initialize with blocks
    public init(
        blocks: [Block],
        metadata: DocumentMetadata = DocumentMetadata(),
        sourceMap: SourceMap? = nil
    )
}

public struct DocumentMetadata: Sendable, Codable {
    /// Document title
    public var title: String?
    
    /// Document authors
    public var authors: [String]
    
    /// Creation date
    public var date: Date?
    
    /// Document tags
    public var tags: [String]
    
    /// Custom metadata
    public var custom: [String: String]
}
```

### Block

Block-level elements in the document.

```swift
public enum Block: Sendable {
    /// Paragraph with inline content
    case paragraph([Inline], Attributes)
    
    /// Heading with level (1-6)
    case heading(Int, [Inline], Attributes)
    
    /// Code block with optional language
    case codeBlock(String?, String, Attributes)
    
    /// Block quote
    case blockQuote([Block], Attributes)
    
    /// List (unordered, ordered, or task)
    case list(ListType, [ListItem], Attributes)
    
    /// Table with headers and rows
    case table([TableCell], [[TableCell]], Attributes)
    
    /// Horizontal rule
    case thematicBreak(Attributes)
    
    /// HTML block
    case htmlBlock(String, Attributes)
    
    /// Custom block from extensions
    case custom(CustomBlock)
}

public enum ListType: Sendable {
    case unordered
    case ordered(start: Int)
    case task
}

public struct ListItem: Sendable {
    public let content: [Block]
    public let checked: Bool?
    public let attributes: Attributes
}
```

### Inline

Inline elements within blocks.

```swift
public enum Inline: Sendable {
    /// Plain text
    case text(String)
    
    /// Emphasis (italic)
    case emphasis([Inline])
    
    /// Strong emphasis (bold)
    case strong([Inline])
    
    /// Strikethrough
    case strikethrough([Inline])
    
    /// Code span
    case code(String)
    
    /// Link with URL and optional title
    case link(URL, String?, [Inline])
    
    /// Image with URL, alt text, and optional title
    case image(URL, String, String?)
    
    /// Line break
    case lineBreak
    
    /// Soft break
    case softBreak
    
    /// HTML inline
    case htmlInline(String)
    
    /// Math inline
    case math(String)
    
    /// Custom inline from extensions
    case custom(CustomInline)
}
```

## Parsing

### Configuration

Configure parsing behavior.

```swift
public struct Configuration: Sendable {
    /// Enable GitHub Flavored Markdown
    public var enableGFM: Bool = true
    
    /// Enable tables
    public var enableTables: Bool = true
    
    /// Enable strikethrough
    public var enableStrikethrough: Bool = true
    
    /// Enable task lists
    public var enableTaskLists: Bool = true
    
    /// Enable autolinks
    public var enableAutolinks: Bool = true
    
    /// Enable smart punctuation
    public var enableSmartPunctuation: Bool = false
    
    /// Enable footnotes
    public var enableFootnotes: Bool = false
    
    /// Enable math
    public var enableMath: Bool = false
    
    /// Enable raw HTML
    public var enableRawHTML: Bool = false
    
    /// Maximum nesting depth
    public var maxNestingDepth: Int = 100
    
    /// Maximum document size
    public var maxDocumentSize: Int = 10_000_000
    
    /// Default configuration
    public static let `default` = Configuration()
    
    /// Strict CommonMark configuration
    public static let commonMark = Configuration(
        enableGFM: false,
        enableTables: false,
        enableStrikethrough: false,
        enableTaskLists: false,
        enableAutolinks: false
    )
}
```

### ParseResult

Result of parsing operation.

```swift
public struct ParseResult: Sendable {
    /// Parsed document
    public let document: Document
    
    /// Parse diagnostics
    public let diagnostics: [Diagnostic]
    
    /// Parse statistics
    public let statistics: ParseStatistics
    
    /// Parse duration
    public let duration: TimeInterval
}

public struct Diagnostic: Sendable {
    public enum Severity: Sendable {
        case error
        case warning
        case info
        case hint
    }
    
    /// Diagnostic severity
    public let severity: Severity
    
    /// Error message
    public let message: String
    
    /// Source location
    public let location: SourceLocation?
    
    /// Suggested fix
    public let fix: String?
}
```

## Rendering

### HTMLConfiguration

Configure HTML rendering.

```swift
public struct HTMLConfiguration: Sendable {
    /// Pretty print HTML
    public var prettyPrint: Bool = false
    
    /// Enable syntax highlighting
    public var enableSyntaxHighlighting: Bool = true
    
    /// Sanitize HTML output
    public var sanitizeHTML: Bool = true
    
    /// Add IDs to headings
    public var addHeadingIDs: Bool = true
    
    /// Generate table of contents
    public var generateTOC: Bool = false
    
    /// Wrap code blocks
    public var wrapCodeBlocks: Bool = true
    
    /// Custom CSS classes
    public var customClasses: [String: String] = [:]
    
    /// Default configuration
    public static let `default` = HTMLConfiguration()
}
```

### Renderer Protocol

Protocol for custom renderers.

```swift
public protocol Renderer: Sendable {
    /// Render document to output format
    func render(_ document: Document) async throws -> String
    
    /// Render single block
    func renderBlock(_ block: Block) -> String
    
    /// Render inline elements
    func renderInlines(_ inlines: [Inline]) -> String
}

public enum OutputFormat: String, Sendable, Equatable, CaseIterable {
    case html
    case latex
    case typst
    case docx
    case pdf
    case epub
}
```

## Extensions

### MarkdownExtension Protocol

Protocol for creating extensions.

```swift
public protocol MarkdownExtension: Sendable {
    /// Extension identifier
    var identifier: String { get }
    
    /// Display name
    var name: String { get }
    
    /// Processing priority
    var priority: Int { get }
    
    /// Pre-process markdown
    func preprocess(_ markdown: String) async throws -> String
    
    /// Transform AST nodes
    func transform(
        _ node: ASTNode,
        context: TransformContext
    ) async throws -> ASTNode
    
    /// Post-process output
    func postprocess(
        _ output: String,
        format: OutputFormat
    ) async throws -> String
}

public struct TransformContext: Sendable {
    /// Current document
    public let document: Document
    
    /// Parent node
    public let parent: ASTNode?
    
    /// Node depth
    public let depth: Int
    
    /// Extension configuration
    public let configuration: [String: Any]
}
```

### CustomBlock Protocol

Protocol for custom block types.

```swift
public protocol CustomBlock: Sendable {
    /// Block identifier
    static var identifier: String { get }
    
    /// Parse from markdown
    static func parse(from markdown: String) -> Self?
    
    /// Render to HTML
    func renderHTML() -> String
    
    /// Render to other formats
    func render(format: OutputFormat) -> String
}
```

## Revolutionary Features

### Slide System

Enhanced slide presentation system.

```swift
public struct SlideEnhancedParser {
    /// Parse enhanced presentation
    public func parseEnhanced(_ markdown: String) async throws -> EnhancedPresentation
}

public struct EnhancedPresentation: Sendable {
    /// Presentation slides
    public let slides: [EnhancedSlide]
    
    /// Global settings
    public let settings: PresentationSettings
    
    /// Theme configuration
    public let theme: SlideTheme
}

public struct EnhancedSlide: Sendable {
    /// Slide content
    public let content: Document
    
    /// Slide metadata
    public let metadata: SlideMetadata
    
    /// Build animations
    public let builds: [BuildAnimation]
}

public struct SlideMetadata: Sendable {
    /// Slide title
    public var title: String?
    
    /// Transition type
    public var transition: SlideTransition
    
    /// Transition duration
    public var duration: TimeInterval
    
    /// Speaker notes
    public var speakerNotes: String?
    
    /// Layout type
    public var layout: SlideLayout
}

public enum SlideTransition: String, Sendable, CaseIterable {
    case none, fade, slide, zoom, flip, cube, morph, dissolve, parallax
}

public enum SlideLayout: String, Sendable, CaseIterable {
    case standard, twoColumn, centered, title, blank, grid
}
```

### Grid System

Excel-style grid layouts.

```swift
public struct GridLayoutEngine {
    /// Parse grid from markdown
    public func parseGrid(_ markdown: String) async throws -> GridLayout
    
    /// Evaluate formulas in grid
    public func evaluateFormulas(_ grid: GridLayout) async -> GridLayout
}

public struct GridLayout: Sendable {
    /// Grid dimensions
    public let rows: Int
    public let columns: Int
    
    /// Grid cells
    public let cells: [GridCell]
    
    /// Cell styles
    public let styles: [CellReference: CellStyle]
}

public struct GridCell: Sendable {
    /// Cell reference
    public let reference: CellReference
    
    /// Cell content
    public var content: String
    
    /// Cell formula
    public var formula: Formula?
    
    /// Merged cells
    public var span: CellSpan?
}

public struct CellReference: Sendable, Hashable {
    /// Row index (1-based)
    public let row: Int
    
    /// Column index (1-based)
    public let column: Int
    
    /// Initialize from notation (e.g., "A1")
    public init(notation: String) throws
}
```

### Shape System

Semantic shape rendering.

```swift
public struct ShapeSystemRenderer {
    /// Render shape to SVG
    public func renderSVG(_ shape: Shape) -> String
    
    /// Compose diagram from shapes
    public func composeDiagram(_ shapes: [Shape]) -> String
}

public struct Shape: Sendable, Identifiable {
    /// Unique identifier
    public let id: UUID
    
    /// Shape type
    public let type: ShapeType
    
    /// Shape label
    public var label: String?
    
    /// Position
    public var position: ShapePosition
    
    /// Style attributes
    public var style: ShapeStyle
    
    /// Connections to other shapes
    public var connections: [ShapeConnection]
}

public enum ShapeType: String, Sendable, CaseIterable {
    // Basic shapes
    case rectangle, square, circle, ellipse
    case triangle, pentagon, hexagon, octagon
    case diamond, parallelogram, trapezoid
    
    // Arrows
    case arrowUp = "arrow-up"
    case arrowDown = "arrow-down"
    case arrowLeft = "arrow-left"
    case arrowRight = "arrow-right"
    
    // Technical
    case server, database, cloud, network
    case computer, mobile, tablet, storage
    
    // ... 70+ total shapes
}
```

### Icon System

Professional icon libraries.

```swift
public struct IconSystemManager {
    /// Get icon by name and provider
    public func getIcon(
        _ name: String,
        provider: IconProvider
    ) async -> IconDefinition?
    
    /// Search icons
    public func searchIcons(
        query: String,
        providers: Set<IconProvider> = Set(IconProvider.allCases)
    ) async -> [IconSearchResult]
}

public enum IconProvider: String, Sendable, CaseIterable {
    case fluent = "fluent"           // 4000+ icons
    case heroicons = "heroicons"      // 300+ icons
    case fontawesome = "fontawesome"  // 6000+ icons
}

public struct IconDefinition: Sendable {
    /// Icon name
    public let name: String
    
    /// Provider
    public let provider: IconProvider
    
    /// SVG path data
    public let path: String
    
    /// Viewbox dimensions
    public let viewBox: String
    
    /// Icon categories
    public let categories: [String]
}
```

## Utilities

### String Helpers

```swift
extension String {
    /// Escape HTML entities
    public func escapeHTML() -> String
    
    /// Normalize line endings
    public func normalizeLineEndings() -> String
    
    /// Extract front matter
    public func extractFrontMatter() -> (metadata: String?, content: String)
}
```

### Attribute Handling

```swift
public struct Attributes: Sendable {
    /// Attribute dictionary
    public var values: [String: String]
    
    /// Get attribute value
    public subscript(key: String) -> String?
    
    /// Parse from string
    public static func parse(_ string: String) -> Attributes
}
```

## Error Types

```swift
public enum MarkdownError: Error, Sendable {
    case invalidInput(String)
    case parsingFailed(String)
    case renderingFailed(String)
    case extensionError(String)
    case securityViolation(String)
    case resourceExhausted(String)
}

public enum SecurityError: Error, Sendable {
    case inputTooLarge(size: Int, limit: Int)
    case maliciousPattern(pattern: String)
    case dangerousUnicode(character: Character)
    case nestingTooDeep(depth: Int, limit: Int)
    case timeout
    case memoryExceeded(used: Int, limit: Int)
}
```

## Performance

### SIMD Optimization

```swift
public struct SIMDOptimizer {
    /// Count character occurrences using SIMD
    public func countOccurrences(of char: Character, in text: String) -> Int
    
    /// Find all positions using SIMD
    public func findPositions(of pattern: String, in text: String) -> [Int]
}
```

### Caching

```swift
public actor DocumentCache {
    /// Cache parsed document
    public func cache(_ key: String, document: Document)
    
    /// Retrieve cached document
    public func get(_ key: String) -> Document?
    
    /// Clear cache
    public func clear()
    
    /// Set cache size limit
    public func setLimit(_ bytes: Int)
}
```

## Next Steps

- Explore <doc:GettingStarted> for quick setup
- Learn about <doc:CustomExtensions> for extending
- See <doc:Performance> for optimization
- Check <doc:Security> for safe usage
