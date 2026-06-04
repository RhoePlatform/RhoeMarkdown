import Foundation
import RhoeMarkdownModel

/// Merged Stage 3 structural normalization pass — combines display math hoisting,
/// structural normalization, section hierarchy building, and table normalization
/// into a **single AST traversal** instead of four separate passes.
///
/// Two-phase approach per block sequence:
/// - **Phase A:** Per-block local transforms (structural normalization → math hoisting)
/// - **Phase B:** Sequence-level section hierarchy building
///
/// Container blocks recurse through `processBlockSequence()` exactly once,
/// running the full two-phase pipeline on children.
struct Stage3NormalizationPass: DocumentPass, Sendable {

    func process(_ document: RhoeMarkdownKit.Document) -> RhoeMarkdownKit.Document {
        let normalized = processBlockSequence(document.blocks)
        return RhoeMarkdownKit.Document(blocks: normalized, metadata: document.metadata)
    }

    // MARK: - Main Entry: Phase A then Phase B

    /// Process a block sequence: apply local transforms, then build section hierarchy.
    private func processBlockSequence(_ blocks: [Block]) -> [Block] {
        // Phase A: structural normalize + math hoist each block
        var locallyNormalized: [Block] = []
        for block in blocks {
            locallyNormalized.append(contentsOf: normalizeAndHoist(block))
        }
        // Phase B: build section hierarchy from the normalized flat sequence
        return buildSections(from: locallyNormalized)
    }

    // MARK: - Phase A: Per-Block Local Transforms

    /// Apply structural normalization then math hoisting to a single block.
    /// Returns 0+ blocks (normalization can remove; hoisting can split).
    private func normalizeAndHoist(_ block: Block) -> [Block] {
        guard let normalized = structuralNormalize(block) else {
            return [] // Block removed (e.g., abbreviationDefinition)
        }
        return mathHoist(normalized)
    }

    // MARK: - Structural Normalization (from StructuralNormalizationPass)

