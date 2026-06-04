import Foundation

// MARK: - Configuration Types

extension RhoeMarkdownKit {

    // MARK: - Configuration

    /// Parser configuration options
    public struct Configuration: Sendable, Equatable {
        // Core extensions
        public let enableTables: Bool
        public let enableStrikethrough: Bool
        public let enableTaskLists: Bool
        public let enableAutolinks: Bool
        public let enableSmartPunctuation: Bool

        // Sprint 1: activate reserved types
        public let enableSuperscript: Bool
        public let enableSubscript: Bool
        public let enableHighlight: Bool
        public let enableFencedDivs: Bool

        // Sprint 2: new inline elements
        public let enableInlineFootnotes: Bool
        public let enableCitations: Bool
        public let enableCrossReferences: Bool

        // Sprint 3: block enhancements
        public let enableGridTables: Bool
        public let enableTableCaptions: Bool
        public let enableYAMLFrontmatter: Bool

        // Sprint 5: academic & extended features
        public let enableFancyLists: Bool
        public let enableLineBlocks: Bool
        public let enableRawInlines: Bool
        public let enableAbbreviations: Bool
        public let enableWikilinks: Bool

        // Sprint 4: core authoring
        public let enableAutoIdentifiers: Bool
        public let enableImplicitFigures: Bool
        public let enableImplicitHeaderReferences: Bool
        public let enableIntrawordUnderscores: Bool

        // RhoeMarkdown block families and composition directives
        public let enableVisualBlocks: Bool
        public let enableTransclusions: Bool
        public let enableAnnotations: Bool
        public let enableSchemaIslands: Bool
        public let enableComponents: Bool
        public let enablePhase1Preprocessing: Bool
        public let allowGeneratedSemanticTransforms: Bool
        public let enablePhase2Transforms: Bool
        public let enableCoreExpressions: Bool
        public let enableInputBindings: Bool

        public init(
            enableTables: Bool = true,
            enableStrikethrough: Bool = true,
            enableTaskLists: Bool = true,
            enableAutolinks: Bool = true,
            enableSmartPunctuation: Bool = false,
            enableSuperscript: Bool = true,
            enableSubscript: Bool = true,
            enableHighlight: Bool = true,
            enableFencedDivs: Bool = true,
            enableInlineFootnotes: Bool = true,
            enableCitations: Bool = true,
            enableCrossReferences: Bool = true,
            enableGridTables: Bool = true,
            enableTableCaptions: Bool = true,
            enableYAMLFrontmatter: Bool = true,
            enableFancyLists: Bool = true,
            enableLineBlocks: Bool = true,
            enableRawInlines: Bool = true,
            enableAbbreviations: Bool = true,
            enableWikilinks: Bool = true,
            enableAutoIdentifiers: Bool = true,
            enableImplicitFigures: Bool = true,
            enableImplicitHeaderReferences: Bool = true,
            enableIntrawordUnderscores: Bool = true,
            enableVisualBlocks: Bool = true,
            enableTransclusions: Bool = true,
            enableAnnotations: Bool = true,
            enableSchemaIslands: Bool = true,
            enableComponents: Bool = true,
            enablePhase1Preprocessing: Bool = true,
            allowGeneratedSemanticTransforms: Bool = false,
            enablePhase2Transforms: Bool = true,
            enableCoreExpressions: Bool = true,
            enableInputBindings: Bool = true
        ) {
            self.enableTables = enableTables
            self.enableStrikethrough = enableStrikethrough
            self.enableTaskLists = enableTaskLists
            self.enableAutolinks = enableAutolinks
            self.enableSmartPunctuation = enableSmartPunctuation
            self.enableSuperscript = enableSuperscript
            self.enableSubscript = enableSubscript
            self.enableHighlight = enableHighlight
            self.enableFencedDivs = enableFencedDivs
            self.enableInlineFootnotes = enableInlineFootnotes
            self.enableCitations = enableCitations
            self.enableCrossReferences = enableCrossReferences
            self.enableGridTables = enableGridTables
            self.enableTableCaptions = enableTableCaptions
            self.enableYAMLFrontmatter = enableYAMLFrontmatter
            self.enableFancyLists = enableFancyLists
            self.enableLineBlocks = enableLineBlocks
            self.enableRawInlines = enableRawInlines
            self.enableAbbreviations = enableAbbreviations
            self.enableWikilinks = enableWikilinks
            self.enableAutoIdentifiers = enableAutoIdentifiers
            self.enableImplicitFigures = enableImplicitFigures
            self.enableImplicitHeaderReferences = enableImplicitHeaderReferences
            self.enableIntrawordUnderscores = enableIntrawordUnderscores
            self.enableVisualBlocks = enableVisualBlocks
            self.enableTransclusions = enableTransclusions
            self.enableAnnotations = enableAnnotations
            self.enableSchemaIslands = enableSchemaIslands
            self.enableComponents = enableComponents
            self.enablePhase1Preprocessing = enablePhase1Preprocessing
            self.allowGeneratedSemanticTransforms = allowGeneratedSemanticTransforms
            self.enablePhase2Transforms = enablePhase2Transforms
            self.enableCoreExpressions = enableCoreExpressions
            self.enableInputBindings = enableInputBindings
        }

