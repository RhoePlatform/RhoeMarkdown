import Foundation
import RhoeMarkdownModel

/// Converts a parsed RhoeMarkdown document to Typst output.
///
/// Produces Typst markup with configurable page setup and preamble.
/// Math expressions pass through directly (Typst uses the same `$...$` syntax).
/// Footnotes are inlined at reference sites using `#footnote[...]`.
public struct TypstWriter: DocumentWriter, Sendable {
    public typealias Output = String

    fileprivate let configuration: RhoeMarkdownKit.TypstConfiguration

    public init(configuration: RhoeMarkdownKit.TypstConfiguration = .default) {
        self.configuration = configuration
    }

    public func write(_ document: RhoeMarkdownKit.Document) -> String {
        let footnotes = collectFootnotes(from: document.blocks)
        var output = ""

        if configuration.generatePreamble {
            output += renderPreamble(document: document)
        }

        for block in document.blocks {
            output += renderBlock(block, footnotes: footnotes, depth: 0)
        }

        return output
    }

    // MARK: - Preamble

    private func renderPreamble(document: RhoeMarkdownKit.Document) -> String {
        var preamble = ""
        let fm = document.metadata.yamlFrontmatter

        // Document metadata
        var docArgs: [String] = []
        if let title = stringFromYAML(fm?["title"]) {
            docArgs.append("title: \"\(title)\"")
        }
        if let author = stringFromYAML(fm?["author"]) {
            docArgs.append("author: \"\(author)\"")
        }
        if let date = stringFromYAML(fm?["date"]) {
            docArgs.append("date: \"\(date)\"")
        }
        if !docArgs.isEmpty {
            preamble += "#set document(\(docArgs.joined(separator: ", ")))\n"
        }

        // Page setup
        preamble += "#set page(paper: \"\(configuration.paperSize)\")\n"

        // Text setup
        var textArgs = ["size: \(configuration.fontSize)"]
        if let font = configuration.fontFamily {
            textArgs.append("font: \"\(font)\"")
        }
        preamble += "#set text(\(textArgs.joined(separator: ", ")))\n"

        if let monoFont = configuration.monoFontFamily {
            preamble += "#show raw: set text(font: \"\(monoFont)\")\n"
        }

        // AST-near function definitions
        if configuration.astNearEmission {
            preamble += "\n// RhoeMarkdown AST-near function definitions\n"
            preamble += "#let rhoe-section(level: 1, body) = heading(level: level, body)\n"
            preamble += "#let rhoe-paragraph(body) = [#body]\n"
            preamble += "#let rhoe-block-quote(body) = quote(block: true, body)\n"
            preamble += "#let rhoe-admonition(kind: \"note\", title: none, body) = block(fill: luma(230), inset: 8pt, radius: 4pt)[#if title != none [*#title*\\ ] #body]\n"
            preamble += "#let rhoe-theorem(title: none, body) = block(stroke: 0.5pt, inset: 8pt, radius: 4pt)[*Theorem.* #if title != none [(#title) ] #body]\n"
            preamble += "#let rhoe-lemma(title: none, body) = block(stroke: 0.5pt, inset: 8pt, radius: 4pt)[*Lemma.* #if title != none [(#title) ] #body]\n"
            preamble += "#let rhoe-definition(title: none, body) = block(stroke: 0.5pt, inset: 8pt, radius: 4pt)[*Definition.* #if title != none [(#title) ] #body]\n"
            preamble += "#let rhoe-corollary(title: none, body) = block(stroke: 0.5pt, inset: 8pt, radius: 4pt)[*Corollary.* #if title != none [(#title) ] #body]\n"
            preamble += "#let rhoe-proposition(title: none, body) = block(stroke: 0.5pt, inset: 8pt, radius: 4pt)[*Proposition.* #if title != none [(#title) ] #body]\n"
            preamble += "#let rhoe-example(title: none, body) = block(stroke: 0.5pt, inset: 8pt, radius: 4pt)[*Example.* #if title != none [(#title) ] #body]\n"
            preamble += "#let rhoe-remark(title: none, body) = block(inset: 8pt)[*Remark.* #if title != none [(#title) ] #body]\n"
            preamble += "#let rhoe-proof(of: none, body) = [_Proof._ #body #h(1fr) $square$]\n"
            preamble += "#let rhoe-list(ordered: false, body) = body\n"
            preamble += "#let rhoe-list-item(body) = [- #body]\n"
            preamble += "#let rhoe-code(language: \"text\", body) = raw(body, lang: language, block: true)\n"
            preamble += "#let rhoe-visual-block(name: \"\", body) = block[#body]\n"
            preamble += "#let rhoe-div(body) = block[#body]\n"
            preamble += "#let rhoe-line-block(body) = block[#body]\n"
            preamble += "#let rhoe-thematic-break() = line(length: 100%)\n"
        }

        preamble += "\n"
        return preamble
    }