    /// Convert surface-local constructs to canonical form.
    /// Container blocks recurse via processBlockSequence (runs full Phase A + B on children).
    private func structuralNormalize(_ block: Block) -> Block? {
        switch block {
        // Surface-local → canonical conversions

        case .widget(let title, let content, let attrs):
            var mergedAttrs = withRole(attrs, role: "widget")
            mergedAttrs = withKeyValue(mergedAttrs, key: "name", value: title)
            return .div(content: processBlockSequence(content), attributes: mergedAttrs)

        case .tab(let title, let content, let attrs):
            var mergedAttrs = withRole(attrs, role: "tab")
            mergedAttrs = withKeyValue(mergedAttrs, key: "name", value: title)
            return .div(content: processBlockSequence(content), attributes: mergedAttrs)

        case .lineBlock(let lines):
            var inlines: [Inline] = []
            for (index, line) in lines.enumerated() {
                inlines.append(contentsOf: line)
                if index < lines.count - 1 {
                    inlines.append(.hardBreak)
                }
            }
            return .paragraph(inlines, attributes: RhoeMarkdownKit.Attributes())

        case .stage(let kind, let content, let attrs):
            return .extension_(vendor: "rhoe", name: "stage.\(kind.rawValue)", content: processBlockSequence(content), attributes: attrs)

        case .lane(let content, let attrs):
            return .extension_(vendor: "rhoe", name: "lane", content: processBlockSequence(content), attributes: attrs)

        case .module(let family, let name, let content, let attrs):
            return .extension_(vendor: "rhoe", name: "module.\(family).\(name)", content: processBlockSequence(content), attributes: attrs)

        case .contractDirective(let kind, let content, let attrs):
            return .extension_(vendor: "rhoe", name: "contract.\(kind.rawValue)", content: [
                .paragraph([.text(content)])
            ], attributes: attrs)

        case .html(let raw):
            return .rawBlock(content: raw, format: "html", attributes: RhoeMarkdownKit.Attributes())

        case .abbreviationDefinition:
            return nil

        // Container blocks — recurse via processBlockSequence

        case .blockQuote(let children, let attrs):
            return .blockQuote(processBlockSequence(children), attributes: attrs)
        case .list(let type, let items, let attrs):
            let normalizedItems = items.map { item in
                ListItem(
                    content: processBlockSequence(item.content),
                    checked: item.checked,
                    isLoose: item.isLoose
                )
            }
            return .list(type: type, items: normalizedItems, attributes: attrs)
        case .admonition(let type, let title, let content, let collapsible, let attrs):
            return .admonition(type: type, title: title, content: processBlockSequence(content), collapsible: collapsible, attributes: attrs)
        case .div(let content, let attrs):
            return .div(content: processBlockSequence(content), attributes: attrs)
        case .footnoteDefinition(let id, let content):
            return .footnoteDefinition(id: id, content: processBlockSequence(content))
        case .visualBlock(let name, let content, let attrs):
            return .visualBlock(name: name, content: processBlockSequence(content), attributes: attrs)
        case .form(let name, let content, let attrs):
            return .form(name: name, content: processBlockSequence(content), attributes: attrs)
        case .componentDeclaration(let family, let name, let args, let slots, let body, let attrs):
            return .componentDeclaration(family: family, name: name, args: args, slots: slots, body: processBlockSequence(body), attributes: attrs)
        // Canonical structural containers.
        case .section(let level, let title, let children, let attrs):
            return .section(level: level, title: title, children: processBlockSequence(children), attributes: attrs)
        case .formalBlock(let family, let title, let number, let content, let attrs):
            return .formalBlock(family: family, title: title, number: number, content: processBlockSequence(content), attributes: attrs)
        case .speakerNotes(let content, let attrs):
            return .speakerNotes(content: processBlockSequence(content), attributes: attrs)
        case .grid(let content, let attrs):
            return .grid(content: processBlockSequence(content), attributes: attrs)
        case .columns(let content, let attrs):
            return .columns(content: processBlockSequence(content), attributes: attrs)
        case .figure(let content, let caption, let attrs):
            return .figure(content: processBlockSequence(content), caption: caption, attributes: attrs)
        case .shape(let content, let attrs):
            return .shape(content: processBlockSequence(content), attributes: attrs)
        case .deck(let slides, let attrs):
            return .deck(slides: processBlockSequence(slides), attributes: attrs)
        case .slide(let title, let content, let attrs):
            return .slide(title: title, content: processBlockSequence(content), attributes: attrs)
        case .slotContent(let name, let content, let attrs):
            return .slotContent(name: name, content: processBlockSequence(content), attributes: attrs)
        case .extension_(let vendor, let name, let content, let attrs):
            return .extension_(vendor: vendor, name: name, content: processBlockSequence(content), attributes: attrs)

        // Leaf blocks — pass through unchanged
        default:
            return block
        }
    }

    // MARK: - Math Hoisting (from DisplayMathHoistingPass)

    /// If the block is a paragraph containing mathDisplay, hoist to mathBlock.
    /// Does NOT recurse into containers (handled by structuralNormalize).
    private func mathHoist(_ block: Block) -> [Block] {
        guard case .paragraph(let inlines, let attrs) = block else {
            return [block]
        }
        guard inlines.contains(where: { isMathDisplay($0) }) else {
            return [.paragraph(inlines, attributes: attrs)]
        }
        return hoistFromParagraph(inlines: inlines, attributes: attrs)
    }

