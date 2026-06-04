import Foundation
import RhoeMarkdownModel

// MARK: - HTMLBlockRenderer (Visitor)

struct HTMLBlockRenderer: BlockVisitor {
    let renderer: RhoeHTMLRenderer
    let isLast: Bool
    var result: String = ""

    mutating func visitParagraph(_ inlines: [Inline], attributes: RhoeMarkdownKit.Attributes) {
        // Implicit figure: lone image with non-empty alt → <figure>
        if renderer.configuration.enableImplicitFigures,
           let figureHTML = renderer.renderImplicitFigure(inlines: inlines, attributes: attributes) {
            result = figureHTML
            return
        }
        let content = renderer.renderInlines(inlines)
        result = "<p\(renderer.withRhoeNode(attributes, "paragraph").toHTMLAttributes())>\(content)</p>"
    }

    mutating func visitHeading(level: Int, content: [Inline], attributes: RhoeMarkdownKit.Attributes) {
        let inlineContent = renderer.renderInlines(content)
        // Use attribute ID if provided, otherwise generate from content
        let autoId = attributes.id ?? renderer.generateHeadingId(from: content)
        var attrs = attributes
        if attrs.id == nil {
            attrs = RhoeMarkdownKit.Attributes(id: autoId, classes: attributes.classes, keyValues: attributes.keyValues)
        }
        result = "<h\(level)\(renderer.withRhoeNode(attrs, "heading").toHTMLAttributes())>\(inlineContent)</h\(level)>"
    }

    mutating func visitBlockQuote(_ blocks: [Block], attributes: RhoeMarkdownKit.Attributes) {
        var html = "<blockquote\(renderer.withRhoeNode(attributes, "blockquote").toHTMLAttributes())>\n"
        guard !blocks.isEmpty else {
            html += "</blockquote>"
            result = html
            return
        }

        for (index, block) in blocks.enumerated() {
            html += renderer.renderBlock(block, isLast: index == blocks.count - 1)
            if index < blocks.count - 1 {
                html += "\n"
            }
        }
        html += "\n</blockquote>"
        result = html
    }

    mutating func visitList(type: ListType, items: [ListItem], attributes: RhoeMarkdownKit.Attributes) {
        let tag = switch type {
        case .ordered: "ol"
        case .unordered, .task: "ul"
        }

        // Merge start attribute and list-style-type with other attributes
        var mergedAttrs = attributes
        if case .ordered(let start, let style) = type {
            var keyValues = attributes.keyValues
            if start != 1 {
                keyValues["start"] = String(start)
            }
            if style != .decimal {
                let cssType = switch style {
                case .lowerAlpha: "lower-alpha"
                case .upperAlpha: "upper-alpha"
                case .lowerRoman: "lower-roman"
                case .upperRoman: "upper-roman"
                case .decimal: "decimal"
                }
                var classes = attributes.classes
                classes.append("list-style-\(cssType)")
                mergedAttrs = RhoeMarkdownKit.Attributes(id: attributes.id, classes: classes, keyValues: keyValues)
            } else if start != 1 {
                mergedAttrs = RhoeMarkdownKit.Attributes(id: attributes.id, classes: attributes.classes, keyValues: keyValues)
            }
        }

        var html = "<\(tag)\(renderer.withRhoeNode(mergedAttrs, "list").toHTMLAttributes())>\n"

        for item in items {
            var itemHtml = "<li"

            // Handle task list items
            if case .task = type, let checked = item.checked {
                itemHtml += " class=\"task-list-item\""
                html += itemHtml + ">"
                html += "<input type=\"checkbox\" class=\"task-list-item-checkbox\""
                if checked {
                    html += " checked"
                }
                html += " disabled> "
            } else {
                html += itemHtml + ">"
            }

            // Render item content
            for (index, block) in item.content.enumerated() {
                // Tight CommonMark lists render paragraph children directly.
                if !item.isLoose, case .paragraph(let inlines, _) = block {
                    html += renderer.renderInlines(inlines)
                    if index < item.content.count - 1 {
                        html += "\n"
                    }
                } else if !item.isLoose,
                          let renderedSection = renderTightListSection(block) {
                    html += renderedSection
                    if index < item.content.count - 1,
                       renderer.shouldSeparateRenderedBlocks(block, item.content[index + 1], renderedHTML: renderedSection) {
                        html += "\n"
                    }
                } else {
                    if index == 0, renderer.isHTMLBoundaryBlock(block) {
                        html += "\n"
                    }
                    let renderedHTML = renderer.renderBlock(block, isLast: index == item.content.count - 1)
                    html += renderedHTML
                    if index < item.content.count - 1,
                       renderer.shouldSeparateRenderedBlocks(block, item.content[index + 1], renderedHTML: renderedHTML) {
                        html += "\n"
                    }
                }
            }

            html += "</li>\n"
        }

        html += "</\(tag)>"
        result = html
    }

