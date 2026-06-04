import Testing
import RhoeMarkdownKit

@Suite("Sprint R1: Critical Bug Fixes")
struct SprintR1ConformanceTests {

    // MARK: - Raw Inline HTML Pass-Through

    @Test("Raw inline HTML passes through unescaped")
    func rawInlineHTMLPassThrough() async {
        let md = "`<span class=\"custom\">raw</span>`{=html}"
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("<span class=\"custom\">raw</span>"))
        #expect(!html.contains("&lt;span"))
    }

    @Test("Raw inline LaTeX is skipped in HTML output")
    func rawInlineLaTeXSkipped() async {
        let md = "`\\textcolor{red}{text}`{=latex}"
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(!html.contains("\\textcolor"))
    }

    // MARK: - Cross-Reference Prefixes

    @Test("All v3.1 cross-reference prefixes exist")
    func allCrossRefPrefixes() {
        let prefixes = CrossRefPrefix.allCases.map(\.rawValue)
        // Structural
        #expect(prefixes.contains("sec"))
        #expect(prefixes.contains("sld"))
        // Figure-like
        #expect(prefixes.contains("fig"))
        #expect(prefixes.contains("tbl"))
        #expect(prefixes.contains("eq"))
        #expect(prefixes.contains("lst"))
        #expect(prefixes.contains("alg"))
        // Theorem-family
        #expect(prefixes.contains("thm"))
        #expect(prefixes.contains("lem"))
        #expect(prefixes.contains("cor"))
        #expect(prefixes.contains("prop"))
        #expect(prefixes.contains("def"))
        #expect(prefixes.contains("ex"))
        #expect(prefixes.contains("rmk"))
        #expect(prefixes.contains("clm"))
        #expect(prefixes.contains("assum"))
        #expect(prefixes.contains("conj"))
        #expect(prefixes.contains("prf"))
    }

    @Test("CrossRefPrefix has 18 cases")
    func crossRefPrefixCount() {
        #expect(CrossRefPrefix.allCases.count == 19) // 18 spec prefixes + note
    }

    @Test("Renamed prefixes use spec spelling (prop not prp, ex not exm)")
    func renamedPrefixSpelling() {
        #expect(CrossRefPrefix.prop.rawValue == "prop")
        #expect(CrossRefPrefix.ex.rawValue == "ex")
    }

    // MARK: - Config Gates

    @Test("Strict config disables transclusion directives")
    func strictDisablesTransclusion() async {
        let md = "<<include \"./file.md\">>"
        let result = await RhoeMarkdownKit.parse(md, configuration: .strict)
        let hasTransclusion = result.document.blocks.contains {
            if case .transclusion = $0 { return true }
            return false
        }
        #expect(!hasTransclusion)
    }

    @Test("Strict config disables annotation directives")
    func strictDisablesAnnotations() async {
        let md = "<<todo>>\nNote.\n<</todo>>"
        let result = await RhoeMarkdownKit.parse(md, configuration: .strict)
        let hasAnnotation = result.document.blocks.contains {
            if case .authorAnnotation = $0 { return true }
            return false
        }
        #expect(!hasAnnotation)
    }

    @Test("Strict config disables schema islands")
    func strictDisablesSchema() async {
        let md = "<<schema rhoedsl>>\ncontent\n<</schema>>"
        let result = await RhoeMarkdownKit.parse(md, configuration: .strict)
        let hasSchema = result.document.blocks.contains {
            if case .schemaIsland = $0 { return true }
            return false
        }
        #expect(!hasSchema)
    }
}
