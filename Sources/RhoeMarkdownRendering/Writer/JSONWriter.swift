import Foundation
import RhoeMarkdownModel

/// Serializes a parsed RhoeMarkdown document to canonical RhoeJSON format.
///
/// Produces a versioned JSON representation of the fully normalized AST
/// using PascalCase node kinds, six-bucket attribute serialization, and
/// the `rhoejson-canonical/v1` envelope.
///
/// Uses the visitor protocol for AST dispatch — no exhaustive switch statements.
public struct JSONWriter: DocumentWriter, Sendable {
    public typealias Output = Data

    public init() {}

    public func write(_ document: RhoeMarkdownKit.Document) -> Data {
        // Build metadata
        var meta: [String: Any] = [
            "wordCount": document.metadata.wordCount
        ]
        if let fm = document.metadata.yamlFrontmatter {
            var fmDict: [String: Any] = [:]
            for (key, value) in fm { fmDict[key] = serializeYAMLValue(value) }
            meta["frontmatter"] = fmDict
        }

        // Canonical envelope.
        let root: [String: Any] = [
            "schema": "rhoejson-canonical/v1",
            "rhoeVersion": "4.0",
            "form": "canonical",
            "document": [
                "node": "Document",
                "children": document.blocks.map { serializeBlock($0) },
                "metadata": meta
            ] as [String: Any]
        ]

        guard let data = try? JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            return Data()
        }
        return data
    }

    // MARK: - Visitor-Based Serialization

    func serializeBlock(_ block: Block) -> [String: Any] {
        var visitor = BlockSerializer()
        block.accept(&visitor)
        return visitor.result
    }

    func serializeInline(_ inline: Inline) -> [String: Any] {
        var visitor = InlineSerializer()
        inline.accept(&visitor)
        return visitor.result
    }

    // MARK: - Block Serializer Visitor

    private struct BlockSerializer: BlockVisitor {
        var result: [String: Any] = [:]
        private let writer = JSONWriter()

        mutating func visitParagraph(_ inlines: [Inline], attributes: RhoeMarkdownKit.Attributes) {
            result = node("Paragraph", attrs: attributes, children: [
                "inlines": inlines.map { writer.serializeInline($0) }
            ])
        }

        mutating func visitHeading(level: Int, content: [Inline], attributes: RhoeMarkdownKit.Attributes) {
            result = node("Heading", attrs: attributes, children: [
                "props": ["level": level],
                "inlines": content.map { writer.serializeInline($0) }
            ])
        }

        mutating func visitBlockQuote(_ blocks: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = node("BlockQuote", attrs: attributes, children: [
                "children": blocks.map { writer.serializeBlock($0) }
            ])
        }

        mutating func visitList(type: ListType, items: [ListItem], attributes: RhoeMarkdownKit.Attributes) {
            result = node("List", attrs: attributes, children: [
                "props": writer.serializeListType(type),
                "items": items.map { writer.serializeListItem($0) }
            ])
        }

        mutating func visitCodeBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes) {
            var props: [String: Any] = [:]
            if let language { props["language"] = language }
            var fields: [String: Any] = ["text": content]
            if !props.isEmpty { fields["props"] = props }
            result = node("CodeBlock", attrs: attributes, children: fields)
        }

        mutating func visitHorizontalRule() {
            result = ["node": "HorizontalRule"]
        }

        mutating func visitTable(headers: [TableCell], rows: [[TableCell]], caption: [Inline]?, attributes: RhoeMarkdownKit.Attributes) {
            var fields: [String: Any] = [
                "headers": headers.map { writer.serializeTableCell($0) },
                "rows": rows.map { $0.map { writer.serializeTableCell($0) } }
            ]
            if let caption { fields["caption"] = caption.map { writer.serializeInline($0) } }
            result = node("Table", attrs: attributes, children: fields)
        }

        mutating func visitDefinitionList(items: [DefinitionListItem], attributes: RhoeMarkdownKit.Attributes) {
            result = node("DefinitionList", attrs: attributes, children: [
                "items": items.map { [
                    "term": $0.term.map { writer.serializeInline($0) },
                    "definitions": $0.definitions.map { $0.map { writer.serializeBlock($0) } }
                ] as [String: Any] }
            ])
        }

        mutating func visitFootnoteDefinition(id: String, content: [Block]) {
            result = ["node": "FootnoteDefinition",
                      "props": ["id": id],
                      "children": content.map { writer.serializeBlock($0) }] as [String: Any]
        }

        mutating func visitAdmonition(type: String, title: String?, content: [Block], collapsible: AdmonitionCollapsible?, attributes: RhoeMarkdownKit.Attributes) {
            var props: [String: Any] = ["admonitionType": type]
            if let title { props["title"] = title }
            if let collapsible { props["collapsible"] = String(describing: collapsible) }
            result = node("Admonition", attrs: attributes, children: [
                "props": props,
                "children": content.map { writer.serializeBlock($0) }
            ])
        }

        mutating func visitBlockHTML(_ html: String) {
            result = ["node": "BlockHTML", "text": html]
        }

        mutating func visitDiv(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = node("Div", attrs: attributes, children: [
                "children": content.map { writer.serializeBlock($0) }
            ])
        }

        mutating func visitLineBlock(lines: [[Inline]]) {
            result = ["node": "LineBlock",
                      "lines": lines.map { $0.map { writer.serializeInline($0) } }] as [String: Any]
        }

        mutating func visitAbbreviationDefinition(abbreviation: String, expansion: String) {
            result = ["node": "AbbreviationDefinition",
                      "props": ["abbreviation": abbreviation, "expansion": expansion]] as [String: Any]
        }

        mutating func visitVisualBlock(name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = node("VisualBlock", attrs: attributes, children: [
                "props": ["name": name],
                "children": content.map { writer.serializeBlock($0) }
            ])
        }

        mutating func visitAuthorAnnotation(kind: AnnotationKind, text: String, attributes: RhoeMarkdownKit.Attributes) {
            result = node("AuthorAnnotation", attrs: attributes, children: [
                "props": ["kind": kind.rawValue],
                "text": text
            ])
        }

        mutating func visitTransclusion(target: String, fragment: String?, mode: TransclusionMode?, attributes: RhoeMarkdownKit.Attributes) {
            var props: [String: Any] = ["target": target]
            if let fragment { props["fragment"] = fragment }
            if let mode { props["mode"] = String(describing: mode) }
            result = node("Transclusion", attrs: attributes, children: [
                "props": props
            ])
        }

        mutating func visitSchemaIsland(schema: String, body: String, attributes: RhoeMarkdownKit.Attributes) {
            result = node("SchemaIsland", attrs: attributes, children: [
                "props": ["schema": schema],
                "text": body
            ])
        }

        mutating func visitComponentDeclaration(family: BlockFamily, name: String, args: String?, slots: String?, body: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = node("ComponentDeclaration", attrs: attributes, children: [
                "props": ["name": name, "family": String(describing: family)],
                "children": body.map { writer.serializeBlock($0) }
            ])
        }

        mutating func visitPhase2Directive(command: String, arguments: [String: String], body: String?, attributes: RhoeMarkdownKit.Attributes) {
            var props: [String: Any] = ["command": command, "arguments": arguments]
            if let body { props["body"] = body }
            result = node("Phase2Directive", attrs: attributes, children: [
                "props": props
            ])
        }

        mutating func visitPlaceholder(fields: [String: String], attributes: RhoeMarkdownKit.Attributes) {
            result = node("Placeholder", attrs: attributes, children: [
                "props": ["fields": fields]
            ])
        }

        mutating func visitExpression(expr: String, attributes: RhoeMarkdownKit.Attributes) {
            result = node("Expression", attrs: attributes, children: [
                "props": ["expr": expr]
            ])
        }

        mutating func visitField(name: String, fieldType: String, attributes: RhoeMarkdownKit.Attributes) {
            result = node("Field", attrs: attributes, children: [
                "props": ["name": name, "fieldType": fieldType]
            ])
        }

        mutating func visitForm(name: String?, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            var props: [String: Any] = [:]
            if let name { props["name"] = name }
            var fields: [String: Any] = [
                "children": content.map { writer.serializeBlock($0) }
            ]
            if !props.isEmpty { fields["props"] = props }
            result = node("Form", attrs: attributes, children: fields)
        }

        mutating func visitWidget(title: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = node("Widget", attrs: attributes, children: [
                "props": ["title": title],
                "children": content.map { writer.serializeBlock($0) }
            ])
        }

        mutating func visitTab(title: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = node("Tab", attrs: attributes, children: [
                "props": ["title": title],
                "children": content.map { writer.serializeBlock($0) }
            ])
        }

        mutating func visitStage(kind: StageKind, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = node("Stage", attrs: attributes, children: [
                "props": ["kind": kind.rawValue],
                "children": content.map { writer.serializeBlock($0) }
            ])
        }

        mutating func visitLane(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = node("Lane", attrs: attributes, children: [
                "children": content.map { writer.serializeBlock($0) }
            ])
        }

        mutating func visitModule(family: String, name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = node("Module", attrs: attributes, children: [
                "props": ["family": family, "name": name],
                "children": content.map { writer.serializeBlock($0) }
            ])
        }

        mutating func visitContractDirective(kind: ContractKind, content: String, attributes: RhoeMarkdownKit.Attributes) {
            result = node("ContractDirective", attrs: attributes, children: [
                "props": ["kind": kind.rawValue],
                "text": content
            ])
        }

        // Canonical node kinds.

        mutating func visitSection(level: Int, title: [Inline], children: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = node("Section", attrs: attributes, children: [
                "props": ["level": level],
                "title": title.map { writer.serializeInline($0) },
                "children": children.map { writer.serializeBlock($0) }
            ])
        }

        mutating func visitFormalBlock(family: String, title: [Inline]?, number: String?, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            var props: [String: Any] = ["family": family]
            if let number { props["number"] = number }
            var fields: [String: Any] = [
                "props": props,
                "children": content.map { writer.serializeBlock($0) }
            ]
            if let title { fields["title"] = title.map { writer.serializeInline($0) } }
            result = node("FormalBlock", attrs: attributes, children: fields)
        }

        mutating func visitSpeakerNotes(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = node("SpeakerNotes", attrs: attributes, children: [
                "children": content.map { writer.serializeBlock($0) }
            ])
        }

        mutating func visitGrid(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = node("Grid", attrs: attributes, children: [
                "children": content.map { writer.serializeBlock($0) }
            ])
        }

        mutating func visitColumns(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = node("Columns", attrs: attributes, children: [
                "children": content.map { writer.serializeBlock($0) }
            ])
        }

        mutating func visitFigure(content: [Block], caption: [Inline]?, attributes: RhoeMarkdownKit.Attributes) {
            var fields: [String: Any] = ["children": content.map { writer.serializeBlock($0) }]
            if let caption { fields["caption"] = caption.map { writer.serializeInline($0) } }
            result = node("Figure", attrs: attributes, children: fields)
        }

        mutating func visitDiagramBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes) {
            var props: [String: Any] = [:]
            if let language { props["language"] = language }
            var fields: [String: Any] = ["text": content]
            if !props.isEmpty { fields["props"] = props }
            result = node("DiagramBlock", attrs: attributes, children: fields)
        }

        mutating func visitShape(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = node("Shape", attrs: attributes, children: [
                "children": content.map { writer.serializeBlock($0) }
            ])
        }

        mutating func visitTableHead(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes) {
            result = node("TableHead", attrs: attributes, children: [
                "rows": rows.map { $0.map { writer.serializeTableCell($0) } }
            ])
        }

        mutating func visitTableBody(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes) {
            result = node("TableBody", attrs: attributes, children: [
                "rows": rows.map { $0.map { writer.serializeTableCell($0) } }
            ])
        }

        mutating func visitTableFoot(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes) {
            result = node("TableFoot", attrs: attributes, children: [
                "rows": rows.map { $0.map { writer.serializeTableCell($0) } }
            ])
        }

        mutating func visitTableRow(cells: [TableCell], attributes: RhoeMarkdownKit.Attributes) {
            result = node("TableRow", attrs: attributes, children: [
                "cells": cells.map { writer.serializeTableCell($0) }
            ])
        }

        mutating func visitExecutableCodeBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes) {
            var props: [String: Any] = [:]
            if let language { props["language"] = language }
            if !attributes.keyValues.isEmpty { props["attributes"] = attributes.keyValues }
            var fields: [String: Any] = ["text": content]
            if !props.isEmpty { fields["props"] = props }
            result = node("ExecutableCodeBlock", attrs: attributes, children: fields)
        }

        mutating func visitMathBlock(expression: String, attributes: RhoeMarkdownKit.Attributes) {
            result = node("MathBlock", attrs: attributes, children: ["text": expression])
        }

        mutating func visitDeck(slides: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = node("Deck", attrs: attributes, children: [
                "children": slides.map { writer.serializeBlock($0) }
            ])
        }

        mutating func visitSlide(title: [Inline]?, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            var fields: [String: Any] = ["children": content.map { writer.serializeBlock($0) }]
            if let title { fields["title"] = title.map { writer.serializeInline($0) } }
            result = node("Slide", attrs: attributes, children: fields)
        }

        mutating func visitSlotContent(name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = node("SlotContent", attrs: attributes, children: [
                "props": ["name": name],
                "children": content.map { writer.serializeBlock($0) }
            ])
        }

        mutating func visitExtension(vendor: String, name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = node("Extension", attrs: attributes, children: [
                "props": ["vendor": vendor, "name": name],
                "children": content.map { writer.serializeBlock($0) }
            ])
        }

        mutating func visitRawBlock(content: String, format: String, attributes: RhoeMarkdownKit.Attributes) {
            result = node("RawBlock", attrs: attributes, children: [
                "props": ["format": format],
                "text": content
            ])
        }

        // MARK: - Node Helper

        private func node(_ kind: String, attrs: RhoeMarkdownKit.Attributes, children: [String: Any]) -> [String: Any] {
            var result: [String: Any] = ["node": kind]

            // Six-bucket attribute serialization
            let buckets = attrs.bucketized()
            if !buckets.isEmpty {
                if !buckets.identity.isEmpty {
                    var identity: [String: Any] = [:]
                    if let id = buckets.identity.id { identity["id"] = id }
                    if !buckets.identity.classes.isEmpty { identity["classes"] = buckets.identity.classes }
                    if let name = buckets.identity.name { identity["name"] = name }
                    if let key = buckets.identity.key { identity["key"] = key }
                    if let ref = buckets.identity.ref { identity["ref"] = ref }
                    result["identity"] = identity
                }
                if !buckets.presentational.isEmpty {
                    result["presentational"] = buckets.presentational
                }
                if !buckets.semantic.isEmpty {
                    result["semantic"] = buckets.semantic
                }
                if !buckets.interaction.isEmpty {
                    result["interaction"] = buckets.interaction
                }
                if !buckets.projection.isEmpty {
                    var projection: [String: Any] = [:]
                    if !buckets.projection.visible.isEmpty { projection["visible"] = buckets.projection.visible }
                    if !buckets.projection.hidden.isEmpty { projection["hidden"] = buckets.projection.hidden }
                    if buckets.projection.assistiveOnly { projection["assistiveOnly"] = true }
                    result["projection"] = projection
                }
                if !buckets.writerHints.isEmpty {
                    result["writerHints"] = buckets.writerHints
                }
            }

            result.merge(children) { _, new in new }
            return result
        }
    }

    // MARK: - Inline Serializer Visitor

    private struct InlineSerializer: InlineVisitor {
        var result: [String: Any] = [:]
        private let writer = JSONWriter()

        mutating func visitText(_ text: String) {
            result = ["node": "Text", "text": text]
        }

        mutating func visitEmphasis(_ inlines: [Inline]) {
            result = ["node": "Emphasis", "inlines": inlines.map { writer.serializeInline($0) }]
        }

        mutating func visitStrong(_ inlines: [Inline]) {
            result = ["node": "Strong", "inlines": inlines.map { writer.serializeInline($0) }]
        }

        mutating func visitStrikethrough(_ inlines: [Inline]) {
            result = ["node": "Strikethrough", "inlines": inlines.map { writer.serializeInline($0) }]
        }

        mutating func visitCodeSpan(_ code: String, attributes: RhoeMarkdownKit.Attributes) {
            result = ["node": "CodeSpan", "text": code]
        }

        mutating func visitLink(text: [Inline], url: String, title: String?, attributes: RhoeMarkdownKit.Attributes) {
            var props: [String: Any] = ["url": url]
            if let title { props["title"] = title }
            result = ["node": "Link", "props": props, "inlines": text.map { writer.serializeInline($0) }] as [String: Any]
        }

        mutating func visitImage(alt: [Inline], url: String, title: String?, attributes: RhoeMarkdownKit.Attributes) {
            var props: [String: Any] = ["url": url]
            if let title { props["title"] = title }
            result = ["node": "Image", "props": props, "inlines": alt.map { writer.serializeInline($0) }] as [String: Any]
        }

        mutating func visitFootnoteRef(id: String) {
            result = ["node": "FootnoteRef", "props": ["id": id]] as [String: Any]
        }

        mutating func visitInlineMath(expression: String, attributes: RhoeMarkdownKit.Attributes) {
            result = ["node": "InlineMath", "text": expression]
        }

        mutating func visitMathDisplay(expression: String, attributes: RhoeMarkdownKit.Attributes) {
            result = ["node": "MathDisplay", "text": expression]
        }

        mutating func visitInlineHTML(_ html: String) {
            result = ["node": "InlineHTML", "text": html]
        }

        mutating func visitHardBreak() {
            result = ["node": "HardBreak"]
        }

        mutating func visitSoftBreak() {
            result = ["node": "SoftBreak"]
        }

        mutating func visitSuperscript(_ inlines: [Inline]) {
            result = ["node": "Superscript", "inlines": inlines.map { writer.serializeInline($0) }]
        }

        mutating func visitSubscript(_ inlines: [Inline]) {
            result = ["node": "Subscript", "inlines": inlines.map { writer.serializeInline($0) }]
        }

        mutating func visitHighlight(_ inlines: [Inline]) {
            result = ["node": "Highlight", "inlines": inlines.map { writer.serializeInline($0) }]
        }

        mutating func visitSpan(content: [Inline], attributes: RhoeMarkdownKit.Attributes) {
            result = ["node": "Span", "inlines": content.map { writer.serializeInline($0) }]
        }

        mutating func visitInlineFootnote(content: [Inline]) {
            result = ["node": "InlineFootnote", "inlines": content.map { writer.serializeInline($0) }]
        }

        mutating func visitCitation(items: [CitationItem], mode: CitationMode) {
            result = ["node": "Citation",
                      "props": ["mode": String(describing: mode)],
                      "items": items.map { ["key": $0.key] as [String: Any] }] as [String: Any]
        }

        mutating func visitCrossReference(prefix: CrossRefPrefix, id: String) {
            result = ["node": "CrossReference",
                      "props": ["prefix": prefix.rawValue, "id": id]] as [String: Any]
        }

        mutating func visitResolvedCitation(text: String, keys: [String], mode: CitationMode) {
            result = ["node": "ResolvedCitation",
                      "props": ["keys": keys, "mode": String(describing: mode)],
                      "text": text] as [String: Any]
        }

        mutating func visitResolvedCrossReference(text: String, targetId: String) {
            result = ["node": "ResolvedCrossReference",
                      "props": ["targetId": targetId],
                      "text": text] as [String: Any]
        }

        mutating func visitRawInline(content: String, format: String) {
            result = ["node": "RawInline",
                      "props": ["format": format],
                      "text": content] as [String: Any]
        }

        mutating func visitWikilink(target: String, display: [Inline]?) {
            var fields: [String: Any] = ["node": "Wikilink", "props": ["target": target] as [String: Any]]
            if let display { fields["inlines"] = display.map { writer.serializeInline($0) } }
            result = fields
        }

        mutating func visitEmoji(name: String, unicode: String?) {
            var props: [String: Any] = ["name": name]
            if let unicode { props["unicode"] = unicode }
            result = ["node": "Emoji", "props": props] as [String: Any]
        }

        mutating func visitTransclusionInline(target: String, fragment: String?, mode: TransclusionMode?, attributes: RhoeMarkdownKit.Attributes) {
            var props: [String: Any] = ["target": target]
            if let fragment { props["fragment"] = fragment }
            if let mode { props["mode"] = String(describing: mode) }
            result = ["node": "TransclusionInline", "props": props] as [String: Any]
        }

        mutating func visitAnnotationInline(kind: AnnotationKind, text: String) {
            result = ["node": "AnnotationInline",
                      "props": ["kind": kind.rawValue],
                      "text": text] as [String: Any]
        }

        mutating func visitParamRef(name: String) {
            result = ["node": "ParamRef", "props": ["name": name]] as [String: Any]
        }

        mutating func visitSlotRef(name: String?) {
            var props: [String: Any] = [:]
            if let name { props["name"] = name }
            var fields: [String: Any] = ["node": "SlotRef"]
            if !props.isEmpty { fields["props"] = props }
            result = fields
        }

        mutating func visitPlaceholderInline(fields: [String: String]) {
            result = ["node": "PlaceholderInline", "props": ["fields": fields]] as [String: Any]
        }

        mutating func visitExpressionInline(expr: String) {
            result = ["node": "ExpressionInline", "props": ["expr": expr]] as [String: Any]
        }

        mutating func visitInputFieldInline(name: String, fieldType: String, attributes: RhoeMarkdownKit.Attributes) {
            result = ["node": "InputFieldInline",
                      "props": ["name": name, "fieldType": fieldType]] as [String: Any]
        }
    }

    // MARK: - Helpers

    func serializeListType(_ type: ListType) -> [String: Any] {
        switch type {
        case .unordered: return ["kind": "unordered"]
        case .ordered(let start, let style): return ["kind": "ordered", "start": start, "style": String(describing: style)]
        case .task: return ["kind": "task"]
        }
    }

    func serializeListItem(_ item: ListItem) -> [String: Any] {
        var fields: [String: Any] = ["children": item.content.map { serializeBlock($0) }]
        if let checked = item.checked { fields["checked"] = checked }
        if item.isLoose { fields["loose"] = true }
        return fields
    }

    func serializeTableCell(_ cell: TableCell) -> [String: Any] {
        var fields: [String: Any] = ["inlines": cell.content.map { serializeInline($0) }]
        if cell.alignment != .none { fields["alignment"] = String(describing: cell.alignment) }
        if cell.rowSpan > 1 { fields["rowSpan"] = cell.rowSpan }
        if cell.colSpan > 1 { fields["colSpan"] = cell.colSpan }
        return fields
    }

    private func serializeYAMLValue(_ value: RhoeMarkdownKit.YAMLValue) -> Any {
        switch value {
        case .string(let s): return s
        case .int(let i): return i
        case .double(let d): return d
        case .bool(let b): return b
        case .array(let arr): return arr.map { serializeYAMLValue($0) }
        case .dictionary(let dict):
            var result: [String: Any] = [:]
            for (k, v) in dict { result[k] = serializeYAMLValue(v) }
            return result
        case .null: return NSNull()
        }
    }
}
