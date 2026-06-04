//
//  SlideAST.swift
//  RhoeMarkdownKit
//
//  EBNF-compliant AST nodes for slide markdown
//

import Foundation

// MARK: - YAML Support

/// Simple YAML value enum for frontmatter parsing
public enum YAMLValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([YAMLValue])
    case dictionary([String: YAMLValue])
}

// MARK: - Top-Level AST Nodes

/// Root node representing a complete presentation
public struct Presentation: Sendable, Equatable {
    public let frontmatter: Frontmatter?
    public let slides: [Slide]
    public let metadata: PresentationMetadata
    
    // Computed properties for convenience
    public var title: String? { metadata.title ?? frontmatter?.title }
    public var author: String? { metadata.author ?? frontmatter?.author }
    public var date: Date? { metadata.date ?? frontmatter?.date }
    
    public init(
        frontmatter: Frontmatter? = nil,
        slides: [Slide],
        metadata: PresentationMetadata = PresentationMetadata()
    ) {
        self.frontmatter = frontmatter
        self.slides = slides
        self.metadata = metadata
    }
}

/// YAML frontmatter with typed values
public struct Frontmatter: Sendable, Equatable {
    public let content: [String: YAMLValue]
    
    // Common frontmatter fields
    public var title: String? {
        if case .string(let value) = content["title"] { return value }
        return nil
    }
    
    public var author: String? {
        if case .string(let value) = content["author"] { return value }
        return nil
    }
    
    public var date: Date? {
        if case .string(let dateStr) = content["date"] {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: dateStr)
        }
        return nil
    }
    
    public var theme: String? {
        if case .string(let value) = content["theme"] { return value }
        return nil
    }
    
    public init(content: [String: YAMLValue]) {
        self.content = content
    }
}

/// Slide type based on separator
public enum SlideType: Sendable, Equatable {
    case regular        // %%%
    case separator      // %%%%
    case section        // %%%%%
    case title          // %%%%%%
    
    /// Number of % characters for this type
    public var separatorLength: Int {
        switch self {
        case .regular: return 3
        case .separator: return 4
        case .section: return 5
        case .title: return 6
        }
    }
    
    /// Whether this slide type supports grid layout
    public var supportsGrid: Bool {
        self == .regular
    }
    
    /// Whether this slide type supports body content
    public var supportsBodyContent: Bool {
        self == .regular
    }
}

/// Slide node matching EBNF productions
public struct Slide: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let type: SlideType
    public let gridSpec: GridSpec?
    public let attributes: RhoeMarkdownKit.Attributes?
    public let content: [SlideContent]
    
    // Convenience properties for special slides
    public var titleElements: TitleElements? {
        guard type != .regular else { return nil }
        
        var supertitle: String? = nil
        var title: String? = nil
        var subtitle: String? = nil
        
        for item in content {
            if case .markdown(let block) = item,
               case .heading(let level, let inlines, _) = block {
                let text = inlines.compactMap { inline -> String? in
                    if case .text(let str) = inline { return str }
                    return nil
                }.joined()
                
                switch level {
                case 3: supertitle = text
                case 1: title = text
                case 2: subtitle = text
                default: break
                }
            }
        }
        
        return TitleElements(
            supertitle: supertitle,
            title: title,
            subtitle: subtitle
        )
    }

    public var title: String? {
        titleElements?.title ?? firstHeadingText(level: 1)
    }

    public var subtitle: String? {
        titleElements?.subtitle ?? firstHeadingText(level: 2)
    }
    
    public init(
        id: UUID = UUID(),
        type: SlideType = .regular,
        gridSpec: GridSpec? = nil,
        attributes: RhoeMarkdownKit.Attributes? = nil,
        content: [SlideContent]
    ) {
        self.id = id
        self.type = type
        self.gridSpec = type.supportsGrid ? gridSpec : nil
        self.attributes = attributes
        self.content = content
    }

    private func firstHeadingText(level: Int) -> String? {
        for item in content {
            guard case .markdown(let block) = item,
                  case .heading(let headingLevel, let inlines, _) = block,
                  headingLevel == level else {
                continue
            }

            let text = inlines.compactMap { inline -> String? in
                if case .text(let str) = inline { return str }
                return nil
            }.joined()

            if !text.isEmpty {
                return text
            }
        }

        return nil
    }
}

