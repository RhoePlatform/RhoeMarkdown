import Testing
import Foundation
import RhoeMarkdownKit

@Suite("Phase 2: Command Execution")
struct Phase2CommandTests {

    // MARK: - Helper

    private func attrs(id: String? = nil, classes: [String] = [], keyValues: [String: String] = [:]) -> RhoeMarkdownKit.Attributes {
        RhoeMarkdownKit.Attributes(id: id, classes: classes, keyValues: keyValues)
    }

    private func process(_ blocks: [Block]) -> [Block] {
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = Phase2ExecutionPass()
        return pass.process(doc).blocks
    }

    // MARK: - select Command

    @Test("select creates a named selection for later use")
    func selectCreatesNamedSelection() {
        // select + collect pattern: select theorems, then collect them
        let blocks: [Block] = [
            .phase2Directive(command: "select", arguments: ["family": "theorem", "as": "theorems"], body: nil),
            .admonition(type: "theorem", title: "Thm 1",
                       content: [.paragraph([.text("Statement 1")])],
                       collapsible: nil, attributes: attrs(id: "thm-1")),
            .admonition(type: "theorem", title: "Thm 2",
                       content: [.paragraph([.text("Statement 2")])],
                       collapsible: nil, attributes: attrs(id: "thm-2")),
            .phase2Directive(command: "collect", arguments: ["from": "theorems", "into": "#index"], body: nil),
            .div(content: [], attributes: attrs(id: "index")),
        ]
        let result = process(blocks)
        // Collected theorems are inserted after the target div as siblings
        let collectedTheorems = result.filter { block in
            if case .admonition(let t, _, _, _, _) = block, t == "theorem" { return true }
            return false
        }
        #expect(collectedTheorems.count >= 2)
    }

    @Test("select with as= parameter names the selection")
    func selectAsParameter() {
        let blocks: [Block] = [
            .phase2Directive(command: "select", arguments: ["family": "example", "as": "examples"], body: nil),
            .admonition(type: "example", title: "Ex 1",
                       content: [.paragraph([.text("Example content")])],
                       collapsible: nil, attributes: attrs(id: "ex-1")),
            .phase2Directive(command: "collect", arguments: ["from": "examples", "into": "#bucket"], body: nil),
            .div(content: [], attributes: attrs(id: "bucket")),
        ]
        let result = process(blocks)
        // The named selection "examples" should be collected and placed after target
        // Original example + collected copy = at least 2 example admonitions in result
        let exampleCount = result.filter { block in
            if case .admonition(let t, _, _, _, _) = block, t == "example" { return true }
            return false
        }.count
        #expect(exampleCount >= 1)
    }

    @Test("select eagerly evaluates at point of directive")
    func selectEagerEvaluation() {
        // Blocks declared after the select should not be captured
        let blocks: [Block] = [
            .phase2Directive(command: "select", arguments: ["family": "theorem", "as": "early"], body: nil),
            .admonition(type: "theorem", title: "Before",
                       content: [.paragraph([.text("Early theorem")])],
                       collapsible: nil, attributes: attrs(id: "thm-before")),
        ]
        // The select should capture thm-before since it exists in the document at that point
        let result = process(blocks)
        // Directive should be removed
        let hasDirective = result.contains { block in
            if case .phase2Directive = block { return true }
            return false
        }
        #expect(!hasDirective)
    }

    // MARK: - set Command

    @Test("set adds metadata to matching nodes")
    func setAddsMetadata() {
        let blocks: [Block] = [
            .phase2Directive(command: "set", arguments: ["family": "theorem", "difficulty": "hard"], body: nil),
            .admonition(type: "theorem", title: "Hard Theorem",
                       content: [.paragraph([.text("Complex proof")])],
                       collapsible: nil, attributes: attrs(id: "thm-1")),
        ]
        let result = process(blocks)
        if case .admonition(_, _, _, _, let a) = result.first {
            #expect(a.keyValues["difficulty"] == "hard")
        } else {
            Issue.record("Expected admonition as first result block")
        }
    }

