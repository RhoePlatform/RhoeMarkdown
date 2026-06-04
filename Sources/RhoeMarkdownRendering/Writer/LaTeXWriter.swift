import Foundation
import RhoeMarkdownModel

/// Converts a parsed RhoeMarkdown document to LaTeX output.
///
/// Produces publication-ready LaTeX with configurable document class,
/// packages, and preamble generation. Math expressions pass through
/// directly (they're already LaTeX). Footnotes are inlined at reference
/// sites using `\footnote{...}`.
public struct LaTeXWriter: DocumentWriter, Sendable {
    public typealias Output = String

    private let configuration: RhoeMarkdownKit.LaTeXConfiguration

    public init(configuration: RhoeMarkdownKit.LaTeXConfiguration = .default) {
        self.configuration = configuration
    }

    public func write(_ document: RhoeMarkdownKit.Document) -> String {
        // Collect footnote definitions for inline rendering
        let footnotes = collectFootnotes(from: document.blocks)

        // Collect LaTeX macros for preamble
        let macros = collectMacros(from: document.blocks)

        // Detect which packages are needed
        let neededPackages = detectRequiredPackages(from: document.blocks)

        var output = ""

        if configuration.generatePreamble {
            output += renderPreamble(
                document: document,
                macros: macros,
                neededPackages: neededPackages
            )
        }

        // Render blocks
        for block in document.blocks {
            output += renderBlock(block, footnotes: footnotes)
        }

        if configuration.generatePreamble {
            output += "\n\\end{document}\n"
        }

        return output
    }

    // MARK: - Preamble

    private func renderPreamble(
        document: RhoeMarkdownKit.Document,
        macros: [String],
        neededPackages: Set<String>
    ) -> String {
        var preamble = ""

        // Document class
        let options = configuration.classOptions.isEmpty
            ? ""
            : "[\(configuration.classOptions.joined(separator: ","))]"
        preamble += "\\documentclass\(options){\(configuration.documentClass)}\n"

        // Core packages
        let corePackages = ["inputenc", "fontenc", "amsmath", "amssymb", "graphicx", "hyperref"]
        for pkg in corePackages {
            preamble += "\\usepackage{\(pkg)}\n"
        }

        // Conditional packages
        for pkg in neededPackages.sorted() {
            if !corePackages.contains(pkg) {
                preamble += "\\usepackage{\(pkg)}\n"
            }
        }

        // User-specified packages
        for pkg in configuration.packages {
            if !corePackages.contains(pkg) && !neededPackages.contains(pkg) {
                preamble += "\\usepackage{\(pkg)}\n"
            }
        }

        // Theorem declarations (if amsthm is loaded)
        if neededPackages.contains("amsthm") {
            preamble += "\\newtheorem{theorem}{Theorem}\n"
            preamble += "\\newtheorem{lemma}{Lemma}\n"
            preamble += "\\newtheorem{definition}{Definition}\n"
            preamble += "\\newtheorem{proposition}{Proposition}\n"
            preamble += "\\newtheorem{corollary}{Corollary}\n"
            preamble += "\\newtheorem{example}{Example}\n"
            preamble += "\\newtheorem{remark}{Remark}\n"
        }

        // LaTeX macros from document
        if !macros.isEmpty {
            preamble += "\n% Document macros\n"
            for macro in macros {
                preamble += "\(macro)\n"
            }
        }

        // Title, author, date from frontmatter
        let fm = document.metadata.yamlFrontmatter
        if let title = stringFromYAML(fm?["title"]) {
            preamble += "\\title{\(latexEscape(title))}\n"
        }
        if let author = stringFromYAML(fm?["author"]) {
            preamble += "\\author{\(latexEscape(author))}\n"
        }
        if let date = stringFromYAML(fm?["date"]) {
            preamble += "\\date{\(latexEscape(date))}\n"
        }

        // AST-near environment declarations
        if configuration.astNearEmission {
            preamble += "\n% RhoeMarkdown AST-near environment definitions\n"
            preamble += "\\usepackage{xparse}\n"
            preamble += "\\ExplSyntaxOn\n"
            preamble += "\\keys_define:nn { rhoe } {\n"
            preamble += "  level .tl_set:N = \\l_rhoe_level_tl,\n"
            preamble += "  title .tl_set:N = \\l_rhoe_title_tl,\n"
            preamble += "  kind .tl_set:N = \\l_rhoe_kind_tl,\n"
            preamble += "  language .tl_set:N = \\l_rhoe_language_tl,\n"
            preamble += "  id .tl_set:N = \\l_rhoe_id_tl,\n"
            preamble += "  ordered .bool_set:N = \\l_rhoe_ordered_bool,\n"
            preamble += "  name .tl_set:N = \\l_rhoe_name_tl,\n"
            preamble += "}\n"
            preamble += "\\ExplSyntaxOff\n"
            preamble += "\\NewDocumentEnvironment{RhoeSection}{O{}}{}{}\n"
            preamble += "\\NewDocumentEnvironment{RhoeBlockQuote}{}{\\begin{quote}}{\\end{quote}}\n"
            preamble += "\\NewDocumentEnvironment{RhoeAdmonition}{O{}}{\\begin{tcolorbox}[#1]}{\\end{tcolorbox}}\n"
            preamble += "\\NewDocumentEnvironment{RhoeTheorem}{O{}}{\\begin{theorem}}{\\end{theorem}}\n"
            preamble += "\\NewDocumentEnvironment{RhoeLemma}{O{}}{\\begin{lemma}}{\\end{lemma}}\n"
            preamble += "\\NewDocumentEnvironment{RhoeDefinition}{O{}}{\\begin{definition}}{\\end{definition}}\n"
            preamble += "\\NewDocumentEnvironment{RhoeCorollary}{O{}}{\\begin{corollary}}{\\end{corollary}}\n"
            preamble += "\\NewDocumentEnvironment{RhoeProposition}{O{}}{\\begin{proposition}}{\\end{proposition}}\n"
            preamble += "\\NewDocumentEnvironment{RhoeExample}{O{}}{\\begin{example}}{\\end{example}}\n"
            preamble += "\\NewDocumentEnvironment{RhoeRemark}{O{}}{\\begin{remark}}{\\end{remark}}\n"
            preamble += "\\NewDocumentEnvironment{RhoeProof}{O{}}{\\begin{proof}}{\\end{proof}}\n"
            preamble += "\\NewDocumentEnvironment{RhoeList}{O{}}{}{}\n"
            preamble += "\\NewDocumentCommand{\\RhoeListItem}{O{}m}{\\item #2}\n"
            preamble += "\\NewDocumentEnvironment{RhoeTable}{O{}}{}{}\n"
            preamble += "\\NewDocumentEnvironment{RhoeFigure}{O{}}{\\begin{figure}[htbp]}{\\end{figure}}\n"
            preamble += "\\NewDocumentCommand{\\RhoeImage}{O{}m}{\\includegraphics[#1]{#2}}\n"
            preamble += "\\NewDocumentCommand{\\RhoeCaption}{m}{\\caption{#1}}\n"
            preamble += "\\NewDocumentEnvironment{RhoeCode}{O{}}{\\begin{lstlisting}[#1]}{\\end{lstlisting}}\n"
            preamble += "\\NewDocumentEnvironment{RhoeVisualBlock}{O{}}{}{}\n"
            preamble += "\\NewDocumentEnvironment{RhoeDiv}{}{}{}\n"
            preamble += "\\NewDocumentEnvironment{RhoeLineBlock}{}{\\begin{verse}}{\\end{verse}}\n"
        }

        preamble += "\n\\begin{document}\n"

        // Emit \maketitle if title was present
        if fm?["title"] != nil {
            preamble += "\\maketitle\n"
        }

        preamble += "\n"
        return preamble
    }