        public static let `default` = Configuration()
        public static let github = Configuration(
            enableSmartPunctuation: false,
            enableYAMLFrontmatter: false,
            enableWikilinks: false
        )
        public static let strict = Configuration(
            enableTables: false,
            enableStrikethrough: false,
            enableTaskLists: false,
            enableAutolinks: false,
            enableSmartPunctuation: false,
            enableSuperscript: false,
            enableSubscript: false,
            enableHighlight: false,
            enableFencedDivs: false,
            enableInlineFootnotes: false,
            enableCitations: false,
            enableCrossReferences: false,
            enableGridTables: false,
            enableTableCaptions: false,
            enableYAMLFrontmatter: false,
            enableFancyLists: false,
            enableLineBlocks: false,
            enableRawInlines: false,
            enableAbbreviations: false,
            enableWikilinks: false,
            enableAutoIdentifiers: false,
            enableImplicitFigures: false,
            enableImplicitHeaderReferences: false,
            enableIntrawordUnderscores: false,
            enableVisualBlocks: false,
            enableTransclusions: false,
            enableAnnotations: false,
            enableSchemaIslands: false,
            enableComponents: false,
            enablePhase1Preprocessing: false,
            allowGeneratedSemanticTransforms: false,
            enablePhase2Transforms: false,
            enableCoreExpressions: false,
            enableInputBindings: false
        )
    }

    /// Math rendering mode
    public enum MathRenderingMode: Sendable {
        case mathjax    // MathJax/KaTeX compatible \(...\) and \[...\]
        case mathml     // Native MathML for modern browsers
    }

    /// HTML rendering configuration
    public struct HTMLConfiguration: Sendable {
        public let prettyPrint: Bool
        public let includeSourcePos: Bool
        public let enableSyntaxHighlighting: Bool
        public let mathRenderingMode: MathRenderingMode
        public let enableImplicitFigures: Bool
        public let includeDefaultCSS: Bool
        public let wrapInDocument: Bool

        public init(
            prettyPrint: Bool = false,
            includeSourcePos: Bool = false,
            enableSyntaxHighlighting: Bool = true,
            mathRenderingMode: MathRenderingMode = .mathjax,
            enableImplicitFigures: Bool = true,
            includeDefaultCSS: Bool = false,
            wrapInDocument: Bool = false
        ) {
            self.prettyPrint = prettyPrint
            self.includeSourcePos = includeSourcePos
            self.enableSyntaxHighlighting = enableSyntaxHighlighting
            self.mathRenderingMode = mathRenderingMode
            self.enableImplicitFigures = enableImplicitFigures
            self.includeDefaultCSS = includeDefaultCSS
            self.wrapInDocument = wrapInDocument
        }

        public static let `default` = HTMLConfiguration()
        public static let mathML = HTMLConfiguration(mathRenderingMode: .mathml)
        public static let styled = HTMLConfiguration(includeDefaultCSS: true, wrapInDocument: true)
    }

    // MARK: - LaTeX Configuration

    /// Configuration for LaTeX document output.
    public struct LaTeXConfiguration: Sendable, Equatable {
        /// LaTeX document class (article, report, book, beamer)
        public let documentClass: String
        /// Class options (e.g., ["12pt", "a4paper"])
        public let classOptions: [String]
        /// Additional packages to include via \usepackage
        public let packages: [String]
        /// Whether to wrap output in full document preamble
        public let generatePreamble: Bool
        /// Bibliography style (plain, alpha, ieee, etc.)
        public let bibliographyStyle: String?
        /// Code listing package to use
        public let codeListingPackage: CodeListingPackage
        /// Whether to use AST-near emission (\Rhoe* environments) vs flat LaTeX
        public let astNearEmission: Bool

