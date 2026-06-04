import Foundation

// MARK: - AST Supporting Types
// Enums and structs used as associated values in Block and Inline nodes.

/// Author annotation kind.
public enum AnnotationKind: String, Sendable, Equatable, CaseIterable {
    case todo
    case doc
    case info
    case comment
}

/// Transclusion mode.
public enum TransclusionMode: String, Sendable, Equatable {
    case block
    case inline
    case excerpt
    case literal
    case quote
}

/// Stage execution pattern.
public enum StageKind: String, Sendable, Equatable, CaseIterable {
    case rack       // Fan-out / merge
    case `case`     // Conditional selection
    case template   // Replica expansion
    case iterate    // Sequential bounded recurrence
    case adapter    // Shape adaptation
}

/// Contract directive type.
public enum ContractKind: String, Sendable, Equatable {
    case input
    case output
}

/// Block family for the two-family block doctrine.
public enum BlockFamily: String, Sendable, Equatable {
    case semantic  // !!!
    case visual    // :::
}

/// List type information
public enum ListType: Sendable, Equatable {
    case unordered
    case ordered(start: Int, style: ListMarkerStyle = .decimal)
    case task
}

/// List marker style for ordered lists
public enum ListMarkerStyle: String, Sendable, Equatable {
    case decimal       // 1. 2. 3.
    case lowerAlpha    // a. b. c.
    case upperAlpha    // A. B. C.
    case lowerRoman    // i. ii. iii.
    case upperRoman    // I. II. III.
}

/// Admonition collapsible state
public enum AdmonitionCollapsible: Sendable, Equatable {
    case expanded  // :::+ (starts open)
    case collapsed // :::- (starts closed)
}

/// List item with content
public struct ListItem: Sendable, Equatable {
    public let content: [Block]
    public let checked: Bool? // For task lists
    public let isLoose: Bool

    public init(content: [Block], checked: Bool? = nil, isLoose: Bool = false) {
        self.content = content
        self.checked = checked
        self.isLoose = isLoose
    }
}

/// Definition list item with term and definitions
public struct DefinitionListItem: Sendable, Equatable {
    public let term: [Inline]
    public let definitions: [[Block]]

    public init(term: [Inline], definitions: [[Block]]) {
        self.term = term
        self.definitions = definitions
    }
}

/// Table cell with content
public struct TableCell: Sendable, Equatable {
    public let content: [Inline]
    public let alignment: TableAlignment
    public let blockContent: [Block]?
    public let rowSpan: Int
    public let colSpan: Int

    public init(
        content: [Inline],
        alignment: TableAlignment = .none,
        blockContent: [Block]? = nil,
        rowSpan: Int = 1,
        colSpan: Int = 1
    ) {
        self.content = content
        self.alignment = alignment
        self.blockContent = blockContent
        self.rowSpan = rowSpan
        self.colSpan = colSpan
    }
}

/// Table column alignment
public enum TableAlignment: Sendable, Equatable {
    case none, left, center, right
}

// MARK: - Citation Types

/// A single citation item within a citation group
public struct CitationItem: Sendable, Equatable {
    /// The citation key (e.g., "smith2024")
    public let key: String

    /// Optional locator (e.g., "p. 42", "ch. 3")
    public let locator: String?

    /// Whether author name is suppressed (e.g., [-@key])
    public let suppressAuthor: Bool

    public init(key: String, locator: String? = nil, suppressAuthor: Bool = false) {
        self.key = key
        self.locator = locator
        self.suppressAuthor = suppressAuthor
    }
}

/// Citation rendering mode
public enum CitationMode: Sendable, Equatable {
    /// Parenthetical citation: [@key]
    case parenthetical
    /// In-text citation: @key
    case inText
    /// Suppress author: [-@key]
    case suppressAuthor
}

/// Cross-reference prefix identifying the target type
public enum CrossRefPrefix: String, Sendable, Equatable, CaseIterable {
    // Structural
    case sec, sld
    // Figure-like
    case fig, tbl, eq, lst, alg
    // Theorem-family
    case thm, lem, cor, prop, def, ex, rmk, clm, assum, conj, prf
    // Other
    case note
}

// MARK: - Bibliography Types

/// A bibliography entry parsed from YAML frontmatter
public struct BibliographyEntry: Sendable, Equatable {
    public let id: String
    public let author: String?
    public let title: String
    public let year: String?
    public let containerTitle: String?
    public let publisher: String?
    public let url: String?
    public let doi: String?
    public let type: String?

    public init(
        id: String, author: String? = nil, title: String,
        year: String? = nil, containerTitle: String? = nil,
        publisher: String? = nil, url: String? = nil,
        doi: String? = nil, type: String? = nil
    ) {
        self.id = id
        self.author = author
        self.title = title
        self.year = year
        self.containerTitle = containerTitle
        self.publisher = publisher
        self.url = url
        self.doi = doi
        self.type = type
    }

    /// Format as a human-readable citation string
    public func formatCitation(suppressAuthor: Bool = false, locator: String? = nil) -> String {
        var parts: [String] = []
        if !suppressAuthor, let author = author {
            parts.append(author)
        }
        if let year = year {
            parts.append(year)
        }
        if let locator = locator {
            parts.append(locator)
        }
        return parts.isEmpty ? id : parts.joined(separator: ", ")
    }

    /// Format as a bibliography list entry
    public func formatReference() -> String {
        var parts: [String] = []
        if let author = author { parts.append(author) }
        if let year = year { parts.append("(\(year))") }
        parts.append(title)
        if let containerTitle = containerTitle { parts.append("*\(containerTitle)*") }
        if let publisher = publisher { parts.append(publisher) }
        if let doi = doi { parts.append("doi:\(doi)") }
        if let url = url { parts.append(url) }
        return parts.joined(separator: ". ") + "."
    }
}

/// Resolved references accumulated by document pipeline passes
public struct ResolvedReferences: Sendable, Equatable {
    public var bibliography: [String: BibliographyEntry] = [:]
    public var elementNumbers: [String: String] = [:]
    public var citedKeys: [String] = []

    public init() {}
}