    // MARK: - Block Rendering

    private func renderBlock(
        _ block: Block,
        footnotes: [String: [Block]]
    ) -> String {
        // Projection visibility: skip blocks hidden from print.
        if let attrs = blockAttributes(block),
           !ProjectionVisibility.isVisible(attributes: attrs, in: .print) {
            return ""
        }

        var visitor = LaTeXBlockRenderer(writer: self, footnotes: footnotes)
        block.accept(&visitor)
        return visitor.result
    }

    // MARK: - Inline Rendering

    private func renderInlines(
        _ inlines: [Inline],
        footnotes: [String: [Block]]
    ) -> String {
        inlines.map { renderInline($0, footnotes: footnotes) }.joined()
    }

    private func renderInline(
        _ inline: Inline,
        footnotes: [String: [Block]]
    ) -> String {
        var visitor = LaTeXInlineRenderer(writer: self, footnotes: footnotes)
        inline.accept(&visitor)
        return visitor.result
    }

    // MARK: - Helpers

    private func headingCommand(for level: Int) -> String {
        switch level {
        case 1: return "section"
        case 2: return "subsection"
        case 3: return "subsubsection"
        case 4: return "paragraph"
        case 5: return "subparagraph"
        default: return "subparagraph"
        }
    }

    private func renderList(
        type: ListType,
        items: [ListItem],
        footnotes: [String: [Block]]
    ) -> String {
        let env: String
        switch type {
        case .unordered:
            env = "itemize"
        case .ordered:
            env = "enumerate"
        case .task:
            env = "itemize"
        }

        var result = "\\begin{\(env)}\n"
        for item in items {
            let content = item.content.map { renderBlock($0, footnotes: footnotes) }.joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if case .task = type {
                let checkbox = item.checked == true ? "$\\boxtimes$" : "$\\square$"
                result += "\\item[\(checkbox)] \(content)\n"
            } else {
                result += "\\item \(content)\n"
            }
        }
        result += "\\end{\(env)}\n\n"
        return result
    }

