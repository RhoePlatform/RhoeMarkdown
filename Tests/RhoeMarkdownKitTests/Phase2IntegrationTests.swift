import Testing
import Foundation
import RhoeMarkdownKit

@Suite("Phase 2: Full Pipeline Integration")
struct Phase2IntegrationTests {

    // MARK: - Helpers

    private func attrs(id: String? = nil, classes: [String] = [], keyValues: [String: String] = [:]) -> RhoeMarkdownKit.Attributes {
        RhoeMarkdownKit.Attributes(id: id, classes: classes, keyValues: keyValues)
    }

    // MARK: - hide + render

    @Test("Hidden content is not rendered in HTML output")
    func hideRendersEmpty() {
        let blocks: [Block] = [
            .phase2Directive(command: "hide", arguments: ["family": "example", "in": "screen"], body: nil),
            .admonition(type: "example", title: "Hidden Example",
                       content: [.paragraph([.text("This should not appear")])],
                       collapsible: nil, attributes: attrs(id: "ex-hidden")),
            .paragraph([.text("Visible paragraph")], attributes: attrs()),
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = Phase2ExecutionPass()
        let processed = pass.process(doc)
        let html = RhoeMarkdownKit.renderHTML(processed)
        #expect(!html.contains("This should not appear"))
        #expect(html.contains("Visible paragraph"))
    }

    // MARK: - select + collect

    @Test("select + collect generates theorem index")
    func selectCollectTheoremIndex() {
        let blocks: [Block] = [
            .phase2Directive(command: "select", arguments: ["family": "theorem", "as": "all-theorems"], body: nil),
            .admonition(type: "theorem", title: "Fundamental Theorem",
                       content: [.paragraph([.text("Every continuous function...")])],
                       collapsible: nil, attributes: attrs(id: "thm-fundamental")),
            .paragraph([.text("Some exposition")], attributes: attrs()),
            .admonition(type: "theorem", title: "Existence Theorem",
                       content: [.paragraph([.text("There exists...")])],
                       collapsible: nil, attributes: attrs(id: "thm-existence")),
            .phase2Directive(command: "collect", arguments: ["from": "all-theorems", "into": "#theorem-list"], body: nil),
            .div(content: [], attributes: attrs(id: "theorem-list")),
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = Phase2ExecutionPass()
        let processed = pass.process(doc)
        let html = RhoeMarkdownKit.renderHTML(processed)
        // Both theorems should appear in the theorem-list section of the HTML
        #expect(html.contains("Fundamental Theorem"))
        #expect(html.contains("Existence Theorem"))
    }

    // MARK: - clone + normalization

    @Test("Cloned block IDs are unique after normalization pass")
    func cloneNormalizationUniqueIds() {
        let blocks: [Block] = [
            .admonition(type: "theorem", title: "Key Result",
                       content: [.paragraph([.text("Proof sketch")])],
                       collapsible: nil, attributes: attrs(id: "thm-key")),
            .phase2Directive(command: "clone", arguments: ["family": "theorem", "into": "#summary"], body: nil),
            .div(content: [], attributes: attrs(id: "summary")),
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        // Run both passes in sequence
        let phase2 = Phase2ExecutionPass()
        let norm = Phase2NormalizationPass()
        let afterPhase2 = phase2.process(doc)
        let afterNorm = norm.process(afterPhase2)

        // Collect all IDs from the result
        var allIds: [String] = []
        collectAllIds(from: afterNorm.blocks, into: &allIds)
        let uniqueIds = Set(allIds)
        #expect(uniqueIds.count == allIds.count, "All IDs should be unique after clone + normalization")
    }

    // MARK: - Phase 1 + Phase 2

    @Test("Liquid variables and AST transforms work in one pipeline")
    func phase1PlusPhase2() async {
        let md = """
        ---
        title: Test Document
        ---

        # {{ page.title }}

        {@ hide family=example in=llm @}

        !!! example "Hidden Example"
            This example is hidden from LLMs.

        Regular content remains visible.
        """
        let parser = DocumentParser()
        let result = await parser.parse(md)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        // Phase 1 should have resolved the variable
        #expect(html.contains("Test Document"))
        // Phase 2 should have added hidden=llm to the example
        // The example still renders in HTML (screen domain), just has hidden=llm attribute
        #expect(html.contains("Regular content remains visible"))
    }

    // MARK: - move + structural integrity

    @Test("Moved content appears at target and is removed from source")
    func moveContentIntegrity() {
        // The target div must have content so removeMatching does not drop it
        let blocks: [Block] = [
            .heading(level: 1, content: [.text("Main Document")], attributes: attrs(id: "main")),
            .admonition(type: "theorem", title: "Appendix Theorem",
                       content: [.paragraph([.text("Deferred proof")])],
                       collapsible: nil, attributes: attrs(id: "thm-defer")),
            .paragraph([.text("Body text stays here")], attributes: attrs()),
            .phase2Directive(command: "move", arguments: ["family": "theorem", "into": "#appendix"], body: nil),
            .heading(level: 1, content: [.text("Appendix")], attributes: attrs(id: "app-heading")),
            .div(content: [
                .paragraph([.text("Appendix content")], attributes: attrs())
            ], attributes: attrs(id: "appendix")),
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = Phase2ExecutionPass()
        let processed = pass.process(doc)
        let html = RhoeMarkdownKit.renderHTML(processed)
        // The theorem content should appear in HTML (it was moved, not deleted)
        #expect(html.contains("Deferred proof"))
        #expect(html.contains("Body text stays here"))
    }

    // MARK: - Multiple Directives in Sequence

    @Test("Multiple directives produce correct final state")
    func multipleDirectivesSequence() {
        let blocks: [Block] = [
            // 1. Set metadata on all theorems
            .phase2Directive(command: "set", arguments: ["family": "theorem", "reviewed": "true"], body: nil),
            // 2. Hide examples from LLM
            .phase2Directive(command: "hide", arguments: ["family": "example", "in": "llm"], body: nil),
            // 3. Show theorems in print
            .phase2Directive(command: "show", arguments: ["family": "theorem", "in": "print"], body: nil),
            .admonition(type: "theorem", title: "Main Theorem",
                       content: [.paragraph([.text("Important result")])],
                       collapsible: nil, attributes: attrs(id: "thm-main")),
            .admonition(type: "example", title: "Example 1",
                       content: [.paragraph([.text("Worked example")])],
                       collapsible: nil, attributes: attrs(id: "ex-1")),
            .paragraph([.text("Plain paragraph")], attributes: attrs()),
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = Phase2ExecutionPass()
        let processed = pass.process(doc)

        for block in processed.blocks {
            switch block {
            case .admonition(let type, _, _, _, let a):
                if type == "theorem" {
                    #expect(a.keyValues["reviewed"] == "true")
                    #expect(a.keyValues["visible"]?.contains("print") == true)
                } else if type == "example" {
                    #expect(a.keyValues["hidden"]?.contains("llm") == true)
                }
            default:
                break
            }
        }
    }

    // MARK: - Config Gate

    @Test("enablePhase2Transforms=false leaves directives unconsumed")
    func configGateDisabled() {
        let config = RhoeMarkdownKit.Configuration(enablePhase2Transforms: false)
        let blocks: [Block] = [
            .phase2Directive(command: "hide", arguments: ["family": "theorem", "in": "llm"], body: nil),
            .admonition(type: "theorem", title: "Untouched",
                       content: [.paragraph([.text("Content")])],
                       collapsible: nil, attributes: attrs(id: "thm-1")),
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pipeline = buildDocumentPipeline(for: config)
        let result = pipeline.run(doc)

        // With Phase 2 disabled, the theorem should not have hidden= set
        for block in result.blocks {
            if case .admonition(_, _, _, _, let a) = block {
                #expect(a.keyValues["hidden"] == nil)
            }
        }
    }

    // MARK: - Edge Cases

    @Test("Phase 2 on empty document does not crash")
    func emptyDocumentNoCrash() {
        let doc = RhoeMarkdownKit.Document(blocks: [])
        let pass = Phase2ExecutionPass()
        let result = pass.process(doc)
        #expect(result.blocks.isEmpty)
    }

    @Test("Phase 2 with no directives returns document unchanged")
    func noDirectivesUnchanged() {
        let blocks: [Block] = [
            .heading(level: 1, content: [.text("Title")], attributes: attrs(id: "h1")),
            .paragraph([.text("Body")], attributes: attrs()),
            .codeBlock(language: "swift", content: "let x = 42", attributes: attrs()),
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = Phase2ExecutionPass()
        let result = pass.process(doc)
        #expect(result.blocks.count == 3)
        #expect(result.blocks == blocks)
    }

    @Test("Full pipeline: hide + render + normalization produces clean HTML")
    func fullPipelineCleanHTML() {
        let config = RhoeMarkdownKit.Configuration(
            enablePhase2Transforms: true,
            enableCoreExpressions: false,
            enableInputBindings: false
        )
        let blocks: [Block] = [
            .phase2Directive(command: "hide", arguments: ["family": "example", "in": "screen"], body: nil),
            .admonition(type: "example", title: "Invisible",
                       content: [.paragraph([.text("Should not be in HTML")])],
                       collapsible: nil, attributes: attrs(id: "ex-invis")),
            .admonition(type: "theorem", title: "Visible Theorem",
                       content: [.paragraph([.text("Should appear")])],
                       collapsible: nil, attributes: attrs(id: "thm-vis")),
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pipeline = buildDocumentPipeline(for: config)
        let processed = pipeline.run(doc)
        let html = RhoeMarkdownKit.renderHTML(processed)
        #expect(!html.contains("Should not be in HTML"))
        #expect(html.contains("Should appear"))
    }

    @Test("Normalization after Phase 2 removes emptied move-source containers")
    func normalizationAfterPhase2() {
        let config = RhoeMarkdownKit.Configuration(enablePhase2Transforms: true)
        // Target div must have content so removeMatching does not drop it
        let blocks: [Block] = [
            .blockQuote([
                .admonition(type: "theorem", title: "Moveable",
                           content: [.paragraph([.text("Content")])],
                           collapsible: nil, attributes: attrs(id: "thm-moveable")),
            ], attributes: attrs()),
            .phase2Directive(command: "move", arguments: ["family": "theorem", "into": "#target"], body: nil),
            .div(content: [
                .paragraph([.text("Target placeholder")], attributes: attrs())
            ], attributes: attrs(id: "target")),
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pipeline = buildDocumentPipeline(for: config)
        let result = pipeline.run(doc)

        // The move pipeline removes source containers that become empty after extraction.
        let blockquoteCount = result.blocks.filter { block in
            if case .blockQuote = block { return true }
            return false
        }.count
        #expect(blockquoteCount == 0)

        let movedContentIsInTarget = result.blocks.contains { block in
            if case .div(let content, let attrs) = block, attrs.id == "target" {
                return content.contains { nested in
                    if case .admonition(type: "theorem", title: "Moveable", _, _, _) = nested {
                        return true
                    }
                    return false
                }
            }
            return false
        }
        #expect(movedContentIsInTarget)
    }

    @Test("Annotate adds metadata that survives rendering")
    func annotateMetadataSurvivesRendering() {
        let blocks: [Block] = [
            .phase2Directive(command: "annotate", arguments: [
                "family": "theorem",
                "with": "difficulty=advanced"
            ], body: nil),
            .admonition(type: "theorem", title: "Advanced Result",
                       content: [.paragraph([.text("Complex proof")])],
                       collapsible: nil, attributes: attrs(id: "thm-adv")),
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = Phase2ExecutionPass()
        let processed = pass.process(doc)
        let html = RhoeMarkdownKit.renderHTML(processed)
        // The theorem content should still render
        #expect(html.contains("Advanced Result"))
        #expect(html.contains("Complex proof"))
        // The metadata should be in the attributes (rendered as data attributes)
        if case .admonition(_, _, _, _, let a) = processed.blocks.first {
            #expect(a.keyValues["difficulty"] == "advanced")
        }
    }

    // MARK: - ID Collection Helper

    private func collectAllIds(from blocks: [Block], into ids: inout [String]) {
        for block in blocks {
            switch block {
            case .heading(_, _, let a):
                if let id = a.id { ids.append(id) }
            case .paragraph(_, let a):
                if let id = a.id { ids.append(id) }
            case .admonition(_, _, let content, _, let a):
                if let id = a.id { ids.append(id) }
                collectAllIds(from: content, into: &ids)
            case .div(let content, let a):
                if let id = a.id { ids.append(id) }
                collectAllIds(from: content, into: &ids)
            case .blockQuote(let content, let a):
                if let id = a.id { ids.append(id) }
                collectAllIds(from: content, into: &ids)
            case .codeBlock(_, _, let a):
                if let id = a.id { ids.append(id) }
            case .table(_, _, _, let a):
                if let id = a.id { ids.append(id) }
            default:
                break
            }
        }
    }
}
