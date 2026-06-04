import Testing
import Foundation
import RhoeMarkdownKit
import RhoeMarkdownModel

@Suite("Wave 3: Phase 2 Transforms + AST-Near Emission")
struct SprintW3ConformanceTests {

    // MARK: - W3-1: Phase 2 Parsing

    @Test("Phase 2 directive AST node constructs correctly")
    func phase2DirectiveConstruction() {
        let block = Block.phase2Directive(
            command: "hide",
            arguments: ["role": "decorative", "in": "llm"],
            body: nil
        )
        if case .phase2Directive(let cmd, let args, _, _) = block {
            #expect(cmd == "hide")
            #expect(args["role"] == "decorative")
        } else {
            #expect(Bool(false), "Expected phase2Directive")
        }
    }

    @Test("Phase 2 collect directive stores arguments correctly")
    func phase2CollectArguments() {
        let block = Block.phase2Directive(
            command: "collect",
            arguments: ["family": "theorem", "into": "#theorem-index"],
            body: nil
        )
        if case .phase2Directive(let cmd, let args, _, _) = block {
            #expect(cmd == "collect")
            #expect(args["family"] == "theorem")
            #expect(args["into"] == "#theorem-index")
        }
    }

    @Test("Phase 2 disabled when enablePhase2Transforms is false")
    func phase2Disabled() async {
        let config = RhoeMarkdownKit.Configuration(enablePhase2Transforms: false)
        let result = await RhoeMarkdownKit.parse("{@ hide role=decorative in=llm @}", configuration: config)
        let hasPhase2 = result.document.blocks.contains { block in
            if case .phase2Directive = block { return true }
            return false
        }
        #expect(!hasPhase2)
    }

    @Test("All writers handle phase2Directive without crashing")
    func writersHandlePhase2() {
        let block = Block.phase2Directive(command: "hide", arguments: ["role": "decorative", "in": "llm"], body: nil)
        let doc = RhoeMarkdownKit.Document(blocks: [block])
        let html = RhoeMarkdownKit.renderHTML(doc)
        let latex = RhoeMarkdownKit.renderLaTeX(doc)
        let typst = RhoeMarkdownKit.renderTypst(doc)
        // Phase 2 directives render as empty (executed in pipeline)
        #expect(html.isEmpty || !html.contains("ERROR"))
        #expect(latex.isEmpty || !latex.contains("ERROR"))
        #expect(typst.isEmpty || !typst.contains("ERROR"))
    }

    // MARK: - W3-2: Phase 2 Execution

    @Test("Phase 2 hide command adds hidden attribute")
    func phase2HideCommand() {
        let blocks: [Block] = [
            .phase2Directive(command: "hide", arguments: ["family": "example", "in": "llm"], body: nil),
            .admonition(type: "example", title: "Example 1", content: [.paragraph([.text("Content")])], collapsible: nil)
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = Phase2ExecutionPass()
        let result = pass.process(doc)

        // Directive should be removed, example should have hidden=llm
        let hasDirective = result.blocks.contains { if case .phase2Directive = $0 { return true }; return false }
        #expect(!hasDirective)

        for block in result.blocks {
            if case .admonition(_, _, _, _, let attrs) = block {
                #expect(attrs.keyValues["hidden"]?.contains("llm") == true)
                return
            }
        }
        #expect(Bool(false), "Admonition not found after Phase 2")
    }

    @Test("Phase 2 show command adds visible attribute")
    func phase2ShowCommand() {
        let blocks: [Block] = [
            .phase2Directive(command: "show", arguments: ["role": "warning", "in": "summary"], body: nil),
            .admonition(type: "warning", title: nil, content: [.paragraph([.text("Caution")])], collapsible: nil, attributes: .init(keyValues: ["role": "warning"]))
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = Phase2ExecutionPass()
        let result = pass.process(doc)

        for block in result.blocks {
            if case .admonition(_, _, _, _, let attrs) = block {
                #expect(attrs.keyValues["visible"]?.contains("summary") == true)
                return
            }
        }
    }

    @Test("Phase 2 set command mutates metadata")
    func phase2SetCommand() {
        let blocks: [Block] = [
            .phase2Directive(command: "set", arguments: ["family": "theorem", "summary": "Key result"], body: nil),
            .admonition(type: "theorem", title: "Main", content: [.paragraph([.text("Proof")])], collapsible: nil)
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = Phase2ExecutionPass()
        let result = pass.process(doc)

        for block in result.blocks {
            if case .admonition(_, _, _, _, let attrs) = block {
                #expect(attrs.keyValues["summary"] == "Key result")
                return
            }
        }
    }

    @Test("Phase 2 directives removed after execution")
    func phase2DirectivesRemoved() {
        let blocks: [Block] = [
            .phase2Directive(command: "hide", arguments: ["family": "example", "in": "llm"], body: nil),
            .paragraph([.text("Kept")])
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = Phase2ExecutionPass()
        let result = pass.process(doc)
        #expect(result.blocks.count == 1)
        if case .paragraph = result.blocks.first {} else {
            #expect(Bool(false), "Expected paragraph, got something else")
        }
    }

    @Test("Phase 2 sequential execution: later directives see earlier results")
    func phase2Sequential() {
        let blocks: [Block] = [
            .phase2Directive(command: "set", arguments: ["family": "theorem", "importance": "high"], body: nil),
            .phase2Directive(command: "set", arguments: ["family": "theorem", "reviewed": "true"], body: nil),
            .admonition(type: "theorem", title: "T1", content: [.paragraph([.text("Body")])], collapsible: nil)
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = Phase2ExecutionPass()
        let result = pass.process(doc)

        for block in result.blocks {
            if case .admonition(_, _, _, _, let attrs) = block {
                #expect(attrs.keyValues["importance"] == "high")
                #expect(attrs.keyValues["reviewed"] == "true")
                return
            }
        }
    }

    // MARK: - W3-4: OutputFormat.json + data-rhoe

    @Test("JSON output contains Phase 2 directives when present")
    func jsonSerializesPhase2() {
        let block = Block.phase2Directive(command: "collect", arguments: ["family": "theorem", "into": "#index"], body: nil)
        let doc = RhoeMarkdownKit.Document(blocks: [block])
        let data = RhoeMarkdownKit.renderJSON(doc)
        let jsonStr = String(data: data, encoding: .utf8)!
        // v4.0: JSON uses PascalCase node name "Phase2Directive"
        #expect(jsonStr.contains("Phase2Directive"))
        #expect(jsonStr.contains("collect"))
        #expect(jsonStr.contains("theorem"))
    }
}