    private func renderCodeBlock(language: String?, content: String) -> String {
        switch configuration.codeListingPackage {
        case .listings:
            let langOpt = language.map { "[language=\($0)]" } ?? ""
            return "\\begin{lstlisting}\(langOpt)\n\(content)\n\\end{lstlisting}\n\n"
        case .minted:
            let lang = language ?? "text"
            return "\\begin{minted}{\(lang)}\n\(content)\n\\end{minted}\n\n"
        }
    }

    private func renderTable(
        headers: [TableCell],
        rows: [[TableCell]],
        caption: [Inline]?,
        attrs: RhoeMarkdownKit.Attributes,
        footnotes: [String: [Block]]
    ) -> String {
        let colCount = headers.count
        let colSpec = String(repeating: "l", count: colCount)

        var result = ""
        let hasCaption = caption != nil || attrs.id != nil

        if hasCaption {
            result += "\\begin{table}[htbp]\n\\centering\n"
        }

        result += "\\begin{tabular}{\(colSpec)}\n\\hline\n"

        // Header row
        let headerCells = headers.map { renderInlines($0.content, footnotes: footnotes) }
        result += headerCells.joined(separator: " & ") + " \\\\\n\\hline\n"

        // Data rows
        for row in rows {
            let cells = row.map { renderInlines($0.content, footnotes: footnotes) }
            result += cells.joined(separator: " & ") + " \\\\\n"
        }

        result += "\\hline\n\\end{tabular}\n"

        if hasCaption {
            if let cap = caption {
                result += "\\caption{\(renderInlines(cap, footnotes: footnotes))}\n"
            }
            if let id = attrs.id {
                result += "\\label{\(id)}\n"
            }
            result += "\\end{table}\n"
        }

        result += "\n"
        return result
    }

    private func renderDiv(
        content: [Block],
        attrs: RhoeMarkdownKit.Attributes,
        footnotes: [String: [Block]]
    ) -> String {
        // Check for theorem environments
        let theoremEnvs = ["theorem", "lemma", "proof", "definition",
                           "proposition", "corollary", "example", "remark"]

        for cls in attrs.classes {
            if theoremEnvs.contains(cls) {
                let inner = content.map { renderBlock($0, footnotes: footnotes) }.joined()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let label = attrs.id.map { "\n\\label{\($0)}" } ?? ""
                if configuration.astNearEmission {
                    let rhoeEnv = "Rhoe\(cls.prefix(1).uppercased())\(cls.dropFirst())"
                    return "\\begin{\(rhoeEnv)}\(label)\n\(inner)\n\\end{\(rhoeEnv)}\n\n"
                }
                return "\\begin{\(cls)}\(label)\n\(inner)\n\\end{\(cls)}\n\n"
            }
        }

        // Check for content visibility
        if attrs.classes.contains("content-visible") {
            if let format = attrs.keyValues["when-format"], !format.contains("latex") {
                return "" // Not for LaTeX
            }
        }
        if attrs.classes.contains("content-hidden") {
            if let format = attrs.keyValues["when-format"], format.contains("latex") {
                return "" // Hidden from LaTeX
            }
        }

        // Generic div
        let inner = content.map { renderBlock($0, footnotes: footnotes) }.joined()
        if configuration.astNearEmission {
            return "\\begin{RhoeDiv}\n\(inner)\\end{RhoeDiv}\n\n"
        }
        return inner
    }

    private func renderCitation(items: [CitationItem], mode: CitationMode) -> String {
        let keys = items.map(\.key).joined(separator: ",")
        switch mode {
        case .parenthetical:
            return "\\cite{\(keys)}"
        case .inText:
            return "\\textcite{\(keys)}"
        case .suppressAuthor:
            return "\\citeyear{\(keys)}"
        }
    }

    private func renderResolvedCitation(keys: [String], mode: CitationMode) -> String {
        let keyStr = keys.joined(separator: ",")
        switch mode {
        case .parenthetical:
            return "\\cite{\(keyStr)}"
        case .inText:
            return "\\textcite{\(keyStr)}"
        case .suppressAuthor:
            return "\\citeyear{\(keyStr)}"
        }
    }

    private func displayName(for prefix: CrossRefPrefix) -> String {
        switch prefix {
        case .fig: return "Figure"
        case .tbl: return "Table"
        case .eq: return "Equation"
        case .sec: return "Section"
        case .lst: return "Listing"
        case .note: return "Note"
        case .thm: return "Theorem"
        case .lem: return "Lemma"
        case .def: return "Definition"
        case .prop: return "Proposition"
        case .cor: return "Corollary"
        case .ex: return "Example"
        case .rmk: return "Remark"
        case .alg: return "Algorithm"
        case .sld: return "Slide"
        case .clm: return "Claim"
        case .assum: return "Assumption"
        case .conj: return "Conjecture"
        case .prf: return "Proof"
        }
    }