    // MARK: - Block Rendering

    fileprivate func blockAttributes(_ block: Block) -> RhoeMarkdownKit.Attributes? {
        switch block {
        case .paragraph(_, let a), .heading(_, _, let a), .blockQuote(_, let a),
             .list(_, _, let a), .codeBlock(_, _, let a), .table(_, _, _, let a),
             .definitionList(_, let a), .admonition(_, _, _, _, let a),
             .div(_, let a), .visualBlock(_, _, let a),
             .authorAnnotation(_, _, let a), .transclusion(_, _, _, let a),
             .schemaIsland(_, _, let a), .componentDeclaration(_, _, _, _, _, let a),
             .phase2Directive(_, _, _, let a),
             .placeholder(_, let a),
             .widget(_, _, let a),
             .tab(_, _, let a),
             // Canonical node kinds
             .section(_, _, _, let a),
             .formalBlock(_, _, _, _, let a),
             .speakerNotes(_, let a),
             .grid(_, let a),
             .columns(_, let a),
             .figure(_, _, let a),
             .diagramBlock(_, _, let a),
             .shape(_, let a),
             .tableHead(_, let a),
             .tableBody(_, let a),
             .tableFoot(_, let a),
             .tableRow(_, let a),
             .executableCodeBlock(_, _, let a),
             .mathBlock(_, let a),
             .deck(_, let a),
             .slide(_, _, let a),
             .slotContent(_, _, let a),
             .extension_(_, _, _, let a),
             .rawBlock(_, _, let a),
             .expression(_, let a),
             .field(_, _, let a),
             .form(_, _, let a),
             .stage(_, _, let a),
             .lane(_, let a),
             .module(_, _, _, let a),
             .contractDirective(_, _, let a):
            return a
        default: return nil
        }
    }

    fileprivate func renderBlock(
        _ block: Block,
        footnotes: [String: [Block]],
        depth: Int
    ) -> String {
        // Projection visibility: skip blocks hidden from print.
        if let attrs = blockAttributes(block),
           !ProjectionVisibility.isVisible(attributes: attrs, in: .print) {
            return ""
        }

        var visitor = TypstBlockRenderer(writer: self, footnotes: footnotes, depth: depth)
        block.accept(&visitor)
        return visitor.result
    }

    // MARK: - Inline Rendering

    fileprivate func renderInlines(
        _ inlines: [Inline],
        footnotes: [String: [Block]]
    ) -> String {
        inlines.map { renderInline($0, footnotes: footnotes) }.joined()
    }

    fileprivate func renderInline(
        _ inline: Inline,
        footnotes: [String: [Block]]
    ) -> String {
        var visitor = TypstInlineRenderer(writer: self, footnotes: footnotes)
        inline.accept(&visitor)
        return visitor.result
    }

    // MARK: - Helpers

    fileprivate func renderList(
        type: ListType,
        items: [ListItem],
        footnotes: [String: [Block]],
        depth: Int
    ) -> String {
        if configuration.astNearEmission {
            let isOrdered: Bool
            switch type {
            case .ordered: isOrdered = true
            default: isOrdered = false
            }
            var result = "#rhoe-list(ordered: \(isOrdered))[\n"
            for item in items {
                let content = item.content.map { renderBlock($0, footnotes: footnotes, depth: depth + 1) }.joined()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                result += "  #rhoe-list-item[\(content)]\n"
            }
            result += "]\n\n"
            return result
        }

        let indent = String(repeating: "  ", count: depth)
        var result = ""

        for (index, item) in items.enumerated() {
            let content = item.content.map { renderBlock($0, footnotes: footnotes, depth: depth + 1) }.joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let marker: String
            switch type {
            case .unordered:
                marker = "-"
            case .ordered(let start, _):
                marker = "\(start + index)."
            case .task:
                let check = item.checked == true ? "[x]" : "[ ]"
                marker = "- \(check)"
            }
            result += "\(indent)\(marker) \(content)\n"
        }
        return result + "\n"
    }

