import Foundation
import RhoeMarkdownModel

/// Assigns numbers to referenceable elements (figures, tables, equations, theorems, etc.).
///
/// Walks the AST collecting elements whose IDs match cross-reference prefix patterns.
/// Supports both flat numbering (1, 2, 3) and section-scoped hierarchical numbering (2.1, 2.2, 3.1).
/// Numbers `Block.admonition` theorem types as well as `Block.div` theorem classes.
public struct CrossReferenceNumberingPass: DocumentPass, Sendable {
    public init() {}

    public func process(_ document: RhoeMarkdownKit.Document) -> RhoeMarkdownKit.Document {
        var counters: [String: Int] = [:]
        var elementNumbers: [String: String] = [:]
        var currentSection = 0

        collectNumbers(
            from: document.blocks,
            counters: &counters,
            numbers: &elementNumbers,
            currentSection: &currentSection
        )

        guard !elementNumbers.isEmpty else { return document }

        var metadata = document.metadata
        metadata.resolvedReferences.elementNumbers = elementNumbers
        return RhoeMarkdownKit.Document(blocks: document.blocks, metadata: metadata)
    }

    /// All theorem-family type names that should be numbered
    private static let theoremFamilyTypes: Set<String> = [
        "theorem", "lemma", "definition", "proposition", "corollary",
        "example", "claim", "assumption", "conjecture"
    ]

    /// Map from type name to cross-reference prefix
    private static let typeToPrefix: [String: String] = [
        "theorem": "thm", "lemma": "lem", "definition": "def",
        "proposition": "prop", "corollary": "cor", "example": "ex",
        "remark": "rmk", "claim": "clm", "assumption": "assum",
        "conjecture": "conj", "proof": "prf", "algorithm": "alg"
    ]

    /// All cross-reference prefixes that can be numbered
    private static let allNumberablePrefixes: Set<String> = [
        "sec", "fig", "tbl", "eq", "lst", "alg", "sld",
        "thm", "lem", "cor", "prop", "def", "ex", "rmk",
        "clm", "assum", "conj", "prf", "note"
    ]

