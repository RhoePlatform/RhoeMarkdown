import Foundation
import RhoeMarkdownModel

/// GitHub Flavored Markdown HTML Renderer - World-class styling engine
public struct RhoeHTMLRenderer: Sendable {

    let configuration: RhoeMarkdownKit.HTMLConfiguration
    /// Element numbers from cross-reference numbering pass, stored during render()
    var elementNumbers: [String: String] = [:]

    public init(configuration: RhoeMarkdownKit.HTMLConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - Public API

    /// Render document to HTML with world-class styling
    public mutating func render(_ document: RhoeMarkdownKit.Document) -> String {
        // Store element numbers for theorem rendering
        elementNumbers = document.metadata.resolvedReferences.elementNumbers

        // Collect LaTeX macro definitions from code blocks for math expansion
        let macros = collectLaTeXMacros(from: document.blocks)

        // Check if TOC is requested via frontmatter (toc: true)
        let tocEnabled = isTOCEnabled(document.metadata)
        let tocDepth = getTOCDepth(document.metadata)
        let tocHTML = tocEnabled ? generateTOC(from: document.blocks, maxDepth: tocDepth) : nil

        // Use string builder for better performance
        var builder = HTMLStringBuilder(estimatedSize: document.blocks.count * 200)

        if configuration.wrapInDocument {
            builder.append("<main class=\"rhoe-document\" data-rhoe-node=\"Document\" data-rhoe-version=\"\(RhoeMarkdownKit.version)\">\n")
            if configuration.includeDefaultCSS {
                builder.append("<style>\n\(RhoeDefaultCSS.stylesheet)\n</style>\n")
            }
        }

        var tocInserted = false

        // Render blocks
        for (index, block) in document.blocks.enumerated() {
            // Insert TOC before the first heading, or at [[toc]] marker
            if let toc = tocHTML, !tocInserted {
                // Check for [[toc]] marker in paragraph
                if case .paragraph(let inlines, _) = block,
                   inlines.count == 1,
                   case .wikilink(let target, _) = inlines.first,
                   target.lowercased() == "toc" {
                    builder.append(toc)
                    tocInserted = true
                    if configuration.prettyPrint && index < document.blocks.count - 1 {
                        builder.append("\n")
                    }
                    continue
                }

                // Insert before first heading or section
                if case .heading = block {
                    builder.append(toc)
                    if configuration.prettyPrint {
                        builder.append("\n")
                    }
                    tocInserted = true
                } else if case .section = block {
                    builder.append(toc)
                    if configuration.prettyPrint {
                        builder.append("\n")
                    }
                    tocInserted = true
                }
            }

            // Apply macro expansion to math blocks
            let renderedBlock = macros.isEmpty ? block : expandMacrosInBlock(block, macros: macros)
            let renderedHTML = renderBlock(renderedBlock, isLast: index == document.blocks.count - 1)
            builder.append(renderedHTML)
            if index < document.blocks.count - 1,
               shouldSeparateRenderedBlocks(renderedBlock, document.blocks[index + 1], renderedHTML: renderedHTML) {
                builder.append("\n")
            }
        }

        // Render bibliography section if citations were resolved
        let refs = document.metadata.resolvedReferences
        if !refs.citedKeys.isEmpty && !refs.bibliography.isEmpty {
            builder.append(renderBibliographySection(
                citedKeys: refs.citedKeys,
                bibliography: refs.bibliography
            ))
        }

        if configuration.wrapInDocument {
            builder.append("</main>\n")
        }

        return builder.build()
    }

    /// Render the bibliography section with all cited entries.
    private func renderBibliographySection(
        citedKeys: [String],
        bibliography: [String: BibliographyEntry]
    ) -> String {
        var html = "<section class=\"bibliography\">\n<h2>References</h2>\n<ol class=\"references\">\n"

        for key in citedKeys {
            guard let entry = bibliography[key] else { continue }
            var parts: [String] = []
            if let author = entry.author { parts.append(htmlEscape(author)) }
            if let year = entry.year { parts.append("(\(htmlEscape(year)))") }
            parts.append("<em>\(htmlEscape(entry.title))</em>")
            if let container = entry.containerTitle { parts.append(htmlEscape(container)) }
            if let publisher = entry.publisher { parts.append(htmlEscape(publisher)) }
            if let doi = entry.doi { parts.append("doi:<a href=\"https://doi.org/\(htmlEscape(doi))\">\(htmlEscape(doi))</a>") }
            if let url = entry.url { parts.append("<a href=\"\(htmlEscape(url))\">\(htmlEscape(url))</a>") }
            html += "<li id=\"ref-\(htmlEscape(key))\">\(parts.joined(separator: ". ")).</li>\n"
        }

        html += "</ol>\n</section>"
        return html
    }

    /// Get world-class CSS styles
    public static func getWorldClassCSS(darkMode: Bool = false) -> String {
        if darkMode {
            return darkModeCSS
        } else {
            return lightModeCSS
        }
    }

    // MARK: - Block Rendering

    public func renderBlock(_ block: Block, isLast: Bool = false) -> String {
        // Projection visibility: check if this block should be rendered.
        if let attrs = blockAttributes(block),
           !ProjectionVisibility.isVisible(attributes: attrs, in: .screen) {
            return ""
        }

        var visitor = HTMLBlockRenderer(renderer: self, isLast: isLast)
        block.accept(&visitor)
        return visitor.result
    }

    func shouldSeparateRenderedBlocks(_ current: Block, _ next: Block, renderedHTML: String) -> Bool {
        if configuration.prettyPrint {
            return true
        }

        guard !renderedHTML.hasSuffix("\n") else {
            return false
        }

        if isHTMLBoundaryBlock(current) {
            return true
        }
        if isHTMLBoundaryBlock(next) {
            return true
        }
        return false
    }

    func isHTMLBoundaryBlock(_ block: Block) -> Bool {
        if case .html = block {
            return true
        }
        if case .rawBlock(_, let format, _) = block {
            let normalizedFormat = format.lowercased()
            return normalizedFormat == "html" || normalizedFormat == "htm"
        }
        return false
    }

    // MARK: - Inline Rendering

    @inline(__always)
    func renderInlines(_ inlines: [Inline]) -> String {
        var builder = HTMLStringBuilder(estimatedSize: inlines.count * 50)

        for inline in inlines {
            builder.append(renderInline(inline))
        }

        return builder.build()
    }

    @inline(__always)
    func renderInline(_ inline: Inline) -> String {
        var visitor = HTMLInlineRenderer(renderer: self)
        inline.accept(&visitor)
        return visitor.result
    }

    func renderTextPreservingSimpleRawHTML(_ text: String) -> String {
        var output = ""
        var index = text.startIndex

        while index < text.endIndex {
            if text[index] == "\\" {
                let next = text.index(after: index)
                if next < text.endIndex, text[next] == "<",
                   let close = text[next...].firstIndex(of: ">") {
                    let candidate = String(text[next...close])
                    if isSimpleRawHTMLTag(candidate) {
                        output.append(htmlEscape(candidate))
                        index = text.index(after: close)
                        continue
                    }
                }
            }

            if text[index] == "\u{E000}" {
                let next = text.index(after: index)
                if next < text.endIndex {
                    output.append(htmlEscape(String(text[next])))
                    index = text.index(after: next)
                } else {
                    index = next
                }
                continue
            }

            guard text[index] == "<",
                  let close = text[index...].firstIndex(of: ">")
            else {
                output.append(htmlEscape(String(text[index])))
                index = text.index(after: index)
                continue
            }

            let candidate = String(text[index...close])
            if isSimpleRawHTMLTag(candidate) {
                output.append(candidate)
            } else if candidate.contains("\u{E000}") {
                output.append(htmlEscape(String(text[index])))
                index = text.index(after: index)
                continue
            } else {
                output.append(htmlEscape(String(text[index...close])))
            }
            index = text.index(after: close)
        }

        return output
    }

    func isSimpleRawHTMLTag(_ text: String) -> Bool {
        guard text.hasPrefix("<"), text.hasSuffix(">") else { return false }

        var inner = text.dropFirst().dropLast()
        if inner.first == "/" {
            inner = inner.dropFirst()
        }
        if inner.last == "/" {
            inner = inner.dropLast()
        }

        guard !inner.isEmpty else { return false }
        guard let first = inner.first, first.isRhoeHTMLASCIIAlpha else { return false }

        var tagName = ""
        for character in inner {
            guard character.isRhoeHTMLASCIIAlpha || character.isRhoeHTMLASCIIDigit || character == "-" else {
                return false
            }
            tagName.append(character.lowercased())
        }

        return Self.simpleRawHTMLTagNames.contains(tagName)
    }

    static let simpleRawHTMLTagNames: Set<String> = [
        "a", "abbr", "b", "br", "cite", "code", "data", "del", "dfn", "em",
        "i", "img", "ins", "kbd", "mark", "q", "rp", "rt", "ruby", "s",
        "samp", "small", "span", "strong", "sub", "sup", "time", "u", "var", "wbr"
    ]

    // MARK: - Helper Methods

    /// Theorem-family types that get special rendering
    private static let theoremFamilyTypes: Set<String> = [
        "theorem", "lemma", "definition", "proposition", "corollary",
        "example", "claim", "assumption", "conjecture", "proof", "remark"
    ]

    func renderAdmonition(type: String, title: String?, content: [Block], collapsible: AdmonitionCollapsible?, attributes: RhoeMarkdownKit.Attributes) -> String {
        // Theorem-family types get distinct rendering.
        let canonicalType = type.lowercased()
        if Self.theoremFamilyTypes.contains(canonicalType) {
            return renderTheoremAdmonition(type: canonicalType, title: title, content: content, attributes: attributes)
        }

        let icon = getAdmonitionIcon(for: type)
        let displayTitle = title ?? type.capitalized

        if let collapsible = collapsible {
            // Collapsible admonition using <details>
            var classes = attributes.classes
            classes.insert("admonition", at: 0)
            classes.insert("admonition-\(type.lowercased())", at: 1)

            var keyValues = attributes.keyValues
            if collapsible == .expanded {
                keyValues["open"] = ""
            }

            let mergedAttrs = RhoeMarkdownKit.Attributes(id: attributes.id, classes: classes, keyValues: keyValues)
            var html = "<details\(withRhoeNode(mergedAttrs, "admonition").toHTMLAttributes())>\n"
            html += "<summary class=\"admonition-title\">\n"
            html += "<span class=\"admonition-icon\">\(icon)</span>\n"
            html += displayTitle
            html += "</summary>\n"
            html += "<div class=\"admonition-content\">\n"

            for block in content {
                html += renderBlock(block)
            }

            html += "</div>\n"
            html += "</details>"
            return html
        } else {
            // Regular admonition using <div>
            var classes = attributes.classes
            classes.insert("admonition", at: 0)
            classes.insert("admonition-\(type.lowercased())", at: 1)

            let mergedAttrs = RhoeMarkdownKit.Attributes(id: attributes.id, classes: classes, keyValues: attributes.keyValues)
            var html = "<div\(withRhoeNode(mergedAttrs, "admonition").toHTMLAttributes())>\n"
            html += "<p class=\"admonition-title\">\n"
            html += "<span class=\"admonition-icon\">\(icon)</span>\n"
            html += displayTitle
            html += "</p>\n"
            html += "<div class=\"admonition-content\">\n"

            for block in content {
                html += renderBlock(block)
            }

            html += "</div>\n"
            html += "</div>"
            return html
        }
    }

    /// Render a theorem-family block with academic-style formatting.
    private func renderTheoremAdmonition(type: String, title: String?, content: [Block], attributes: RhoeMarkdownKit.Attributes) -> String {
        let familyLabel = type.capitalized
        var numberStr = ""
        if let id = attributes.id, let num = elementNumbers[id] {
            numberStr = " \(num)"
        }
        let titleStr = title.map { " (\($0))" } ?? ""

        var classes = attributes.classes
        classes.insert("theorem-env", at: 0)
        classes.insert("theorem-\(type)", at: 1)
        let mergedAttrs = RhoeMarkdownKit.Attributes(id: attributes.id, classes: classes, keyValues: attributes.keyValues)

        let isProof = type == "proof"
        let headerStyle = isProof ? "font-style: italic" : "font-weight: bold"

        var html = "<div\(mergedAttrs.toHTMLAttributes())>\n"
        html += "<p class=\"theorem-header\" style=\"\(headerStyle)\">"
        html += "\(familyLabel)\(numberStr).\(titleStr)"
        html += "</p>\n"
        html += "<div class=\"theorem-body\">\n"
        for block in content {
            html += renderBlock(block)
        }
        html += "</div>\n"
        if isProof {
            html += "<p class=\"qed\">&#x25A1;</p>\n"
        }
        html += "</div>"
        return html
    }

    /// Extract attributes from a block for projection visibility checking.
    private func blockAttributes(_ block: Block) -> RhoeMarkdownKit.Attributes? {
        switch block {
        case .paragraph(_, let a): return a
        case .heading(_, _, let a): return a
        case .blockQuote(_, let a): return a
        case .list(_, _, let a): return a
        case .codeBlock(_, _, let a): return a
        case .table(_, _, _, let a): return a
        case .definitionList(_, let a): return a
        case .admonition(_, _, _, _, let a): return a
        case .div(_, let a): return a
        case .visualBlock(_, _, let a): return a
        case .authorAnnotation(_, _, let a): return a
        case .transclusion(_, _, _, let a): return a
        case .schemaIsland(_, _, let a): return a
        case .componentDeclaration(_, _, _, _, _, let a): return a
        case .phase2Directive(_, _, _, let a): return a
        case .placeholder(_, let a): return a
        case .expression(_, let a): return a
        case .field(_, _, let a): return a
        case .form(_, _, let a): return a
        case .widget(_, _, let a): return a
        case .tab(_, _, let a): return a
        case .stage(_, _, let a): return a
        case .lane(_, let a): return a
        case .module(_, _, _, let a): return a
        case .contractDirective(_, _, let a): return a
        case .horizontalRule, .html, .lineBlock, .footnoteDefinition, .abbreviationDefinition:
            return nil
            // Canonical node kinds.
        case .section(_, _, _, let a): return a
        case .formalBlock(_, _, _, _, let a): return a
        case .speakerNotes(_, let a): return a
        case .grid(_, let a): return a
        case .columns(_, let a): return a
        case .figure(_, _, let a): return a
        case .diagramBlock(_, _, let a): return a
        case .shape(_, let a): return a
        case .tableHead(_, let a): return a
        case .tableBody(_, let a): return a
        case .tableFoot(_, let a): return a
        case .tableRow(_, let a): return a
        case .executableCodeBlock(_, _, let a): return a
        case .mathBlock(_, let a): return a
        case .deck(_, let a): return a
        case .slide(_, _, let a): return a
        case .slotContent(_, _, let a): return a
        case .extension_(_, _, _, let a): return a
        case .rawBlock(_, _, let a): return a
        }
    }

    private func getAdmonitionIcon(for type: String) -> String {
        switch type.lowercased() {
        case "note", "info":
            return "\u{2139}\u{FE0F}"
        case "tip", "hint":
            return "\u{1F4A1}"
        case "success", "check":
            return "\u{2705}"
        case "warning", "caution":
            return "\u{26A0}\u{FE0F}"
        case "danger", "error":
            return "\u{1F6A8}"
        case "important":
            return "\u{2757}"
        case "question", "help", "faq":
            return "\u{2753}"
        case "quote", "cite":
            return "\u{1F4AC}"
        case "example":
            return "\u{1F4CB}"
        case "abstract", "summary", "tldr":
            return "\u{1F4C4}"
        case "bug":
            return "\u{1F41B}"
        case "failure", "fail", "missing":
            return "\u{274C}"
        default:
            return "\u{1F4DD}"
        }
    }

    @inline(__always)
    func htmlEscape(_ text: String) -> String {
        text.htmlEscaped()
    }

    func mathEscape(_ text: String) -> String {
        // For math expressions, we only escape HTML entities but preserve backslashes
        return text.htmlEscaped()
    }

    /// Detect if a paragraph contains exactly one image with non-empty alt text,
    /// and render it as a `<figure>` with `<figcaption>`.
    func renderImplicitFigure(inlines: [Inline], attributes: RhoeMarkdownKit.Attributes) -> String? {
        // Must contain exactly one image and no other non-trivial inlines
        var imageInline: (alt: [Inline], url: String, title: String?, attrs: RhoeMarkdownKit.Attributes)?

        for inline in inlines {
            switch inline {
            case .image(let alt, let url, let title, let attrs):
                // Only one image allowed
                guard imageInline == nil else { return nil }
                // Alt text must be non-empty
                let altText = alt.map { extractText(from: $0) }.joined()
                guard !altText.isEmpty else { return nil }
                imageInline = (alt, url, title, attrs)
            case .text(let text):
                // Allow whitespace-only text around the image
                guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            case .softBreak, .hardBreak:
                continue
            default:
                // Any other inline type -> not a lone image paragraph
                return nil
            }
        }

        guard let img = imageInline else { return nil }

        let imgHTML = renderInline(.image(alt: img.alt, url: img.url, title: img.title, attributes: img.attrs))
        let captionText = renderInlines(img.alt)

        var figureAttrs = attributes
        if figureAttrs.classes.isEmpty {
            figureAttrs = RhoeMarkdownKit.Attributes(
                id: attributes.id,
                classes: ["figure"],
                keyValues: attributes.keyValues
            )
        }

        return "<figure\(figureAttrs.toHTMLAttributes())>\(imgHTML)<figcaption>\(captionText)</figcaption></figure>"
    }

    func renderCitation(items: [CitationItem], mode: CitationMode) -> String {
        var parts: [String] = []
        for item in items {
            var text = ""
            if item.suppressAuthor {
                text += "-"
            }
            text += "@\(htmlEscape(item.key))"
            if let locator = item.locator {
                text += ", \(htmlEscape(locator))"
            }
            parts.append(text)
        }
        let content = parts.joined(separator: "; ")
        let modeClass = switch mode {
        case .parenthetical: "citation-parenthetical"
        case .inText: "citation-intext"
        case .suppressAuthor: "citation-suppress-author"
        }
        return "<span class=\"citation \(modeClass)\">[\(content)]</span>"
    }

    // MARK: - Theorem Environments (5.6)

    /// Recognized theorem-like environment class names.
    private static let theoremEnvironments: [String: String] = [
        "theorem": "Theorem",
        "lemma": "Lemma",
        "proof": "Proof",
        "definition": "Definition",
        "proposition": "Proposition",
        "corollary": "Corollary",
        "example": "Example",
        "remark": "Remark"
    ]

    /// Render a div as a theorem environment if it has a recognized class.
    func renderTheoremEnvironment(
        content: [Block],
        attributes: RhoeMarkdownKit.Attributes
    ) -> String? {
        for cls in attributes.classes {
            guard let envName = Self.theoremEnvironments[cls] else { continue }

            let isProof = cls == "proof"
            var html = "<div class=\"\(cls)\"\(attributes.idAttribute())>"

            if isProof {
                html += "<em>\(envName).</em> "
            } else {
                html += "<strong>\(envName).</strong> "
            }

            for (index, block) in content.enumerated() {
                html += renderBlock(block, isLast: index == content.count - 1)
            }

            if isProof {
                html += " <span class=\"qed\">\u{25A1}</span>"
            }

            html += "</div>"
            return html
        }
        return nil
    }

    // MARK: - Content Visibility (5.7)

    /// Check if a div's visibility attributes hide it for HTML output.
    ///
    /// Returns `true` if visible, `false` if hidden, `nil` if no visibility attributes.
    func checkContentVisibility(
        attributes: RhoeMarkdownKit.Attributes
    ) -> Bool? {
        let hasVisible = attributes.classes.contains("content-visible")
        let hasHidden = attributes.classes.contains("content-hidden")

        guard hasVisible || hasHidden else { return nil }

        let whenFormat = attributes.keyValues["when-format"] ?? attributes.keyValues["when-profile"]

        if hasVisible {
            // content-visible: only show when format matches
            if let format = whenFormat {
                return format.lowercased().contains("html")
            }
            return true // No format restriction -> always visible
        }

        if hasHidden {
            // content-hidden: hide when format matches
            if let format = whenFormat {
                return !format.lowercased().contains("html")
            }
            return false // No format restriction -> always hidden
        }

        return nil
    }

    // MARK: - Automatic Table of Contents (5.9)

    /// Check if TOC is enabled via YAML frontmatter `toc: true`.
    private func isTOCEnabled(_ metadata: RhoeMarkdownKit.DocumentMetadata) -> Bool {
        guard let frontmatter = metadata.yamlFrontmatter,
              let tocValue = frontmatter["toc"] else { return false }
        if case .bool(true) = tocValue { return true }
        if case .string(let s) = tocValue, s.lowercased() == "true" { return true }
        return false
    }

    /// Get TOC depth from frontmatter `toc-depth: N` (default: 3).
    private func getTOCDepth(_ metadata: RhoeMarkdownKit.DocumentMetadata) -> Int {
        guard let frontmatter = metadata.yamlFrontmatter else { return 3 }
        if let depthVal = frontmatter["toc-depth"] {
            if case .int(let n) = depthVal { return max(1, min(n, 6)) }
            if case .string(let s) = depthVal, let n = Int(s) { return max(1, min(n, 6)) }
        }
        return 3
    }

    /// Generate a `<nav class="toc">` with nested lists from document headings.
    private func generateTOC(from blocks: [Block], maxDepth: Int) -> String {
        // Collect headings
        var entries: [(level: Int, text: String, id: String)] = []
        collectHeadings(from: blocks, into: &entries, maxDepth: maxDepth)
        guard !entries.isEmpty else { return "" }

        var html = "<nav class=\"toc\">\n"

        // Build nested list structure
        var currentLevel = 0
        for entry in entries {
            while currentLevel < entry.level {
                html += "<ul>\n"
                currentLevel += 1
            }
            while currentLevel > entry.level {
                html += "</ul>\n"
                currentLevel -= 1
            }
            html += "<li><a href=\"#\(htmlEscape(entry.id))\">\(htmlEscape(entry.text))</a></li>\n"
        }

        // Close remaining open lists
        while currentLevel > 0 {
            html += "</ul>\n"
            currentLevel -= 1
        }

        html += "</nav>"
        return html
    }

    /// Recursively collect headings from blocks.
    private func collectHeadings(from blocks: [Block], into entries: inout [(level: Int, text: String, id: String)], maxDepth: Int) {
        for block in blocks {
            switch block {
            case .heading(let level, let content, let attributes) where level <= maxDepth:
                // Skip projection-hidden headings from the table of contents.
                if !ProjectionVisibility.isVisible(attributes: attributes, in: .screen) {
                    continue
                }
                let text = content.map { extractText(from: $0) }.joined()
                let id = attributes.id ?? generateHeadingId(from: content)
                entries.append((level: level, text: text, id: id))
            case .section(let level, let title, let children, let attributes) where level <= maxDepth:
                if !ProjectionVisibility.isVisible(attributes: attributes, in: .screen) {
                    continue
                }
                let text = title.map { extractText(from: $0) }.joined()
                let id = attributes.id ?? generateHeadingId(from: title)
                entries.append((level: level, text: text, id: id))
                // Recurse into section children
                collectHeadings(from: children, into: &entries, maxDepth: maxDepth)
            case .blockQuote(let nested, _), .div(let nested, _):
                collectHeadings(from: nested, into: &entries, maxDepth: maxDepth)
            case .list(_, let items, _):
                for item in items {
                    collectHeadings(from: item.content, into: &entries, maxDepth: maxDepth)
                }
            default:
                break
            }
        }
    }

    // MARK: - LaTeX Macro Expansion (5.8)

    /// Collect `\newcommand` definitions from code blocks in the document.
    ///
    /// Macro definitions are typically placed in a `latex-macros` or `math` code block:
    /// ````
    /// ```{=latex}
    /// \newcommand{\R}{\mathbb{R}}
    /// \newcommand{\vect}[1]{\boldsymbol{#1}}
    /// ```
    /// ````
    private func collectLaTeXMacros(from blocks: [Block]) -> [Math.MacroDefinition] {
        var macros: [Math.MacroDefinition] = []

        for block in blocks {
            switch block {
            case .codeBlock(let language, let content, _):
                // Check for latex-macros, latex, or math code blocks
                let lang = language?.lowercased() ?? ""
                if lang == "latex-macros" || lang == "latex" || lang == "{=latex}" {
                    macros.append(contentsOf: Math.parseMacroDefinitions(from: content))
                }
            case .section(_, _, let children, _):
                macros.append(contentsOf: collectLaTeXMacros(from: children))
            default:
                break
            }
        }

        return macros
    }

    /// Apply LaTeX macro expansion to math inlines in a block.
    private func expandMacrosInBlock(_ block: Block, macros: [Math.MacroDefinition]) -> Block {
        switch block {
        case .paragraph(let inlines, let attrs):
            return .paragraph(expandMacrosInInlines(inlines, macros: macros), attributes: attrs)
        case .heading(let level, let content, let attrs):
            return .heading(level: level, content: expandMacrosInInlines(content, macros: macros), attributes: attrs)
        case .section(let level, let title, let children, let attrs):
            return .section(level: level, title: expandMacrosInInlines(title, macros: macros),
                            children: children.map { expandMacrosInBlock($0, macros: macros) }, attributes: attrs)
        case .blockQuote(let blocks, let attrs):
            return .blockQuote(blocks.map { expandMacrosInBlock($0, macros: macros) }, attributes: attrs)
        case .list(let type, let items, let attrs):
            let expandedItems = items.map { item in
                ListItem(
                    content: item.content.map { expandMacrosInBlock($0, macros: macros) },
                    checked: item.checked,
                    isLoose: item.isLoose
                )
            }
            return .list(type: type, items: expandedItems, attributes: attrs)
        case .div(let content, let attrs):
            return .div(content: content.map { expandMacrosInBlock($0, macros: macros) }, attributes: attrs)
        default:
            return block
        }
    }

    private func expandMacrosInInlines(_ inlines: [Inline], macros: [Math.MacroDefinition]) -> [Inline] {
        inlines.map { inline -> Inline in
            switch inline {
            case .inlineMath(let expr, let attrs):
                return .inlineMath(expression: Math.expandMacros(expr, macros: macros), attributes: attrs)
            case .mathDisplay(let expr, let attrs):
                return .mathDisplay(expression: Math.expandMacros(expr, macros: macros), attributes: attrs)
            case .emphasis(let content):
                return .emphasis(expandMacrosInInlines(content, macros: macros))
            case .strong(let content):
                return .strong(expandMacrosInInlines(content, macros: macros))
            case .strikethrough(let content):
                return .strikethrough(expandMacrosInInlines(content, macros: macros))
            default:
                return inline
            }
        }
    }

    func renderMathExpression(_ expression: String, inline: Bool, attributes: RhoeMarkdownKit.Attributes) -> String {
        switch configuration.mathRenderingMode {
        case .mathjax:
            // MathJax/KaTeX compatible format
            var classes = attributes.classes
            classes.insert("math", at: 0)
            classes.insert(inline ? "math-inline" : "math-display", at: 1)

            let mergedAttrs = RhoeMarkdownKit.Attributes(id: attributes.id, classes: classes, keyValues: attributes.keyValues)
            let content = inline ? "\\(\(mathEscape(expression))\\)" : "\\[\(mathEscape(expression))\\]"
            return "<span\(mergedAttrs.toHTMLAttributes())>\(content)</span>"

        case .mathml:
            // Native MathML for modern browsers
            // MathML writer owns its output element in 0.1.0; attributes stay on MathJax/KaTeX spans.
            return Math.latexToMathML(expression, inline: inline)
        }
    }

    /// Inject `data-rhoe-node` attribute into an attribute set for HTML rendering.
    func withRhoeNode(_ attrs: RhoeMarkdownKit.Attributes, _ nodeType: String) -> RhoeMarkdownKit.Attributes {
        var kv = attrs.keyValues
        kv["data-rhoe-node"] = nodeType
        return RhoeMarkdownKit.Attributes(id: attrs.id, classes: attrs.classes, keyValues: kv)
    }

    func generateHeadingId(from inlines: [Inline]) -> String {
        var text = ""
        for inline in inlines {
            text += extractText(from: inline)
        }

        // Convert to lowercase and replace spaces/special chars with hyphens
        let id = text
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s-]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return id.isEmpty ? "heading" : id
    }