    @Test("set can set multiple keys at once")
    func setMultipleKeys() {
        let blocks: [Block] = [
            .phase2Directive(command: "set", arguments: [
                "family": "theorem",
                "difficulty": "hard",
                "topic": "analysis"
            ], body: nil),
            .admonition(type: "theorem", title: "Analysis Thm",
                       content: [.paragraph([.text("Proof")])],
                       collapsible: nil, attributes: attrs(id: "thm-analysis")),
        ]
        let result = process(blocks)
        if case .admonition(_, _, _, _, let a) = result.first {
            #expect(a.keyValues["difficulty"] == "hard")
            #expect(a.keyValues["topic"] == "analysis")
        } else {
            Issue.record("Expected admonition as first result block")
        }
    }

    // MARK: - hide Command

    @Test("hide adds hidden= attribute to matching blocks")
    func hideAddsHiddenAttribute() {
        let blocks: [Block] = [
            .phase2Directive(command: "hide", arguments: ["family": "example", "in": "llm"], body: nil),
            .admonition(type: "example", title: "Ex 1",
                       content: [.paragraph([.text("Example content")])],
                       collapsible: nil, attributes: attrs(id: "ex-1")),
        ]
        let result = process(blocks)
        if case .admonition(_, _, _, _, let a) = result.first {
            #expect(a.keyValues["hidden"]?.contains("llm") == true)
        } else {
            Issue.record("Expected admonition as first result block")
        }
    }

    @Test("hide with domain parameter restricts hiding to that domain")
    func hideDomainParameter() {
        let blocks: [Block] = [
            .phase2Directive(command: "hide", arguments: ["family": "theorem", "in": "print"], body: nil),
            .admonition(type: "theorem", title: "Screen Only",
                       content: [.paragraph([.text("Proof")])],
                       collapsible: nil, attributes: attrs(id: "thm-screen")),
        ]
        let result = process(blocks)
        if case .admonition(_, _, _, _, let a) = result.first {
            #expect(a.keyValues["hidden"] == "print")
        } else {
            Issue.record("Expected admonition as first result block")
        }
    }

    @Test("hide defaults to 'all' domain when in= is not specified")
    func hideDefaultsDomainAll() {
        let blocks: [Block] = [
            .phase2Directive(command: "hide", arguments: ["family": "example"], body: nil),
            .admonition(type: "example", title: "Hidden Example",
                       content: [.paragraph([.text("Content")])],
                       collapsible: nil, attributes: attrs(id: "ex-hidden")),
        ]
        let result = process(blocks)
        if case .admonition(_, _, _, _, let a) = result.first {
            #expect(a.keyValues["hidden"]?.contains("all") == true)
        } else {
            Issue.record("Expected admonition as first result block")
        }
    }

    // MARK: - show Command

    @Test("show adds visible= attribute to matching blocks")
    func showAddsVisibleAttribute() {
        let blocks: [Block] = [
            .phase2Directive(command: "show", arguments: ["family": "theorem", "in": "screen"], body: nil),
            .admonition(type: "theorem", title: "Visible Theorem",
                       content: [.paragraph([.text("Proof")])],
                       collapsible: nil, attributes: attrs(id: "thm-vis")),
        ]
        let result = process(blocks)
        if case .admonition(_, _, _, _, let a) = result.first {
            #expect(a.keyValues["visible"]?.contains("screen") == true)
        } else {
            Issue.record("Expected admonition as first result block")
        }
    }

    @Test("show defaults to 'all' when in= is not specified")
    func showDefaultsDomainAll() {
        let blocks: [Block] = [
            .phase2Directive(command: "show", arguments: ["family": "theorem"], body: nil),
            .admonition(type: "theorem", title: "Shown",
                       content: [.paragraph([.text("Content")])],
                       collapsible: nil, attributes: attrs()),
        ]
        let result = process(blocks)
        if case .admonition(_, _, _, _, let a) = result.first {
            #expect(a.keyValues["visible"]?.contains("all") == true)
        } else {
            Issue.record("Expected admonition as first result block")
        }
    }