    fileprivate func renderTable(
        headers: [TableCell],
        rows: [[TableCell]],
        caption: [Inline]?,
        attrs: RhoeMarkdownKit.Attributes,
        footnotes: [String: [Block]]
    ) -> String {
        let colCount = headers.count
        var result = ""

        let hasCaption = caption != nil || attrs.id != nil
        if hasCaption {
            let cap = caption.map { renderInlines($0, footnotes: footnotes) } ?? ""
            let label = attrs.id.map { " <\($0)>" } ?? ""
            result += "#figure(\n  "

            result += "#table(\n  columns: \(colCount),\n"
            for cell in headers {
                result += "  [*\(renderInlines(cell.content, footnotes: footnotes))*],"
            }
            result += "\n"
            for row in rows {
                for cell in row {
                    result += "  [\(renderInlines(cell.content, footnotes: footnotes))],"
                }
                result += "\n"
            }
            result += ")"

            result += ",\n  caption: [\(cap)]\n)\(label)\n\n"
            return result
        }

        result += "#table(\n  columns: \(colCount),\n"

        // Header cells
        for cell in headers {
            result += "  [*\(renderInlines(cell.content, footnotes: footnotes))*],"
        }
        result += "\n"

        // Data rows
        for row in rows {
            for cell in row {
                result += "  [\(renderInlines(cell.content, footnotes: footnotes))],"
            }
            result += "\n"
        }

        result += ")\n\n"
        return result
    }

    fileprivate func renderDiv(
        content: [Block],
        attrs: RhoeMarkdownKit.Attributes,
        footnotes: [String: [Block]],
        depth: Int
    ) -> String {
        // Theorem environments
        let theoremEnvs = ["theorem", "lemma", "proof", "definition",
                           "proposition", "corollary", "example", "remark"]
        for cls in attrs.classes {
            if theoremEnvs.contains(cls) {
                let inner = content.map { renderBlock($0, footnotes: footnotes, depth: depth + 1) }.joined()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let label = attrs.id.map { " <\($0)>" } ?? ""
                if configuration.astNearEmission {
                    return "#rhoe-\(cls)()[\(inner)]\(label)\n\n"
                }
                let title = cls.capitalized
                return "#block(stroke: 0.5pt, inset: 8pt, radius: 4pt)[\n  *\(title).*\(label) \(inner)\n]\n\n"
            }
        }

        // Content visibility
        if attrs.classes.contains("content-visible") {
            if let format = attrs.keyValues["when-format"], !format.contains("typst") {
                return ""
            }
        }
        if attrs.classes.contains("content-hidden") {
            if let format = attrs.keyValues["when-format"], format.contains("typst") {
                return ""
            }
        }

        let inner = content.map { renderBlock($0, footnotes: footnotes, depth: depth) }.joined()
        if configuration.astNearEmission {
            return "#rhoe-div[\(inner.trimmingCharacters(in: .whitespacesAndNewlines))]\n\n"
        }
        return inner
    }

    // MARK: - Typst Escaping

    fileprivate func typstEscape(_ text: String) -> String {
        var result = ""
        for char in text {
            switch char {
            case "#": result += "\\#"
            case "@": result += "\\@"
            case "\\": result += "\\\\"
            default: result.append(char)
            }
        }
        return result
    }

    // MARK: - Collection