    func extractText(from inline: Inline) -> String {
        switch inline {
        case .text(let text):
            return text.replacingOccurrences(of: "\u{E000}", with: "")
        case .emphasis(let content), .strong(let content), .strikethrough(let content):
            return content.map { extractText(from: $0) }.joined()
        case .codeSpan(let code, _):
            return code
        case .link(let text, _, _, _):
            return text.map { extractText(from: $0) }.joined()
        case .image(let alt, _, _, _):
            return alt.map { extractText(from: $0) }.joined()
        case .footnoteRef(let id):
            return "[^\(id)]"
        case .inlineMath(let expression, _):
            return "$\(expression)$"
        case .mathDisplay(let expression, _):
            return "$$\(expression)$$"
        case .html:
            return ""
        case .hardBreak, .softBreak:
            return " "
        case .superscript(let content), .`subscript`(let content), .highlight(let content):
            return content.map { extractText(from: $0) }.joined()
        case .span(let content, _):
            return content.map { extractText(from: $0) }.joined()
        case .inlineFootnote(let content):
            return content.map { extractText(from: $0) }.joined()
        case .citation(let items, _):
            return items.map { "@\($0.key)" }.joined(separator: "; ")
        case .crossReference(let prefix, let id):
            return "\(prefix.rawValue)-\(id)"
        case .rawInline(let content, _):
            return content
        case .wikilink(let target, let display):
            return display.map { $0.map { extractText(from: $0) }.joined() } ?? target
        case .resolvedCitation(let text, _, _):
            return text
        case .resolvedCrossReference(let text, _):
            return text

        case .transclusionInline:
            return ""
        case .annotationInline:
            return ""
        case .paramRef(let name):
            return "<<param \(name)>>"
        case .slotRef(let name):
            return "<<slot \(name ?? "default")>>"
        case .placeholderInline(let fields):
            if let name = fields["name"] { return "[\(name)]" }
            return "[\(fields.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))]"
        case .expressionInline(let expr):
            return expr
        case .inputFieldInline(let name, _, _):
            return name
        case .emoji(let name, let unicode):
            return unicode ?? ":\(name):"
        }
    }