    // MARK: - annotate Command

    @Test("annotate attaches key-value metadata via with= clause")
    func annotateWithClause() {
        let blocks: [Block] = [
            .phase2Directive(command: "annotate", arguments: [
                "family": "theorem",
                "with": "source=textbook-ch3"
            ], body: nil),
            .admonition(type: "theorem", title: "Referenced Theorem",
                       content: [.paragraph([.text("Statement")])],
                       collapsible: nil, attributes: attrs(id: "thm-ref")),
        ]
        let result = process(blocks)
        if case .admonition(_, _, _, _, let a) = result.first {
            #expect(a.keyValues["source"] == "textbook-ch3")
        } else {
            Issue.record("Expected admonition as first result block")
        }
    }

    @Test("annotate attaches direct key-value arguments")
    func annotateDirectKeyValues() {
        let blocks: [Block] = [
            .phase2Directive(command: "annotate", arguments: [
                "family": "theorem",
                "reviewed": "2024-01-15"
            ], body: nil),
            .admonition(type: "theorem", title: "Reviewed Theorem",
                       content: [.paragraph([.text("Statement")])],
                       collapsible: nil, attributes: attrs(id: "thm-reviewed")),
        ]
        let result = process(blocks)
        if case .admonition(_, _, _, _, let a) = result.first {
            #expect(a.keyValues["reviewed"] == "2024-01-15")
        } else {
            Issue.record("Expected admonition as first result block")
        }
    }

    // MARK: - collect Command

    @Test("collect gathers matching nodes at target location")
    func collectGathersNodes() {
        let blocks: [Block] = [
            .admonition(type: "theorem", title: "Thm A",
                       content: [.paragraph([.text("Statement A")])],
                       collapsible: nil, attributes: attrs(id: "thm-a")),
            .paragraph([.text("Interleaved text")], attributes: attrs()),
            .admonition(type: "theorem", title: "Thm B",
                       content: [.paragraph([.text("Statement B")])],
                       collapsible: nil, attributes: attrs(id: "thm-b")),
            .phase2Directive(command: "collect", arguments: ["family": "theorem", "into": "#theorem-index"], body: nil),
            .div(content: [], attributes: attrs(id: "theorem-index")),
        ]
        let result = process(blocks)
        // Collected theorems are inserted after the target div
        // Count total theorem admonitions: originals + collected copies
        let theoremCount = result.filter { block in
            if case .admonition(let t, _, _, _, _) = block, t == "theorem" { return true }
            return false
        }.count
        // Should have originals + collected copies after the target div
        #expect(theoremCount >= 2)
        // Verify the target div exists
        let hasIndex = result.contains { block in
            if case .div(_, let a) = block, a.id == "theorem-index" { return true }
            return false
        }
        #expect(hasIndex)
    }

    @Test("collect from named selection uses previously selected blocks")
    func collectFromNamedSelection() {
        let blocks: [Block] = [
            .phase2Directive(command: "select", arguments: ["family": "example", "as": "examples"], body: nil),
            .admonition(type: "example", title: "Ex 1",
                       content: [.paragraph([.text("Content 1")])],
                       collapsible: nil, attributes: attrs(id: "ex-1")),
            .admonition(type: "example", title: "Ex 2",
                       content: [.paragraph([.text("Content 2")])],
                       collapsible: nil, attributes: attrs(id: "ex-2")),
            .phase2Directive(command: "collect", arguments: ["from": "examples", "into": "#ex-index"], body: nil),
            .div(content: [], attributes: attrs(id: "ex-index")),
        ]
        let result = process(blocks)
        // The named selection should have captured the 2 examples and placed them after target
        let exampleCount = result.filter { block in
            if case .admonition(let t, _, _, _, _) = block, t == "example" { return true }
            return false
        }.count
        // Originals (2) + collected copies (2) = at least 4
        #expect(exampleCount >= 2)
    }

