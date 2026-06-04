import Foundation
import RhoeMarkdownModel
import RhoeMarkdownRendering

/// Post-parse pipeline pass that renders diagram code blocks into inline SVG.
///
/// Walks the document's block tree, identifies code blocks whose language
/// matches a recognized diagram engine (Mermaid, Graphviz, PlantUML, D2),
/// and replaces them with `html(...)` blocks containing the rendered SVG
/// wrapped in a `<figure class="diagram">` element.
///
/// When a diagram tool is not installed or rendering fails, the original
/// code block is preserved unchanged, allowing writers to render it as
/// a standard code listing.
public struct DiagramRenderingPass: DocumentPass, Sendable {
    private let engine: DiagramEngine

    public init(configuration: RhoeMarkdownKit.DiagramConfiguration) {
        self.engine = DiagramEngine(configuration: configuration)
    }

    public func process(_ document: RhoeMarkdownKit.Document) -> RhoeMarkdownKit.Document {
        let transformedBlocks = document.blocks.map { transformBlock($0) }
        return RhoeMarkdownKit.Document(
            blocks: transformedBlocks,
            metadata: document.metadata
        )
    }

    // MARK: - Block Transformation

    private func transformBlock(_ block: Block) -> Block {
        switch block {
        case .codeBlock(let language, let content, let attrs):
            guard let lang = language, engine.isDiagramLanguage(lang) else {
                return block
            }
            if let result = engine.render(language: lang, source: content) {
                return .html(wrapDiagramSVG(result.svg, language: lang, attributes: attrs))
            }
            // Tool not available or rendering failed — keep as code block
            return block

        case .blockQuote(let blocks, let attrs):
            return .blockQuote(blocks.map { transformBlock($0) }, attributes: attrs)

        case .list(let type, let items, let attrs):
            let mapped = items.map { item in
                ListItem(
                    content: item.content.map { transformBlock($0) },
                    checked: item.checked,
                    isLoose: item.isLoose
                )
            }
            return .list(type: type, items: mapped, attributes: attrs)

        case .div(let content, let attrs):
            return .div(content: content.map { transformBlock($0) }, attributes: attrs)

        case .admonition(let type, let title, let content, let collapsible, let attrs):
            return .admonition(
                type: type,
                title: title,
                content: content.map { transformBlock($0) },
                collapsible: collapsible,
                attributes: attrs
            )

        default:
            return block
        }
    }

    // MARK: - SVG Wrapping

    private func wrapDiagramSVG(
        _ svg: String,
        language: String,
        attributes: RhoeMarkdownKit.Attributes
    ) -> String {
        let idAttr = attributes.id.map { " id=\"\($0)\"" } ?? ""
        let extraClasses = attributes.classes.isEmpty ? "" : " " + attributes.classes.joined(separator: " ")
        return "<figure class=\"diagram \(language)\(extraClasses)\"\(idAttr)>\(svg)</figure>"
    }
}