    private func prefixDisplayName(_ prefix: String) -> String {
        switch prefix {
        case "fig": return "Figure"
        case "tbl": return "Table"
        case "eq": return "Equation"
        case "sec": return "Section"
        case "lst": return "Listing"
        case "thm": return "Theorem"
        case "lem": return "Lemma"
        case "def": return "Definition"
        case "prp": return "Proposition"
        case "cor": return "Corollary"
        case "exm": return "Example"
        default: return prefix.capitalized
        }
    }

    // MARK: - LaTeX Escaping

    private func blockAttributes(_ block: Block) -> RhoeMarkdownKit.Attributes? {
        switch block {
        case .paragraph(_, let a), .heading(_, _, let a), .blockQuote(_, let a),
             .list(_, _, let a), .codeBlock(_, _, let a), .table(_, _, _, let a),
             .definitionList(_, let a), .admonition(_, _, _, _, let a),
             .div(_, let a), .visualBlock(_, _, let a),
             .authorAnnotation(_, _, let a), .transclusion(_, _, _, let a),
             .schemaIsland(_, _, let a), .componentDeclaration(_, _, _, _, _, let a),
             .phase2Directive(_, _, _, let a),
             .placeholder(_, let a),
             .expression(_, let a),
             .field(_, _, let a),
             .form(_, _, let a),
             .widget(_, _, let a),
             .tab(_, _, let a),
             .stage(_, _, let a),
             .lane(_, let a),
             .module(_, _, _, let a),
             .contractDirective(_, _, let a),
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
             .rawBlock(_, _, let a):
            return a
        case .horizontalRule, .html, .lineBlock, .footnoteDefinition, .abbreviationDefinition:
            return nil
        }
    }

    private func latexEscape(_ text: String) -> String {
        var result = ""
        for char in text {
            switch char {
            case "\\": result += "\\textbackslash{}"
            case "{": result += "\\{"
            case "}": result += "\\}"
            case "$": result += "\\$"
            case "&": result += "\\&"
            case "%": result += "\\%"
            case "#": result += "\\#"
            case "_": result += "\\_"
            case "~": result += "\\textasciitilde{}"
            case "^": result += "\\textasciicircum{}"
            default: result.append(char)
            }
        }
        return result
    }

    // MARK: - Collection Passes

    private func collectFootnotes(from blocks: [Block]) -> [String: [Block]] {
        var footnotes: [String: [Block]] = [:]
        for block in blocks {
            if case .footnoteDefinition(let id, let content) = block {
                footnotes[id] = content
            }
            // Recurse into nested blocks
            switch block {
            case .blockQuote(let nested, _), .div(let nested, _),
                 .widget(_, let nested, _), .tab(_, let nested, _):
                let nested = collectFootnotes(from: nested)
                footnotes.merge(nested) { _, new in new }
            case .list(_, let items, _):
                for item in items {
                    let nested = collectFootnotes(from: item.content)
                    footnotes.merge(nested) { _, new in new }
                }
            default: break
            }
        }
        return footnotes
    }

    private func collectMacros(from blocks: [Block]) -> [String] {
        var macros: [String] = []
        for block in blocks {
            if case .codeBlock(let language, let content, _) = block {
                let lang = language?.lowercased() ?? ""
                if lang == "latex-macros" || lang == "latex" || lang == "{=latex}" {
                    // Extract raw \newcommand lines
                    for line in content.components(separatedBy: "\n") {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.hasPrefix("\\newcommand") || trimmed.hasPrefix("\\renewcommand") || trimmed.hasPrefix("\\def") {
                            macros.append(trimmed)
                        }
                    }
                }
            }
        }
        return macros
    }

    private func detectRequiredPackages(from blocks: [Block]) -> Set<String> {
        var packages = Set<String>()

        for block in blocks {
            switch block {
            case .codeBlock:
                packages.insert(configuration.codeListingPackage.rawValue)
            case .admonition:
                packages.insert("tcolorbox")
            case .div(_, let attrs):
                let theoremClasses = ["theorem", "lemma", "definition", "proposition",
                                       "corollary", "example", "remark"]
                if attrs.classes.contains(where: { theoremClasses.contains($0) }) {
                    packages.insert("amsthm")
                }
            default:
                break
            }

            // Check inlines for package needs
            detectInlinePackages(from: block, packages: &packages)
        }

        return packages
    }