/// Title elements for special slides
public struct TitleElements: Sendable, Equatable {
    public let supertitle: String?  // ### text
    public let title: String?       // # text
    public let subtitle: String?    // ## text
    
    public init(
        supertitle: String? = nil,
        title: String? = nil,
        subtitle: String? = nil
    ) {
        self.supertitle = supertitle
        self.title = title
        self.subtitle = subtitle
    }
}

/// Grid specification (e.g., D4, F8)
public struct GridSpec: Sendable, Equatable {
    public let columns: Int
    public let rows: Int
    public let raw: String // Original specification string
    
    public init?(from spec: String) {
        guard let dims = Self.parseDimensions(spec) else { return nil }
        self.columns = dims.columns
        self.rows = dims.rows
        self.raw = spec
    }

    private static func parseDimensions(_ spec: String) -> (columns: Int, rows: Int)? {
        let trimmed = spec.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return nil }

        let letters = trimmed.prefix { $0.isLetter }
        let digits = trimmed.drop { $0.isLetter }

        guard !letters.isEmpty, !digits.isEmpty, let rows = Int(digits), rows > 0 else {
            return nil
        }

        var columns = 0
        for character in letters {
            guard let ascii = character.asciiValue, ascii >= 65, ascii <= 90 else {
                return nil
            }
            columns = (columns * 26) + Int(ascii - 64)
        }

        return (columns, rows)
    }
}

// MARK: - Slide Content Types

/// Content that can appear in a slide
public enum SlideContent: Sendable, Equatable {
    case slot(SlotElement)
    case grid(GridElement)
    case markdown(Block)
}

/// Slot-based positioned element
public struct SlotElement: Sendable, Equatable {
    public let position: SlotPosition
    public let content: [Block]
    
    public init(position: SlotPosition, content: [Block]) {
        self.position = position
        self.content = content
    }
}

/// Slot position in the slide
public enum SlotPosition: String, Sendable, Equatable {
    // Slide slots
    case topLeft = "TL"
    case top = "T"
    case topRight = "TR"
    case left = "L"
    case center = "C"
    case right = "R"
    case bottomLeft = "BL"
    case bottom = "B"
    case bottomRight = "BR"
    
    // Header slots
    case headerTopLeft = "HTL"
    case headerTop = "HT"
    case headerTopRight = "HTR"
    case headerLeft = "HL"
    case headerCenter = "HC"
    case headerRight = "HR"
    case headerBottomLeft = "HBL"
    case headerBottom = "HB"
    case headerBottomRight = "HBR"
    
    // Footer slots
    case footerTopLeft = "FTL"
    case footerTop = "FT"
    case footerTopRight = "FTR"
    case footerLeft = "FL"
    case footerCenter = "FC"
    case footerRight = "FR"
    case footerBottomLeft = "FBL"
    case footerBottom = "FB"
    case footerBottomRight = "FBR"
    
    /// Get the region this slot belongs to
    public var region: SlotRegion {
        switch self {
        case .topLeft, .top, .topRight, .left, .center, .right, .bottomLeft, .bottom, .bottomRight:
            return .slide
        case .headerTopLeft, .headerTop, .headerTopRight, .headerLeft, .headerCenter, .headerRight,
             .headerBottomLeft, .headerBottom, .headerBottomRight:
            return .header
        case .footerTopLeft, .footerTop, .footerTopRight, .footerLeft, .footerCenter, .footerRight,
             .footerBottomLeft, .footerBottom, .footerBottomRight:
            return .footer
        }
    }
}

/// Region of a slot position
public enum SlotRegion: Sendable, Equatable {
    case slide
    case header
    case footer
}

/// Grid-based element
public struct GridElement: Sendable, Equatable {
    public let reference: CellReference
    public let alignment: CellAlignment?
    public let content: CellContent
    
    public init(
        reference: CellReference,
        alignment: CellAlignment? = nil,
        content: CellContent
    ) {
        self.reference = reference
        self.alignment = alignment
        self.content = content
    }
}

/// Cell reference (single or range)
public enum CellReference: Sendable, Equatable {
    case single(column: Int, row: Int)
    case range(startColumn: Int, startRow: Int, endColumn: Int, endRow: Int)
    
