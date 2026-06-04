import Testing
import RhoeMarkdownKit

@Suite("Sprint 3.1-CDE: Composition Directives")
struct Sprint31CDEConformanceTests {

    // MARK: - Block Transclusion

    @Test("Block transclusion <<include>> parses to .transclusion")
    func blockTransclusion() async {
        let md = "<<include \"./chapter2.md\">>"
        let result = await RhoeMarkdownKit.parse(md)
        guard case .transclusion(let target, let fragment, _, _) = result.document.blocks.first else {
            Issue.record("Expected .transclusion, got \(result.document.blocks.first.debugDescription)")
            return
        }
        #expect(target == "./chapter2.md")
        #expect(fragment == nil)
    }

    @Test("Transclusion with fragment parses path and fragment")
    func transclusionWithFragment() async {
        let md = "<<include \"./chapter2.md#methodology\">>"
        let result = await RhoeMarkdownKit.parse(md)
        guard case .transclusion(let target, let fragment, _, _) = result.document.blocks.first else {
            Issue.record("Expected .transclusion with fragment")
            return
        }
        #expect(target == "./chapter2.md")
        #expect(fragment == "methodology")
    }

    // MARK: - Inline Transclusion

    @Test("Inline transclusion parses in text")
    func inlineTransclusion() async {
        let md = "See <<include \"./glossary.md#term\">> for details."
        let result = await RhoeMarkdownKit.parse(md)
        guard case .paragraph(let inlines, _) = result.document.blocks.first else {
            Issue.record("Expected paragraph")
            return
        }
        let hasTransclusion = inlines.contains {
            if case .transclusionInline = $0 { return true }
            return false
        }
        #expect(hasTransclusion)
    }

    @Test("Inline transclusion preserves explicit mode attributes")
    func inlineTransclusionWithMode() async {
        let md = "See <<include \"./glossary.md#term\" {mode=quote}>> for details."
        let result = await RhoeMarkdownKit.parse(md)
        guard case .paragraph(let inlines, _) = result.document.blocks.first else {
            Issue.record("Expected paragraph")
            return
        }
        for inline in inlines {
            if case .transclusionInline(let target, let fragment, let mode, _) = inline {
                #expect(target == "./glossary.md")
                #expect(fragment == "term")
                #expect(mode == .quote)
                return
            }
        }
        Issue.record("No transclusion found in inlines: \(inlines)")
    }

    // MARK: - Block Annotations

    @Test("Block annotation <<todo>> with opaque body")
    func blockAnnotationTodo() async {
        let md = "<<todo>>\nRevise this section.\n<</todo>>"
        let result = await RhoeMarkdownKit.parse(md)
        guard case .authorAnnotation(let kind, let text, _) = result.document.blocks.first else {
            Issue.record("Expected .authorAnnotation, got \(result.document.blocks.first.debugDescription)")
            return
        }
        #expect(kind == .todo)
        #expect(text.contains("Revise"))
    }

    @Test("Block annotation <<doc>> parses correctly")
    func blockAnnotationDoc() async {
        let md = "<<doc>>\nInternal documentation note.\n<</doc>>"
        let result = await RhoeMarkdownKit.parse(md)
        guard case .authorAnnotation(let kind, _, _) = result.document.blocks.first else {
            Issue.record("Expected .authorAnnotation")
            return
        }
        #expect(kind == .doc)
    }

    @Test("Block annotation <<info>> parses correctly")
    func blockAnnotationInfo() async {
        let md = "<<info>>\nInformational note.\n<</info>>"
        let result = await RhoeMarkdownKit.parse(md)
        guard case .authorAnnotation(let kind, _, _) = result.document.blocks.first else {
            Issue.record("Expected .authorAnnotation")
            return
        }
        #expect(kind == .info)
    }

    @Test("Block annotation <<comment>> parses correctly")
    func blockAnnotationComment() async {
        let md = "<<comment>>\nGeneric comment.\n<</comment>>"
        let result = await RhoeMarkdownKit.parse(md)
        guard case .authorAnnotation(let kind, _, _) = result.document.blocks.first else {
            Issue.record("Expected .authorAnnotation")
            return
        }
        #expect(kind == .comment)
    }

    // MARK: - Inline Annotations

