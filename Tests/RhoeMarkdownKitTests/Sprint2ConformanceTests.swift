import Testing
import RhoeMarkdownKit

@Suite("Sprint 2: New Inline Elements")
struct Sprint2ConformanceTests {

    // MARK: - Inline Footnotes

    @Test("Inline footnote parses ^[content] to footnote element")
    func inlineFootnoteBasic() async {
        let html = await RhoeMarkdownKit.toHTML("See here^[This is a footnote] for details.")
        #expect(html.contains("<sup class=\"inline-footnote\">"))
        #expect(html.contains("This is a footnote"))
        #expect(html.contains("</sup>"))
    }

    @Test("Inline footnote with formatting inside")
    func inlineFootnoteWithFormatting() async {
        let html = await RhoeMarkdownKit.toHTML("Text^[with **bold** inside] more text.")
        #expect(html.contains("<sup class=\"inline-footnote\">"))
        #expect(html.contains("<strong>bold</strong>"))
    }

    @Test("Inline footnote does not match empty brackets")
    func inlineFootnoteNoEmpty() async {
        let html = await RhoeMarkdownKit.toHTML("Text^[] more text.")
        #expect(!html.contains("<sup class=\"inline-footnote\">"))
    }

    @Test("Inline footnote is disabled when config says so")
    func inlineFootnoteDisabled() async {
        let config = RhoeMarkdownKit.Configuration(enableInlineFootnotes: false)
        let result = await RhoeMarkdownKit.parse("Text^[footnote] more.", configuration: config)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(!html.contains("<sup class=\"inline-footnote\">"))
    }

    @Test("Inline footnote disambiguated from superscript")
    func inlineFootnoteVsSuperscript() async {
        let html = await RhoeMarkdownKit.toHTML("x^2^ and ^[footnote here]")
        #expect(html.contains("<sup>2</sup>"))
        #expect(html.contains("<sup class=\"inline-footnote\">"))
        #expect(html.contains("footnote here"))
    }

    // MARK: - Citations

    @Test("Parenthetical citation parses [@key]")
    func citationParenthetical() async {
        let html = await RhoeMarkdownKit.toHTML("See [@smith2024] for details.")
        #expect(html.contains("<span class=\"citation"))
        #expect(html.contains("@smith2024"))
    }

    @Test("Citation with locator parses [@key, p. 42]")
    func citationWithLocator() async {
        let html = await RhoeMarkdownKit.toHTML("See [@smith2024, p. 42] for details.")
        #expect(html.contains("@smith2024"))
        #expect(html.contains("p. 42"))
    }

    @Test("Multiple citations parse [@a; @b; @c]")
    func citationMultiple() async {
        let html = await RhoeMarkdownKit.toHTML("See [@smith2024; @jones2023; @doe2025].")
        #expect(html.contains("@smith2024"))
        #expect(html.contains("@jones2023"))
        #expect(html.contains("@doe2025"))
    }

    @Test("Suppress-author citation parses [-@key]")
    func citationSuppressAuthor() async {
        let html = await RhoeMarkdownKit.toHTML("See [-@smith2024] for the year.")
        #expect(html.contains("citation-suppress-author"))
        #expect(html.contains("@smith2024"))
    }

    @Test("Citation does not interfere with regular links")
    func citationVsLink() async {
        let html = await RhoeMarkdownKit.toHTML("[click here](https://example.com)")
        #expect(html.contains("<a"))
        #expect(html.contains("https://example.com"))
        #expect(!html.contains("citation"))
    }

    @Test("Citation does not match footnote reference [^id]")
    func citationVsFootnoteRef() async {
        let html = await RhoeMarkdownKit.toHTML("See[^1] for more.")
        #expect(!html.contains("citation"))
    }

    @Test("Citation is disabled when config says so")
    func citationDisabled() async {
        let config = RhoeMarkdownKit.Configuration(enableCitations: false)
        let result = await RhoeMarkdownKit.parse("See [@smith2024].", configuration: config)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(!html.contains("citation"))
    }

    // MARK: - Cross-References

    @Test("Cross-reference parses @fig-name")
    func crossRefFigure() async {
        let html = await RhoeMarkdownKit.toHTML("See @fig-revenue for the chart.")
        #expect(html.contains("<a href=\"#fig-revenue\""))
        #expect(html.contains("class=\"crossref\""))
        #expect(html.contains("fig-revenue"))
    }

    @Test("Cross-reference parses @tbl-name")
    func crossRefTable() async {
        let html = await RhoeMarkdownKit.toHTML("See @tbl-quarterly for data.")
        #expect(html.contains("<a href=\"#tbl-quarterly\""))
        #expect(html.contains("class=\"crossref\""))
    }

    @Test("Cross-reference parses @eq-name")
    func crossRefEquation() async {
        let html = await RhoeMarkdownKit.toHTML("Refer to @eq-euler for the formula.")
        #expect(html.contains("<a href=\"#eq-euler\""))
        #expect(html.contains("class=\"crossref\""))
    }

    @Test("Cross-reference parses @sec-name")
    func crossRefSection() async {
        let html = await RhoeMarkdownKit.toHTML("See @sec-introduction.")
        #expect(html.contains("<a href=\"#sec-introduction\""))
    }

    @Test("Cross-reference parses theorem prefixes")
    func crossRefTheorem() async {
        let html = await RhoeMarkdownKit.toHTML("By @thm-pythagorean we know.")
        #expect(html.contains("<a href=\"#thm-pythagorean\""))
        #expect(html.contains("class=\"crossref\""))
    }

    @Test("Non-crossref @mention is not treated as crossref")
    func crossRefVsMention() async {
        let html = await RhoeMarkdownKit.toHTML("Contact @username for help.")
        #expect(!html.contains("class=\"crossref\""))
    }

    @Test("Cross-reference is disabled when config says so")
    func crossRefDisabled() async {
        let config = RhoeMarkdownKit.Configuration(enableCrossReferences: false)
        let result = await RhoeMarkdownKit.parse("See @fig-chart.", configuration: config)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(!html.contains("class=\"crossref\""))
    }

    // MARK: - Configuration

    @Test("Default configuration enables inline footnotes, citations, and cross-references")
    func defaultConfigEnablesNewFeatures() {
        let config = RhoeMarkdownKit.Configuration.default
        #expect(config.enableInlineFootnotes == true)
        #expect(config.enableCitations == true)
        #expect(config.enableCrossReferences == true)
    }

    @Test("Strict configuration disables all Sprint 2 features")
    func strictConfigDisablesNewFeatures() {
        let config = RhoeMarkdownKit.Configuration.strict
        #expect(config.enableInlineFootnotes == false)
        #expect(config.enableCitations == false)
        #expect(config.enableCrossReferences == false)
    }

    // MARK: - Combined / Edge Cases

    @Test("All Sprint 2 features coexist in one paragraph")
    func allFeaturesCoexist() async {
        let html = await RhoeMarkdownKit.toHTML("See @fig-chart and [@smith2024]^[An important note].")
        #expect(html.contains("class=\"crossref\""))
        #expect(html.contains("citation"))
        #expect(html.contains("inline-footnote"))
    }

    @Test("Sprint 1 and Sprint 2 features coexist")
    func sprint1And2Coexist() async {
        let html = await RhoeMarkdownKit.toHTML("x^2^ and [@smith2024] with ==highlight==")
        #expect(html.contains("<sup>2</sup>"))
        #expect(html.contains("citation"))
        #expect(html.contains("<mark>highlight</mark>"))
    }
}