    private func collectNumbers(
        from blocks: [Block],
        counters: inout [String: Int],
        numbers: inout [String: String],
        currentSection: inout Int
    ) {
        for block in blocks {
            switch block {
            case .heading(let level, _, let attrs):
                // Track section numbers for hierarchical numbering
                if level == 1 || level == 2 {
                    currentSection += 1
                    // Reset scoped counters on section change
                    resetScopedCounters(&counters)
                }
                if let id = attrs.id {
                    assignNumber(id: id, prefix: "sec", section: currentSection,
                                counters: &counters, numbers: &numbers)
                }

            case .paragraph(let inlines, _):
                // Implicit figures
                if inlines.count == 1, case .image(_, _, _, let attrs) = inlines.first {
                    if let id = attrs.id {
                        assignNumber(id: id, prefix: "fig", section: currentSection,
                                    counters: &counters, numbers: &numbers)
                    }
                }
                // Display math
                for inline in inlines {
                    if case .mathDisplay(_, let attrs) = inline, let id = attrs.id {
                        assignNumber(id: id, prefix: "eq", section: currentSection,
                                    counters: &counters, numbers: &numbers)
                    }
                }

            case .table(_, _, let caption, let attrs):
                // Number tables that have an ID or a caption (unless kind=layout)
                let tableKind = attrs.keyValues["kind"]
                let isLayout = tableKind == "layout"
                if let id = attrs.id, !isLayout {
                    assignNumber(id: id, prefix: "tbl", section: currentSection,
                                counters: &counters, numbers: &numbers)
                } else if caption != nil && !isLayout {
                    // Tables with captions are numbered even without explicit IDs
                    let autoId = "tbl-auto-\(counters["tbl", default: 0] + 1)"
                    assignNumber(id: autoId, prefix: "tbl", section: currentSection,
                                counters: &counters, numbers: &numbers)
                }

            case .codeBlock(_, _, let attrs):
                if let id = attrs.id {
                    // Could be equation or listing
                    if id.hasPrefix("eq-") {
                        assignNumber(id: id, prefix: "eq", section: currentSection,
                                    counters: &counters, numbers: &numbers)
                    } else if id.hasPrefix("lst-") {
                        assignNumber(id: id, prefix: "lst", section: currentSection,
                                    counters: &counters, numbers: &numbers)
                    }
                }

            case .admonition(let type, _, let content, _, let attrs):
                // Number theorem-family admonitions.
                let canonicalType = type.lowercased()
                if Self.theoremFamilyTypes.contains(canonicalType), let id = attrs.id {
                    let prefix = Self.typeToPrefix[canonicalType] ?? canonicalType
                    assignNumber(id: id, prefix: prefix, section: currentSection,
                                counters: &counters, numbers: &numbers)
                }
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .div(let content, let attrs):
                if let id = attrs.id {
                    // Check for theorem classes (Pandoc compat: ::: {.theorem})
                    for cls in attrs.classes {
                        let lower = cls.lowercased()
                        if let prefix = Self.typeToPrefix[lower] {
                            assignNumber(id: id, prefix: prefix, section: currentSection,
                                        counters: &counters, numbers: &numbers)
                            break
                        }
                    }
                }
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .blockQuote(let nested, _):
                collectNumbers(from: nested, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .list(_, let items, _):
                for item in items {
                    collectNumbers(from: item.content, counters: &counters, numbers: &numbers,
                                  currentSection: &currentSection)
                }

            case .visualBlock(_, let content, _):
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .widget(_, let content, _):
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .tab(_, let content, _):
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .stage(_, let content, _):
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .lane(let content, _):
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .module(_, _, let content, _):
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            // Canonical node kinds.

            case .mathBlock(_, let attrs):
                // Equation numbering for display math blocks
                if let id = attrs.id {
                    assignNumber(id: id, prefix: "eq", section: currentSection,
                                counters: &counters, numbers: &numbers)
                }

            case .section(let level, _, let children, let attrs):
                // Section numbering (replaces heading numbering after SectionHierarchyPass)
                if level == 1 || level == 2 {
                    currentSection += 1
                    resetScopedCounters(&counters)
                }
                if let id = attrs.id {
                    assignNumber(id: id, prefix: "sec", section: currentSection,
                                counters: &counters, numbers: &numbers)
                }
                collectNumbers(from: children, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .formalBlock(let family, _, _, let content, let attrs):
                let canonicalType = family.lowercased()
                if let id = attrs.id {
                    let prefix = Self.typeToPrefix[canonicalType] ?? canonicalType
                    assignNumber(id: id, prefix: prefix, section: currentSection,
                                counters: &counters, numbers: &numbers)
                }
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .figure(let content, _, let attrs):
                if let id = attrs.id {
                    assignNumber(id: id, prefix: "fig", section: currentSection,
                                counters: &counters, numbers: &numbers)
                }
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .speakerNotes(let content, _):
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .grid(let content, _):
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .columns(let content, _):
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .deck(let slides, _):
                collectNumbers(from: slides, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .slide(_, let content, _):
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .slotContent(_, let content, _):
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .extension_(_, _, let content, _):
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .form(_, let content, _):
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .shape(let content, _):
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .componentDeclaration(_, _, _, _, let body, _):
                collectNumbers(from: body, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            case .footnoteDefinition(_, let content):
                collectNumbers(from: content, counters: &counters, numbers: &numbers,
                              currentSection: &currentSection)

            default:
                break
            }
        }
    }

    private func assignNumber(
        id: String,
        prefix: String,
        section: Int,
        counters: inout [String: Int],
        numbers: inout [String: String]
    ) {
        guard id.hasPrefix("\(prefix)-") else { return }

        let count = (counters[prefix] ?? 0) + 1
        counters[prefix] = count

        // Hierarchical numbering: section.counter (e.g., 2.1, 2.2)
        if section > 0 {
            numbers[id] = "\(section).\(count)"
        } else {
            numbers[id] = String(count)
        }
    }

    /// Reset counters that are scoped to sections (everything except sections themselves)
    private func resetScopedCounters(_ counters: inout [String: Int]) {
        for key in counters.keys where key != "sec" {
            counters[key] = 0
        }
    }
}