    @Test("Inline annotation <<todo \"text\">> parses")
    func inlineAnnotationTodo() async {
        let md = "Content <<todo \"fix this\">> here."
        let result = await RhoeMarkdownKit.parse(md)
        guard case .paragraph(let inlines, _) = result.document.blocks.first else {
            Issue.record("Expected paragraph")
            return
        }
        let hasAnnotation = inlines.contains {
            if case .annotationInline(let kind, _) = $0, kind == .todo { return true }
            return false
        }
        #expect(hasAnnotation)
    }

    // MARK: - Schema Islands

    @Test("Schema island <<schema rhoedsl>> parses to .schemaIsland")
    func schemaIsland() async {
        let md = "<<schema rhoedsl>>\nSection { H1 { Overview } }\n<</schema>>"
        let result = await RhoeMarkdownKit.parse(md)
        guard case .schemaIsland(let schema, let body, _) = result.document.blocks.first else {
            Issue.record("Expected .schemaIsland, got \(result.document.blocks.first.debugDescription)")
            return
        }
        #expect(schema == "rhoedsl")
        #expect(body.contains("Section"))
    }

    @Test("Schema island name is case-insensitive")
    func schemaIslandCaseInsensitive() async {
        let md = "<<schema RhoeDSL>>\ncontent\n<</schema>>"
        let result = await RhoeMarkdownKit.parse(md)
        guard case .schemaIsland(let schema, _, _) = result.document.blocks.first else {
            Issue.record("Expected .schemaIsland")
            return
        }
        #expect(schema == "rhoedsl")
    }

    // MARK: - Case Insensitive Keywords

    @Test("Composition directive keywords are case-insensitive")
    func caseInsensitiveKeywords() async {
        let md = "<<TODO>>\nTask here.\n<</TODO>>"
        let result = await RhoeMarkdownKit.parse(md)
        guard case .authorAnnotation(let kind, _, _) = result.document.blocks.first else {
            Issue.record("Expected .authorAnnotation for case-insensitive TODO")
            return
        }
        #expect(kind == .todo)
    }

    // MARK: - Self-Contained Annotations

    @Test("Self-contained annotation <<todo \"text\">> at block level")
    func selfContainedAnnotationBlock() async {
        let md = "<<todo \"revise theorem numbering\">>"
        let result = await RhoeMarkdownKit.parse(md)
        guard case .authorAnnotation(let kind, let text, _) = result.document.blocks.first else {
            Issue.record("Expected .authorAnnotation")
            return
        }
        #expect(kind == .todo)
        #expect(text == "revise theorem numbering")
    }

    // MARK: - Annotations Are Non-Rendering

    @Test("Annotations produce no visible HTML output")
    func annotationsNonRendering() async {
        let md = "# Title\n\n<<todo>>\nInternal note.\n<</todo>>\n\nVisible paragraph."
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<h1"))
        #expect(html.contains("Visible paragraph"))
        #expect(!html.contains("Internal note"))
    }

    // MARK: - Group Directive

    @Test("Group directive <<group>> parses to div with slot-name")
    func groupDirective() async {
        let md = "<<group header>>\nHeader content.\n<</group>>"
        let result = await RhoeMarkdownKit.parse(md)
        guard case .div(let content, let attrs) = result.document.blocks.first else {
            Issue.record("Expected .div for group, got \(result.document.blocks.first.debugDescription)")
            return
        }
        #expect(!content.isEmpty)
        #expect(attrs.keyValues["slot-name"] == "header")
    }

    // MARK: - Inline Bare Path

    @Test("Inline bare path <<./path>> parses as transclusion")
    func inlineBarePath() async {
        let md = "See <<./file.md>> for details."
        let result = await RhoeMarkdownKit.parse(md)
        guard case .paragraph(let inlines, _) = result.document.blocks.first else {
            Issue.record("Expected paragraph")
            return
        }
        // Print all inlines for debugging
        for inline in inlines {
            if case .transclusionInline = inline {
                return // test passes
            }
        }
        Issue.record("No transclusion found in inlines: \(inlines)")
    }

    // MARK: - Edge Cases

    @Test("Escaped \\<< does not trigger directive parsing")
    func escapedAngleBrackets() async {
        let md = "This has \\<< not a directive >> in it."
        let html = await RhoeMarkdownKit.toHTML(md)
        // Should not produce any directive-like output
        #expect(html.contains("&lt;&lt;") || html.contains("<<"))
    }
}