        /// Code listing package options
        public enum CodeListingPackage: String, Sendable, Equatable {
            case listings
            case minted
        }

        public init(
            documentClass: String = "article",
            classOptions: [String] = [],
            packages: [String] = [],
            generatePreamble: Bool = true,
            bibliographyStyle: String? = nil,
            codeListingPackage: CodeListingPackage = .listings,
            astNearEmission: Bool = true
        ) {
            self.documentClass = documentClass
            self.classOptions = classOptions
            self.packages = packages
            self.generatePreamble = generatePreamble
            self.bibliographyStyle = bibliographyStyle
            self.codeListingPackage = codeListingPackage
            self.astNearEmission = astNearEmission
        }

        public static let `default` = LaTeXConfiguration()
        public static let fragment = LaTeXConfiguration(generatePreamble: false)
        public static let flat = LaTeXConfiguration(astNearEmission: false)
    }

    // MARK: - Typst Configuration

    /// Configuration for Typst document output.
    public struct TypstConfiguration: Sendable, Equatable {
        /// Paper size (a4, us-letter)
        public let paperSize: String
        /// Font size (e.g., "11pt", "12pt")
        public let fontSize: String
        /// Main text font family
        public let fontFamily: String?
        /// Monospace font family for code
        public let monoFontFamily: String?
        /// Whether to generate preamble (#set document, #set page, etc.)
        public let generatePreamble: Bool
        /// Whether to use AST-near emission (#rhoe-* functions) vs flat Typst syntax
        public let astNearEmission: Bool

        public init(
            paperSize: String = "a4",
            fontSize: String = "11pt",
            fontFamily: String? = nil,
            monoFontFamily: String? = nil,
            generatePreamble: Bool = true,
            astNearEmission: Bool = true
        ) {
            self.paperSize = paperSize
            self.fontSize = fontSize
            self.fontFamily = fontFamily
            self.monoFontFamily = monoFontFamily
            self.generatePreamble = generatePreamble
            self.astNearEmission = astNearEmission
        }

        public static let `default` = TypstConfiguration()
        public static let fragment = TypstConfiguration(generatePreamble: false)
        public static let flat = TypstConfiguration(astNearEmission: false)
    }

    // MARK: - DOCX Configuration

    /// Configuration for DOCX (Word) document output.
    public struct DOCXConfiguration: Sendable, Equatable {
        /// Page size
        public let pageSize: PageSize
        /// Whether to include a table of contents
        public let generateTOC: Bool
        /// Heading depth for TOC
        public let tocDepth: Int

        /// Supported page sizes
        public enum PageSize: String, Sendable, Equatable {
            case letter
            case a4
        }

        public init(
            pageSize: PageSize = .letter,
            generateTOC: Bool = false,
            tocDepth: Int = 3
        ) {
            self.pageSize = pageSize
            self.generateTOC = generateTOC
            self.tocDepth = tocDepth
        }

        public static let `default` = DOCXConfiguration()
    }

    // MARK: - Diagram Configuration

    /// Configuration for diagram rendering engines (Mermaid, Graphviz, PlantUML, D2).
    public struct DiagramConfiguration: Sendable, Equatable {
        /// Whether server-side diagram rendering is enabled
        public let enableDiagramRendering: Bool
        /// For Mermaid in HTML output, keep client-side `<pre class="mermaid">` rendering
        public let mermaidClientSide: Bool
        /// Additional filesystem paths to search for diagram tool binaries
        public let additionalSearchPaths: [String]

        public init(
            enableDiagramRendering: Bool = true,
            mermaidClientSide: Bool = true,
            additionalSearchPaths: [String] = []
        ) {
            self.enableDiagramRendering = enableDiagramRendering
            self.mermaidClientSide = mermaidClientSide
            self.additionalSearchPaths = additionalSearchPaths
        }

        public static let `default` = DiagramConfiguration()
        public static let disabled = DiagramConfiguration(enableDiagramRendering: false)
    }

    // MARK: - PDF Configuration

