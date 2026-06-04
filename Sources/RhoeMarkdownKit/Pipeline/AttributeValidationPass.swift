import Foundation
import RhoeMarkdownModel

/// Validates attributes for context-correctness, semantic consistency,
/// and projection coherence. Produces diagnostics without modifying the AST.
///
/// Validation layers:
/// - Layer 2 (Context): Is this attribute valid in this element context?
/// - Layer 3 (Semantic): Are semantic attributes internally consistent?
/// - Layer 4 (Projection): Are projection attributes non-contradictory?
public struct AttributeValidationPass: DocumentPass, Sendable {
    public init() {}

    public func process(_ document: RhoeMarkdownKit.Document) -> RhoeMarkdownKit.Document {
        var diagnostics: [RhoeMarkdownKit.Diagnostic] = []
        validateBlocks(document.blocks, diagnostics: &diagnostics)

        guard !diagnostics.isEmpty else { return document }

        var metadata = document.metadata
        metadata.attributeValidationDiagnostics = diagnostics
        return RhoeMarkdownKit.Document(blocks: document.blocks, metadata: metadata)
    }

    private func validateBlocks(_ blocks: [Block], diagnostics: inout [RhoeMarkdownKit.Diagnostic]) {
        for block in blocks {
            validateBlock(block, diagnostics: &diagnostics)
        }
    }

    private func validateBlock(_ block: Block, diagnostics: inout [RhoeMarkdownKit.Diagnostic]) {
        switch block {
        case .heading(_, _, let attrs):
            validateContextKeys(attrs, context: "heading", disallowed: ["scope", "required", "placeholder", "min", "max", "step"], diagnostics: &diagnostics)

        case .paragraph(_, let attrs):
            validateContextKeys(attrs, context: "paragraph", disallowed: ["scope", "required", "collapsed"], diagnostics: &diagnostics)

        case .codeBlock(_, _, let attrs):
            validateContextKeys(attrs, context: "code block", disallowed: ["scope", "required", "alt"], diagnostics: &diagnostics)

        case .table(_, _, _, let attrs):
            validateTableAttributes(attrs, diagnostics: &diagnostics)

        case .admonition(_, _, let content, _, let attrs):
            validateContextKeys(attrs, context: "admonition", disallowed: ["scope", "required", "alt"], diagnostics: &diagnostics)
            validateBlocks(content, diagnostics: &diagnostics)

        case .blockQuote(let nested, _):
            validateBlocks(nested, diagnostics: &diagnostics)

        case .list(_, let items, _):
            for item in items {
                validateBlocks(item.content, diagnostics: &diagnostics)
            }

        case .div(let nested, let attrs):
            validateSemanticConsistency(attrs, diagnostics: &diagnostics)
            validateProjectionConsistency(attrs, diagnostics: &diagnostics)
            validateBlocks(nested, diagnostics: &diagnostics)

        default:
            break
        }

        // Validate projection consistency on all blocks with attributes
        if let attrs = blockAttributes(block) {
            validateProjectionConsistency(attrs, diagnostics: &diagnostics)
        }
    }

    // MARK: - Layer 2: Context Validation

    private func validateContextKeys(
        _ attrs: RhoeMarkdownKit.Attributes,
        context: String,
        disallowed: [String],
        diagnostics: inout [RhoeMarkdownKit.Diagnostic]
    ) {
        for key in disallowed {
            if attrs.keyValues[key] != nil {
                diagnostics.append(RhoeMarkdownKit.Diagnostic(
                    severity: .warning,
                    message: "Attribute '\(key)' is not valid on a \(context) element."
                ))
            }
        }
    }

    // MARK: - Layer 3: Semantic Validation

    private func validateSemanticConsistency(
        _ attrs: RhoeMarkdownKit.Attributes,
        diagnostics: inout [RhoeMarkdownKit.Diagnostic]
    ) {
        // decorative + non-empty alt is suspicious
        if attrs.keyValues["decorative"] != nil,
           let alt = attrs.keyValues["alt"], !alt.isEmpty {
            diagnostics.append(RhoeMarkdownKit.Diagnostic(
                severity: .warning,
                message: "Element marked decorative but has non-empty alt text. If meaningful, remove decorative; if decorative, remove alt."
            ))
        }

        // role=diagram without alt, summary, or longdesc
        if attrs.keyValues["role"] == "diagram" &&
           attrs.keyValues["alt"] == nil &&
           attrs.keyValues["summary"] == nil &&
           attrs.keyValues["longdesc"] == nil {
            diagnostics.append(RhoeMarkdownKit.Diagnostic(
                severity: .warning,
                message: "Diagram lacks text alternative. Add alt, summary, or longdesc for accessibility."
            ))
        }
    }

    private func validateTableAttributes(
        _ attrs: RhoeMarkdownKit.Attributes,
        diagnostics: inout [RhoeMarkdownKit.Diagnostic]
    ) {
        // kind=layout with scope attributes is suspicious
        if attrs.keyValues["kind"] == "layout" && attrs.keyValues["scope"] != nil {
            diagnostics.append(RhoeMarkdownKit.Diagnostic(
                severity: .warning,
                message: "Layout table has header scope semantics. If this is a data table, change kind to 'data'."
            ))
        }
    }

    // MARK: - Layer 4: Projection Validation

    private func validateProjectionConsistency(
        _ attrs: RhoeMarkdownKit.Attributes,
        diagnostics: inout [RhoeMarkdownKit.Diagnostic]
    ) {
        guard let visible = attrs.keyValues["visible"],
              let hidden = attrs.keyValues["hidden"] else { return }

        let visibleDomains = Set(visible.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        let hiddenDomains = Set(hidden.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })

        let overlap = visibleDomains.intersection(hiddenDomains)
        for domain in overlap {
            diagnostics.append(RhoeMarkdownKit.Diagnostic(
                severity: .error,
                message: "Contradictory visibility: '\(domain)' appears in both visible and hidden lists."
            ))
        }
    }

    // MARK: - Helpers

    private func blockAttributes(_ block: Block) -> RhoeMarkdownKit.Attributes? {
        switch block {
        case .heading(_, _, let a): return a
        case .paragraph(_, let a): return a
        case .blockQuote(_, let a): return a
        case .list(_, _, let a): return a
        case .codeBlock(_, _, let a): return a
        case .table(_, _, _, let a): return a
        case .admonition(_, _, _, _, let a): return a
        case .div(_, let a): return a
        case .placeholder(_, let a): return a
        default: return nil
        }
    }
}
