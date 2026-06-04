import Testing
import RhoeMarkdownKit

@Suite("Sprint R7: Table Semantic Enrichment")
struct SprintR7ConformanceTests {

    // MARK: - R7.1 Header Scope Attributes

    @Test("Table header cells get scope=col")
    func headerCellsScopeCol() async {
        let md = "| A | B |\n|---|---|\n| 1 | 2 |"
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("scope=\"col\""))
        #expect(html.contains("<th"))
    }

    // MARK: - R7.2 Table Rendering Structure

    @Test("Table renders with rhoe-table class")
    func tableHasRhoeTableClass() async {
        let md = "| A | B |\n|---|---|\n| 1 | 2 |"
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("rhoe-table"))
        #expect(html.contains("<table"))
        #expect(html.contains("<thead>"))
        #expect(html.contains("<tbody>"))
    }

    @Test("Table with caption renders caption element")
    func tableCaption() async {
        let md = "Table: Revenue Summary\n\n| Q1 | Q2 |\n|---|---|\n| 100 | 200 |"
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<caption>"))
    }

    // MARK: - R7.3 Table Numbering

    @Test("Cross-reference numbering pass handles table prefix")
    func tableNumberingPassSupportsTablePrefix() async {
        // Verify the numbering pass recognizes "tbl" as a valid prefix
        let pass = CrossReferenceNumberingPass()
        // Create a document with a table that has an ID
        let table = Block.table(
            headers: [TableCell(content: [.text("A")])],
            rows: [[TableCell(content: [.text("1")])]],
            attributes: RhoeMarkdownKit.Attributes(id: "tbl-results")
        )
        let doc = RhoeMarkdownKit.Document(blocks: [table])
        let processed = pass.process(doc)
        let numbers = processed.metadata.resolvedReferences.elementNumbers
        #expect(numbers["tbl-results"] != nil)
    }

    @Test("Table cross-reference resolves")
    func tableCrossRef() async {
        let md = "| A | B |\n|---|---|\n| 1 | 2 |\n{#tbl-data}\n\nSee @tbl-data."
        let result = await RhoeMarkdownKit.parse(md)
        let pipeline = buildDocumentPipeline(for: .default)
        let processed = pipeline.run(result.document)
        let html = RhoeMarkdownKit.renderHTML(processed)
        #expect(html.contains("Table"))
    }

    // MARK: - R7.4 Table Semantic Keys (Attribute-Driven)

    @Test("Table kind attribute renders correctly when present in AST")
    func tableKindRendering() async {
        // Construct a table with kind=data directly (bypasses parser attribute limitation)
        let table = Block.table(
            headers: [TableCell(content: [.text("A")]), TableCell(content: [.text("B")])],
            rows: [[TableCell(content: [.text("1")]), TableCell(content: [.text("2")])]],
            attributes: RhoeMarkdownKit.Attributes(keyValues: ["kind": "data"])
        )
        let doc = RhoeMarkdownKit.Document(blocks: [table])
        let html = RhoeMarkdownKit.renderHTML(doc)
        #expect(html.contains("data-rhoe-kind=\"data\""))
        #expect(html.contains("rhoe-table-data"))
    }

    @Test("Layout table with kind=layout excluded from numbering")
    func layoutTableNotNumbered() async {
        let md = "| A | B |\n|---|---|\n| 1 | 2 |\n{#tbl-grid kind=layout}"
        let result = await RhoeMarkdownKit.parse(md)
        let pipeline = buildDocumentPipeline(for: .default)
        let processed = pipeline.run(result.document)
        let numbers = processed.metadata.resolvedReferences.elementNumbers
        #expect(numbers["tbl-grid"] == nil)
    }

    @Test("Writers handle table blocks without crashing")
    func writersHandleTable() async {
        let md = "| A | B |\n|---|---|\n| 1 | 2 |"
        let result = await RhoeMarkdownKit.parse(md)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        let latex = RhoeMarkdownKit.renderLaTeX(result.document)
        let typst = RhoeMarkdownKit.renderTypst(result.document)
        #expect(!html.isEmpty)
        #expect(!latex.isEmpty)
        #expect(!typst.isEmpty)
    }
}
