import Foundation

/// RhoeMarkdownKit - standalone markdown parsing, semantic rendering,
/// presentation parsing, and projection support for Swift.
///
/// The active package surface centers on:
/// - ``RhoeMarkdownKit/parse(_:)`` and ``RhoeMarkdownKit/parse(_:configuration:)``
/// - ``RhoeMarkdownKit/renderHTML(_:configuration:)``
/// - ``SlideParser`` and presentation projection support
/// - ``ResourceManager`` and ``IconSystemManager``
///
/// ## Architecture
///
/// The repository is split into focused implementation modules:
/// - `RhoeMarkdownModel`
/// - `RhoeMarkdownParsing`
/// - `RhoeMarkdownRendering`
/// - `RhoeMarkdownPresentation`
///
/// ## Quick Start
///
/// ```swift
/// let result = await RhoeMarkdownKit.parse("# Hello World\n\nThis is **bold** text.")
/// let html = RhoeMarkdownKit.renderHTML(result.document)
/// ```
public struct RhoeMarkdownKit {

    /// Current public release version of RhoeMarkdownKit.
    public static let version = "0.1.1"

    /// Build date for diagnostics and runtime provenance.
    public static let buildDate = Date()

    // MARK: - Document Structure

    /// A parsed markdown document
    public struct Document: Sendable, Identifiable {
        public let id = UUID()
        public let blocks: [Block]
        public let metadata: DocumentMetadata

        public init(blocks: [Block], metadata: DocumentMetadata = DocumentMetadata()) {
            self.blocks = blocks
            self.metadata = metadata
        }
    }

    /// YAML frontmatter value types
    public enum YAMLValue: Sendable, Equatable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case array([YAMLValue])
        case dictionary([String: YAMLValue])
        case null

        /// Convert to a Liquid-compatible `Any` value for template rendering.
        public var liquidValue: Any {
            switch self {
            case .string(let s): return s
            case .int(let i): return i
            case .double(let d): return d
            case .bool(let b): return b
            case .array(let a): return a.map(\.liquidValue)
            case .dictionary(let d): return d.mapValues(\.liquidValue)
            case .null: return "" as Any // WASI-safe: avoid NSNull
            }
        }
    }

    /// Document-level metadata
    public struct DocumentMetadata: Sendable {
        public let createdAt: Date
        public let wordCount: Int
        public let estimatedReadingTime: TimeInterval

        // Pandoc-style YAML frontmatter
        public let yamlFrontmatter: [String: YAMLValue]?

        // Resolved references from pipeline passes
        public var resolvedReferences: ResolvedReferences

        // Attribute validation diagnostics collected by semantic pipeline passes.
        public var attributeValidationDiagnostics: [RhoeMarkdownKit.Diagnostic]

        public init(
            createdAt: Date = Date(),
            wordCount: Int = 0,
            estimatedReadingTime: TimeInterval = 0,
            yamlFrontmatter: [String: YAMLValue]? = nil,
            resolvedReferences: ResolvedReferences = ResolvedReferences(),
            attributeValidationDiagnostics: [RhoeMarkdownKit.Diagnostic] = []
        ) {
            self.createdAt = createdAt
            self.wordCount = wordCount
            self.estimatedReadingTime = estimatedReadingTime
            self.yamlFrontmatter = yamlFrontmatter
            self.resolvedReferences = resolvedReferences
            self.attributeValidationDiagnostics = attributeValidationDiagnostics
        }
    }

    /// Parsing result with document and diagnostics
    public struct ParseResult: Sendable {
        public let document: Document
        public let diagnostics: [Diagnostic]
        public let parseTime: TimeInterval

        public init(document: Document, diagnostics: [Diagnostic] = [], parseTime: TimeInterval = 0) {
            self.document = document
            self.diagnostics = diagnostics
            self.parseTime = parseTime
        }
    }

    /// Parsing diagnostic information
    public struct Diagnostic: Sendable, Equatable {
        public enum Severity: Sendable, Equatable {
            case info, warning, error
        }

        public let severity: Severity
        public let message: String
        public let line: Int?
        public let column: Int?
        public let sourceRange: SourceRange?

        public init(
            severity: Severity,
            message: String,
            line: Int? = nil,
            column: Int? = nil,
            sourceRange: SourceRange? = nil
        ) {
            self.severity = severity
            self.message = message
            self.line = line
            self.column = column
            self.sourceRange = sourceRange
        }

        public var sourceLocation: SourceLocation? {
            sourceRange?.start
        }
    }
}

// MARK: - Block Types