    private func detectInlinePackages(from block: Block, packages: inout Set<String>) {
        let inlines: [Inline]
        switch block {
        case .paragraph(let i, _): inlines = i
        case .heading(_, let i, _): inlines = i
        default: return
        }

        for inline in inlines {
            switch inline {
            case .strikethrough: packages.insert("ulem")
            case .highlight: packages.insert("soul")
            case .citation, .resolvedCitation: packages.insert("natbib")
            default: break
            }
        }
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

    // MARK: - Block Visitor

    private struct LaTeXBlockRenderer: BlockVisitor {
        let writer: LaTeXWriter
        let footnotes: [String: [Block]]
        var result: String = ""

        mutating func visitParagraph(_ inlines: [Inline], attributes: RhoeMarkdownKit.Attributes) {
            result = writer.renderInlines(inlines, footnotes: footnotes) + "\n\n"
        }

        mutating func visitHeading(level: Int, content: [Inline], attributes: RhoeMarkdownKit.Attributes) {
            let text = writer.renderInlines(content, footnotes: footnotes)
            let label = attributes.id.map { "\\label{\($0)}" } ?? ""
            if writer.configuration.astNearEmission {
                result = "\\begin{RhoeSection}[level=\(level),title={\(text)}]\(label)\n\\end{RhoeSection}\n\n"
                return
            }
            let command = writer.headingCommand(for: level)
            result = "\\\(command){\(text)}\(label)\n\n"
        }

        mutating func visitBlockQuote(_ blocks: [Block], attributes: RhoeMarkdownKit.Attributes) {
            let inner = blocks.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
            if writer.configuration.astNearEmission {
                result = "\\begin{RhoeBlockQuote}\n\(inner)\\end{RhoeBlockQuote}\n\n"
                return
            }
            result = "\\begin{quote}\n\(inner)\\end{quote}\n\n"
        }

        mutating func visitList(type: ListType, items: [ListItem], attributes: RhoeMarkdownKit.Attributes) {
            result = writer.renderList(type: type, items: items, footnotes: footnotes)
        }

        mutating func visitCodeBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes) {
            if writer.configuration.astNearEmission, let lang = language {
                result = "\\begin{RhoeCode}[language={\(writer.latexEscape(lang))}]\n\(content)\n\\end{RhoeCode}\n\n"
                return
            }
            result = writer.renderCodeBlock(language: language, content: content)
        }

        mutating func visitHorizontalRule() {
            result = "\\noindent\\rule{\\textwidth}{0.4pt}\n\n"
        }

        mutating func visitTable(headers: [TableCell], rows: [[TableCell]], caption: [Inline]?, attributes: RhoeMarkdownKit.Attributes) {
            result = writer.renderTable(headers: headers, rows: rows, caption: caption, attrs: attributes, footnotes: footnotes)
        }

        mutating func visitDefinitionList(items: [DefinitionListItem], attributes: RhoeMarkdownKit.Attributes) {
            var output = "\\begin{description}\n"
            for item in items {
                let term = writer.renderInlines(item.term, footnotes: footnotes)
                output += "\\item[\(term)]"
                for def in item.definitions {
                    output += " " + def.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
                }
            }
            output += "\\end{description}\n\n"
            result = output
        }

        mutating func visitFootnoteDefinition(id: String, content: [Block]) {
            result = "" // Rendered inline at reference sites
        }

        mutating func visitAdmonition(type: String, title: String?, content: [Block], collapsible: AdmonitionCollapsible?, attributes: RhoeMarkdownKit.Attributes) {
            let titleStr = title ?? type.capitalized
            let inner = content.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
            if writer.configuration.astNearEmission {
                var opts = "kind={\(type)}"
                if let title { opts += ",title={\(writer.latexEscape(title))}" }
                result = "\\begin{RhoeAdmonition}[\(opts)]\n\(inner)\\end{RhoeAdmonition}\n\n"
                return
            }
            result = "\\begin{tcolorbox}[title={\(writer.latexEscape(titleStr))}]\n\(inner)\\end{tcolorbox}\n\n"
        }

        mutating func visitBlockHTML(_ html: String) {
            result = "% HTML block omitted in LaTeX output\n"
        }

        mutating func visitDiv(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = writer.renderDiv(content: content, attrs: attributes, footnotes: footnotes)
        }

        mutating func visitLineBlock(lines: [[Inline]]) {
            let lineTexts = lines.map { writer.renderInlines($0, footnotes: footnotes) }
            if writer.configuration.astNearEmission {
                result = "\\begin{RhoeLineBlock}\n\(lineTexts.joined(separator: " \\\\\n"))\n\\end{RhoeLineBlock}\n\n"
                return
            }
            result = "\\begin{verse}\n\(lineTexts.joined(separator: " \\\\\n"))\n\\end{verse}\n\n"
        }

        mutating func visitAbbreviationDefinition(abbreviation: String, expansion: String) {
            result = "" // Consumed during expansion
        }

        mutating func visitVisualBlock(name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            let inner = content.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
            if writer.configuration.astNearEmission {
                result = "\\begin{RhoeVisualBlock}[name={\(writer.latexEscape(name))}]\n\(inner)\\end{RhoeVisualBlock}\n\n"
                return
            }
            result = "\\begin{rhoevisual}[\(writer.latexEscape(name))]\n\(inner)\\end{rhoevisual}\n\n"
        }

        mutating func visitAuthorAnnotation(kind: AnnotationKind, text: String, attributes: RhoeMarkdownKit.Attributes) {
            result = "" // Non-rendering
        }

        mutating func visitTransclusion(target: String, fragment: String?, mode: TransclusionMode?, attributes: RhoeMarkdownKit.Attributes) {
            let fragSuffix = fragment.map { "\\#\($0)" } ?? ""
            result = "\\textit{[Transclusion: \(writer.latexEscape(target))\(fragSuffix)]}\n\n"
        }

        mutating func visitSchemaIsland(schema: String, body: String, attributes: RhoeMarkdownKit.Attributes) {
            result = "\\begin{verbatim}\n\(body)\n\\end{verbatim}\n\n"
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
            result = "\\textit{[\(writer.latexEscape(display))]}\n\n"
        }

        mutating func visitExpression(expr: String, attributes: RhoeMarkdownKit.Attributes) {
            result = "\\texttt{\(writer.latexEscape(expr))}\n\n"
        }

        mutating func visitField(name: String, fieldType: String, attributes: RhoeMarkdownKit.Attributes) {
            result = "\(writer.latexEscape(name))\n\n"
        }

        mutating func visitForm(name: String?, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            result = content.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
        }

        mutating func visitWidget(title: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            let inner = content.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
            result = "\\begin{rhoewidget}[\(writer.latexEscape(title))]\n\(inner)\\end{rhoewidget}\n\n"
        }

        mutating func visitTab(title: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            let inner = content.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
            result = "\\begin{rhoetab}[\(writer.latexEscape(title))]\n\(inner)\\end{rhoetab}\n\n"
        }

        mutating func visitStage(kind: StageKind, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            let inner = content.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
            result = "\\begin{rhoestage}[\(writer.latexEscape(kind.rawValue))]\n\(inner)\\end{rhoestage}\n\n"
        }

        mutating func visitLane(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            let inner = content.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
            result = "\\begin{rhoelane}\n\(inner)\\end{rhoelane}\n\n"
        }

        mutating func visitModule(family: String, name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            let inner = content.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
            result = "\\begin{rhoemodule}[\(writer.latexEscape(family)).\(writer.latexEscape(name))]\n\(inner)\\end{rhoemodule}\n\n"
        }

        mutating func visitContractDirective(kind: ContractKind, content: String, attributes: RhoeMarkdownKit.Attributes) {
            result = "\\begin{rhoecontract}[\(writer.latexEscape(kind.rawValue))]\n\(writer.latexEscape(content))\n\\end{rhoecontract}\n\n"
        }

        mutating func visitSection(level: Int, title: [Inline], children: [Block], attributes: RhoeMarkdownKit.Attributes) {
            let titleText = writer.renderInlines(title, footnotes: footnotes)
            let label = attributes.id.map { "\\label{\($0)}" } ?? ""
            if writer.configuration.astNearEmission {
                result = "\\begin{RhoeSection}[level=\(level),title={\(titleText)}]\(label)\n"
                for child in children {
                    result += writer.renderBlock(child, footnotes: footnotes)
                }
                result += "\\end{RhoeSection}\n\n"
                return
            }
            let command = writer.headingCommand(for: level)
            result = "\\\(command){\(titleText)}\(label)\n"
            for child in children {
                result += writer.renderBlock(child, footnotes: footnotes)
            }
        }

        mutating func visitFormalBlock(family: String, title: [Inline]?, number: String?, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            let env = family.lowercased()
            let inner = content.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let label = attributes.id.map { "\n\\label{\($0)}" } ?? ""
            if let titleInlines = title {
                let titleText = writer.renderInlines(titleInlines, footnotes: footnotes)
                result = "\\begin{\(env)}[\(titleText)]\(label)\n\(inner)\n\\end{\(env)}\n\n"
            } else {
                result = "\\begin{\(env)}\(label)\n\(inner)\n\\end{\(env)}\n\n"
            }
        }

        mutating func visitSpeakerNotes(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            let inner = content.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            result = "% speaker notes: \(inner)\n"
        }

        mutating func visitGrid(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            let inner = content.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
            result = "% begin grid\n\(inner)% end grid\n\n"
        }

        mutating func visitColumns(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            let inner = content.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
            result = "\\begin{minipage}{\\textwidth}\n\(inner)\\end{minipage}\n\n"
        }

        mutating func visitFigure(content: [Block], caption: [Inline]?, attributes: RhoeMarkdownKit.Attributes) {
            let inner = content.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let label = attributes.id.map { "\n\\label{\($0)}" } ?? ""
            var output = "\\begin{figure}[htbp]\n\\centering\n\(inner)\n"
            if let caption {
                output += "\\caption{\(writer.renderInlines(caption, footnotes: footnotes))}\(label)\n"
            }
            output += "\\end{figure}\n\n"
            result = output
        }

        mutating func visitDiagramBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes) {
            result = writer.renderCodeBlock(language: language, content: content)
        }