    func renderTightListSection(_ block: Block) -> String? {
        guard case .section(let level, let title, let children, _) = block else {
            return nil
        }

        var html = "<h\(level)>\(renderer.renderInlines(title))</h\(level)>"
        for (index, child) in children.enumerated() {
            html += "\n"
            if case .paragraph(let inlines, _) = child {
                html += renderer.renderInlines(inlines)
            } else {
                html += renderer.renderBlock(child, isLast: index == children.count - 1)
            }
        }
        return html
    }

    mutating func visitCodeBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes) {
        // Mermaid diagrams: render as <pre class="mermaid"> for client-side rendering
        if let lang = language, lang.lowercased() == "mermaid" {
            result = "<pre class=\"mermaid\"\(attributes.toHTMLAttributes())>\(renderer.htmlEscape(content))</pre>"
            return
        }

        var html = "<pre><code"

        // Merge language class with attribute classes
        var mergedClasses = attributes.classes
        if let lang = language {
            mergedClasses.insert("language-\(renderer.htmlEscape(lang))", at: 0)
        }

        let mergedAttrs = RhoeMarkdownKit.Attributes(id: attributes.id, classes: mergedClasses, keyValues: attributes.keyValues)
        html += renderer.withRhoeNode(mergedAttrs, "code").toHTMLAttributes()
        html += ">"

        if renderer.configuration.enableSyntaxHighlighting, let lang = language {
            html += renderer.highlightCode(content, language: lang)
        } else {
            html += renderer.htmlEscape(content)
        }

        html += "</code></pre>"
        result = html
    }

    mutating func visitHorizontalRule() {
        result = "<hr>"
    }

    mutating func visitTable(headers: [TableCell], rows: [[TableCell]], caption: [Inline]?, attributes: RhoeMarkdownKit.Attributes) {
        let tableKind = attributes.keyValues["kind"]
        let isLayout = tableKind == "layout"
        let isMatrix = tableKind == "matrix"

        // Build table opening tag with semantic classes and attributes
        var extraClasses = ["rhoe-table"]
        if let kind = tableKind { extraClasses.append("rhoe-table-\(kind)") }
        if let responsive = attributes.keyValues["responsive"] {
            extraClasses.append("rhoe-responsive-\(responsive)")
        }
        let allClasses = (attributes.classes + extraClasses).joined(separator: " ")

        var html = "<table\(attributes.toHTMLAttributes()) class=\"\(allClasses)\" data-rhoe-node=\"table\""
        if let kind = tableKind { html += " data-rhoe-kind=\"\(kind)\"" }
        if isLayout { html += " role=\"presentation\"" }
        html += ">\n"

        // Caption
        if let caption {
            html += "<caption>\(renderer.renderInlines(caption))</caption>\n"
        }

        // Summary (visually hidden, accessible)
        if let summary = attributes.keyValues["summary"] {
            html += "<p class=\"rhoe-table-summary\" aria-hidden=\"false\" style=\"position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0,0,0,0)\">\(renderer.htmlEscape(summary))</p>\n"
        }

        html += "<thead>\n<tr>\n"

        // Render headers with scope
        for header in headers {
            let alignment = renderer.renderAlignment(header.alignment)
            let spanAttrs = renderer.renderSpanAttributes(header)
            html += "<th scope=\"col\"\(alignment)\(spanAttrs)>\(renderer.renderCellContent(header))</th>\n"
        }

        html += "</tr>\n</thead>\n<tbody>\n"

        // Render rows
        for row in rows {
            html += "<tr>\n"
            for (colIndex, cell) in row.enumerated() {
                let alignment = renderer.renderAlignment(cell.alignment)
                let spanAttrs = renderer.renderSpanAttributes(cell)
                // For matrix tables, first column cells get scope="row"
                if isMatrix && colIndex == 0 {
                    html += "<th scope=\"row\"\(alignment)\(spanAttrs)>\(renderer.renderCellContent(cell))</th>\n"
                } else {
                    html += "<td\(alignment)\(spanAttrs)>\(renderer.renderCellContent(cell))</td>\n"
                }
            }
            html += "</tr>\n"
        }

        html += "</tbody>\n</table>"
        result = html
    }

    mutating func visitDefinitionList(items: [DefinitionListItem], attributes: RhoeMarkdownKit.Attributes) {
        var html = "<dl\(attributes.toHTMLAttributes())>\n"

        for item in items {
            // Render the term
            html += "<dt>\(renderer.renderInlines(item.term))</dt>\n"

            // Render each definition
            for definition in item.definitions {
                html += "<dd>"
                let definitionContent = definition.map { renderer.renderBlock($0) }.joined()
                html += definitionContent
                html += "</dd>\n"
            }
        }

        html += "</dl>"
        result = html
    }

    mutating func visitFootnoteDefinition(id: String, content: [Block]) {
        var html = "<div class=\"footnote\" id=\"fn:\(id)\">\n"
        html += "<p><sup>\(id)</sup> "

        // Render content blocks
        for (index, block) in content.enumerated() {
            if index == 0, case .paragraph(let inlines, _) = block {
                // First paragraph, render inline
                html += renderer.renderInlines(inlines)
            } else {
                // Other blocks
                html += renderer.renderBlock(block)
            }
        }

        html += " <a href=\"#fnref:\(id)\" class=\"footnote-backref\">↩</a></p>\n"
        html += "</div>"
        result = html
    }

    mutating func visitAdmonition(type: String, title: String?, content: [Block], collapsible: AdmonitionCollapsible?, attributes: RhoeMarkdownKit.Attributes) {
        result = renderer.renderAdmonition(type: type, title: title, content: content, collapsible: collapsible, attributes: attributes)
    }

    mutating func visitBlockHTML(_ html: String) {
        result = html
    }

    mutating func visitDiv(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        // 5.6 Theorem environments — detect recognized class names
        if let theoremHtml = renderer.renderTheoremEnvironment(content: content, attributes: attributes) {
            result = theoremHtml
            return
        }

        // 5.7 Content visibility — check for .content-visible / .content-hidden
        if let visibilityResult = renderer.checkContentVisibility(attributes: attributes) {
            if !visibilityResult {
                result = "" // Hidden for HTML format
                return
            }
        }

        var html = "<div\(renderer.withRhoeNode(attributes, "div").toHTMLAttributes())>\n"
        for (index, block) in content.enumerated() {
            html += renderer.renderBlock(block, isLast: index == content.count - 1)
            if index < content.count - 1 {
                html += "\n"
            }
        }
        html += "\n</div>"
        result = html
    }

    mutating func visitLineBlock(lines: [[Inline]]) {
        let rendered = lines.map { renderer.renderInlines($0) }.joined(separator: "<br>\n")
        result = "<div class=\"line-block\">\(rendered)</div>"
    }

    mutating func visitAbbreviationDefinition(abbreviation: String, expansion: String) {
        result = "" // Consumed during abbreviation expansion
    }

    mutating func visitVisualBlock(name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let canonicalName = name.lowercased()
        if canonicalName == "rhoe.page" {
            let width = attributes.keyValues["width"] ?? "1200"
            let height = attributes.keyValues["height"] ?? "1600"
            var keyValues = attributes.keyValues
            keyValues["style"] = "width: min(100%, \(width)px); min-height: \(height)px; margin: 0 auto; padding: 16px; box-sizing: border-box; background: white; box-shadow: 0 0 0 1px rgba(15, 23, 42, 0.08);"
            let pageAttributes = renderer.withRhoeNode(
                RhoeMarkdownKit.Attributes(
                    id: attributes.id,
                    classes: ["rhoe-publication-page"] + attributes.classes,
                    keyValues: keyValues
                ),
                "publication-page"
            )
            var html = "<section\(pageAttributes.toHTMLAttributes())>\n"
            for (index, block) in content.enumerated() {
                html += renderer.renderBlock(block, isLast: index == content.count - 1)
                if index < content.count - 1 {
                    html += "\n"
                }
            }
            html += "\n</section>"
            result = html
            return
        }

        if canonicalName == "rhoe.canvas" {
            var keyValues = attributes.keyValues
            keyValues["style"] = "position: relative; width: 100%; height: 100%; overflow: hidden;"
            let canvasAttributes = renderer.withRhoeNode(
                RhoeMarkdownKit.Attributes(
                    id: attributes.id,
                    classes: ["rhoe-publication-canvas"] + attributes.classes,
                    keyValues: keyValues
                ),
                "publication-canvas"
            )
            var html = "<div\(canvasAttributes.toHTMLAttributes())>\n"
            for (index, block) in content.enumerated() {
                html += renderer.renderBlock(block, isLast: index == content.count - 1)
                if index < content.count - 1 {
                    html += "\n"
                }
            }
            html += "\n</div>"
            result = html
            return
        }

        if canonicalName == "rhoe.pagebreak" {
            let label = attributes.keyValues["label"] ?? "Page Break"
            var keyValues = attributes.keyValues
            keyValues["aria-label"] = label
            let pageBreakAttributes = renderer.withRhoeNode(
                RhoeMarkdownKit.Attributes(
                    id: attributes.id,
                    classes: ["rhoe-pagebreak"] + attributes.classes,
                    keyValues: keyValues
                ),
                "publication-pagebreak"
            )
            result = "<hr\(pageBreakAttributes.toHTMLAttributes())>"
            return
        }

        var classes = attributes.classes
        classes.insert("rhoe-visual", at: 0)
        classes.insert("rhoe-\(name)", at: 1)
        let mergedAttrs = RhoeMarkdownKit.Attributes(id: attributes.id, classes: classes, keyValues: attributes.keyValues)
        var html = "<div\(mergedAttrs.toHTMLAttributes())>\n"
        for (index, block) in content.enumerated() {
            html += renderer.renderBlock(block, isLast: index == content.count - 1)
            if index < content.count - 1 {
                html += "\n"
            }
        }
        html += "\n</div>"
        result = html
    }

    mutating func visitAuthorAnnotation(kind: AnnotationKind, text: String, attributes: RhoeMarkdownKit.Attributes) {
        result = "" // Non-rendering
    }

    mutating func visitTransclusion(target: String, fragment: String?, mode: TransclusionMode?, attributes: RhoeMarkdownKit.Attributes) {
        let fragSuffix = fragment.map { "#\($0)" } ?? ""
        let display = renderer.htmlEscape("\(target)\(fragSuffix)")
        result = "<div class=\"rhoe-transclusion\" data-target=\"\(renderer.htmlEscape(target))\"" +
            (fragment.map { " data-fragment=\"\(renderer.htmlEscape($0))\"" } ?? "") +
            "><p class=\"rhoe-transclusion-placeholder\">[Transclusion: \(display)]</p></div>"
    }

    mutating func visitSchemaIsland(schema: String, body: String, attributes: RhoeMarkdownKit.Attributes) {
        result = "<div class=\"rhoe-schema-island\" data-schema=\"\(renderer.htmlEscape(schema))\">" +
            "<pre><code class=\"language-\(renderer.htmlEscape(schema))\">\(renderer.htmlEscape(body))</code></pre></div>"
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
            display = renderer.htmlEscape(name)
        } else {
            display = fields.map { "\(renderer.htmlEscape($0.key))=\(renderer.htmlEscape($0.value))" }.joined(separator: ", ")
        }
        result = "<span class=\"rhoe-placeholder\" data-rhoe-node=\"placeholder\">[\(display)]</span>"
    }

    mutating func visitExpression(expr: String, attributes: RhoeMarkdownKit.Attributes) {
        result = "<span class=\"rhoe-expression\" data-rhoe-node=\"Expression\">\(renderer.htmlEscape(expr))</span>"
    }

    mutating func visitField(name: String, fieldType: String, attributes: RhoeMarkdownKit.Attributes) {
        result = "<div class=\"rhoe-field\"><label>\(renderer.htmlEscape(name))</label><input type=\"\(renderer.htmlEscape(fieldType))\"></div>"
    }

    mutating func visitForm(name: String?, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let nameAttr = name.map { " name=\"\(renderer.htmlEscape($0))\"" } ?? ""
        var html = "<form class=\"rhoe-form\"\(nameAttr)>\n"
        for (index, block) in content.enumerated() {
            html += renderer.renderBlock(block, isLast: index == content.count - 1)
            if index < content.count - 1 {
                html += "\n"
            }
        }
        html += "\n</form>"
        result = html
    }

    mutating func visitWidget(title: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        var kv = attributes.keyValues
        kv["data-rhoe-node"] = "widget"
        kv["data-rhoe-surface"] = "widget"
        kv["data-title"] = title
        let mergedAttrs = RhoeMarkdownKit.Attributes(
            id: attributes.id,
            classes: ["rhoe-widget"] + attributes.classes,
            keyValues: kv
        )
        var html = "<div\(mergedAttrs.toHTMLAttributes())>\n"
        for (index, block) in content.enumerated() {
            html += renderer.renderBlock(block, isLast: index == content.count - 1)
            if index < content.count - 1 {
                html += "\n"
            }
        }
        html += "\n</div>"
        result = html
    }

    mutating func visitTab(title: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        var kv = attributes.keyValues
        kv["data-rhoe-node"] = "tab"
        kv["data-rhoe-surface"] = "tab"
        kv["data-title"] = title
        let mergedAttrs = RhoeMarkdownKit.Attributes(
            id: attributes.id,
            classes: ["rhoe-tab"] + attributes.classes,
            keyValues: kv
        )
        var html = "<div\(mergedAttrs.toHTMLAttributes())>\n"
        for (index, block) in content.enumerated() {
            html += renderer.renderBlock(block, isLast: index == content.count - 1)
            if index < content.count - 1 {
                html += "\n"
            }
        }
        html += "\n</div>"
        result = html
    }

    mutating func visitStage(kind: StageKind, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let mergedAttrs = RhoeMarkdownKit.Attributes(
            id: attributes.id,
            classes: ["rhoe-stage", "rhoe-stage-\(kind.rawValue)"] + attributes.classes,
            keyValues: attributes.keyValues
        )
        var html = "<div\(mergedAttrs.toHTMLAttributes())>\n"
        for (index, block) in content.enumerated() {
            html += renderer.renderBlock(block, isLast: index == content.count - 1)
            if index < content.count - 1 {
                html += "\n"
            }
        }
        html += "\n</div>"
        result = html
    }

    mutating func visitLane(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let mergedAttrs = RhoeMarkdownKit.Attributes(
            id: attributes.id,
            classes: ["rhoe-lane"] + attributes.classes,
            keyValues: attributes.keyValues
        )
        var html = "<div\(mergedAttrs.toHTMLAttributes())>\n"
        for (index, block) in content.enumerated() {
            html += renderer.renderBlock(block, isLast: index == content.count - 1)
            if index < content.count - 1 {
                html += "\n"
            }
        }
        html += "\n</div>"
        result = html
    }

    mutating func visitModule(family: String, name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let mergedAttrs = RhoeMarkdownKit.Attributes(
            id: attributes.id,
            classes: ["rhoe-module", "rhoe-module-\(family)-\(name)"] + attributes.classes,
            keyValues: attributes.keyValues
        )
        var html = "<div\(mergedAttrs.toHTMLAttributes())>\n"
        for (index, block) in content.enumerated() {
            html += renderer.renderBlock(block, isLast: index == content.count - 1)
            if index < content.count - 1 {
                html += "\n"
            }
        }
        html += "\n</div>"
        result = html
    }

    mutating func visitContractDirective(kind: ContractKind, content: String, attributes: RhoeMarkdownKit.Attributes) {
        let mergedAttrs = RhoeMarkdownKit.Attributes(
            id: attributes.id,
            classes: ["rhoe-contract", "rhoe-contract-\(kind.rawValue)"] + attributes.classes,
            keyValues: attributes.keyValues
        )
        result = "<div\(mergedAttrs.toHTMLAttributes())>\(renderer.htmlEscape(content))</div>"
    }

    mutating func visitSection(level: Int, title: [Inline], children: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let titleHTML = renderer.renderInlines(title)
        let id = attributes.id ?? renderer.generateHeadingId(from: title)
        let sectionAttrs = RhoeMarkdownKit.Attributes(
            id: id,
            classes: attributes.classes,
            keyValues: attributes.keyValues
        )
        var html = "<section\(renderer.withRhoeNode(sectionAttrs, "Section").toHTMLAttributes())>"
        html += "<h\(level)>\(titleHTML)</h\(level)>"
        for (index, child) in children.enumerated() {
            html += renderer.renderBlock(child, isLast: index == children.count - 1)
        }
        html += "</section>"
        result = html
    }

    mutating func visitFormalBlock(family: String, title: [Inline]?, number: String?, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        let familyLower = family.lowercased()
        let familyCapitalized = family.prefix(1).uppercased() + family.dropFirst()
        var html = "<div class=\"formal-block formal-\(renderer.htmlEscape(familyLower))\"\(attributes.toHTMLAttributes()) data-rhoe-node=\"FormalBlock\">"
        // Title line
        var titleParts: [String] = [familyCapitalized]
        if let num = number {
            titleParts.append(renderer.htmlEscape(num))
        }
        var titleLine = titleParts.joined(separator: " ")
        if let titleInlines = title {
            titleLine += ": " + renderer.renderInlines(titleInlines)
        }
        html += "<p class=\"formal-title\">\(titleLine)</p>"
        html += "<div class=\"formal-content\">"
        for child in content {
            html += renderer.renderBlock(child)
        }
        html += "</div></div>"
        result = html
    }

    mutating func visitSpeakerNotes(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        var html = "<aside class=\"speaker-notes\" data-rhoe-node=\"SpeakerNotes\"\(attributes.toHTMLAttributes())>"
        for child in content {
            html += renderer.renderBlock(child)
        }
        html += "</aside>"
        result = html
    }

    mutating func visitGrid(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        var html = "<div class=\"rhoe-grid\"\(attributes.toHTMLAttributes()) data-rhoe-node=\"Grid\">"
        for child in content {
            html += renderer.renderBlock(child)
        }
        html += "</div>"
        result = html
    }

    mutating func visitColumns(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        var html = "<div class=\"rhoe-columns\"\(attributes.toHTMLAttributes()) data-rhoe-node=\"Columns\">"
        for child in content {
            html += renderer.renderBlock(child)
        }
        html += "</div>"
        result = html
    }

    mutating func visitFigure(content: [Block], caption: [Inline]?, attributes: RhoeMarkdownKit.Attributes) {
        var html = "<figure\(attributes.toHTMLAttributes()) data-rhoe-node=\"Figure\">"
        for child in content {
            html += renderer.renderBlock(child)
        }
        if let caption {
            html += "<figcaption>\(renderer.renderInlines(caption))</figcaption>"
        }
        html += "</figure>"
        result = html
    }

    mutating func visitDiagramBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes) {
        var classes = ["diagram"]
        if let lang = language {
            classes.append("language-\(renderer.htmlEscape(lang))")
        }
        let mergedClasses = (attributes.classes + classes)
        let mergedAttrs = RhoeMarkdownKit.Attributes(id: attributes.id, classes: mergedClasses, keyValues: attributes.keyValues)
        result = "<pre\(mergedAttrs.toHTMLAttributes()) data-rhoe-node=\"DiagramBlock\"><code>\(renderer.htmlEscape(content))</code></pre>"
    }

    mutating func visitShape(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        var html = "<div class=\"rhoe-shape\"\(attributes.toHTMLAttributes()) data-rhoe-node=\"Shape\">"
        for child in content {
            html += renderer.renderBlock(child)
        }
        html += "</div>"
        result = html
    }

    mutating func visitTableHead(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes) {
        var html = "<thead\(attributes.toHTMLAttributes())>\n"
        for row in rows {
            html += "<tr>\n"
            for cell in row {
                let alignment = renderer.renderAlignment(cell.alignment)
                let spanAttrs = renderer.renderSpanAttributes(cell)
                html += "<th scope=\"col\"\(alignment)\(spanAttrs)>\(renderer.renderCellContent(cell))</th>\n"
            }
            html += "</tr>\n"
        }
        html += "</thead>"
        result = html
    }

    mutating func visitTableBody(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes) {
        var html = "<tbody\(attributes.toHTMLAttributes())>\n"
        for row in rows {
            html += "<tr>\n"
            for cell in row {
                let alignment = renderer.renderAlignment(cell.alignment)
                let spanAttrs = renderer.renderSpanAttributes(cell)
                html += "<td\(alignment)\(spanAttrs)>\(renderer.renderCellContent(cell))</td>\n"
            }
            html += "</tr>\n"
        }
        html += "</tbody>"
        result = html
    }

    mutating func visitTableFoot(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes) {
        var html = "<tfoot\(attributes.toHTMLAttributes())>\n"
        for row in rows {
            html += "<tr>\n"
            for cell in row {
                let alignment = renderer.renderAlignment(cell.alignment)
                let spanAttrs = renderer.renderSpanAttributes(cell)
                html += "<td\(alignment)\(spanAttrs)>\(renderer.renderCellContent(cell))</td>\n"
            }
            html += "</tr>\n"
        }
        html += "</tfoot>"
        result = html
    }

    mutating func visitTableRow(cells: [TableCell], attributes: RhoeMarkdownKit.Attributes) {
        var html = "<tr\(attributes.toHTMLAttributes())>\n"
        for cell in cells {
            let alignment = renderer.renderAlignment(cell.alignment)
            let spanAttrs = renderer.renderSpanAttributes(cell)
            html += "<td\(alignment)\(spanAttrs)>\(renderer.renderCellContent(cell))</td>\n"
        }
        html += "</tr>"
        result = html
    }

    mutating func visitExecutableCodeBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes) {
        var mergedClasses = ["executable"] + attributes.classes
        if let lang = language {
            mergedClasses.insert("language-\(renderer.htmlEscape(lang))", at: 0)
        }
        let mergedAttrs = RhoeMarkdownKit.Attributes(id: attributes.id, classes: mergedClasses, keyValues: attributes.keyValues)
        result = "<pre><code\(mergedAttrs.toHTMLAttributes()) data-rhoe-node=\"ExecutableCodeBlock\">\(renderer.htmlEscape(content))</code></pre>"
    }

    mutating func visitMathBlock(expression: String, attributes: RhoeMarkdownKit.Attributes) {
        result = renderer.renderMathExpression(expression, inline: false, attributes: attributes)
    }

    mutating func visitDeck(slides: [Block], attributes: RhoeMarkdownKit.Attributes) {
        var html = "<div class=\"rhoe-deck\"\(attributes.toHTMLAttributes()) data-rhoe-node=\"Deck\">"
        for slide in slides {
            html += renderer.renderBlock(slide)
        }
        html += "</div>"
        result = html
    }

    mutating func visitSlide(title: [Inline]?, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        var html = "<section class=\"rhoe-slide\"\(attributes.toHTMLAttributes()) data-rhoe-node=\"Slide\">"
        if let title {
            html += "<h2>\(renderer.renderInlines(title))</h2>"
        }
        for child in content {
            html += renderer.renderBlock(child)
        }
        html += "</section>"
        result = html
    }

    mutating func visitSlotContent(name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        var html = "<div class=\"rhoe-slot\" data-slot=\"\(renderer.htmlEscape(name))\"\(attributes.toHTMLAttributes()) data-rhoe-node=\"SlotContent\">"
        for child in content {
            html += renderer.renderBlock(child)
        }
        html += "</div>"
        result = html
    }

    mutating func visitExtension(vendor: String, name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
        var html = "<div class=\"rhoe-extension\" data-vendor=\"\(renderer.htmlEscape(vendor))\" data-name=\"\(renderer.htmlEscape(name))\"\(attributes.toHTMLAttributes()) data-rhoe-node=\"Extension\">"
        for child in content {
            html += renderer.renderBlock(child)
        }
        html += "</div>"
        result = html
    }

    mutating func visitRawBlock(content: String, format: String, attributes: RhoeMarkdownKit.Attributes) {
        if format == "html" || format == "htm" {
            result = content
        } else {
            result = "<pre\(attributes.toHTMLAttributes()) data-rhoe-node=\"RawBlock\" data-format=\"\(renderer.htmlEscape(format))\">\(renderer.htmlEscape(content))</pre>"
        }
    }
}