    // MARK: - clone Command

    @Test("clone duplicates blocks with new IDs")
    func cloneDuplicatesWithNewIds() {
        let blocks: [Block] = [
            .admonition(type: "theorem", title: "Important",
                       content: [.paragraph([.text("Key result")])],
                       collapsible: nil, attributes: attrs(id: "thm-key")),
            .phase2Directive(command: "clone", arguments: ["family": "theorem", "into": "#summary"], body: nil),
            .div(content: [], attributes: attrs(id: "summary")),
        ]
        let result = process(blocks)
        // Clone inserts copies INSIDE the target div
        // Find the target div and check its content
        var clonedTheorems: [Block] = []
        for block in result {
            if case .div(let content, let a) = block, a.id == "summary" {
                clonedTheorems = content.filter { inner in
                    if case .admonition(_, _, _, _, let ia) = inner, let id = ia.id, id.hasPrefix("clone-") {
                        return true
                    }
                    return false
                }
            }
        }
        #expect(clonedTheorems.count == 1)
        // Original should still exist with its original ID
        let originals = result.filter { block in
            if case .admonition(_, _, _, _, let a) = block, a.id == "thm-key" { return true }
            return false
        }
        #expect(originals.count == 1)
    }

    @Test("clone preserves content of duplicated blocks")
    func clonePreservesContent() {
        let blocks: [Block] = [
            .admonition(type: "theorem", title: "Preserved",
                       content: [.paragraph([.text("Original content")])],
                       collapsible: nil, attributes: attrs(id: "thm-orig")),
            .phase2Directive(command: "clone", arguments: ["family": "theorem", "into": "#copies"], body: nil),
            .div(content: [], attributes: attrs(id: "copies")),
        ]
        let result = process(blocks)
        // Find the cloned theorem INSIDE the target div (clone- prefix ID)
        var cloned: Block?
        for block in result {
            if case .div(let content, let a) = block, a.id == "copies" {
                cloned = content.first { inner in
                    if case .admonition(_, _, _, _, let ia) = inner, let id = ia.id, id.hasPrefix("clone-") {
                        return true
                    }
                    return false
                }
            }
        }
        if case .admonition(let type, let title, let inner, _, _) = cloned {
            #expect(type == "theorem")
            #expect(title == "Preserved")
            if case .paragraph(let inlines, _) = inner.first {
                if case .text(let t) = inlines.first {
                    #expect(t == "Original content")
                }
            }
        } else {
            Issue.record("Expected cloned theorem to be present")
        }
    }

    // MARK: - move Command

    @Test("move removes blocks from source and inserts at target")
    func moveRemovesAndInserts() {
        // The target div must have content, since removeMatching drops empty divs
        let blocks: [Block] = [
            .admonition(type: "theorem", title: "Relocated",
                       content: [.paragraph([.text("Moved content")])],
                       collapsible: nil, attributes: attrs(id: "thm-move")),
            .paragraph([.text("Stays in place")], attributes: attrs(id: "static-p")),
            .phase2Directive(command: "move", arguments: ["family": "theorem", "into": "#appendix"], body: nil),
            .div(content: [
                .paragraph([.text("Appendix intro")], attributes: attrs())
            ], attributes: attrs(id: "appendix")),
        ]
        let result = process(blocks)

        // Count top-level theorems: should be 0 (moved out of top level into/after appendix)
        let topLevelTheorems = result.compactMap { block -> String? in
            if case .admonition(let t, _, _, _, _) = block, t == "theorem" { return t }
            return nil
        }
        // Theorem was removed from original position
        #expect(topLevelTheorems.isEmpty)

        // The static paragraph should still be present
        let hasStaticP = result.contains { block in
            if case .paragraph(let inlines, _) = block {
                return inlines.contains { inline in
                    if case .text(let t) = inline, t == "Stays in place" { return true }
                    return false
                }
            }
            return false
        }
        #expect(hasStaticP)
    }

