import Foundation
import RhoeMarkdownModel

/// Converts a parsed RhoeMarkdown document to DOCX (Open XML) format.
///
/// Produces a ZIP-based DOCX file containing Open XML markup.
/// Uses `/usr/bin/zip` for archive creation (same pattern as PPTXWriter).
public struct DOCXWriter: DocumentWriter, Sendable {
    public typealias Output = Data

    private let configuration: RhoeMarkdownKit.DOCXConfiguration

    public init(configuration: RhoeMarkdownKit.DOCXConfiguration = .default) {
        self.configuration = configuration
    }

    /// Write the document to DOCX format, returning ZIP archive data.
    public func write(_ document: RhoeMarkdownKit.Document) -> Data {
        do {
            return try generateDOCX(document)
        } catch {
            return Data() // Return empty data on failure
        }
    }

    private func generateDOCX(_ document: RhoeMarkdownKit.Document) throws -> Data {
        let footnotes = collectFootnotes(from: document.blocks)
        var footnoteIndex = 1 // 0 is reserved for separator
        var numberingId = 1

        // Build document.xml body
        var bodyXML = ""
        for block in document.blocks {
            bodyXML += renderBlock(block, footnotes: footnotes,
                                   footnoteIndex: &footnoteIndex,
                                   numberingId: &numberingId, listDepth: 0)
        }

        // Build footnotes.xml entries
        var footnotesXML = ""
        for (id, content) in footnotes.sorted(by: { $0.key < $1.key }) {
            let fnContent = content.map { renderBlockPlain($0) }.joined()
            footnotesXML += """
            <w:footnote w:id="\(footnoteIdFor(id, in: footnotes))">
            <w:p><w:pPr><w:pStyle w:val="FootnoteText"/></w:pPr>
            <w:r><w:rPr><w:rStyle w:val="FootnoteReference"/></w:rPr>
            <w:footnoteRef/></w:r>
            <w:r><w:t xml:space="preserve"> </w:t></w:r>
            <w:r><w:t>\(xmlEscape(fnContent))</w:t></w:r></w:p>
            </w:footnote>
            """
        }

        // Create temp directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("docx-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create directory structure
        let dirs = ["_rels", "word", "word/_rels", "docProps"]
        for dir in dirs {
            try FileManager.default.createDirectory(
                at: tempDir.appendingPathComponent(dir),
                withIntermediateDirectories: true
            )
        }

        // Write files
        let fm = document.metadata.yamlFrontmatter
        try writeFile("[Content_Types].xml", in: tempDir, content: contentTypesXML())
        try writeFile("_rels/.rels", in: tempDir, content: relsXML())
        try writeFile("word/_rels/document.xml.rels", in: tempDir, content: documentRelsXML(hasFootnotes: !footnotes.isEmpty))
        try writeFile("word/document.xml", in: tempDir, content: documentXML(body: bodyXML))
        try writeFile("word/styles.xml", in: tempDir, content: stylesXML())
        try writeFile("docProps/core.xml", in: tempDir, content: corePropsXML(
            title: stringFromYAML(fm?["title"]),
            author: stringFromYAML(fm?["author"])
        ))

        if !footnotes.isEmpty {
            try writeFile("word/footnotes.xml", in: tempDir, content: footnotesDocXML(entries: footnotesXML))
        }

        if numberingId > 1 {
            try writeFile("word/numbering.xml", in: tempDir, content: numberingXML(maxId: numberingId))
        }

        // ZIP and return Data
        return try createZipData(from: tempDir)
    }

    // MARK: - Block Rendering

    private func renderBlock(
        _ block: Block,
        footnotes: [String: [Block]],
        footnoteIndex: inout Int,
        numberingId: inout Int,
        listDepth: Int
    ) -> String {
        // Projection visibility: skip blocks hidden from print.
        if let attrs = blockAttrs(block),
           !ProjectionVisibility.isVisible(attributes: attrs, in: .print) {
            return ""
        }

        var visitor = DOCXBlockRenderer(
            writer: self,
            footnotes: footnotes,
            footnoteIndex: footnoteIndex,
            numberingId: numberingId,
            listDepth: listDepth
        )
        block.accept(&visitor)
        footnoteIndex = visitor.footnoteIndex
        numberingId = visitor.numberingId
        return visitor.result
    }

    // MARK: - Block Visitor

    private struct DOCXBlockRenderer: BlockVisitor {
        let writer: DOCXWriter
        let footnotes: [String: [Block]]
        var footnoteIndex: Int
        var numberingId: Int
        let listDepth: Int
        var result: String = ""

        mutating func visitParagraph(_ inlines: [Inline], attributes: RhoeMarkdownKit.Attributes) {
            result = writer.wrapParagraph(writer.renderRuns(inlines, footnotes: footnotes, footnoteIndex: &footnoteIndex))
        }