    /// Parse from string (e.g., "A1" or "A1:D4")
    public init?(from string: String) {
        if string.contains(":") {
            // Range reference
            let parts = string.split(separator: ":")
            guard parts.count == 2,
                  let start = Self.parseReference(String(parts[0])),
                  let end = Self.parseReference(String(parts[1])) else {
                return nil
            }
            self = .range(startColumn: start.column, startRow: start.row, endColumn: end.column, endRow: end.row)
        } else {
            // Single cell reference
            guard let cell = Self.parseReference(string) else { return nil }
            self = .single(column: cell.column, row: cell.row)
        }
    }
    
    /// Get all cells covered by this reference
    public var cells: [(column: Int, row: Int)] {
        switch self {
        case .single(let col, let row):
            return [(column: col, row: row)]
        case .range(let startColumn, let startRow, let endColumn, let endRow):
            var cells: [(column: Int, row: Int)] = []
            for col in startColumn...endColumn {
                for row in startRow...endRow {
                    cells.append((column: col, row: row))
                }
            }
            return cells
        }
    }

    private static func parseReference(_ ref: String) -> (column: Int, row: Int)? {
        let trimmed = ref.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let letters = trimmed.prefix { $0.isLetter }
        let digits = trimmed.drop { $0.isLetter }

        guard !letters.isEmpty, !digits.isEmpty, let row = Int(digits), row > 0 else {
            return nil
        }

        var column = 0
        for character in letters {
            guard let ascii = character.asciiValue, ascii >= 65, ascii <= 90 else {
                return nil
            }
            column = (column * 26) + Int(ascii - 64)
        }

        return (column, row)
    }
}

/// Content of a grid cell
public enum CellContent: Sendable, Equatable {
    case inline(InlineContent)
    case shape(ShapeContent)
    case blocks([Block])
}

/// Inline content (potentially multiple cells on one line)
public struct InlineContent: Sendable, Equatable {
    public let items: [InlineCellItem]
    
    public init(items: [InlineCellItem]) {
        self.items = items
    }
}

/// Single inline cell item
public struct InlineCellItem: Sendable, Equatable {
    public let reference: CellReference?
    public let content: [Inline]
    
    public init(reference: CellReference? = nil, content: [Inline]) {
        self.reference = reference
        self.content = content
    }
}

// MARK: - Shape System

/// Shape content with type and attributes
public struct ShapeContent: Sendable, Equatable {
    public let shape: ShapeType
    public let attributes: RhoeMarkdownKit.Attributes?
    public let content: [Block]
    
    public init(
        shape: ShapeType,
        attributes: RhoeMarkdownKit.Attributes? = nil,
        content: [Block]
    ) {
        self.shape = shape
        self.attributes = attributes
        self.content = content
    }
}

/// Available shape types (now supports icons and emojis)
public enum ShapeType: Sendable, Equatable, Hashable {
    // Basic shapes
    case basic(BasicShape)
    
    // Icon shapes
    case icon(iconSet: IconSet?, name: String)
    
    // Emoji shapes
    case emoji(name: String)
    
    /// Parse from string representation
    public init?(from string: String) {
        // Try basic shapes first
        if let basic = BasicShape(rawValue: string) {
            self = .basic(basic)
            return
        }
        
        // Check for emoji notation
        if string.hasPrefix("Emoji.") {
            let components = string.split(separator: ".", maxSplits: 1)
            guard components.count == 2 else { return nil }
            
            let emojiName = String(components[1])
            self = .emoji(name: emojiName)
            return
        }
        
        // Check for icon notation
        if string.hasPrefix("Icon") {
            let components = string.split(separator: ".", maxSplits: 1)
            guard components.count == 2 else { return nil }
            
            let prefix = String(components[0])
            let iconName = String(components[1])
            
            if prefix == "Icon" {
                // Generic icon
                self = .icon(iconSet: nil, name: iconName)
            } else {
                // Specific icon set
                guard let iconSet = IconSet.from(prefix: prefix) else { return nil }
                self = .icon(iconSet: iconSet, name: iconName)
            }
            return
        }
        
        return nil
    }
    
    /// String representation for serialization
    public var rawValue: String {
        switch self {
        case .basic(let shape):
            return shape.rawValue
        case .icon(let iconSet, let name):
            if let iconSet = iconSet {
                return "\(iconSet.prefix).\(name)"
            } else {
                return "Icon.\(name)"
            }
        case .emoji(let name):
            return "Emoji.\(name)"
        }
    }
}

