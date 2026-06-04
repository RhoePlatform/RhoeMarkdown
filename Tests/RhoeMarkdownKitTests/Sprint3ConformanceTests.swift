import Testing
import RhoeMarkdownKit

@Suite("Sprint 3: Block Enhancements")
struct Sprint3ConformanceTests {

    // MARK: - Full YAML Frontmatter

    @Test("Flat key-value YAML still works")
    func yamlFlatKeyValue() async {
        let md = """
        ---
        title: Hello World
        author: Thor
        year: 2026
        ---

        Some text.
        """
        let result = await RhoeMarkdownKit.parse(md)
        let yaml = result.document.metadata.yamlFrontmatter
        #expect(yaml?["title"] == .string("Hello World"))
        #expect(yaml?["author"] == .string("Thor"))
        #expect(yaml?["year"] == .int(2026))
    }

    @Test("Nested YAML mapping")
    func yamlNestedMapping() async {
        let md = """
        ---
        title: My Document
        author:
          name: Thor Fuchs
          email: thor@example.com
        ---

        Content.
        """
        let result = await RhoeMarkdownKit.parse(md)
        let yaml = result.document.metadata.yamlFrontmatter
        #expect(yaml?["title"] == .string("My Document"))
        if case .dictionary(let author) = yaml?["author"] {
            #expect(author["name"] == .string("Thor Fuchs"))
            #expect(author["email"] == .string("thor@example.com"))
        } else {
            #expect(Bool(false), "Expected nested mapping for author")
        }
    }

    @Test("YAML list items with dash syntax")
    func yamlListItems() async {
        let md = """
        ---
        tags:
          - swift
          - markdown
          - parser
        ---

        Content.
        """
        let result = await RhoeMarkdownKit.parse(md)
        let yaml = result.document.metadata.yamlFrontmatter
        if case .array(let tags) = yaml?["tags"] {
            #expect(tags.count == 3)
            #expect(tags[0] == .string("swift"))
            #expect(tags[1] == .string("markdown"))
            #expect(tags[2] == .string("parser"))
        } else {
            #expect(Bool(false), "Expected array for tags")
        }
    }

    @Test("YAML multi-line literal block")
    func yamlLiteralBlock() async {
        let md = """
        ---
        abstract: |
          This is a multi-line
          abstract that preserves
          line breaks.
        ---

        Content.
        """
        let result = await RhoeMarkdownKit.parse(md)
        let yaml = result.document.metadata.yamlFrontmatter
        if case .string(let abstract) = yaml?["abstract"] {
            #expect(abstract.contains("This is a multi-line"))
            #expect(abstract.contains("line breaks."))
        } else {
            #expect(Bool(false), "Expected string for abstract")
        }
    }

    @Test("YAML folded block scalar")
    func yamlFoldedBlock() async {
        let md = """
        ---
        description: >
          This is a long
          description that
          should be folded.
        ---

        Content.
        """
        let result = await RhoeMarkdownKit.parse(md)
        let yaml = result.document.metadata.yamlFrontmatter
        if case .string(let desc) = yaml?["description"] {
            #expect(desc.contains("This is a long"))
            #expect(desc.contains("description"))
        } else {
            #expect(Bool(false), "Expected string for description")
        }
    }

    @Test("YAML flow mapping")
    func yamlFlowMapping() async {
        let md = """
        ---
        crossref: {fig-prefix: Figure, tbl-prefix: Table}
        ---

        Content.
        """
        let result = await RhoeMarkdownKit.parse(md)
        let yaml = result.document.metadata.yamlFrontmatter
        if case .dictionary(let crossref) = yaml?["crossref"] {
            #expect(crossref["fig-prefix"] == .string("Figure"))
            #expect(crossref["tbl-prefix"] == .string("Table"))
        } else {
            #expect(Bool(false), "Expected dictionary for crossref")
        }
    }

    @Test("YAML anchors and aliases")
    func yamlAnchorsAndAliases() async {
        let md = """
        ---
        base_url: &url https://example.com
        site_url: *url
        ---

        Content.
        """
        let result = await RhoeMarkdownKit.parse(md)
        let yaml = result.document.metadata.yamlFrontmatter
        #expect(yaml?["base_url"] == .string("https://example.com"))
        #expect(yaml?["site_url"] == .string("https://example.com"))
    }

    @Test("YAML complex nested structure")
    func yamlComplexNested() async {
        let md = """
        ---
        title: Research Paper
        bibliography: refs.bib
        csl: apa.csl
        keywords:
          - machine learning
          - natural language processing
        author:
          - name: Alice
            affiliation: MIT
          - name: Bob
            affiliation: Stanford
        ---

        Content.
        """
        let result = await RhoeMarkdownKit.parse(md)
        let yaml = result.document.metadata.yamlFrontmatter
        #expect(yaml?["title"] == .string("Research Paper"))
        #expect(yaml?["bibliography"] == .string("refs.bib"))

        if case .array(let keywords) = yaml?["keywords"] {
            #expect(keywords.count == 2)
        } else {
            #expect(Bool(false), "Expected array for keywords")
        }

        if case .array(let authors) = yaml?["author"] {
            #expect(authors.count == 2)
            if case .dictionary(let first) = authors[0] {
                #expect(first["name"] == .string("Alice"))
                #expect(first["affiliation"] == .string("MIT"))
            }
        } else {
            #expect(Bool(false), "Expected array for author")
        }
    }