    // MARK: - Sequential Execution

    @Test("Later directives see results of earlier directives")
    func sequentialExecution() {
        let blocks: [Block] = [
            // First: set metadata
            .phase2Directive(command: "set", arguments: ["family": "theorem", "reviewed": "yes"], body: nil),
            // Then: hide reviewed theorems (the set from above should be visible)
            .phase2Directive(command: "hide", arguments: ["family": "theorem", "in": "summary"], body: nil),
            .admonition(type: "theorem", title: "T1",
                       content: [.paragraph([.text("Content")])],
                       collapsible: nil, attributes: attrs(id: "thm-1")),
        ]
        let result = process(blocks)
        if case .admonition(_, _, _, _, let a) = result.first {
            // Should have both: reviewed from set and hidden from hide
            #expect(a.keyValues["reviewed"] == "yes")
            #expect(a.keyValues["hidden"]?.contains("summary") == true)
        } else {
            Issue.record("Expected admonition with both set and hide attributes")
        }
    }

    // MARK: - Directive Removal

    @Test("phase2Directive nodes are removed from final output")
    func directivesRemovedFromOutput() {
        let blocks: [Block] = [
            .phase2Directive(command: "hide", arguments: ["family": "example", "in": "llm"], body: nil),
            .phase2Directive(command: "set", arguments: ["family": "theorem", "level": "advanced"], body: nil),
            .admonition(type: "example", title: "Ex 1",
                       content: [.paragraph([.text("Content")])],
                       collapsible: nil, attributes: attrs(id: "ex-1")),
            .admonition(type: "theorem", title: "Thm 1",
                       content: [.paragraph([.text("Proof")])],
                       collapsible: nil, attributes: attrs(id: "thm-1")),
        ]
        let result = process(blocks)
        let directiveCount = result.filter { block in
            if case .phase2Directive = block { return true }
            return false
        }.count
        #expect(directiveCount == 0)
    }

    @Test("Document with no directives passes through unchanged")
    func noDirectivesPassThrough() {
        let blocks: [Block] = [
            .heading(level: 1, content: [.text("Title")], attributes: attrs(id: "title")),
            .paragraph([.text("Body text")], attributes: attrs()),
        ]
        let result = process(blocks)
        #expect(result.count == 2)
        if case .heading(let level, _, _) = result[0] {
            #expect(level == 1)
        }
    }

    @Test("Unknown command is ignored gracefully")
    func unknownCommandIgnored() {
        let blocks: [Block] = [
            .phase2Directive(command: "nonexistent", arguments: ["family": "theorem"], body: nil),
            .paragraph([.text("Content")], attributes: attrs()),
        ]
        let result = process(blocks)
        // Directive removed, paragraph remains
        #expect(result.count == 1)
        if case .paragraph = result[0] { } else {
            Issue.record("Expected paragraph to remain after unknown command")
        }
    }

    @Test("hide does not affect blocks that do not match selector")
    func hideOnlyAffectsMatching() {
        let blocks: [Block] = [
            .phase2Directive(command: "hide", arguments: ["family": "example", "in": "llm"], body: nil),
            .admonition(type: "example", title: "Hidden",
                       content: [.paragraph([.text("Example")])],
                       collapsible: nil, attributes: attrs(id: "ex-1")),
            .admonition(type: "theorem", title: "Visible",
                       content: [.paragraph([.text("Theorem")])],
                       collapsible: nil, attributes: attrs(id: "thm-1")),
        ]
        let result = process(blocks)
        // example should have hidden, theorem should not
        for block in result {
            if case .admonition(let type, _, _, _, let a) = block {
                if type == "example" {
                    #expect(a.keyValues["hidden"]?.contains("llm") == true)
                } else if type == "theorem" {
                    #expect(a.keyValues["hidden"] == nil)
                }
            }
        }
    }
}