/// Basic shape types (non-icon)
public enum BasicShape: String, Sendable, Equatable, Hashable, CaseIterable {
    // Geometric shapes
    case circle = "Circle"
    case rect = "Rect"
    case roundedRect = "RoundedRect"
    case ellipse = "Ellipse"
    case capsule = "Capsule"
    
    // Polygons
    case triangle = "Triangle"
    case diamond = "Diamond"
    case pentagon = "Pentagon"
    case hexagon = "Hexagon"
    case octagon = "Octagon"
    
    // Arrows
    case arrow = "Arrow"
    case arrowUp = "ArrowUp"
    case arrowDown = "ArrowDown"
    case arrowLeft = "ArrowLeft"
    case arrowRight = "ArrowRight"
    
    // Symbols
    case chevron = "Chevron"
    case plus = "Plus"
    case cross = "Cross"
    case star = "Star"
    case star6 = "Star6"
    
    // Special shapes
    case cloud = "Cloud"
    case heart = "Heart"
    case shield = "Shield"
    case burst = "Burst"
    case callout = "Callout"
    
    // Communication & Flow
    case speechBubble = "SpeechBubble"
    case thoughtBubble = "ThoughtBubble"
    case banner = "Banner"
    case flag = "Flag"
    case tag = "Tag"
    
    // Advanced Polygons
    case square = "Square"
    case parallelogram = "Parallelogram"
    case trapezoid = "Trapezoid"
    case rhombus = "Rhombus"
    case star4 = "Star4"
    case star8 = "Star8"
    case star12 = "Star12"
    
    // Business & Diagrams
    case cylinder = "Cylinder"
    case cube = "Cube"
    case pyramid = "Pyramid"
    case funnel = "Funnel"
    case process = "Process"
    case decision = "Decision"
    case document = "Document"
    case folder = "Folder"
    
    // Modern UI
    case pill = "Pill"
    case badge = "Badge"
    case tooltip = "Tooltip"
    case tab = "Tab"
    case card = "Card"
    
    // Nature & Organic
    case flower = "Flower"
    case leaf = "Leaf"
    case drop = "Drop"
    
    // Additional Special
    case gear = "Gear"
    case lightning = "Lightning"
    case moon = "Moon"
    case sun = "Sun"
    
    // Content shapes
    case chart = "Chart"
    case mermaid = "Mermaid"
    case liquid = "Liquid"
    
    // Gradient shapes
    case meshGradient = "MeshGradient"
    
    // Layout shapes
    case grid = "Grid"
    
    // Semantic shapes
    case math = "Math"
    case sticker = "Sticker"
    
    // Map shapes
    case countryMap = "CountryMap"
}

/// Supported icon sets
public enum IconSet: String, Sendable, Equatable, Hashable, CaseIterable {
    case lucide = "lucide"
    case fluent = "fluent"
    case feather = "feather"
    case heroicons = "heroicons"
    case heroiconsSolid = "heroicons-solid"
    
    /// Display name for the icon set
    public var displayName: String {
        switch self {
        case .lucide: return "Lucide Icons"
        case .fluent: return "Fluent UI System Icons"
        case .feather: return "Feather Icons"
        case .heroicons: return "Heroicons (Outline)"
        case .heroiconsSolid: return "Heroicons (Solid)"
        }
    }
    
    /// The prefix used in markdown (e.g., "IconLucide")
    public var prefix: String {
        switch self {
        case .lucide: return "IconLucide"
        case .fluent: return "IconFluent"
        case .feather: return "IconFeather"
        case .heroicons: return "IconHeroicons"
        case .heroiconsSolid: return "IconHeroiconsSolid"
        }
    }
    
    /// Initialize from prefix string
    public static func from(prefix: String) -> IconSet? {
        for iconSet in IconSet.allCases {
            if iconSet.prefix == prefix {
                return iconSet
            }
        }
        return nil
    }
}

// MARK: - Special Content Types

/// Chart content with data
public struct ChartContent: Sendable, Equatable {
    public let type: ChartType
    public let data: ChartData
    public let attributes: RhoeMarkdownKit.Attributes?
    
    public init(
        type: ChartType,
        data: ChartData,
        attributes: RhoeMarkdownKit.Attributes? = nil
    ) {
        self.type = type
        self.data = data
        self.attributes = attributes
    }
}