    private func collectFootnotes(from blocks: [Block]) -> [String: [Block]] {
        var footnotes: [String: [Block]] = [:]
        for block in blocks {
            if case .footnoteDefinition(let id, let content) = block {
                footnotes[id] = content
            }
            switch block {
            case .blockQuote(let nested, _), .div(let nested, _),
                 .widget(_, let nested, _), .tab(_, let nested, _):
                footnotes.merge(collectFootnotes(from: nested)) { _, new in new }
            case .list(_, let items, _):
                for item in items {
                    footnotes.merge(collectFootnotes(from: item.content)) { _, new in new }
                }
            default: break
            }
        }
        return footnotes
    }

    private func stringFromYAML(_ value: RhoeMarkdownKit.YAMLValue?) -> String? {
        guard let value = value else { return nil }
        switch value {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        default: return nil
        }
    }
}

// MARK: - Block Visitor

private struct TypstBlockRenderer: BlockVisitor {
    let writer: TypstWriter
    let footnotes: [String: [Block]]
    let depth: Int
    var result: String = ""

    mutating func visitParagraph(_ inlines: [Inline], attributes: RhoeMarkdownKit.Attributes) {
        let text = writer.renderInlines(inlines, footnotes: footnotes)
        if writer.configuration.astNearEmission {
            result = "#rhoe-paragraph[\(text)]\n\n"
        } else {
            result = text + "\n\n"
        }
    }

    mutating func visitHeading(level: Int, content: [Inline], attributes: RhoeMarkdownKit.Attributes) {
        let text = writer.renderInlines(content, footnotes: footnotes)
        let label = attributes.id.map { " <\($0)>" } ?? ""
        if writer.configuration.astNearEmission {
            result = "#rhoe-section(level: \(level))[\(text)]\(label)\n\n"
        } else {
            let marker = String(repeating: "=", count: level)
            result = "\(marker) \(text)\(label)\n\n"
        }
    }

    mutating func visitBlockQuote(_ blocks: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let inner = blocks.map { writer.renderBlock($0, footnotes: footnotes, depth: depth + 1) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if writer.configuration.astNearEmission {
            result = "#rhoe-block-quote[\(inner)]\n\n"
        } else {
            result = "#quote(block: true)[\(inner)]\n\n"
        }
    }

    mutating func visitList(type: ListType, items: [ListItem], attributes: RhoeMarkdownKit.Attributes) {
        result = writer.renderList(type: type, items: items, footnotes: footnotes, depth: depth)
    }

    mutating func visitCodeBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes) {
        if writer.configuration.astNearEmission, let lang = language {
            result = "#rhoe-code(language: \"\(writer.typstEscape(lang))\")[\n```\(writer.typstEscape(lang))\n\(content)\n```\n]\n\n"
        } else {
            let lang = language.map { "\(writer.typstEscape($0))" } ?? ""
            result = "```\(lang)\n\(content)\n```\n\n"
        }
    }

    mutating func visitHorizontalRule() {
        if writer.configuration.astNearEmission {
            result = "#rhoe-thematic-break()\n\n"
        } else {
            result = "#line(length: 100%)\n\n"
        }
    }

    mutating func visitTable(headers: [TableCell], rows: [[TableCell]], caption: [Inline]?, attributes: RhoeMarkdownKit.Attributes) {
        result = writer.renderTable(headers: headers, rows: rows, caption: caption, attrs: attributes, footnotes: footnotes)
    }

    mutating func visitDefinitionList(items: [DefinitionListItem], attributes: RhoeMarkdownKit.Attributes) {
        var output = ""
        for item in items {
            let term = writer.renderInlines(item.term, footnotes: footnotes)
            for def in item.definitions {
                let defText = def.map { writer.renderBlock($0, footnotes: footnotes, depth: depth) }.joined()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                output += "/ \(term): \(defText)\n"
            }
        }
        result = output + "\n"
    }

    mutating func visitFootnoteDefinition(id: String, content: [Block]) {
        result = "" // Rendered inline at reference sites
    }