        mutating func visitHeading(level: Int, content: [Inline], attributes: RhoeMarkdownKit.Attributes) {
            let style = "Heading\(min(level, 9))"
            result = writer.wrapParagraph(
                writer.renderRuns(content, footnotes: footnotes, footnoteIndex: &footnoteIndex),
                style: style
            )
        }

        mutating func visitBlockQuote(_ blocks: [Block], attributes: RhoeMarkdownKit.Attributes) {
            var output = ""
            for b in blocks {
                // Render inner blocks with Quote style
                let inner = writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                               numberingId: &numberingId, listDepth: listDepth)
                output += inner.replacingOccurrences(of: "<w:pStyle w:val=\"Normal\"/>",
                                                     with: "<w:pStyle w:val=\"Quote\"/>")
            }
            result = output
        }

        mutating func visitList(type: ListType, items: [ListItem], attributes: RhoeMarkdownKit.Attributes) {
            let currentNumId = numberingId
            numberingId += 1
            var output = ""
            for (index, item) in items.enumerated() {
                for (bIdx, b) in item.content.enumerated() {
                    if bIdx == 0 {
                        // First block gets list numbering
                        let runs = writer.blockToRuns(b, footnotes: footnotes, footnoteIndex: &footnoteIndex)
                        let numType: Int = {
                            switch type {
                            case .ordered: return 1
                            case .unordered: return 0
                            case .task: return 0
                            }
                        }()
                        let _ = index // suppress unused warning
                        output += writer.wrapParagraph(runs, numbering: (currentNumId, listDepth, numType))
                    } else {
                        output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                                     numberingId: &numberingId, listDepth: listDepth + 1)
                    }
                }
            }
            result = output
        }

        mutating func visitCodeBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes) {
            // Render as monospace paragraph(s)
            var output = ""
            for line in content.components(separatedBy: "\n") {
                output += "<w:p><w:pPr><w:pStyle w:val=\"Normal\"/></w:pPr>"
                output += "<w:r><w:rPr><w:rFonts w:ascii=\"Courier New\" w:hAnsi=\"Courier New\"/><w:sz w:val=\"20\"/></w:rPr>"
                output += "<w:t xml:space=\"preserve\">\(writer.xmlEscape(line))</w:t></w:r></w:p>"
            }
            result = output
        }

        mutating func visitHorizontalRule() {
            result = "<w:p><w:pPr><w:pBdr><w:bottom w:val=\"single\" w:sz=\"6\" w:space=\"1\" w:color=\"auto\"/></w:pBdr></w:pPr></w:p>"
        }

        mutating func visitTable(headers: [TableCell], rows: [[TableCell]], caption: [Inline]?, attributes: RhoeMarkdownKit.Attributes) {
            result = writer.renderTable(headers: headers, rows: rows, footnotes: footnotes, footnoteIndex: &footnoteIndex)
        }

        mutating func visitDefinitionList(items: [DefinitionListItem], attributes: RhoeMarkdownKit.Attributes) {
            var output = ""
            for item in items {
                // Term in bold
                let term = writer.renderRuns(item.term, footnotes: footnotes, footnoteIndex: &footnoteIndex, bold: true)
                output += writer.wrapParagraph(term)
                for def in item.definitions {
                    for b in def {
                        output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                                     numberingId: &numberingId, listDepth: listDepth)
                    }
                }
            }
            result = output
        }

        mutating func visitFootnoteDefinition(id: String, content: [Block]) {
            result = "" // Rendered via footnotes.xml
        }

        mutating func visitAdmonition(type: String, title: String?, content: [Block], collapsible: AdmonitionCollapsible?, attributes: RhoeMarkdownKit.Attributes) {
            let titleStr = title ?? type.capitalized
            var output = writer.wrapParagraph(writer.wrapRun(writer.xmlEscape(titleStr), bold: true))
            for b in content {
                output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                             numberingId: &numberingId, listDepth: listDepth)
            }
            result = output
        }

        mutating func visitBlockHTML(_ html: String) {
            result = "" // Skip HTML
        }

        mutating func visitDiv(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            // Theorem environments: render title + content
            let theoremEnvs = ["theorem", "lemma", "proof", "definition",
                               "proposition", "corollary", "example", "remark"]
            for cls in attributes.classes {
                if theoremEnvs.contains(cls) {
                    var output = writer.wrapParagraph(writer.wrapRun(writer.xmlEscape("\(cls.capitalized)."), bold: cls != "proof", italic: cls == "proof"))
                    for b in content {
                        output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                                     numberingId: &numberingId, listDepth: listDepth)
                    }
                    result = output
                    return
                }
            }
            // Content visibility
            if attributes.classes.contains("content-visible") {
                if let format = attributes.keyValues["when-format"], !format.contains("docx") {
                    result = ""
                    return
                }
            }
            if attributes.classes.contains("content-hidden") {
                if let format = attributes.keyValues["when-format"], format.contains("docx") {
                    result = ""
                    return
                }
            }
            var output = ""
            for b in content {
                output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                             numberingId: &numberingId, listDepth: listDepth)
            }
            result = output
        }

        mutating func visitLineBlock(lines: [[Inline]]) {
            var output = ""
            for line in lines {
                let runs = writer.renderRuns(line, footnotes: footnotes, footnoteIndex: &footnoteIndex)
                output += writer.wrapParagraph(runs)
            }
            result = output
        }

        mutating func visitAbbreviationDefinition(abbreviation: String, expansion: String) {
            result = ""
        }

        mutating func visitVisualBlock(name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            var output = writer.wrapParagraph(writer.wrapRun(writer.xmlEscape(name), bold: true))
            for b in content {
                output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                             numberingId: &numberingId, listDepth: listDepth)
            }
            result = output
        }

        mutating func visitAuthorAnnotation(kind: AnnotationKind, text: String, attributes: RhoeMarkdownKit.Attributes) {
            result = "" // Non-rendering
        }

        mutating func visitTransclusion(target: String, fragment: String?, mode: TransclusionMode?, attributes: RhoeMarkdownKit.Attributes) {
            let fragSuffix = fragment.map { "#\($0)" } ?? ""
            result = writer.wrapParagraph(writer.wrapRun(writer.xmlEscape("[Transclusion: \(target)\(fragSuffix)]"), italic: true))
        }

        mutating func visitSchemaIsland(schema: String, body: String, attributes: RhoeMarkdownKit.Attributes) {
            result = "<w:p><w:pPr><w:pStyle w:val=\"Normal\"/></w:pPr>" +
                "<w:r><w:rPr><w:rFonts w:ascii=\"Courier New\" w:hAnsi=\"Courier New\"/><w:sz w:val=\"20\"/></w:rPr>" +
                "<w:t xml:space=\"preserve\">\(writer.xmlEscape(body))</w:t></w:r></w:p>"
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
            result = writer.wrapParagraph(writer.wrapRun(writer.xmlEscape("[\(display)]"), italic: true))
        }

        mutating func visitExpression(expr: String, attributes: RhoeMarkdownKit.Attributes) {
            result = writer.wrapParagraph(writer.wrapRun(writer.xmlEscape(expr)))
        }

        mutating func visitField(name: String, fieldType: String, attributes: RhoeMarkdownKit.Attributes) {
            result = writer.wrapParagraph(writer.wrapRun(writer.xmlEscape(name)))
        }

        mutating func visitForm(name: String?, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            var output = ""
            for b in content {
                output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                             numberingId: &numberingId, listDepth: listDepth)
            }
            result = output
        }

        mutating func visitWidget(title: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            var output = writer.wrapParagraph(writer.wrapRun(writer.xmlEscape("Widget: \(title)"), bold: true))
            for b in content {
                output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                             numberingId: &numberingId, listDepth: listDepth)
            }
            result = output
        }

        mutating func visitTab(title: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            var output = writer.wrapParagraph(writer.wrapRun(writer.xmlEscape("Tab: \(title)"), bold: true))
            for b in content {
                output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                             numberingId: &numberingId, listDepth: listDepth)
            }
            result = output
        }

        mutating func visitStage(kind: StageKind, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            var output = writer.wrapParagraph(writer.wrapRun(writer.xmlEscape("Stage: \(kind.rawValue)"), bold: true))
            for b in content {
                output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                             numberingId: &numberingId, listDepth: listDepth)
            }
            result = output
        }

        mutating func visitLane(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            var output = writer.wrapParagraph(writer.wrapRun(writer.xmlEscape("Lane"), bold: true))
            for b in content {
                output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                             numberingId: &numberingId, listDepth: listDepth)
            }
            result = output
        }

        mutating func visitModule(family: String, name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            var output = writer.wrapParagraph(writer.wrapRun(writer.xmlEscape("Module: \(family).\(name)"), bold: true))
            for b in content {
                output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                             numberingId: &numberingId, listDepth: listDepth)
            }
            result = output
        }

        mutating func visitContractDirective(kind: ContractKind, content: String, attributes: RhoeMarkdownKit.Attributes) {
            result = writer.wrapParagraph(writer.wrapRun(writer.xmlEscape("Contract \(kind.rawValue): \(content)"), bold: true))
        }

        mutating func visitSection(level: Int, title: [Inline], children: [Block], attributes: RhoeMarkdownKit.Attributes) {
            let style = "Heading\(min(level, 9))"
            var output = writer.wrapParagraph(
                writer.renderRuns(title, footnotes: footnotes, footnoteIndex: &footnoteIndex),
                style: style
            )
            for child in children {
                output += writer.renderBlock(child, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                              numberingId: &numberingId, listDepth: listDepth)
            }
            result = output
        }

        mutating func visitMathBlock(expression: String, attributes: RhoeMarkdownKit.Attributes) {
            result = writer.wrapParagraph(writer.wrapRun(writer.xmlEscape("\\[\(expression)\\]")))
        }

        // MARK: - Canonical Block Visitors

        mutating func visitFormalBlock(family: String, title: [Inline]?, number: String?, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            var header = family.capitalized
            if let num = number { header += " \(num)" }
            var titleRuns = writer.wrapRun(writer.xmlEscape(header), bold: true)
            if let title {
                titleRuns += writer.wrapRun(writer.xmlEscape(": "))
                titleRuns += writer.renderRuns(title, footnotes: footnotes, footnoteIndex: &footnoteIndex)
            }
            var output = writer.wrapParagraph(titleRuns)
            for b in content {
                output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                             numberingId: &numberingId, listDepth: listDepth)
            }
            result = output
        }

        mutating func visitSpeakerNotes(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            // Speaker notes are hidden in print output; render as hidden (vanish) text
            var output = ""
            for b in content {
                let inner = writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                               numberingId: &numberingId, listDepth: listDepth)
                output += inner.replacingOccurrences(of: "</w:rPr>", with: "<w:vanish/></w:rPr>")
            }
            result = output
        }

        mutating func visitGrid(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            // DOCX has limited grid layout; render children sequentially
            var output = ""
            for b in content {
                output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                             numberingId: &numberingId, listDepth: listDepth)
            }
            result = output
        }

        mutating func visitColumns(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            // DOCX has limited column layout; render children sequentially
            var output = ""
            for b in content {
                output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                             numberingId: &numberingId, listDepth: listDepth)
            }
            result = output
        }

        mutating func visitFigure(content: [Block], caption: [Inline]?, attributes: RhoeMarkdownKit.Attributes) {
            var output = ""
            for b in content {
                output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                             numberingId: &numberingId, listDepth: listDepth)
            }
            if let caption {
                let capRuns = writer.renderRuns(caption, footnotes: footnotes, footnoteIndex: &footnoteIndex, italic: true)
                output += writer.wrapParagraph(capRuns)
            }
            result = output
        }

        mutating func visitDiagramBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes) {
            // Render as monospace code block, same as visitCodeBlock
            var output = ""
            for line in content.components(separatedBy: "\n") {
                output += "<w:p><w:pPr><w:pStyle w:val=\"Normal\"/></w:pPr>"
                output += "<w:r><w:rPr><w:rFonts w:ascii=\"Courier New\" w:hAnsi=\"Courier New\"/><w:sz w:val=\"20\"/></w:rPr>"
                output += "<w:t xml:space=\"preserve\">\(writer.xmlEscape(line))</w:t></w:r></w:p>"
            }
            result = output
        }

        mutating func visitShape(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            var output = ""
            for b in content {
                output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                             numberingId: &numberingId, listDepth: listDepth)
            }
            result = output
        }

        mutating func visitTableHead(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes) {
            // Structural table part; render rows with bold header cells
            var xml = ""
            for row in rows {
                xml += "<w:tr>"
                for cell in row {
                    let runs = writer.renderRuns(cell.content, footnotes: footnotes, footnoteIndex: &footnoteIndex, bold: true)
                    xml += "<w:tc><w:p><w:pPr><w:pStyle w:val=\"Normal\"/></w:pPr>\(runs)</w:p></w:tc>"
                }
                xml += "</w:tr>"
            }
            result = xml
        }

        mutating func visitTableBody(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes) {
            var xml = ""
            for row in rows {
                xml += "<w:tr>"
                for cell in row {
                    let runs = writer.renderRuns(cell.content, footnotes: footnotes, footnoteIndex: &footnoteIndex)
                    xml += "<w:tc><w:p><w:pPr><w:pStyle w:val=\"Normal\"/></w:pPr>\(runs)</w:p></w:tc>"
                }
                xml += "</w:tr>"
            }
            result = xml
        }

        mutating func visitTableFoot(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes) {
            var xml = ""
            for row in rows {
                xml += "<w:tr>"
                for cell in row {
                    let runs = writer.renderRuns(cell.content, footnotes: footnotes, footnoteIndex: &footnoteIndex)
                    xml += "<w:tc><w:p><w:pPr><w:pStyle w:val=\"Normal\"/></w:pPr>\(runs)</w:p></w:tc>"
                }
                xml += "</w:tr>"
            }
            result = xml
        }

        mutating func visitTableRow(cells: [TableCell], attributes: RhoeMarkdownKit.Attributes) {
            var xml = "<w:tr>"
            for cell in cells {
                let runs = writer.renderRuns(cell.content, footnotes: footnotes, footnoteIndex: &footnoteIndex)
                xml += "<w:tc><w:p><w:pPr><w:pStyle w:val=\"Normal\"/></w:pPr>\(runs)</w:p></w:tc>"
            }
            xml += "</w:tr>"
            result = xml
        }

        mutating func visitExecutableCodeBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes) {
            // Render as monospace code block, same as visitCodeBlock
            var output = ""
            for line in content.components(separatedBy: "\n") {
                output += "<w:p><w:pPr><w:pStyle w:val=\"Normal\"/></w:pPr>"
                output += "<w:r><w:rPr><w:rFonts w:ascii=\"Courier New\" w:hAnsi=\"Courier New\"/><w:sz w:val=\"20\"/></w:rPr>"
                output += "<w:t xml:space=\"preserve\">\(writer.xmlEscape(line))</w:t></w:r></w:p>"
            }
            result = output
        }

        mutating func visitDeck(slides: [Block], attributes: RhoeMarkdownKit.Attributes) {
            var output = ""
            for slide in slides {
                output += writer.renderBlock(slide, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                             numberingId: &numberingId, listDepth: listDepth)
            }
            result = output
        }

        mutating func visitSlide(title: [Inline]?, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            // Page break + title as Heading1
            var output = "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"
            if let title {
                let titleRuns = writer.renderRuns(title, footnotes: footnotes, footnoteIndex: &footnoteIndex)
                output += writer.wrapParagraph(titleRuns, style: "Heading1")
            }
            for b in content {
                output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                             numberingId: &numberingId, listDepth: listDepth)
            }
            result = output
        }

        mutating func visitSlotContent(name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            var output = ""
            for b in content {
                output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                             numberingId: &numberingId, listDepth: listDepth)
            }
            result = output
        }

        mutating func visitExtension(vendor: String, name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            var output = writer.wrapParagraph(writer.wrapRun(writer.xmlEscape("Extension: @\(vendor).\(name)"), bold: true))
            for b in content {
                output += writer.renderBlock(b, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                             numberingId: &numberingId, listDepth: listDepth)
            }
            result = output
        }

        mutating func visitRawBlock(content: String, format: String, attributes: RhoeMarkdownKit.Attributes) {
            if format == "docx" || format == "openxml" {
                result = content
            } else {
                result = "" // Skip raw blocks for other formats
            }
        }
    }

    // MARK: - Inline / Run Rendering

    private func renderRuns(
        _ inlines: [Inline],
        footnotes: [String: [Block]],
        footnoteIndex: inout Int,
        bold: Bool = false,
        italic: Bool = false
    ) -> String {
        inlines.map { renderRun($0, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                 bold: bold, italic: italic) }.joined()
    }

    private func renderRun(
        _ inline: Inline,
        footnotes: [String: [Block]],
        footnoteIndex: inout Int,
        bold: Bool = false,
        italic: Bool = false
    ) -> String {
        var visitor = DOCXInlineRenderer(
            writer: self,
            footnotes: footnotes,
            footnoteIndex: footnoteIndex,
            bold: bold,
            italic: italic
        )
        inline.accept(&visitor)
        footnoteIndex = visitor.footnoteIndex
        return visitor.result
    }

    // MARK: - Inline Visitor

    private struct DOCXInlineRenderer: InlineVisitor {
        let writer: DOCXWriter
        let footnotes: [String: [Block]]
        var footnoteIndex: Int
        let bold: Bool
        let italic: Bool
        var result: String = ""

        mutating func visitText(_ text: String) {
            result = writer.wrapRun(writer.xmlEscape(text), bold: bold, italic: italic)
        }

        mutating func visitEmphasis(_ inlines: [Inline]) {
            result = writer.renderRuns(inlines, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                       bold: bold, italic: true)
        }

        mutating func visitStrong(_ inlines: [Inline]) {
            result = writer.renderRuns(inlines, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                       bold: true, italic: italic)
        }

        mutating func visitStrikethrough(_ inlines: [Inline]) {
            result = writer.renderRuns(inlines, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                       bold: bold, italic: italic)
                .replacingOccurrences(of: "</w:rPr>", with: "<w:strike/></w:rPr>")
        }

        mutating func visitCodeSpan(_ code: String, attributes: RhoeMarkdownKit.Attributes) {
            result = "<w:r><w:rPr><w:rFonts w:ascii=\"Courier New\" w:hAnsi=\"Courier New\"/></w:rPr><w:t>\(writer.xmlEscape(code))</w:t></w:r>"
        }

        mutating func visitLink(text: [Inline], url: String, title: String?, attributes: RhoeMarkdownKit.Attributes) {
            result = writer.renderRuns(text, footnotes: footnotes, footnoteIndex: &footnoteIndex)
        }

        mutating func visitImage(alt: [Inline], url: String, title: String?, attributes: RhoeMarkdownKit.Attributes) {
            let altText = writer.inlinesToPlainText(alt)
            result = writer.wrapRun(writer.xmlEscape("[Image: \(altText)]"), italic: true)
        }

        mutating func visitFootnoteRef(id: String) {
            if footnotes[id] != nil {
                let fnId = writer.footnoteIdFor(id, in: footnotes)
                result = "<w:r><w:rPr><w:rStyle w:val=\"FootnoteReference\"/></w:rPr><w:footnoteReference w:id=\"\(fnId)\"/></w:r>"
            } else {
                result = writer.wrapRun(writer.xmlEscape("[^\(id)]"))
            }
        }

        mutating func visitInlineMath(expression: String, attributes: RhoeMarkdownKit.Attributes) {
            result = writer.wrapRun(writer.xmlEscape("$\(expression)$"), italic: true)
        }

        mutating func visitMathDisplay(expression: String, attributes: RhoeMarkdownKit.Attributes) {
            result = writer.wrapRun(writer.xmlEscape("$$\(expression)$$"), italic: true)
        }

        mutating func visitInlineHTML(_ html: String) {
            result = ""
        }

        mutating func visitHardBreak() {
            result = "<w:r><w:br/></w:r>"
        }

        mutating func visitSoftBreak() {
            result = writer.wrapRun(" ")
        }

        mutating func visitSuperscript(_ inlines: [Inline]) {
            let inner = writer.renderRuns(inlines, footnotes: footnotes, footnoteIndex: &footnoteIndex)
            result = inner.replacingOccurrences(of: "</w:rPr>", with: "<w:vertAlign w:val=\"superscript\"/></w:rPr>")
        }

        mutating func visitSubscript(_ inlines: [Inline]) {
            let inner = writer.renderRuns(inlines, footnotes: footnotes, footnoteIndex: &footnoteIndex)
            result = inner.replacingOccurrences(of: "</w:rPr>", with: "<w:vertAlign w:val=\"subscript\"/></w:rPr>")
        }

        mutating func visitHighlight(_ inlines: [Inline]) {
            let inner = writer.renderRuns(inlines, footnotes: footnotes, footnoteIndex: &footnoteIndex)
            result = inner.replacingOccurrences(of: "</w:rPr>", with: "<w:highlight w:val=\"yellow\"/></w:rPr>")
        }

        mutating func visitSpan(content: [Inline], attributes: RhoeMarkdownKit.Attributes) {
            result = writer.renderRuns(content, footnotes: footnotes, footnoteIndex: &footnoteIndex,
                                       bold: bold, italic: italic)
        }

        mutating func visitInlineFootnote(content: [Inline]) {
            let text = content.map { writer.inlineToPlainText($0) }.joined()
            result = writer.wrapRun(writer.xmlEscape("[\(text)]"))
        }

        mutating func visitCitation(items: [CitationItem], mode: CitationMode) {
            let keys = items.map(\.key).joined(separator: "; ")
            result = writer.wrapRun(writer.xmlEscape("[\(keys)]"))
        }

        mutating func visitResolvedCitation(text: String, keys: [String], mode: CitationMode) {
            result = writer.wrapRun(writer.xmlEscape(text))
        }

        mutating func visitCrossReference(prefix: CrossRefPrefix, id: String) {
            result = writer.wrapRun(writer.xmlEscape("\(prefix.rawValue)-\(id)"))
        }

        mutating func visitResolvedCrossReference(text: String, targetId: String) {
            result = writer.wrapRun(writer.xmlEscape(text))
        }

        mutating func visitRawInline(content: String, format: String) {
            if format == "docx" { result = content }
            else { result = "" }
        }

        mutating func visitWikilink(target: String, display: [Inline]?) {
            let text = display.map { writer.inlinesToPlainText($0) } ?? target
            result = writer.wrapRun(writer.xmlEscape(text))
        }

        mutating func visitTransclusionInline(target: String, fragment: String?, mode: TransclusionMode?, attributes: RhoeMarkdownKit.Attributes) {
            let fragSuffix = fragment.map { "#\($0)" } ?? ""
            result = writer.wrapRun(writer.xmlEscape("[\(target)\(fragSuffix)]"), italic: true)
        }

        mutating func visitAnnotationInline(kind: AnnotationKind, text: String) {
            result = "" // Non-rendering
        }

        mutating func visitParamRef(name: String) {
            result = writer.wrapRun(writer.xmlEscape("<<param \(name)>>"))
        }

        mutating func visitSlotRef(name: String?) {
            result = writer.wrapRun(writer.xmlEscape("<<slot \(name ?? "default")>>"))
        }

        mutating func visitPlaceholderInline(fields: [String: String]) {
            let display: String
            if let name = fields["name"] {
                display = name
            } else {
                display = fields.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            }
            result = writer.wrapRun(writer.xmlEscape("[\(display)]"), italic: true)
        }

        mutating func visitExpressionInline(expr: String) {
            result = writer.wrapRun(writer.xmlEscape(expr))
        }

        mutating func visitInputFieldInline(name: String, fieldType: String, attributes: RhoeMarkdownKit.Attributes) {
            result = writer.wrapRun(writer.xmlEscape(name))
        }

        mutating func visitEmoji(name: String, unicode: String?) {
            if let unicode {
                result = writer.wrapRun(unicode)
            } else {
                result = writer.wrapRun(writer.xmlEscape(":\(name):"))
            }
        }
    }

    // MARK: - XML Helpers

    private func wrapParagraph(
        _ runs: String,
        style: String = "Normal",
        numbering: (numId: Int, level: Int, type: Int)? = nil
    ) -> String {
        var pPr = "<w:pPr><w:pStyle w:val=\"\(style)\"/>"
        if let num = numbering {
            pPr += "<w:numPr><w:ilvl w:val=\"\(num.level)\"/><w:numId w:val=\"\(num.numId)\"/></w:numPr>"
        }
        pPr += "</w:pPr>"
        return "<w:p>\(pPr)\(runs)</w:p>"
    }

    private func wrapRun(_ text: String, bold: Bool = false, italic: Bool = false) -> String {
        var rPr = "<w:rPr>"
        if bold { rPr += "<w:b/>" }
        if italic { rPr += "<w:i/>" }
        rPr += "</w:rPr>"
        return "<w:r>\(rPr)<w:t xml:space=\"preserve\">\(text)</w:t></w:r>"
    }

    private func renderTable(
        headers: [TableCell],
        rows: [[TableCell]],
        footnotes: [String: [Block]],
        footnoteIndex: inout Int
    ) -> String {
        var xml = "<w:tbl><w:tblPr><w:tblStyle w:val=\"TableGrid\"/><w:tblW w:w=\"0\" w:type=\"auto\"/><w:tblBorders>"
        xml += "<w:top w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>"
        xml += "<w:left w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>"
        xml += "<w:bottom w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>"
        xml += "<w:right w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>"
        xml += "<w:insideH w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>"
        xml += "<w:insideV w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/>"
        xml += "</w:tblBorders></w:tblPr>"

        // Header row
        xml += "<w:tr>"
        for cell in headers {
            let runs = renderRuns(cell.content, footnotes: footnotes, footnoteIndex: &footnoteIndex, bold: true)
            xml += "<w:tc><w:p><w:pPr><w:pStyle w:val=\"Normal\"/></w:pPr>\(runs)</w:p></w:tc>"
        }
        xml += "</w:tr>"

        // Data rows
        for row in rows {
            xml += "<w:tr>"
            for cell in row {
                let runs = renderRuns(cell.content, footnotes: footnotes, footnoteIndex: &footnoteIndex)
                xml += "<w:tc><w:p><w:pPr><w:pStyle w:val=\"Normal\"/></w:pPr>\(runs)</w:p></w:tc>"
            }
            xml += "</w:tr>"
        }

        xml += "</w:tbl>"
        return xml
    }

    // MARK: - Helper utilities

    private func blockToRuns(_ block: Block, footnotes: [String: [Block]], footnoteIndex: inout Int) -> String {
        if case .paragraph(let inlines, _) = block {
            return renderRuns(inlines, footnotes: footnotes, footnoteIndex: &footnoteIndex)
        }
        return wrapRun(xmlEscape(renderBlockPlain(block)))
    }

    private func renderBlockPlain(_ block: Block) -> String {
        switch block {
        case .paragraph(let inlines, _):
            return inlinesToPlainText(inlines)
        case .heading(_, let content, _):
            return inlinesToPlainText(content)
        default:
            return ""
        }
    }

    private func inlinesToPlainText(_ inlines: [Inline]) -> String {
        inlines.map { inlineToPlainText($0) }.joined()
    }

    private func inlineToPlainText(_ inline: Inline) -> String {
        switch inline {
        case .text(let t): return t
        case .emphasis(let c), .strong(let c), .strikethrough(let c),
             .superscript(let c), .subscript(let c), .highlight(let c):
            return inlinesToPlainText(c)
        case .codeSpan(let t, _): return t
        case .link(let text, _, _, _): return inlinesToPlainText(text)
        case .image(let alt, _, _, _): return inlinesToPlainText(alt)
        case .inlineMath(let e, _): return e
        case .resolvedCitation(let t, _, _): return t
        case .resolvedCrossReference(let t, _): return t
        default: return ""
        }
    }

    private func footnoteIdFor(_ id: String, in footnotes: [String: [Block]]) -> Int {
        let sortedKeys = footnotes.keys.sorted()
        return (sortedKeys.firstIndex(of: id) ?? 0) + 1
    }

    private func blockAttrs(_ block: Block) -> RhoeMarkdownKit.Attributes? {
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

    private func xmlEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

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
                for item in items { footnotes.merge(collectFootnotes(from: item.content)) { _, new in new } }
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
        default: return nil
        }
    }

    // MARK: - Open XML Templates

    private func contentTypesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
        <Override PartName="/word/footnotes.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml"/>
        <Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
        <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
        </Types>
        """
    }

    private func relsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
        </Relationships>
        """
    }

    private func documentRelsXML(hasFootnotes: Bool) -> String {
        var rels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>
        """
        if hasFootnotes {
            rels += "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes\" Target=\"footnotes.xml\"/>"
        }
        rels += "</Relationships>"
        return rels
    }

    private func documentXML(body: String) -> String {
        let pageW: String
        let pageH: String
        switch configuration.pageSize {
        case .letter: pageW = "12240"; pageH = "15840"
        case .a4: pageW = "11906"; pageH = "16838"
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <w:body>
        \(body)
        <w:sectPr><w:pgSz w:w="\(pageW)" w:h="\(pageH)"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr>
        </w:body>
        </w:document>
        """
    }

    private func stylesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:style w:type="paragraph" w:styleId="Normal" w:default="1"><w:name w:val="Normal"/><w:rPr><w:sz w:val="24"/></w:rPr></w:style>
        <w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:pPr><w:spacing w:before="240" w:after="120"/></w:pPr><w:rPr><w:b/><w:sz w:val="48"/></w:rPr></w:style>
        <w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:pPr><w:spacing w:before="200" w:after="100"/></w:pPr><w:rPr><w:b/><w:sz w:val="36"/></w:rPr></w:style>
        <w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="heading 3"/><w:pPr><w:spacing w:before="160" w:after="80"/></w:pPr><w:rPr><w:b/><w:sz w:val="28"/></w:rPr></w:style>
        <w:style w:type="paragraph" w:styleId="Quote"><w:name w:val="Quote"/><w:pPr><w:ind w:left="720"/></w:pPr><w:rPr><w:i/><w:sz w:val="24"/></w:rPr></w:style>
        <w:style w:type="character" w:styleId="FootnoteReference"><w:name w:val="footnote reference"/><w:rPr><w:vertAlign w:val="superscript"/></w:rPr></w:style>
        <w:style w:type="paragraph" w:styleId="FootnoteText"><w:name w:val="footnote text"/><w:rPr><w:sz w:val="20"/></w:rPr></w:style>
        <w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/></w:style>
        </w:styles>
        """
    }

    private func footnotesDocXML(entries: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:footnote w:type="separator" w:id="-1"><w:p><w:r><w:separator/></w:r></w:p></w:footnote>
        <w:footnote w:type="continuationSeparator" w:id="0"><w:p><w:r><w:continuationSeparator/></w:r></w:p></w:footnote>
        \(entries)
        </w:footnotes>
        """
    }

    private func numberingXML(maxId: Int) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:abstractNum w:abstractNumId="0"><w:lvl w:ilvl="0"><w:numFmt w:val="bullet"/><w:lvlText w:val="\u{2022}"/></w:lvl></w:abstractNum>
        <w:abstractNum w:abstractNumId="1"><w:lvl w:ilvl="0"><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/></w:lvl></w:abstractNum>
        """
        for id in 1..<maxId {
            xml += "<w:num w:numId=\"\(id)\"><w:abstractNumId w:val=\"\(id % 2)\"/></w:num>"
        }
        xml += "</w:numbering>"
        return xml
    }

    private func corePropsXML(title: String?, author: String?) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
                           xmlns:dc="http://purl.org/dc/elements/1.1/">
        \(title.map { "<dc:title>\(xmlEscape($0))</dc:title>" } ?? "")
        \(author.map { "<dc:creator>\(xmlEscape($0))</dc:creator>" } ?? "")
        </cp:coreProperties>
        """
    }

    // MARK: - File I/O

    private func writeFile(_ path: String, in directory: URL, content: String) throws {
        let fileURL = directory.appendingPathComponent(path)
        try content.data(using: .utf8)?.write(to: fileURL)
    }

    private func createZipData(from sourceDir: URL) throws -> Data {
        #if os(WASI)
        // Process execution not available on WASI
        return Data()
        #else
        let tempZip = sourceDir.appendingPathComponent("output.docx")

        let process = Process()
        process.currentDirectoryURL = sourceDir
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q", "output.docx", ".", "-x", "output.docx"]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return Data()
        }

        return try Data(contentsOf: tempZip)
        #endif
    }
}
