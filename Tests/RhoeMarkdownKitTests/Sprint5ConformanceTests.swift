import Testing
import RhoeMarkdownKit

@Suite("Sprint 5: Academic & Extended Features")
struct Sprint5ConformanceTests {

    // MARK: - 5.2 Line Blocks

    @Test("Line block renders as paragraph with br separators")
    func lineBlockBasic() async {
        let md = """
        | The limerick packs laughs anatomical
        | In space that is quite economical.
        """
        let result = await RhoeMarkdownKit.parse(md)
        // v4.0: StructuralNormalizationPass converts lineBlock to paragraph with hardBreaks
        let hasParagraphWithBreaks = result.document.blocks.contains { block in
            if case .paragraph(let inlines, _) = block {
                return inlines.contains { if case .hardBreak = $0 { return true }; return false }
            }
            return false
        }
        #expect(hasParagraphWithBreaks)
    }

    @Test("Line block renders correct HTML")
    func lineBlockHTML() async {
        let md = """
        | First line
        | Second line
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        // v4.0: lineBlock is normalized to paragraph with <br> separators
        #expect(html.contains("<br>"))
    }

    @Test("Line blocks disambiguate from tables (multiple pipes = table)")
    func lineBlockNotTable() async {
        let md = "| A | B |"
        let html = await RhoeMarkdownKit.toHTML(md)
        // Multiple pipes → should not become a line block
        #expect(!html.contains("line-block"))
    }

    // MARK: - 5.3 Raw Format Inline

    @Test("Inline code with {=format} becomes rawInline")
    func rawInlineBasic() async {
        let md = "`<br>`{=html}"
        let result = await RhoeMarkdownKit.parse(md)
        let hasRawInline = result.document.blocks.contains { block in
            if case .paragraph(let inlines, _) = block {
                return inlines.contains { inline in
                    if case .rawInline(let content, let format) = inline {
                        return content == "<br>" && format == "html"
                    }
                    return false
                }
            }
            return false
        }
        #expect(hasRawInline)
    }

    @Test("Raw inline HTML passes through unescaped")
    func rawInlineHTML() async {
        let md = "`<em>hi</em>`{=html}"
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<em>hi</em>"))
    }

    @Test("Inline code without {=format} stays as code")
    func rawInlineNotTriggered() async {
        let md = "`code`"
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<code>"))
        #expect(!html.contains("raw-"))
    }

    @Test("Raw inline disabled falls back to code with attribute")
    func rawInlineDisabled() async {
        let config = RhoeMarkdownKit.Configuration(enableRawInlines: false)
        let result = await RhoeMarkdownKit.parse("`hello`{=html}", configuration: config)
        let hasCode = result.document.blocks.contains { block in
            if case .paragraph(let inlines, _) = block {
                return inlines.contains { inline in
                    if case .codeSpan = inline { return true }
                    return false
                }
            }
            return false
        }
        #expect(hasCode)
    }

    // MARK: - 5.4 Abbreviation Definitions

    @Test("Abbreviation definition is parsed from source")
    func abbreviationDefinitionParsed() async {
        let md = """
        *[HTML]: Hyper Text Markup Language

        The HTML specification is maintained by the W3C.
        """
        let result = await RhoeMarkdownKit.parse(md)
        // After expansion, HTML should be wrapped in <abbr>
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("<abbr"))
        #expect(html.contains("Hyper Text Markup Language"))
    }

    @Test("Abbreviation expansion inserts abbr tags in text")
    func abbreviationExpansion() async {
        let md = """
        *[CSS]: Cascading Style Sheets

        CSS is great for styling.
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<abbr title=\"Cascading Style Sheets\">CSS</abbr>"))
    }

    @Test("Abbreviation definitions disabled")
    func abbreviationDisabled() async {
        let config = RhoeMarkdownKit.Configuration(enableAbbreviations: false)
        let result = await RhoeMarkdownKit.parse(
            "*[HTML]: Hyper Text Markup Language\n\nThe HTML spec.",
            configuration: config
        )
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(!html.contains("<abbr"))
    }

    // MARK: - 5.5 Wikilinks

    @Test("Wikilink with simple target")
    func wikilinkSimple() async {
        let md = "See [[Page Name]] for details."
        let result = await RhoeMarkdownKit.parse(md)
        let hasWikilink = result.document.blocks.contains { block in
            if case .paragraph(let inlines, _) = block {
                return inlines.contains { inline in
                    if case .wikilink(let target, let display) = inline {
                        return target == "Page Name" && display == nil
                    }
                    return false
                }
            }
            return false
        }
        #expect(hasWikilink)
    }

    @Test("Wikilink with display text")
    func wikilinkWithDisplay() async {
        let md = "Visit [[Page Name|Click Here]]."
        let result = await RhoeMarkdownKit.parse(md)
        let hasWikilink = result.document.blocks.contains { block in
            if case .paragraph(let inlines, _) = block {
                return inlines.contains { inline in
                    if case .wikilink(let target, let display) = inline {
                        return target == "Page Name" && display != nil
                    }
                    return false
                }
            }
            return false
        }
        #expect(hasWikilink)
    }

    @Test("Wikilink renders as anchor with wikilink class")
    func wikilinkHTML() async {
        let md = "See [[Home Page]]."
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("class=\"wikilink\""))
        #expect(html.contains("href=\"Home Page\""))
        #expect(html.contains(">Home Page</a>"))
    }

    @Test("Wikilink with pipe display renders display text")
    func wikilinkDisplayHTML() async {
        let md = "See [[Home Page|Go Home]]."
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains(">Go Home</a>"))
    }

    @Test("Wikilinks disabled")
    func wikilinkDisabled() async {
        let config = RhoeMarkdownKit.Configuration(enableWikilinks: false)
        let result = await RhoeMarkdownKit.parse("See [[Page]].", configuration: config)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(!html.contains("wikilink"))
    }

    // MARK: - 5.6 Theorem Environments

    @Test("Fenced div with theorem class renders theorem header")
    func theoremEnvironment() async {
        let md = """
        ::: {.theorem}
        Every even integer greater than 2 is the sum of two primes.
        :::
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<strong>Theorem.</strong>"))
        #expect(html.contains("class=\"theorem\""))
    }

    @Test("Fenced div with proof class renders proof with QED")
    func proofEnvironment() async {
        let md = """
        ::: {.proof}
        This is trivially true.
        :::
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<em>Proof.</em>"))
        #expect(html.contains("□"))
    }

    @Test("Fenced div with lemma class renders lemma")
    func lemmaEnvironment() async {
        let md = """
        ::: {.lemma}
        A useful result.
        :::
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<strong>Lemma.</strong>"))
        #expect(html.contains("class=\"lemma\""))
    }

    // MARK: - 5.7 Content Visibility

    @Test("Basic fenced div has content")
    func basicFencedDivContent() async {
        let md = "::: note\nHello world.\n:::"
        let result = await RhoeMarkdownKit.parse(md)
        for block in result.document.blocks {
            if case .div(let content, _) = block {
                #expect(!content.isEmpty, "Fenced div content should not be empty")
            }
        }
    }

    @Test("Content-visible div with when-format=html is shown")
    func contentVisibleForHTML() async {
        let md = """
        ::: {.content-visible when-format=html}
        Only in HTML output.
        :::
        """
        let result = await RhoeMarkdownKit.parse(md)
        // Check the parsed blocks to see what we got
        let blocks = result.document.blocks
        var foundDiv = false
        for block in blocks {
            if case .div(let content, let attrs) = block {
                foundDiv = true
                #expect(attrs.classes.contains("content-visible"))
                #expect(!content.isEmpty, "Fenced div content should not be empty")
            }
        }
        #expect(foundDiv, "Should parse a div block; got \(blocks)")
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("Only in HTML output"))
    }

    @Test("Content-hidden div with when-format=html is hidden")
    func contentHiddenForHTML() async {
        let md = """
        ::: {.content-hidden when-format=html}
        Not for HTML.
        :::
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(!html.contains("Not for HTML"))
    }

    @Test("Content-visible div with when-format=pdf is hidden from HTML")
    func contentVisibleForPDFOnly() async {
        let md = """
        ::: {.content-visible when-format=pdf}
        Only in PDF.
        :::
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(!html.contains("Only in PDF"))
    }

    // MARK: - 5.8 LaTeX Macros in Math

    @Test("LaTeX macro expansion in math inline")
    func latexMacroExpansion() async {
        let md = """
        ```latex
        \\newcommand{\\R}{\\mathbb{R}}
        ```

        The set $\\R$ is real numbers.
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        // The macro \\R should be expanded to \\mathbb{R}
        #expect(html.contains("\\mathbb{R}"))
    }

    @Test("LaTeX macro with arguments")
    func latexMacroWithArgs() async {
        let md = """
        ```latex
        \\newcommand{\\vect}[1]{\\boldsymbol{#1}}
        ```

        The vector $\\vect{v}$ has magnitude.
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("\\boldsymbol{v}"))
    }

    @Test("Math.parseMacroDefinitions handles newcommand")
    func mathParseMacros() {
        let latex = #"\newcommand{\R}{\mathbb{R}}"#
        let macros = Math.parseMacroDefinitions(from: latex)
        #expect(macros.count == 1)
        #expect(macros.first?.name == "\\R")
        #expect(macros.first?.expansion == "\\mathbb{R}")
        #expect(macros.first?.argCount == 0)
    }

    @Test("Math.parseMacroDefinitions handles newcommand with args")
    func mathParseMacrosWithArgs() {
        let latex = #"\newcommand{\vect}[1]{\boldsymbol{#1}}"#
        let macros = Math.parseMacroDefinitions(from: latex)
        #expect(macros.count == 1)
        #expect(macros.first?.name == "\\vect")
        #expect(macros.first?.argCount == 1)
        #expect(macros.first?.expansion == "\\boldsymbol{#1}")
    }

    @Test("Math.expandMacros applies simple substitution")
    func mathExpandSimple() {
        let macros = [Math.MacroDefinition(name: "\\R", argCount: 0, expansion: "\\mathbb{R}")]
        let result = Math.expandMacros("x \\in \\R", macros: macros)
        #expect(result == "x \\in \\mathbb{R}")
    }

    @Test("Math.expandMacros applies argument substitution")
    func mathExpandWithArgs() {
        let macros = [Math.MacroDefinition(name: "\\vect", argCount: 1, expansion: "\\boldsymbol{#1}")]
        let result = Math.expandMacros("\\vect{v}", macros: macros)
        #expect(result == "\\boldsymbol{v}")
    }

    // MARK: - 5.9 Automatic Table of Contents

    @Test("TOC generated when frontmatter has toc: true")
    func tocGeneration() async {
        let md = """
        ---
        toc: true
        ---

        # Introduction

        Some text.

        ## Background

        More text.

        ## Methods

        Details.
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<nav class=\"toc\">"))
        #expect(html.contains("Introduction"))
        #expect(html.contains("Background"))
        #expect(html.contains("Methods"))
    }

    @Test("TOC not generated when frontmatter missing")
    func tocNotGenerated() async {
        let md = """
        # Introduction

        Some text.
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(!html.contains("<nav class=\"toc\">"))
    }

    @Test("TOC respects toc-depth")
    func tocDepth() async {
        let md = """
        ---
        toc: true
        toc-depth: 1
        ---

        # Chapter One

        ## Section A

        ### Subsection
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<nav class=\"toc\">"))
        // TOC should only contain h1 links (depth 1), not h2/h3
        // The TOC nav should contain "Chapter One" but NOT "Section A" as a link
        guard let tocRange = html.range(of: "<nav class=\"toc\">"),
              let tocEndRange = html.range(of: "</nav>", range: tocRange.lowerBound..<html.endIndex) else {
            #expect(Bool(false), "Expected TOC nav element in HTML output")
            return
        }
        let tocContent = String(html[tocRange.lowerBound..<tocEndRange.upperBound])
        #expect(tocContent.contains("Chapter One"))
        #expect(!tocContent.contains("Section A"))
    }

    // MARK: - 5.1 Fancy List Markers

    @Test("Lowercase alpha list parsed with correct style")
    func fancyListLowerAlpha() async {
        let md = """
        a. First item
        b. Second item
        c. Third item
        """
        let result = await RhoeMarkdownKit.parse(md)
        let hasFancyList = result.document.blocks.contains { block in
            if case .list(let type, _, _) = block,
               case .ordered(_, let style) = type {
                return style == .lowerAlpha
            }
            return false
        }
        #expect(hasFancyList)
    }

    @Test("Uppercase Roman list parsed with correct style")
    func fancyListUpperRoman() async {
        let md = """
        I. First item
        II. Second item
        III. Third item
        """
        let result = await RhoeMarkdownKit.parse(md)
        let hasFancyList = result.document.blocks.contains { block in
            if case .list(let type, _, _) = block,
               case .ordered(_, let style) = type {
                return style == .upperRoman
            }
            return false
        }
        #expect(hasFancyList)
    }

    @Test("Hash auto-number list uses decimal style")
    func fancyListHash() async {
        let md = """
        #. First item
        #. Second item
        """
        let result = await RhoeMarkdownKit.parse(md)
        let hasList = result.document.blocks.contains { block in
            if case .list(let type, _, _) = block,
               case .ordered(let start, let style) = type {
                return start == 1 && style == .decimal
            }
            return false
        }
        #expect(hasList)
    }

    @Test("Fancy list renders with CSS class in HTML")
    func fancyListHTMLRendering() async {
        let md = """
        a. Alpha item
        b. Beta item
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("list-style-lower-alpha"))
    }

    @Test("Fancy lists disabled in strict config")
    func fancyListDisabled() async {
        let config = RhoeMarkdownKit.Configuration(enableFancyLists: false)
        let md = "a. Not a list"
        let result = await RhoeMarkdownKit.parse(md, configuration: config)
        // Should not produce a fancy list (marker not recognized)
        let hasFancyList = result.document.blocks.contains { block in
            if case .list(let type, _, _) = block,
               case .ordered(_, let style) = type {
                return style != .decimal
            }
            return false
        }
        #expect(!hasFancyList)
    }

    // MARK: - Configuration Guards

    @Test("All Sprint 5 features disabled in strict preset")
    func strictPresetDisablesAll() async {
        let config = RhoeMarkdownKit.Configuration.strict

        #expect(!config.enableFancyLists)
        #expect(!config.enableLineBlocks)
        #expect(!config.enableRawInlines)
        #expect(!config.enableAbbreviations)
        #expect(!config.enableWikilinks)
    }

    @Test("All Sprint 5 features enabled in default config")
    func defaultConfigEnablesAll() async {
        let config = RhoeMarkdownKit.Configuration()

        #expect(config.enableFancyLists)
        #expect(config.enableLineBlocks)
        #expect(config.enableRawInlines)
        #expect(config.enableAbbreviations)
        #expect(config.enableWikilinks)
    }
}
