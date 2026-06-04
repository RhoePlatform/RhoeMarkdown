import Foundation
import RhoeMarkdownModel

/// Stage 7 validation pass: ensures no pipeline-internal node kinds survive
/// past the canonical semantic freeze boundary.
///
/// Pipeline-internal cases are nodes produced during early pipeline stages
/// (parsing, Phase 1/2, component expansion) that must be resolved, evaluated,
/// or normalized before the AST reaches canonical form.
///
/// Any pipeline-internal node found after Stage 7 indicates a pipeline bug —
/// either a pass failed to run or failed to process all nodes.
struct CanonicalFreezeValidationPass: DocumentPass, Sendable {

    struct FreezeViolation: Sendable {
        let nodeDescription: String
        let context: String
    }

    /// DocumentPass conformance: validates and attaches freeze-violation
    /// diagnostics to the document metadata.
    ///
    /// The AST itself passes through unchanged — violations are diagnostic-only
    /// and indicate a pipeline bug where a normalization pass failed to convert
    /// a surface-local construct before the freeze boundary.
    func process(_ document: RhoeMarkdownKit.Document) -> RhoeMarkdownKit.Document {
        let violations = validate(document)
        guard !violations.isEmpty else { return document }

        let freezeDiagnostics = violations.map { violation in
            RhoeMarkdownKit.Diagnostic.warning(
                "Pipeline-internal node survived to Stage 7: \(violation.nodeDescription) (\(violation.context))"
            )
        }

        var metadata = document.metadata
        metadata.attributeValidationDiagnostics.append(contentsOf: freezeDiagnostics)
        return RhoeMarkdownKit.Document(blocks: document.blocks, metadata: metadata)
    }

    /// Validate that the document contains no pipeline-internal inline or block nodes.
    func validate(_ document: RhoeMarkdownKit.Document) -> [FreezeViolation] {
        var checker = FreezeChecker()
        for block in document.blocks {
            checker.checkBlock(block, context: "document")
        }
        return checker.violations
    }

    // MARK: - Internal Checker

    private struct FreezeChecker {
        var violations: [FreezeViolation] = []

        mutating func checkBlock(_ block: Block, context: String) {
            // Check for pipeline-internal block cases
            switch block {
            case .componentDeclaration:
                violations.append(FreezeViolation(nodeDescription: "componentDeclaration", context: context))
            case .phase2Directive:
                violations.append(FreezeViolation(nodeDescription: "phase2Directive", context: context))
            case .placeholder:
                violations.append(FreezeViolation(nodeDescription: "placeholder", context: context))
            case .expression:
                violations.append(FreezeViolation(nodeDescription: "expression", context: context))
            case .transclusion:
                violations.append(FreezeViolation(nodeDescription: "transclusion", context: context))
            case .schemaIsland:
                violations.append(FreezeViolation(nodeDescription: "schemaIsland", context: context))
            case .abbreviationDefinition:
                violations.append(FreezeViolation(nodeDescription: "abbreviationDefinition", context: context))
            // Surface-local constructs (should be converted by StructuralNormalizationPass)
            case .widget:
                violations.append(FreezeViolation(nodeDescription: "widget (should be normalized to div)", context: context))
            case .tab:
                violations.append(FreezeViolation(nodeDescription: "tab (should be normalized to div)", context: context))
            case .lineBlock:
                // Sprint 34 promotes lineBlock into the editor contract, but the
                // canonical freeze boundary still requires normalization back to
                // paragraph-plus-break semantics for Stage 7 output.
                violations.append(FreezeViolation(nodeDescription: "lineBlock (should be normalized to paragraph)", context: context))
            case .stage:
                violations.append(FreezeViolation(nodeDescription: "stage (should be normalized to extension_)", context: context))
            case .lane:
                violations.append(FreezeViolation(nodeDescription: "lane (should be normalized to extension_)", context: context))
            case .module:
                violations.append(FreezeViolation(nodeDescription: "module (should be normalized to extension_)", context: context))
            case .contractDirective:
                violations.append(FreezeViolation(nodeDescription: "contractDirective (should be normalized to extension_)", context: context))
            case .html:
                violations.append(FreezeViolation(nodeDescription: "html (should be normalized to rawBlock)", context: context))
            case .heading:
                violations.append(FreezeViolation(nodeDescription: "heading (should be normalized to section)", context: context))
            default:
                break
            }

            // Recurse into children
            for child in blockChildren(block) {
                checkBlock(child, context: "nested in \(blockName(block))")
            }

            // Check inline content
            for inline in blockInlines(block) {
                checkInline(inline, context: "inline in \(blockName(block))")
            }
        }