    func renderAlignment(_ alignment: TableAlignment) -> String {
        switch alignment {
        case .none:
            return ""
        case .left:
            return " style=\"text-align: left;\""
        case .center:
            return " style=\"text-align: center;\""
        case .right:
            return " style=\"text-align: right;\""
        }
    }

    /// Render colspan/rowspan attributes for grid table cells.
    func renderSpanAttributes(_ cell: TableCell) -> String {
        var attrs = ""
        if cell.colSpan > 1 {
            attrs += " colspan=\"\(cell.colSpan)\""
        }
        if cell.rowSpan > 1 {
            attrs += " rowspan=\"\(cell.rowSpan)\""
        }
        return attrs
    }

    /// Render cell content -- uses block content for grid tables, inline content otherwise.
    func renderCellContent(_ cell: TableCell) -> String {
        if let blockContent = cell.blockContent {
            return blockContent.map { renderBlock($0, isLast: false) }.joined()
        }
        return renderInlines(cell.content)
    }

    func highlightCode(_ code: String, language: String) -> String {
        // For now, just escape the code
        // In a real implementation, you'd use a syntax highlighter
        return htmlEscape(code)
    }
}

private extension Character {
    var isRhoeHTMLASCIIAlpha: Bool {
        guard let scalar = unicodeScalars.first, unicodeScalars.count == 1 else {
            return false
        }
        return (65...90).contains(Int(scalar.value)) || (97...122).contains(Int(scalar.value))
    }

    var isRhoeHTMLASCIIDigit: Bool {
        guard let scalar = unicodeScalars.first, unicodeScalars.count == 1 else {
            return false
        }
        return (48...57).contains(Int(scalar.value))
    }
}
