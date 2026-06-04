import Testing
import RhoeMarkdownKit

@Suite("Sprint 4: Core Authoring Completeness")
struct Sprint4ConformanceTests {

    // MARK: - Implicit Figures

    @Test("Lone image with alt text renders as <figure>")
    func implicitFigureBasic() async {
        let html = await RhoeMarkdownKit.toHTML("![Beautiful sunset](sunset.jpg)")
        #expect(html.contains("<figure"))
        #expect(html.contains("<figcaption>Beautiful sunset</figcaption>"))
        #expect(html.contains("src=\"sunset.jpg\""))
        #expect(!html.contains("<p>"))
    }

    @Test("Image with empty alt text stays as <p>")
    func implicitFigureNoEmptyAlt() async {
        let html = await RhoeMarkdownKit.toHTML("![](image.jpg)")
        #expect(!html.contains("<figure"))
        #expect(html.contains("<p"))
    }

    @Test("Image with surrounding text stays as <p>")
    func implicitFigureNotLoneImage() async {
        let html = await RhoeMarkdownKit.toHTML("Here is ![photo](img.jpg) in text")
        #expect(!html.contains("<figure"))
        #expect(html.contains("<p"))
    }

    @Test("Implicit figure with title attribute")
    func implicitFigureWithTitle() async {
        let html = await RhoeMarkdownKit.toHTML("![Sunset](sunset.jpg \"A beautiful sunset\")")
        #expect(html.contains("<figure"))
        #expect(html.contains("<figcaption>Sunset</figcaption>"))
    }

    @Test("Implicit figure disabled renders as <p>")
    func implicitFigureDisabled() async {
        let config = RhoeMarkdownKit.Configuration()
        let result = await RhoeMarkdownKit.parse("![Alt text](image.jpg)", configuration: config)
        let htmlConfig = RhoeMarkdownKit.HTMLConfiguration(enableImplicitFigures: false)
        let html = HTMLRenderer(configuration: htmlConfig).render(result.document)
        #expect(!html.contains("<figure"))
        #expect(html.contains("<p"))
    }

    // MARK: - Inline Code Attributes

    @Test("Inline code with class attribute")
    func inlineCodeWithClass() async {
        let html = await RhoeMarkdownKit.toHTML("Use `print()`{.python} for output.")
        #expect(html.contains("<code"))
        #expect(html.contains("class=\"python\""))
        #expect(html.contains("print()"))
    }

    @Test("Inline code with id attribute")
    func inlineCodeWithId() async {
        let html = await RhoeMarkdownKit.toHTML("The `main`{#entry-point} function.")
        #expect(html.contains("id=\"entry-point\""))
        #expect(html.contains("main"))
    }

    @Test("Inline code with multiple attributes")
    func inlineCodeWithMultipleAttrs() async {
        let html = await RhoeMarkdownKit.toHTML("Run `npm install`{.shell .command}.")
        #expect(html.contains("class=\"shell command\""))
        #expect(html.contains("npm install"))
    }

    @Test("Inline code without attributes still works")
    func inlineCodeNoAttributes() async {
        let html = await RhoeMarkdownKit.toHTML("Use `let x = 5` in Swift.")
        #expect(html.contains("<code>let x = 5</code>"))
    }

    // MARK: - Configuration

    @Test("Default configuration enables Sprint 4 features")
    func defaultConfigEnablesSprint4() {
        let config = RhoeMarkdownKit.Configuration.default
        #expect(config.enableAutoIdentifiers == true)
        #expect(config.enableImplicitFigures == true)
        #expect(config.enableImplicitHeaderReferences == true)
        #expect(config.enableIntrawordUnderscores == true)
    }

    @Test("Strict configuration disables Sprint 4 features")
    func strictConfigDisablesSprint4() {
        let config = RhoeMarkdownKit.Configuration.strict
        #expect(config.enableAutoIdentifiers == false)
        #expect(config.enableImplicitFigures == false)
        #expect(config.enableImplicitHeaderReferences == false)
        #expect(config.enableIntrawordUnderscores == false)
    }

    @Test("HTML configuration enables implicit figures by default")
    func htmlConfigDefaultImplicitFigures() {
        let config = RhoeMarkdownKit.HTMLConfiguration.default
        #expect(config.enableImplicitFigures == true)
    }

    // MARK: - Combined / Edge Cases

    @Test("Implicit figure coexists with other features")
    func implicitFigureCoexistence() async {
        let md = """
        # A Heading

        ![Photo](photo.jpg)

        Some **bold** text with `code`{.swift}.
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<figure"))
        #expect(html.contains("<h1"))
        #expect(html.contains("<strong>bold</strong>"))
        #expect(html.contains("class=\"swift\""))
    }
}