    mutating func visitAdmonition(type: String, title: String?, content: [Block], collapsible: AdmonitionCollapsible?, attributes: RhoeMarkdownKit.Attributes) {
        let titleStr = title ?? type.capitalized
        let inner = content.map { writer.renderBlock($0, footnotes: footnotes, depth: depth + 1) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if writer.configuration.astNearEmission {
            var params = "kind: \"\(type)\""
            if let title { params += ", title: \"\(writer.typstEscape(title))\"" }
            result = "#rhoe-admonition(\(params))[\(inner)]\n\n"
        } else {
            result = "#block(fill: luma(230), inset: 8pt, radius: 4pt)[\n  *\(writer.typstEscape(titleStr))*\n\n  \(inner)\n]\n\n"
        }
    }

    mutating func visitBlockHTML(_ html: String) {
        result = "" // Skip HTML in Typst
    }

    mutating func visitDiv(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        result = writer.renderDiv(content: content, attrs: attributes, footnotes: footnotes, depth: depth)
    }

    mutating func visitLineBlock(lines: [[Inline]]) {
        let lineTexts = lines.map { writer.renderInlines($0, footnotes: footnotes) }
        let inner = lineTexts.joined(separator: " \\\n")
        if writer.configuration.astNearEmission {
            result = "#rhoe-line-block[\(inner)]\n\n"
        } else {
            result = inner + "\n\n"
        }
    }

    mutating func visitAbbreviationDefinition(abbreviation: String, expansion: String) {
        result = "" // Consumed during expansion
    }

    mutating func visitVisualBlock(name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let inner = content.map { writer.renderBlock($0, footnotes: footnotes, depth: depth + 1) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if writer.configuration.astNearEmission {
            result = "#rhoe-visual-block(name: \"\(writer.typstEscape(name))\")[\(inner)]\n\n"
        } else {
            result = "#block[\n  // \(writer.typstEscape(name))\n  \(inner)\n]\n\n"
        }
    }

    mutating func visitAuthorAnnotation(kind: AnnotationKind, text: String, attributes: RhoeMarkdownKit.Attributes) {
        result = "" // Non-rendering
    }

    mutating func visitTransclusion(target: String, fragment: String?, mode: TransclusionMode?, attributes: RhoeMarkdownKit.Attributes) {
        let fragSuffix = fragment.map { "#\($0)" } ?? ""
        result = "_[Transclusion: \(writer.typstEscape(target))\(fragSuffix)]_\n\n"
    }

    mutating func visitSchemaIsland(schema: String, body: String, attributes: RhoeMarkdownKit.Attributes) {
        result = "```\(schema)\n\(body)\n```\n\n"
    }

    mutating func visitComponentDeclaration(family: BlockFamily, name: String, args: String?, slots: String?, body: [Block], attributes: RhoeMarkdownKit.Attributes) {
        result = "" // Expanded in pipeline
    }

    mutating func visitPhase2Directive(command: String, arguments: [String: String], body: String?, attributes: RhoeMarkdownKit.Attributes) {
        result = "" // Executed in pipeline
    }

    mutating func visitPlaceholder(fields: [String: String], attributes: RhoeMarkdownKit.Attributes) {
        let display: String
        if let name = fields["name"] {
            display = name
        } else {
            display = fields.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        }
        result = "_[\(writer.typstEscape(display))]_\n\n"
    }

    mutating func visitExpression(expr: String, attributes: RhoeMarkdownKit.Attributes) {
        result = "`\(expr)`\n\n"
    }

    mutating func visitField(name: String, fieldType: String, attributes: RhoeMarkdownKit.Attributes) {
        result = "\(writer.typstEscape(name))\n\n"
    }

    mutating func visitForm(name: String?, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        result = content.map { writer.renderBlock($0, footnotes: footnotes, depth: depth + 1) }.joined()
    }

    mutating func visitWidget(title: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let inner = content.map { writer.renderBlock($0, footnotes: footnotes, depth: depth + 1) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        result = "#block[\n  // widget: \(writer.typstEscape(title))\n  \(inner)\n]\n\n"
    }

    mutating func visitTab(title: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let inner = content.map { writer.renderBlock($0, footnotes: footnotes, depth: depth + 1) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        result = "#block[\n  // tab: \(writer.typstEscape(title))\n  \(inner)\n]\n\n"
    }

    mutating func visitStage(kind: StageKind, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let inner = content.map { writer.renderBlock($0, footnotes: footnotes, depth: depth + 1) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        result = "#block[\n  // stage: \(writer.typstEscape(kind.rawValue))\n  \(inner)\n]\n\n"
    }

    mutating func visitLane(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let inner = content.map { writer.renderBlock($0, footnotes: footnotes, depth: depth + 1) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        result = "#block[\n  // lane\n  \(inner)\n]\n\n"
    }

    mutating func visitModule(family: String, name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let inner = content.map { writer.renderBlock($0, footnotes: footnotes, depth: depth + 1) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        result = "#block[\n  // module: \(writer.typstEscape(family)).\(writer.typstEscape(name))\n  \(inner)\n]\n\n"
    }

    mutating func visitContractDirective(kind: ContractKind, content: String, attributes: RhoeMarkdownKit.Attributes) {
        result = "#block[\n  // contract-\(writer.typstEscape(kind.rawValue)): \(writer.typstEscape(content))\n]\n\n"
    }

    mutating func visitSection(level: Int, title: [Inline], children: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let titleText = writer.renderInlines(title, footnotes: footnotes)
        let label = attributes.id.map { " <\($0)>" } ?? ""
        if writer.configuration.astNearEmission {
            result = "#rhoe-section(level: \(level))[\n"
            result += "  \(titleText)\(label)\n"
            for child in children {
                result += writer.renderBlock(child, footnotes: footnotes, depth: depth + 1)
            }
            result += "]\n\n"
            return
        }
        let marker = String(repeating: "=", count: level)
        result = "\(marker) \(titleText)\(label)\n\n"
        for child in children {
            result += writer.renderBlock(child, footnotes: footnotes, depth: depth + 1)
        }
    }

    mutating func visitMathBlock(expression: String, attributes: RhoeMarkdownKit.Attributes) {
        result = "$ \(expression) $\n\n"
    }

    // MARK: - Canonical Block Visitors

    mutating func visitFormalBlock(family: String, title: [Inline]?, number: String?, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let inner = content.map { writer.renderBlock($0, footnotes: footnotes, depth: depth + 1) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let titleText = title.map { writer.renderInlines($0, footnotes: footnotes) }
        let label = attributes.id.map { " <\($0)>" } ?? ""
        var header = "*\(writer.typstEscape(family.capitalized))"
        if let num = number { header += " \(writer.typstEscape(num))" }
        header += "*"
        if let t = titleText { header += ": \(t)" }
        result = "#block[\(header) \\\n  \(inner)\n]\(label)\n\n"
    }

    mutating func visitSpeakerNotes(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        // Speaker notes are non-visual in print; emit as Typst comments
        let inner = content.map { writer.renderBlock($0, footnotes: footnotes, depth: depth + 1) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let commented = inner.components(separatedBy: "\n").map { "// \($0)" }.joined(separator: "\n")
        result = commented + "\n\n"
    }

    mutating func visitGrid(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let cols = attributes.keyValues["columns"] ?? "2"
        let inner = content.map { writer.renderBlock($0, footnotes: footnotes, depth: depth + 1) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        result = "#grid(columns: \(cols))[\(inner)]\n\n"
    }

    mutating func visitColumns(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let cols = attributes.keyValues["count"] ?? "2"
        let inner = content.map { writer.renderBlock($0, footnotes: footnotes, depth: depth + 1) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        result = "#columns(\(cols))[\(inner)]\n\n"
    }

    mutating func visitFigure(content: [Block], caption: [Inline]?, attributes: RhoeMarkdownKit.Attributes) {
        let inner = content.map { writer.renderBlock($0, footnotes: footnotes, depth: depth + 1) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let label = attributes.id.map { " <\($0)>" } ?? ""
        if let cap = caption {
            let capText = writer.renderInlines(cap, footnotes: footnotes)
            result = "#figure([\(inner)], caption: [\(capText)])\(label)\n\n"
        } else {
            result = "#figure([\(inner)])\(label)\n\n"
        }
    }

    mutating func visitDiagramBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes) {
        let lang = language.map { writer.typstEscape($0) } ?? ""
        result = "```\(lang)\n\(content)\n```\n\n"
    }

    mutating func visitShape(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let inner = content.map { writer.renderBlock($0, footnotes: footnotes, depth: depth + 1) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        result = "#block[\(inner)]\n\n"
    }

    mutating func visitTableHead(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes) {
        // Table head/body/foot/row are structural children of a table; pass through rows
        var output = ""
        for row in rows {
            for cell in row {
                let text = writer.renderInlines(cell.content, footnotes: footnotes)
                output += "  [*\(text)*],"
            }
            output += "\n"
        }
        result = output
    }

    mutating func visitTableBody(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes) {
        var output = ""
        for row in rows {
            for cell in row {
                let text = writer.renderInlines(cell.content, footnotes: footnotes)
                output += "  [\(text)],"
            }
            output += "\n"
        }
        result = output
    }

    mutating func visitTableFoot(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes) {
        var output = ""
        for row in rows {
            for cell in row {
                let text = writer.renderInlines(cell.content, footnotes: footnotes)
                output += "  [\(text)],"
            }
            output += "\n"
        }
        result = output
    }

    mutating func visitTableRow(cells: [TableCell], attributes: RhoeMarkdownKit.Attributes) {
        var output = ""
        for cell in cells {
            let text = writer.renderInlines(cell.content, footnotes: footnotes)
            output += "  [\(text)],"
        }
        result = output + "\n"
    }

    mutating func visitExecutableCodeBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes) {
        let lang = language.map { writer.typstEscape($0) } ?? ""
        result = "```\(lang)\n\(content)\n```\n\n"
    }

    mutating func visitDeck(slides: [Block], attributes: RhoeMarkdownKit.Attributes) {
        var output = "// Deck\n"
        for slide in slides {
            output += writer.renderBlock(slide, footnotes: footnotes, depth: depth + 1)
        }
        result = output
    }

    mutating func visitSlide(title: [Inline]?, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        var output = "#pagebreak()\n"
        if let title {
            let titleText = writer.renderInlines(title, footnotes: footnotes)
            output += "= \(titleText)\n\n"
        }
        for child in content {
            output += writer.renderBlock(child, footnotes: footnotes, depth: depth + 1)
        }
        result = output
    }

    mutating func visitSlotContent(name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        var output = "// Slot: \(writer.typstEscape(name))\n"
        for child in content {
            output += writer.renderBlock(child, footnotes: footnotes, depth: depth + 1)
        }
        result = output
    }

    mutating func visitExtension(vendor: String, name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        var output = "// Extension: \\@\(writer.typstEscape(vendor)).\(writer.typstEscape(name))\n"
        for child in content {
            output += writer.renderBlock(child, footnotes: footnotes, depth: depth + 1)
        }
        result = output
    }

    mutating func visitRawBlock(content: String, format: String, attributes: RhoeMarkdownKit.Attributes) {
        if format == "typst" {
            result = content + "\n\n"
        } else {
            result = "// raw block (format: \(writer.typstEscape(format)))\n\n"
        }
    }
}

// MARK: - Inline Visitor

private struct TypstInlineRenderer: InlineVisitor {
    let writer: TypstWriter
    let footnotes: [String: [Block]]
    var result: String = ""

    mutating func visitText(_ text: String) {
        result = writer.typstEscape(text)
    }

    mutating func visitEmphasis(_ inlines: [Inline]) {
        result = "_\(writer.renderInlines(inlines, footnotes: footnotes))_"
    }

    mutating func visitStrong(_ inlines: [Inline]) {
        result = "*\(writer.renderInlines(inlines, footnotes: footnotes))*"
    }

    mutating func visitStrikethrough(_ inlines: [Inline]) {
        result = "#strike[\(writer.renderInlines(inlines, footnotes: footnotes))]"
    }

    mutating func visitCodeSpan(_ code: String, attributes: RhoeMarkdownKit.Attributes) {
        result = "`\(code)`"
    }

    mutating func visitLink(text: [Inline], url: String, title: String?, attributes: RhoeMarkdownKit.Attributes) {
        result = "#link(\"\(url)\")[\(writer.renderInlines(text, footnotes: footnotes))]"
    }

    mutating func visitImage(alt: [Inline], url: String, title: String?, attributes: RhoeMarkdownKit.Attributes) {
        let altText = writer.renderInlines(alt, footnotes: footnotes)
        let label = attributes.id.map { " <\($0)>" } ?? ""
        if !altText.isEmpty {
            result = "#figure(image(\"\(url)\"), caption: [\(altText)])\(label)"
        } else {
            result = "#image(\"\(url)\")"
        }
    }

    mutating func visitFootnoteRef(id: String) {
        if let content = footnotes[id] {
            let inner = content.map { writer.renderBlock($0, footnotes: footnotes, depth: 0) }.joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            result = "#footnote[\(inner)]"
        } else {
            result = "#footnote[\(writer.typstEscape(id))]"
        }
    }

    mutating func visitInlineMath(expression: String, attributes: RhoeMarkdownKit.Attributes) {
        result = "$\(expression)$"
    }

    mutating func visitMathDisplay(expression: String, attributes: RhoeMarkdownKit.Attributes) {
        result = "$ \(expression) $"
    }

    mutating func visitInlineHTML(_ html: String) {
        result = ""
    }

    mutating func visitHardBreak() {
        result = " \\\n"
    }

    mutating func visitSoftBreak() {
        result = " "
    }

    mutating func visitSuperscript(_ inlines: [Inline]) {
        result = "#super[\(writer.renderInlines(inlines, footnotes: footnotes))]"
    }

    mutating func visitSubscript(_ inlines: [Inline]) {
        result = "#sub[\(writer.renderInlines(inlines, footnotes: footnotes))]"
    }

    mutating func visitHighlight(_ inlines: [Inline]) {
        result = "#highlight[\(writer.renderInlines(inlines, footnotes: footnotes))]"
    }

    mutating func visitSpan(content: [Inline], attributes: RhoeMarkdownKit.Attributes) {
        result = writer.renderInlines(content, footnotes: footnotes)
    }

    mutating func visitInlineFootnote(content: [Inline]) {
        result = "#footnote[\(writer.renderInlines(content, footnotes: footnotes))]"
    }

    mutating func visitCitation(items: [CitationItem], mode: CitationMode) {
        let keys = items.map { "#cite(<\($0.key)>)" }
        result = keys.joined(separator: " ")
    }

    mutating func visitResolvedCitation(text: String, keys: [String], mode: CitationMode) {
        let cites = keys.map { "#cite(<\($0)>)" }
        result = cites.joined(separator: " ")
    }

    mutating func visitCrossReference(prefix: CrossRefPrefix, id: String) {
        result = "@\(prefix.rawValue)-\(id)"
    }

    mutating func visitResolvedCrossReference(text: String, targetId: String) {
        result = "@\(targetId)"
    }

    mutating func visitRawInline(content: String, format: String) {
        if format == "typst" {
            result = content
        } else {
            result = ""
        }
    }

    mutating func visitWikilink(target: String, display: [Inline]?) {
        result = display.map { writer.renderInlines($0, footnotes: footnotes) } ?? writer.typstEscape(target)
    }

    mutating func visitTransclusionInline(target: String, fragment: String?, mode: TransclusionMode?, attributes: RhoeMarkdownKit.Attributes) {
        let fragSuffix = fragment.map { "#\($0)" } ?? ""
        result = "_[\(writer.typstEscape(target))\(fragSuffix)]_"
    }

    mutating func visitAnnotationInline(kind: AnnotationKind, text: String) {
        result = "" // Non-rendering
    }

    mutating func visitParamRef(name: String) {
        result = writer.typstEscape("<<param \(name)>>")
    }

    mutating func visitSlotRef(name: String?) {
        result = writer.typstEscape("<<slot \(name ?? "default")>>")
    }

    mutating func visitPlaceholderInline(fields: [String: String]) {
        let display: String
        if let name = fields["name"] {
            display = name
        } else {
            display = fields.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        }
        result = "_[\(writer.typstEscape(display))]_"
    }

    mutating func visitExpressionInline(expr: String) {
        result = "`\(expr)`"
    }

    mutating func visitInputFieldInline(name: String, fieldType: String, attributes: RhoeMarkdownKit.Attributes) {
        result = writer.typstEscape(name)
    }

    mutating func visitEmoji(name: String, unicode: String?) {
        if let unicode {
            result = unicode
        } else {
            result = ":\(writer.typstEscape(name)):"
        }
    }
}