    /// Configuration for PDF document output.
    ///
    /// Supports three rendering pipelines:
    /// - `.webkit` (default) — HTML→WebKit→PDF. Native on Apple platforms, highest fidelity.
    /// - `.typst` — Typst→PDF. Cross-platform, requires `typst` CLI.
    /// - `.latex` — LaTeX→PDF. Cross-platform, requires `pdflatex`/`xelatex`.
    ///
    /// For presentation slides, use `page:` or `fromPage:`/`toPage:` to select specific slides.
    public struct PDFConfiguration: Sendable, Equatable {
        /// Which compilation pipeline to use.
        public let pipeline: PDFPipeline
        /// Paper size name (a4, letter). Used by all pipelines.
        public let paperSize: String
        /// Page orientation. Used by WebKit pipeline.
        public let orientation: String
        /// Font size (11pt, 12pt). Used by Typst/LaTeX pipelines.
        public let fontSize: String
        /// Whether to generate a table of contents.
        public let enableTableOfContents: Bool
        /// Render only this page (1-based). Nil = all pages.
        public let page: Int?
        /// Render from this page (1-based, inclusive). Used with `toPage`.
        public let fromPage: Int?
        /// Render to this page (1-based, inclusive). Used with `fromPage`.
        public let toPage: Int?

        /// PDF compilation pipeline.
        public enum PDFPipeline: String, Sendable, Equatable, CaseIterable {
            /// Use LaTeXWriter output → pdflatex/xelatex.
            case latex
            /// Use TypstWriter output → typst compile.
            case typst
            /// Use HTML → WebKit → PDF (Apple platforms only).
            case webkit
        }

        public init(
            pipeline: PDFPipeline = .webkit,
            paperSize: String = "a4",
            orientation: String = "portrait",
            fontSize: String = "11pt",
            enableTableOfContents: Bool = false,
            page: Int? = nil,
            fromPage: Int? = nil,
            toPage: Int? = nil
        ) {
            self.pipeline = pipeline
            self.paperSize = paperSize
            self.orientation = orientation
            self.fontSize = fontSize
            self.enableTableOfContents = enableTableOfContents
            self.page = page
            self.fromPage = fromPage
            self.toPage = toPage
        }

        public static let `default` = PDFConfiguration()
        public static let typst = PDFConfiguration(pipeline: .typst)
        public static let latex = PDFConfiguration(pipeline: .latex)
    }

    // MARK: - EPUB Configuration

    /// Configuration for EPUB 3.2 document output.
    public struct EPUBConfiguration: Sendable, Equatable {
        /// Heading level at which to split chapters (default: 1 = split at `# Heading`)
        public let chapterLevel: Int
        /// Depth of headings to include in the table of contents
        public let tocDepth: Int
        /// BCP 47 language code
        public let language: String
        /// Custom CSS content to embed in the EPUB
        public let cssContent: String?

        public init(
            chapterLevel: Int = 1,
            tocDepth: Int = 3,
            language: String = "en",
            cssContent: String? = nil
        ) {
            self.chapterLevel = chapterLevel
            self.tocDepth = tocDepth
            self.language = language
            self.cssContent = cssContent
        }

        public static let `default` = EPUBConfiguration()
    }

    // MARK: - Output Format

    /// Supported output formats for document rendering.
    public enum OutputFormat: String, Sendable, Equatable, CaseIterable {
        case html
        case latex
        case typst
        case docx
        case pdf
        case epub

        /// Standard file extension for this format
        public var fileExtension: String {
            switch self {
            case .html: return "html"
            case .latex: return "tex"
            case .typst: return "typ"
            case .docx: return "docx"
            case .pdf: return "pdf"
            case .epub: return "epub"
            }
        }

        /// Whether this format produces binary output (Data) vs text (String)
        public var isBinary: Bool {
            switch self {
            case .html, .latex, .typst: return false
            case .docx, .pdf, .epub: return true
            }
        }

        /// Detect format from a file extension
        public static func fromExtension(_ ext: String) -> OutputFormat? {
            let lowered = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            switch lowered {
            case "html", "htm": return .html
            case "tex", "latex": return .latex
            case "typ", "typst": return .typst
            case "docx": return .docx
            case "pdf": return .pdf
            case "epub": return .epub
            default: return nil
            }
        }
    }
}