/// Block-level markdown elements
public enum Block: Sendable, Equatable {
    case paragraph([Inline], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case heading(level: Int, content: [Inline], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case blockQuote([Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case list(type: ListType, items: [ListItem], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case codeBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case horizontalRule
    case table(headers: [TableCell], rows: [[TableCell]], caption: [Inline]? = nil, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case definitionList(items: [DefinitionListItem], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case footnoteDefinition(id: String, content: [Block])
    case admonition(type: String, title: String?, content: [Block], collapsible: AdmonitionCollapsible?, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case html(String)
    case div(content: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case lineBlock(lines: [[Inline]])
    case abbreviationDefinition(abbreviation: String, expansion: String)
    // RhoeMarkdown extension block cases.
    case visualBlock(name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case authorAnnotation(kind: AnnotationKind, text: String, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case transclusion(target: String, fragment: String?, mode: TransclusionMode?, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case schemaIsland(schema: String, body: String, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case componentDeclaration(family: BlockFamily, name: String, args: String?, slots: String?, body: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Phase 2 semantic transform directive: {@ command args @}
    case phase2Directive(command: String, arguments: [String: String], body: String?, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Parser-native placeholder: {? name: "Field", type: text ?}
    case placeholder(fields: [String: String], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Core render-layer expression: <<= expr >>
    case expression(expr: String, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Input field binding: <<field name {type=text}>>
    case field(name: String, fieldType: String, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Transactional input form: <<form>>...<</form>>
    case form(name: String?, content: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Notebook widget surface: ::: widget {title="Summary"}
    case widget(title: String, content: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Notebook tab surface: ::: tab {title="Results"}
    case tab(title: String, content: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Structural execution stage: ::: stage.rack, ::: stage.case, etc.
    case stage(kind: StageKind, content: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Lane container within a stage: === lane
    case lane(content: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Typed execution module: ::: module.transform.map, ::: module.records.filter
    case module(family: String, name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Contract directive: !!! input or !!! output
    case contractDirective(kind: ContractKind, content: String, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())

    // MARK: - Canonical Structural Node Kinds

    /// Headed structural section (canonical AST form of headings)
    case section(level: Int, title: [Inline], children: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Theorem-family semantic block (theorem, lemma, definition, example, proof, etc.)
    case formalBlock(family: String, title: [Inline]?, number: String?, content: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Presenter-oriented semantic block
    case speakerNotes(content: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Layout/grid container
    case grid(content: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Multi-column structural container
    case columns(content: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Figure/media wrapper with optional caption
    case figure(content: [Block], caption: [Inline]?, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Diagram/raw-diagram block
    case diagramBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Geometric/shape node
    case shape(content: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Table header section (hierarchical table model)
    case tableHead(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Table body section (hierarchical table model)
    case tableBody(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Table footer section (hierarchical table model)
    case tableFoot(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Table row (hierarchical table model)
    case tableRow(cells: [TableCell], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Computable code block with runtime/language metadata
    case executableCodeBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Display math block (canonical block-level math)
    case mathBlock(expression: String, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Slide deck container
    case deck(slides: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Slide with optional title
    case slide(title: [Inline]?, content: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Named slot content within a component or slide
    case slotContent(name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Extension-owned semantic node
    case extension_(vendor: String, name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    /// Target-scoped raw block with format identifier
    case rawBlock(content: String, format: String, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
}

/// Inline markdown elements
public enum Inline: Sendable, Equatable {
    case text(String)
    case emphasis([Inline])
    case strong([Inline])
    case strikethrough([Inline])
    case codeSpan(String, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case link(text: [Inline], url: String, title: String?, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case image(alt: [Inline], url: String, title: String?, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case footnoteRef(id: String)
    case inlineMath(expression: String, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case mathDisplay(expression: String, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case html(String)
    case hardBreak
    case softBreak
    case superscript([Inline])
    case `subscript`([Inline])
    case highlight([Inline])
    case span(content: [Inline], attributes: RhoeMarkdownKit.Attributes)
    case inlineFootnote(content: [Inline])
    case citation(items: [CitationItem], mode: CitationMode)
    case crossReference(prefix: CrossRefPrefix, id: String)
    case resolvedCitation(text: String, keys: [String], mode: CitationMode)
    case resolvedCrossReference(text: String, targetId: String)
    case rawInline(content: String, format: String)
    case wikilink(target: String, display: [Inline]?)
    /// Emoji shortcode resolved from `:name:` syntax.
    case emoji(name: String, unicode: String?)
    // RhoeMarkdown extension inline cases.
    case transclusionInline(target: String, fragment: String?, mode: TransclusionMode?, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
    case annotationInline(kind: AnnotationKind, text: String)
    case paramRef(name: String)
    case slotRef(name: String?)
    /// Parser-native inline placeholder: {? name: "Field" ?}
    case placeholderInline(fields: [String: String])
    /// Inline expression evaluation: <<= expr >>
    case expressionInline(expr: String)
    /// Inline input field: <<field name {type=text}>>
    case inputFieldInline(name: String, fieldType: String, attributes: RhoeMarkdownKit.Attributes = RhoeMarkdownKit.Attributes())
}

// Supporting types (AnnotationKind, ListType, TableCell, CitationItem, etc.)
// are defined in SupportingTypes.swift