    // MARK: - Table Captions

    @Test("Table with caption before")
    func tableCaptionBefore() async {
        let md = """
        Table: Sales by Quarter

        | Quarter | Revenue |
        |---------|---------|
        | Q1      | $100K   |
        | Q2      | $150K   |
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<caption>Sales by Quarter</caption>"))
        #expect(html.contains("<table"))
    }

    @Test("Table with caption after")
    func tableCaptionAfter() async {
        let md = """
        | Name  | Age |
        |-------|-----|
        | Alice | 30  |

        Table: Team Members
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<caption>Team Members</caption>"))
    }

    @Test("Table with lowercase table: prefix caption")
    func tableCaptionLowercasePrefix() async {
        let md = """
        table: Population Data

        | City    | Pop  |
        |---------|------|
        | Berlin  | 3.6M |
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<caption>Population Data</caption>"))
    }

    @Test("Table without caption stays normal")
    func tableWithoutCaption() async {
        let md = """
        | A | B |
        |---|---|
        | 1 | 2 |
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(!html.contains("<caption>"))
        #expect(html.contains("<table"))
    }

    @Test("Table caption disabled in strict config")
    func tableCaptionDisabledStrict() async {
        let md = """
        Table: My Caption

        | A | B |
        |---|---|
        | 1 | 2 |
        """
        let config = RhoeMarkdownKit.Configuration.strict
        let result = await RhoeMarkdownKit.parse(md, configuration: config)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(!html.contains("<caption>"))
    }

    // MARK: - Grid Tables

    @Test("Basic grid table")
    func gridTableBasic() async {
        let md = """
        +------+------+
        | Head | Head |
        +======+======+
        | A    | B    |
        +------+------+
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<table"))
        #expect(html.contains("<th"))
        #expect(html.contains("<td>"))
        #expect(html.contains("Head"))
    }

    @Test("Grid table without header separator")
    func gridTableNoHeaderSep() async {
        let md = """
        +------+------+
        | A    | B    |
        +------+------+
        | 1    | 2    |
        +------+------+
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<table"))
        #expect(html.contains("<th"))
        #expect(html.contains("<td>"))
    }

    @Test("Grid table disabled in strict mode")
    func gridTableStrict() async {
        let md = """
        +---+---+
        | A | B |
        +===+===+
        | 1 | 2 |
        +---+---+
        """
        let config = RhoeMarkdownKit.Configuration.strict
        let result = await RhoeMarkdownKit.parse(md, configuration: config)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(!html.contains("<table>"))
    }

    // MARK: - Mermaid Diagrams

    @Test("Mermaid code block renders with mermaid class")
    func mermaidRendering() async {
        let md = """
        ```mermaid
        graph TD
            A --> B
        ```
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<pre class=\"mermaid\">"))
        #expect(html.contains("graph TD"))
        #expect(!html.contains("<code"))
    }

    @Test("Non-mermaid code blocks still use code element")
    func nonMermaidCodeBlock() async {
        let md = """
        ```python
        print("hello")
        ```
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<code"))
        #expect(!html.contains("class=\"mermaid\""))
    }

    // MARK: - Configuration

    @Test("Default configuration enables Sprint 3 features")
    func defaultConfigEnablesSprint3() {
        let config = RhoeMarkdownKit.Configuration.default
        #expect(config.enableGridTables == true)
        #expect(config.enableTableCaptions == true)
    }

    @Test("Strict configuration disables Sprint 3 features")
    func strictConfigDisablesSprint3() {
        let config = RhoeMarkdownKit.Configuration.strict
        #expect(config.enableGridTables == false)
        #expect(config.enableTableCaptions == false)
    }

    // MARK: - Combined / Edge Cases

    @Test("Grid table with inline formatting in cells")
    func gridTableWithFormatting() async {
        let md = """
        +----------+----------+
        | **Bold** | *Italic* |
        +==========+==========+
        | `code`   | Normal   |
        +----------+----------+
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<strong>Bold</strong>"))
        #expect(html.contains("<em>Italic</em>"))
        #expect(html.contains("<code>code</code>"))
    }

    @Test("Table caption with inline formatting")
    func tableCaptionWithFormatting() async {
        let md = """
        Table: Results for **2026**

        | Metric | Value |
        |--------|-------|
        | Score  | 95    |
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<caption>"))
        #expect(html.contains("2026"))
    }

    @Test("Multiple features coexist")
    func sprint3Coexistence() async {
        let md = """
        ---
        title: Full Document
        tags:
          - test
          - sprint3
        ---

        # Introduction

        Table: Key Metrics

        | Metric | Value |
        |--------|-------|
        | Tests  | All   |

        ```mermaid
        graph LR
            A --> B
        ```
        """
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<caption>Key Metrics</caption>"))
        #expect(html.contains("<pre class=\"mermaid\">"))
        #expect(html.contains("<h1"))
    }
}
