import Testing
import RhoeMarkdownKit

@Suite("Sprint 1: Reserved Type Activation")
struct Sprint1ConformanceTests {

    // MARK: - Superscript

    @Test("Superscript parses ^text^ to <sup>")
    func superscriptBasic() async {
        let html = await RhoeMarkdownKit.toHTML("E = mc^2^")
        #expect(html.contains("<sup>2</sup>"))
    }

    @Test("Superscript parses multi-character content")
    func superscriptMultiChar() async {
        let html = await RhoeMarkdownKit.toHTML("The 1^st^ of January")
        #expect(html.contains("<sup>st</sup>"))
    }

    @Test("Superscript does not match with spaces inside")
    func superscriptNoSpaces() async {
        let html = await RhoeMarkdownKit.toHTML("^not super^")
        // Space inside should prevent matching
        #expect(!html.contains("<sup>"))
    }

    @Test("Superscript is disabled when config says so")
    func superscriptDisabled() async {
        let config = RhoeMarkdownKit.Configuration(enableSuperscript: false)
        let result = await RhoeMarkdownKit.parse("E = mc^2^", configuration: config)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(!html.contains("<sup>"))
    }

    // MARK: - Subscript

    @Test("Subscript parses ~text~ to <sub>")
    func subscriptBasic() async {
        let html = await RhoeMarkdownKit.toHTML("H~2~O")
        #expect(html.contains("<sub>2</sub>"))
    }

    @Test("Double tilde remains strikethrough, not subscript")
    func subscriptVsStrikethrough() async {
        let html = await RhoeMarkdownKit.toHTML("~~deleted~~")
        #expect(html.contains("<del>deleted</del>"))
        #expect(!html.contains("<sub>"))
    }

    @Test("Subscript is disabled when config says so")
    func subscriptDisabled() async {
        let config = RhoeMarkdownKit.Configuration(enableSubscript: false)
        let result = await RhoeMarkdownKit.parse("H~2~O", configuration: config)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(!html.contains("<sub>"))
    }

    // MARK: - Highlight

    @Test("Highlight parses ==text== to <mark>")
    func highlightBasic() async {
        let html = await RhoeMarkdownKit.toHTML("This is ==highlighted== text")
        #expect(html.contains("<mark>highlighted</mark>"))
    }

    @Test("Single equals sign is not highlight")
    func highlightSingleEquals() async {
        let html = await RhoeMarkdownKit.toHTML("a = b")
        #expect(!html.contains("<mark>"))
    }

    @Test("Highlight is disabled when config says so")
    func highlightDisabled() async {
        let config = RhoeMarkdownKit.Configuration(enableHighlight: false)
        let result = await RhoeMarkdownKit.parse("==highlighted==", configuration: config)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(!html.contains("<mark>"))
    }

    // MARK: - Fenced Divs

    @Test("Fenced div parses ::: with class name")
    func fencedDivBasic() async {
        let md = """
        ::: warning
        Important content here.
        :::
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<div"))
        #expect(html.contains("warning"))
    }

    @Test("Fenced div is disabled when config says so")
    func fencedDivDisabled() async {
        let config = RhoeMarkdownKit.Configuration(enableFencedDivs: false)
        let md = """
        ::: warning
        Content
        :::
        """
        let result = await RhoeMarkdownKit.parse(md, configuration: config)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(!html.contains("<div"))
    }

    // MARK: - Smart Punctuation

    @Test("Smart punctuation converts double quotes when enabled")
    func smartQuotesDouble() async {
        let config = RhoeMarkdownKit.Configuration(enableSmartPunctuation: true)
        let result = await RhoeMarkdownKit.parse("He said \"hello\" to her.", configuration: config)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("\u{201C}"))  // left double quote
        #expect(html.contains("\u{201D}"))  // right double quote
    }

    @Test("Smart punctuation converts em-dash when enabled")
    func smartEmDash() async {
        let config = RhoeMarkdownKit.Configuration(enableSmartPunctuation: true)
        let result = await RhoeMarkdownKit.parse("Something --- indeed", configuration: config)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("\u{2014}"))  // em-dash
    }

    @Test("Smart punctuation converts en-dash when enabled")
    func smartEnDash() async {
        let config = RhoeMarkdownKit.Configuration(enableSmartPunctuation: true)
        let result = await RhoeMarkdownKit.parse("Pages 10--20", configuration: config)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("\u{2013}"))  // en-dash
    }

    @Test("Smart punctuation converts ellipsis when enabled")
    func smartEllipsis() async {
        let config = RhoeMarkdownKit.Configuration(enableSmartPunctuation: true)
        let result = await RhoeMarkdownKit.parse("And then...", configuration: config)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("\u{2026}"))  // horizontal ellipsis
    }

    @Test("Smart punctuation is off by default")
    func smartPunctuationOffByDefault() async {
        let html = await RhoeMarkdownKit.toHTML("He said \"hello\" to her.")
        // Should keep ASCII quotes, not convert to curly
        #expect(!html.contains("\u{201C}"))
    }

    // MARK: - Configuration

    @Test("Default configuration enables superscript, subscript, highlight, and fenced divs")
    func defaultConfigEnablesNewFeatures() {
        let config = RhoeMarkdownKit.Configuration.default
        #expect(config.enableSuperscript == true)
        #expect(config.enableSubscript == true)
        #expect(config.enableHighlight == true)
        #expect(config.enableFencedDivs == true)
        #expect(config.enableSmartPunctuation == false)
    }

    @Test("Strict configuration disables all new features")
    func strictConfigDisablesNewFeatures() {
        let config = RhoeMarkdownKit.Configuration.strict
        #expect(config.enableSuperscript == false)
        #expect(config.enableSubscript == false)
        #expect(config.enableHighlight == false)
        #expect(config.enableFencedDivs == false)
    }

    // MARK: - Combined / Edge Cases

    @Test("Superscript and subscript can coexist in one paragraph")
    func superscriptAndSubscriptCoexist() async {
        let html = await RhoeMarkdownKit.toHTML("x^2^ + H~2~O")
        #expect(html.contains("<sup>2</sup>"))
        #expect(html.contains("<sub>2</sub>"))
    }

    @Test("Highlight with plain text content")
    func highlightPlainContent() async {
        let html = await RhoeMarkdownKit.toHTML("This has ==very important== info")
        #expect(html.contains("<mark>very important</mark>"))
    }
}