        mutating func visitShape(content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            let inner = content.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
            result = "% begin shape\n\(inner)% end shape\n\n"
        }

        mutating func visitTableHead(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes) {
            var output = ""
            for row in rows {
                let cells = row.map { writer.renderInlines($0.content, footnotes: footnotes) }
                output += "\\textbf{" + cells.joined(separator: "} & \\textbf{") + "} \\\\\n\\hline\n"
            }
            result = output
        }

        mutating func visitTableBody(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes) {
            var output = ""
            for row in rows {
                let cells = row.map { writer.renderInlines($0.content, footnotes: footnotes) }
                output += cells.joined(separator: " & ") + " \\\\\n"
            }
            result = output
        }

        mutating func visitTableFoot(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes) {
            var output = "\\hline\n"
            for row in rows {
                let cells = row.map { writer.renderInlines($0.content, footnotes: footnotes) }
                output += cells.joined(separator: " & ") + " \\\\\n"
            }
            result = output
        }

        mutating func visitTableRow(cells: [TableCell], attributes: RhoeMarkdownKit.Attributes) {
            let rendered = cells.map { writer.renderInlines($0.content, footnotes: footnotes) }
            result = rendered.joined(separator: " & ") + " \\\\\n"
        }

        mutating func visitExecutableCodeBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes) {
            result = writer.renderCodeBlock(language: language, content: content)
        }

        mutating func visitMathBlock(expression: String, attributes: RhoeMarkdownKit.Attributes) {
            result = "\\[\(expression)\\]\n\n"
        }

        mutating func visitDeck(slides: [Block], attributes: RhoeMarkdownKit.Attributes) {
            var output = ""
            for slide in slides {
                output += writer.renderBlock(slide, footnotes: footnotes)
            }
            result = output
        }

        mutating func visitSlide(title: [Inline]?, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            let label = attributes.id.map { "\\label{\($0)}" } ?? ""
            var output = "\\begin{frame}"
            if let title {
                output += "{\(writer.renderInlines(title, footnotes: footnotes))}"
            }
            output += "\(label)\n"
            for child in content {
                output += writer.renderBlock(child, footnotes: footnotes)
            }
            output += "\\end{frame}\n\n"
            result = output
        }

        mutating func visitSlotContent(name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            let inner = content.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
            result = "% slot: \(writer.latexEscape(name))\n\(inner)"
        }

        mutating func visitExtension(vendor: String, name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {
            let inner = content.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
            result = "% extension: \(writer.latexEscape(vendor)).\(writer.latexEscape(name))\n\(inner)"
        }

        mutating func visitRawBlock(content: String, format: String, attributes: RhoeMarkdownKit.Attributes) {
            if format == "latex" || format == "tex" {
                result = content + "\n"
            } else {
                result = "% raw block (\(writer.latexEscape(format))) omitted in LaTeX output\n"
            }
        }
    }

    // MARK: - Inline Visitor

    private struct LaTeXInlineRenderer: InlineVisitor {
        let writer: LaTeXWriter
        let footnotes: [String: [Block]]
        var result: String = ""

        mutating func visitText(_ text: String) {
            result = writer.latexEscape(text)
        }

        mutating func visitEmphasis(_ inlines: [Inline]) {
            result = "\\textit{\(writer.renderInlines(inlines, footnotes: footnotes))}"
        }

        mutating func visitStrong(_ inlines: [Inline]) {
            result = "\\textbf{\(writer.renderInlines(inlines, footnotes: footnotes))}"
        }

        mutating func visitStrikethrough(_ inlines: [Inline]) {
            result = "\\sout{\(writer.renderInlines(inlines, footnotes: footnotes))}"
        }

        mutating func visitCodeSpan(_ code: String, attributes: RhoeMarkdownKit.Attributes) {
            result = "\\texttt{\(writer.latexEscape(code))}"
        }

        mutating func visitLink(text: [Inline], url: String, title: String?, attributes: RhoeMarkdownKit.Attributes) {
            result = "\\href{\(url)}{\(writer.renderInlines(text, footnotes: footnotes))}"
        }

        mutating func visitImage(alt: [Inline], url: String, title: String?, attributes: RhoeMarkdownKit.Attributes) {
            let altText = writer.renderInlines(alt, footnotes: footnotes)
            let label = attributes.id.map { "\n\\label{\($0)}" } ?? ""
            if !altText.isEmpty {
                result = "\\begin{figure}[htbp]\n\\centering\n\\includegraphics{\(url)}\n\\caption{\(altText)}\(label)\n\\end{figure}"
                return
            }
            result = "\\includegraphics{\(url)}"
        }

        mutating func visitFootnoteRef(id: String) {
            if let content = footnotes[id] {
                let inner = content.map { writer.renderBlock($0, footnotes: footnotes) }.joined()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                result = "\\footnote{\(inner)}"
                return
            }
            result = "\\footnote{\(writer.latexEscape(id))}"
        }

        mutating func visitInlineMath(expression: String, attributes: RhoeMarkdownKit.Attributes) {
            result = "$\(expression)$"
        }

        mutating func visitMathDisplay(expression: String, attributes: RhoeMarkdownKit.Attributes) {
            result = "\\[\(expression)\\]"
        }

        mutating func visitInlineHTML(_ html: String) {
            result = "" // Skip HTML in LaTeX
        }

        mutating func visitHardBreak() {
            result = " \\\\\n"
        }

        mutating func visitSoftBreak() {
            result = " "
        }

        mutating func visitSuperscript(_ inlines: [Inline]) {
            result = "\\textsuperscript{\(writer.renderInlines(inlines, footnotes: footnotes))}"
        }

        mutating func visitSubscript(_ inlines: [Inline]) {
            result = "\\textsubscript{\(writer.renderInlines(inlines, footnotes: footnotes))}"
        }

        mutating func visitHighlight(_ inlines: [Inline]) {
            result = "\\hl{\(writer.renderInlines(inlines, footnotes: footnotes))}"
        }

        mutating func visitSpan(content: [Inline], attributes: RhoeMarkdownKit.Attributes) {
            result = writer.renderInlines(content, footnotes: footnotes)
        }

        mutating func visitInlineFootnote(content: [Inline]) {
            result = "\\footnote{\(writer.renderInlines(content, footnotes: footnotes))}"
        }

        mutating func visitCitation(items: [CitationItem], mode: CitationMode) {
            result = writer.renderCitation(items: items, mode: mode)
        }

        mutating func visitResolvedCitation(text: String, keys: [String], mode: CitationMode) {
            result = writer.renderResolvedCitation(keys: keys, mode: mode)
        }

        mutating func visitCrossReference(prefix: CrossRefPrefix, id: String) {
            let label = writer.displayName(for: prefix)
            result = "\(label)~\\ref{\(prefix.rawValue)-\(id)}"
        }

        mutating func visitResolvedCrossReference(text: String, targetId: String) {
            let prefix = targetId.split(separator: "-").first.map(String.init) ?? ""
            let label = writer.prefixDisplayName(prefix)
            result = "\(label)~\\ref{\(targetId)}"
        }

        mutating func visitRawInline(content: String, format: String) {
            if format == "latex" || format == "tex" {
                result = content // Pass through LaTeX raw content
                return
            }
            result = "" // Skip non-LaTeX raw inlines
        }

        mutating func visitWikilink(target: String, display: [Inline]?) {
            result = display.map { writer.renderInlines($0, footnotes: footnotes) } ?? writer.latexEscape(target)
        }

        mutating func visitTransclusionInline(target: String, fragment: String?, mode: TransclusionMode?, attributes: RhoeMarkdownKit.Attributes) {
            let fragSuffix = fragment.map { "\\#\($0)" } ?? ""
            result = "\\textit{[\(writer.latexEscape(target))\(fragSuffix)]}"
        }

        mutating func visitAnnotationInline(kind: AnnotationKind, text: String) {
            result = "" // Non-rendering
        }

        mutating func visitParamRef(name: String) {
            result = writer.latexEscape("<<param \(name)>>")
        }

        mutating func visitSlotRef(name: String?) {
            result = writer.latexEscape("<<slot \(name ?? "default")>>")
        }

        mutating func visitPlaceholderInline(fields: [String: String]) {
            let display: String
            if let name = fields["name"] {
                display = name
            } else {
                display = fields.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            }
            result = "\\textit{[\(writer.latexEscape(display))]}"
        }

        mutating func visitExpressionInline(expr: String) {
            result = "\\texttt{\(writer.latexEscape(expr))}"
        }

        mutating func visitInputFieldInline(name: String, fieldType: String, attributes: RhoeMarkdownKit.Attributes) {
            result = writer.latexEscape(name)
        }

        mutating func visitEmoji(name: String, unicode: String?) {
            if let unicode {
                result = unicode
            } else {
                result = writer.latexEscape(":\(name):")
            }
        }
    }
}
