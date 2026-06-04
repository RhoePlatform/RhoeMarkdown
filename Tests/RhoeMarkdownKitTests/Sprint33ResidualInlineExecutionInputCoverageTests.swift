import Testing
import RhoeMarkdownKit

@Suite("Sprint 33: Residual Inline Execution/Input Coverage")
struct Sprint33ResidualInlineExecutionInputCoverageTests {

    @Test("Inline placeholder syntax parses to a first-class placeholderInline node")
    func inlinePlaceholderParsesToFirstClassNode() async {
        let result = await RhoeMarkdownKit.parse("Start {? name: \"Email\", required ?} end")
        guard case .paragraph(let inlines, _) = result.document.blocks.first else {
            Issue.record("Expected paragraph")
            return
        }

        for inline in inlines {
            if case .placeholderInline(let fields) = inline {
                #expect(fields["name"] == "Email")
                #expect(fields["required"] == "true")
                return
            }
        }

        Issue.record("No placeholderInline found in parsed paragraph: \(inlines)")
    }

    @Test("Inline expression directives parse to first-class expressionInline nodes")
    func inlineExpressionParsesToFirstClassNode() async {
        let result = await RhoeMarkdownKit.parse("Total <<= in.total >> now")
        guard case .paragraph(let inlines, _) = result.document.blocks.first else {
            Issue.record("Expected paragraph")
            return
        }

        for inline in inlines {
            if case .expressionInline(let expr) = inline {
                #expect(expr == "in.total")
                return
            }
        }

        Issue.record("No expressionInline found in parsed paragraph: \(inlines)")
    }

    @Test("Inline field directives parse to first-class inputFieldInline nodes")
    func inlineFieldParsesToFirstClassNode() async {
        let result = await RhoeMarkdownKit.parse("Use <<field amount {type=currency required=true}>> soon")
        guard case .paragraph(let inlines, _) = result.document.blocks.first else {
            Issue.record("Expected paragraph")
            return
        }

        for inline in inlines {
            if case .inputFieldInline(let name, let fieldType, let attributes) = inline {
                #expect(name == "amount")
                #expect(fieldType == "currency")
                #expect(attributes.keyValues["required"] == "true")
                return
            }
        }

        Issue.record("No inputFieldInline found in parsed paragraph: \(inlines)")
    }
}