/// Chart types
public enum ChartType: String, Sendable, Equatable {
    case bar = "bar"
    case line = "line"
    case pie = "pie"
    case scatter = "scatter"
    case waterfall = "waterfall"
}

/// Chart data representation
public enum ChartData: Sendable, Equatable {
    case csv(String)
    case json(String)
    case yaml(String)
}

/// Liquid template content
public struct LiquidContent: Sendable, Equatable {
    public let template: String
    public let context: [String: YAMLValue]?
    
    public init(template: String, context: [String: YAMLValue]? = nil) {
        self.template = template
        self.context = context
    }
}

// MARK: - AST Extensions

extension Block {
    /// Extend Block enum with slide-specific cases - COMMENTED OUT
    // public static func gridLayout(_ layout: GridLayout) -> Block {
    //     // Wrap grid layout in a custom block type
    //     return .div(
    //         content: layout.cells.flatMap { cell in
    //             cell.content
    //         },
    //         attributes: layout.attributes ?? RhoeMarkdownKit.Attributes()
    //     )
    // }
    
    /// Create a shape block
    public static func shape(_ shape: ShapeContent) -> Block {
        return .admonition(
            type: shape.shape.rawValue,
            title: nil,
            content: shape.content,
            collapsible: nil,
            attributes: shape.attributes ?? RhoeMarkdownKit.Attributes()
        )
    }
}

// MARK: - Visitor Pattern Support

/// Protocol for traversing the slide AST
public protocol SlideASTVisitor {
    associatedtype Result
    
    func visit(_ presentation: Presentation) -> Result
    func visit(_ slide: Slide) -> Result
    func visit(_ slotElement: SlotElement) -> Result
    func visit(_ gridElement: GridElement) -> Result
    func visit(_ shapeContent: ShapeContent) -> Result
    func visit(_ chartContent: ChartContent) -> Result
    func visit(_ liquidContent: LiquidContent) -> Result
}

/// Default implementations
extension SlideASTVisitor {
    public func visit(_ presentation: Presentation) -> Result {
        fatalError("Must implement visit(_: Presentation)")
    }
    
    public func visit(_ slide: Slide) -> Result {
        fatalError("Must implement visit(_: Slide)")
    }
    
    public func visit(_ slotElement: SlotElement) -> Result {
        fatalError("Must implement visit(_: SlotElement)")
    }
    
    public func visit(_ gridElement: GridElement) -> Result {
        fatalError("Must implement visit(_: GridElement)")
    }
    
    public func visit(_ shapeContent: ShapeContent) -> Result {
        fatalError("Must implement visit(_: ShapeContent)")
    }
    
    public func visit(_ chartContent: ChartContent) -> Result {
        fatalError("Must implement visit(_: ChartContent)")
    }
    
    public func visit(_ liquidContent: LiquidContent) -> Result {
        fatalError("Must implement visit(_: LiquidContent)")
    }
}

// MARK: - Metadata Extensions

public struct PresentationMetadata: Sendable, Equatable {
    public let title: String?
    public let author: String?
    public let date: Date?
    public let theme: String?
    public let fontConfig: SlideFontConfiguration?
    public let customFields: [String: YAMLValue]
    
    public init(
        title: String? = nil,
        author: String? = nil,
        date: Date? = nil,
        theme: String? = nil,
        fontConfig: SlideFontConfiguration? = nil,
        customFields: [String: YAMLValue] = [:]
    ) {
        self.title = title
        self.author = author
        self.date = date
        self.theme = theme
        self.fontConfig = fontConfig
        self.customFields = customFields
    }
}

// MARK: - Source Location Tracking

/// Source position for error reporting
public struct SourcePosition: Sendable, Equatable {
    public let line: Int
    public let column: Int
    public let offset: Int
    
    public init(line: Int, column: Int, offset: Int) {
        self.line = line
        self.column = column
        self.offset = offset
    }
}

/// Protocol for AST nodes with source location
public protocol SourceLocatable {
    var sourceRange: SourceRange? { get }
}

/// Source range with start and end positions
public struct SourceRange: Sendable, Equatable {
    public let start: SourcePosition
    public let end: SourcePosition
    
    public init(start: SourcePosition, end: SourcePosition) {
        self.start = start
        self.end = end
    }
}