        mutating func checkInline(_ inline: Inline, context: String) {
            // Check for pipeline-internal inline cases
            switch inline {
            case .softBreak:
                violations.append(FreezeViolation(nodeDescription: "softBreak", context: context))
            case .inlineFootnote:
                violations.append(FreezeViolation(nodeDescription: "inlineFootnote", context: context))
            case .resolvedCitation:
                violations.append(FreezeViolation(nodeDescription: "resolvedCitation", context: context))
            case .resolvedCrossReference:
                violations.append(FreezeViolation(nodeDescription: "resolvedCrossReference", context: context))
            case .annotationInline:
                violations.append(FreezeViolation(nodeDescription: "annotationInline", context: context))
            case .transclusionInline:
                violations.append(FreezeViolation(nodeDescription: "transclusionInline", context: context))
            case .paramRef:
                violations.append(FreezeViolation(nodeDescription: "paramRef", context: context))
            case .slotRef:
                violations.append(FreezeViolation(nodeDescription: "slotRef", context: context))
            case .placeholderInline:
                violations.append(FreezeViolation(nodeDescription: "placeholderInline", context: context))
            case .expressionInline:
                violations.append(FreezeViolation(nodeDescription: "expressionInline", context: context))
            case .inputFieldInline:
                violations.append(FreezeViolation(nodeDescription: "inputFieldInline", context: context))
            case .mathDisplay:
                violations.append(FreezeViolation(nodeDescription: "mathDisplay (should be hoisted to Block.mathBlock)", context: context))
            default:
                break
            }

            // Recurse into child inlines
            for child in inlineChildren(inline) {
                checkInline(child, context: context)
            }
        }

        // MARK: - Child Extraction Helpers

        private func blockChildren(_ block: Block) -> [Block] {
            switch block {
            case .blockQuote(let blocks, _): return blocks
            case .list(_, let items, _): return items.flatMap(\.content)
            case .admonition(_, _, let content, _, _): return content
            case .div(let content, _): return content
            case .visualBlock(_, let content, _): return content
            case .form(_, let content, _): return content
            case .footnoteDefinition(_, let content): return content
            case .componentDeclaration(_, _, _, _, let body, _): return body
            case .widget(_, let content, _): return content
            case .tab(_, let content, _): return content
            case .stage(_, let content, _): return content
            case .lane(let content, _): return content
            case .module(_, _, let content, _): return content
            case .section(_, _, let children, _): return children
            case .formalBlock(_, _, _, let content, _): return content
            case .speakerNotes(let content, _): return content
            case .grid(let content, _): return content
            case .columns(let content, _): return content
            case .figure(let content, _, _): return content
            case .shape(let content, _): return content
            case .deck(let slides, _): return slides
            case .slide(_, let content, _): return content
            case .slotContent(_, let content, _): return content
            case .extension_(_, _, let content, _): return content
            default: return []
            }
        }

        private func blockInlines(_ block: Block) -> [Inline] {
            switch block {
            case .paragraph(let inlines, _): return inlines
            case .heading(_, let content, _): return content
            case .section(_, let title, _, _): return title
            case .formalBlock(_, let title, _, _, _): return title ?? []
            case .figure(_, let caption, _): return caption ?? []
            case .slide(let title, _, _): return title ?? []
            default: return []
            }
        }

        private func inlineChildren(_ inline: Inline) -> [Inline] {
            switch inline {
            case .emphasis(let c), .strong(let c), .strikethrough(let c),
                 .superscript(let c), .subscript(let c), .highlight(let c):
                return c
            case .link(let text, _, _, _): return text
            case .image(let alt, _, _, _): return alt
            case .span(let content, _): return content
            case .inlineFootnote(let content): return content
            case .wikilink(_, let display): return display ?? []
            default: return []
            }
        }

        private func blockName(_ block: Block) -> String {
            switch block {
            case .paragraph: return "paragraph"
            case .heading: return "heading"
            case .blockQuote: return "blockQuote"
            case .list: return "list"
            case .admonition: return "admonition"
            case .div: return "div"
            case .section: return "section"
            case .formalBlock: return "formalBlock"
            default: return "block"
            }
        }
    }
}
