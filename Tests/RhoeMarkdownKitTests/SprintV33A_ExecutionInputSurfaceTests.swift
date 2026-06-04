import Testing
import RhoeMarkdownKit
import RhoeMarkdownModel

@Suite("v3.3 Wave A: Execution + Input Surfaces")
struct SprintV33AExecutionInputSurfaceTests {

    @Test("recognized kernel fence with execution attributes parses to executableCodeBlock")
    func executableCodeBlockParse() async {
        let markdown = """
        ```python {in=data out=result runtime=shared}
        result = sum(data)
        ```
        """

        let result = await RhoeMarkdownKit.parse(markdown)
        #expect(result.document.blocks.count == 1)
        guard case let .executableCodeBlock(language, content, attributes) = result.document.blocks[0] else {
            Issue.record("Expected executableCodeBlock from fenced kernel cell.")
            return
        }
        #expect(language == "python")
        #expect(content == "result = sum(data)\n")
        #expect(attributes.keyValues["in"] == "data")
        #expect(attributes.keyValues["out"] == "result")
        #expect(attributes.keyValues["runtime"] == "shared")
    }

    @Test("recognized kernel fence without execution attributes stays codeBlock")
    func plainKernelFenceStaysCodeBlock() async {
        let markdown = """
        ```python
        print("hello")
        ```
        """

        let result = await RhoeMarkdownKit.parse(markdown)
        #expect(result.document.blocks.count == 1)
        guard case let .codeBlock(language, content, _) = result.document.blocks[0] else {
            Issue.record("Expected plain codeBlock when no execution attributes are present.")
            return
        }
        #expect(language == "python")
        #expect(content == "print(\"hello\")\n")
    }

    @Test("writers serialize executableCodeBlock without crashing")
    func executableCodeBlockWriters() {
        let document = RhoeMarkdownKit.Document(blocks: [
            .executableCodeBlock(
                language: "swift",
                content: "let result = data.reduce(0, +)",
                attributes: .init(keyValues: ["in": "data", "out": "result", "runtime": "shared"])
            )
        ])

        let html = RhoeMarkdownKit.renderHTML(document)
        let json = String(data: RhoeMarkdownKit.renderJSON(document), encoding: .utf8) ?? ""

        #expect(html.contains("ExecutableCodeBlock") || html.contains("executable"))
        #expect(json.contains("ExecutableCodeBlock"))
        #expect(json.contains("runtime"))
    }
}
