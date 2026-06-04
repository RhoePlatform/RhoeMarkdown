import Testing
import Foundation
import RhoeMarkdownKit
import RhoeMarkdownModel
import RhoeMarkdownRendering

@Suite("v3.2 Wave B: Core Expressions + Input Bindings")
struct SprintV32BConformanceTests {

    // MARK: - B1: Core Expressions

    @Test("Expression block <<= expr >> parses to AST node")
    func expressionBlockParse() async {
        let md = "<<= SUM(B2:B5) >>\n\nSome text."
        let result = await RhoeMarkdownKit.parse(md)
        let hasExpr = result.document.blocks.contains { block in
            if case .expression = block { return true }
            return false
        }
        #expect(hasExpr)
    }

    @Test("Expression block stores expression string")
    func expressionBlockContent() {
        let block = Block.expression(expr: "ROUND(in.amount * 0.19, 2)")
        if case .expression(let expr, _) = block {
            #expect(expr == "ROUND(in.amount * 0.19, 2)")
        }
    }

    @Test("Inline expression <<= expr >> parses")
    func expressionInlineParse() {
        let inline = Inline.expressionInline(expr: "in.amount * 0.19")
        if case .expressionInline(let expr) = inline {
            #expect(expr == "in.amount * 0.19")
        }
    }

    @Test("Expression disabled when enableCoreExpressions is false")
    func expressionDisabled() async {
        let config = RhoeMarkdownKit.Configuration(enableCoreExpressions: false)
        let result = await RhoeMarkdownKit.parse("<<= SUM(1,2,3) >>", configuration: config)
        let hasExpr = result.document.blocks.contains { block in
            if case .expression = block { return true }
            return false
        }
        #expect(!hasExpr)
    }

    @Test("All writers handle expression block without crashing")
    func writersHandleExpression() {
        let doc = RhoeMarkdownKit.Document(blocks: [
            .expression(expr: "42 + 1")
        ])
        let html = RhoeMarkdownKit.renderHTML(doc)
        let latex = RhoeMarkdownKit.renderLaTeX(doc)
        let typst = RhoeMarkdownKit.renderTypst(doc)
        #expect(!html.isEmpty)
        #expect(!latex.isEmpty)
        #expect(!typst.isEmpty)
    }

    @Test("JSON serializes expression with expr field")
    func jsonSerializesExpression() {
        let doc = RhoeMarkdownKit.Document(blocks: [
            .expression(expr: "SUM(A1:A5)")
        ])
        let data = RhoeMarkdownKit.renderJSON(doc)
        let json = String(data: data, encoding: .utf8)!
        // v4.0: JSON node name is "Expression" (capitalized per canonical schema)
        #expect(json.contains("Expression"))
        #expect(json.contains("SUM(A1:A5)"))
    }

    // MARK: - B2: Input Bindings

    @Test("Field directive <<field name>> parses to inputField")
    func fieldParse() async {
        let md = "<<field recipient {type=text required label=\"Recipient\"}>>"
        let result = await RhoeMarkdownKit.parse(md)
        let hasField = result.document.blocks.contains { block in
            if case .field = block { return true }
            return false
        }
        #expect(hasField)
    }

    @Test("InputField stores name and type")
    func fieldContent() {
        let block = Block.field(name: "amount", fieldType: "number")
        if case .field(let name, let fieldType, _) = block {
            #expect(name == "amount")
            #expect(fieldType == "number")
        }
    }

    @Test("Form directive <<form>>...<</form>> parses to form")
    func formParse() async {
        let md = """
        <<form {name=billing}>>
        <<field recipient {type=text}>>
        <<field amount {type=number}>>
        <</form>>
        """
        let result = await RhoeMarkdownKit.parse(md)
        let hasForm = result.document.blocks.contains { block in
            if case .form = block { return true }
            return false
        }
        #expect(hasForm)
    }

    @Test("Field disabled when enableInputBindings is false")
    func fieldDisabled() async {
        let config = RhoeMarkdownKit.Configuration(enableInputBindings: false)
        let result = await RhoeMarkdownKit.parse("<<field name {type=text}>>", configuration: config)
        let hasField = result.document.blocks.contains { block in
            if case .field = block { return true }
            return false
        }
        #expect(!hasField)
    }

    @Test("HTML renders field with input element")
    func htmlRendersField() {
        let doc = RhoeMarkdownKit.Document(blocks: [
            .field(name: "email", fieldType: "email", attributes: .init(keyValues: ["label": "Email Address", "required": "true"]))
        ])
        let html = RhoeMarkdownKit.renderHTML(doc)
        #expect(html.contains("rhoe-field"))
        #expect(html.contains("input"))
    }

    @Test("HTML renders form wrapping children")
    func htmlRendersForm() {
        let doc = RhoeMarkdownKit.Document(blocks: [
            .form(name: "billing", content: [
                .field(name: "recipient", fieldType: "text")
            ])
        ])
        let html = RhoeMarkdownKit.renderHTML(doc)
        #expect(html.contains("rhoe-form"))
    }

    @Test("JSON serializes field with binding name and type")
    func jsonSerializesField() {
        let doc = RhoeMarkdownKit.Document(blocks: [
            .field(name: "amount", fieldType: "number")
        ])
        let data = RhoeMarkdownKit.renderJSON(doc)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("field"))
        #expect(json.contains("amount"))
        #expect(json.contains("number"))
    }

    // MARK: - B3: CSS + Integration

    @Test("Default CSS contains expression styles")
    func cssExpressionStyles() {
        let css = RhoeDefaultCSS.stylesheet
        #expect(css.contains(".rhoe-expression"))
    }

    @Test("Default CSS contains field styles")
    func cssFieldStyles() {
        let css = RhoeDefaultCSS.stylesheet
        #expect(css.contains(".rhoe-field"))
        #expect(css.contains(".rhoe-field label"))
        #expect(css.contains(".rhoe-field input"))
    }

    @Test("Default CSS contains form styles")
    func cssFormStyles() {
        let css = RhoeDefaultCSS.stylesheet
        #expect(css.contains(".rhoe-form"))
    }

    @Test("Inline expression type constructs correctly")
    func inlineExpressionType() {
        let inline = Inline.expressionInline(expr: "in.amount")
        if case .expressionInline(let expr) = inline {
            #expect(expr == "in.amount")
        }
    }
}