    private func hoistFromParagraph(inlines: [Inline], attributes: RhoeMarkdownKit.Attributes) -> [Block] {
        let nonWhitespace = inlines.filter { !isWhitespaceInline($0) }
        if nonWhitespace.count == 1, case .mathDisplay(let expr, let mathAttrs) = nonWhitespace[0] {
            let mergedAttrs = mergeAttributes(mathAttrs, into: attributes)
            return [.mathBlock(expression: expr, attributes: mergedAttrs)]
        }

        var result: [Block] = []
        var currentInlines: [Inline] = []

        for inline in inlines {
            if case .mathDisplay(let expr, let mathAttrs) = inline {
                if !currentInlines.isEmpty && currentInlines.contains(where: { !isWhitespaceInline($0) }) {
                    result.append(.paragraph(currentInlines, attributes: attributes))
                }
                currentInlines = []
                result.append(.mathBlock(expression: expr, attributes: mathAttrs))
            } else {
                currentInlines.append(inline)
            }
        }

        if !currentInlines.isEmpty && currentInlines.contains(where: { !isWhitespaceInline($0) }) {
            result.append(.paragraph(currentInlines, attributes: attributes))
        }

        return result
    }

    // MARK: - Section Hierarchy (from SectionHierarchyPass)

    /// Build section hierarchy from a flat block sequence.
    /// Does NOT recurse into containers (children already processed by Phase A).
    private func buildSections(from blocks: [Block]) -> [Block] {
        var result: [Block] = []
        var sectionStack: [SectionBuilder] = []

        for block in blocks {
            switch block {
            case .heading(let level, let content, let attrs):
                while let top = sectionStack.last, top.level >= level {
                    let closed = sectionStack.removeLast()
                    let section = closed.build()
                    if sectionStack.isEmpty {
                        result.append(section)
                    } else {
                        sectionStack[sectionStack.count - 1].children.append(section)
                    }
                }
                sectionStack.append(SectionBuilder(level: level, title: content, attributes: attrs))
            default:
                if sectionStack.isEmpty {
                    result.append(block)
                } else {
                    sectionStack[sectionStack.count - 1].children.append(block)
                }
            }
        }

        while let top = sectionStack.popLast() {
            let section = top.build()
            if sectionStack.isEmpty {
                result.append(section)
            } else {
                sectionStack[sectionStack.count - 1].children.append(section)
            }
        }

        return result
    }

    // MARK: - Helpers

    private struct SectionBuilder {
        let level: Int
        let title: [Inline]
        let attributes: RhoeMarkdownKit.Attributes
        var children: [Block] = []
        func build() -> Block {
            .section(level: level, title: title, children: children, attributes: attributes)
        }
    }

    private func isMathDisplay(_ inline: Inline) -> Bool {
        if case .mathDisplay = inline { return true }
        return false
    }

    private func isWhitespaceInline(_ inline: Inline) -> Bool {
        switch inline {
        case .text(let t) where t.allSatisfy(\.isWhitespace): return true
        case .softBreak, .hardBreak: return true
        default: return false
        }
    }

    private func mergeAttributes(_ source: RhoeMarkdownKit.Attributes, into target: RhoeMarkdownKit.Attributes) -> RhoeMarkdownKit.Attributes {
        let id = source.id ?? target.id
        let classes = source.classes.isEmpty ? target.classes : source.classes
        var kv = target.keyValues
        for (k, v) in source.keyValues { kv[k] = v }
        return RhoeMarkdownKit.Attributes(id: id, classes: classes, keyValues: kv)
    }

    private func withRole(_ attrs: RhoeMarkdownKit.Attributes, role: String) -> RhoeMarkdownKit.Attributes {
        var kv = attrs.keyValues
        kv["role"] = role
        return RhoeMarkdownKit.Attributes(id: attrs.id, classes: attrs.classes, keyValues: kv)
    }

    private func withKeyValue(_ attrs: RhoeMarkdownKit.Attributes, key: String, value: String) -> RhoeMarkdownKit.Attributes {
        var kv = attrs.keyValues
        kv[key] = value
        return RhoeMarkdownKit.Attributes(id: attrs.id, classes: attrs.classes, keyValues: kv)
    }
}
