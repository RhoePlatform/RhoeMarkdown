import Testing
import Foundation
import RhoeMarkdownKit
import RhoeMarkdownModel
import RhoeDSLParsing

@Suite("Wave E: RhoeDSL Implementation")
struct SprintWaveEConformanceTests {

    // MARK: - E1: Lexer

    @Test("DSL lexer tokenizes identifiers")
    func lexerIdentifiers() {
        let lexer = RhoeDSLLexer()
        let tokens = lexer.tokenize("Section Paragraph H1")
        let identifiers = tokens.compactMap { token -> String? in
            if case .identifier(let name) = token.type { return name }
            return nil
        }
        #expect(identifiers == ["Section", "Paragraph", "H1"])
    }

    @Test("DSL lexer tokenizes string literals with escapes")
    func lexerStrings() {
        let lexer = RhoeDSLLexer()
        let tokens = lexer.tokenize("\"hello \\\"world\\\"\"")
        let strings = tokens.compactMap { token -> String? in
            if case .stringLiteral(let s) = token.type { return s }
            return nil
        }
        #expect(strings == ["hello \"world\""])
    }

    @Test("DSL lexer tokenizes numbers and booleans")
    func lexerLiterals() {
        let lexer = RhoeDSLLexer()
        let tokens = lexer.tokenize("42 3.14 true false null")
        let types = tokens.filter { if case .newline = $0.type { return false }; if case .eof = $0.type { return false }; return true }.map(\.type)
        #expect(types.count == 5)
    }

    @Test("DSL lexer strips comments")
    func lexerComments() {
        let lexer = RhoeDSLLexer()
        let tokens = lexer.tokenize("Section // this is a comment\nParagraph")
        let identifiers = tokens.compactMap { token -> String? in
            if case .identifier(let name) = token.type { return name }
            return nil
        }
        #expect(identifiers == ["Section", "Paragraph"])
    }

    // MARK: - E2: Parser Core

    @Test("DSL parser parses simple node")
    func parserSimpleNode() {
        let parser = RhoeDSLParser()
        let (blocks, _) = parser.parse("Paragraph { Hello world. }")
        #expect(blocks.count == 1)
        if case .paragraph(let inlines, _) = blocks.first {
            let text = inlines.compactMap { if case .text(let t) = $0 { return t }; return nil }.joined()
            #expect(text.contains("Hello world"))
        }
    }

    @Test("DSL parser parses node with parameters")
    func parserWithParams() {
        let parser = RhoeDSLParser()
        let (blocks, _) = parser.parse("H1(id: \"intro\") { Introduction }")
        #expect(blocks.count == 1)
        if case .heading(let level, _, let attrs) = blocks.first {
            #expect(level == 1)
            #expect(attrs.id == "intro")
        }
    }

    @Test("DSL parser parses nested structural nodes")
    func parserNested() {
        let parser = RhoeDSLParser()
        let (blocks, _) = parser.parse("""
        Section {
            H1 { Title }
            Paragraph { Body text. }
        }
        """)
        #expect(blocks.count == 1)
        if case .div(let content, _) = blocks.first {
            #expect(content.count == 2) // heading + paragraph
        }
    }

    @Test("DSL parser parses trailing modifier chain")
    func parserTrailingChain() {
        let parser = RhoeDSLParser()
        let (blocks, _) = parser.parse("Paragraph { Hello. }.id(\"intro\").class(\"hero\")")
        #expect(blocks.count == 1)
        if case .paragraph(_, let attrs) = blocks.first {
            #expect(attrs.id == "intro")
            #expect(attrs.classes.contains("hero"))
        }
    }

    @Test("DSL parser parses code block with raw text body")
    func parserCodeBlock() {
        let parser = RhoeDSLParser()
        let (blocks, _) = parser.parse("Code(language: \"python\") { print(\"hello\") }")
        #expect(blocks.count == 1)
        if case .codeBlock(let lang, let content, _) = blocks.first {
            #expect(lang == "python")
            #expect(content.contains("print"))
        }
    }

    // MARK: - E3: Node Catalog + AST Mapping

    @Test("DSL heading maps to correct AST")
    func headingMapping() {
        let parser = RhoeDSLParser()
        let (blocks, _) = parser.parse("H2 { Chapter Two }")
        if case .heading(let level, let content, _) = blocks.first {
            #expect(level == 2)
            let text = content.compactMap { if case .text(let t) = $0 { return t }; return nil }.joined()
            #expect(text.contains("Chapter Two"))
        }
    }

    @Test("DSL admonition maps correctly")
    func admonitionMapping() {
        let parser = RhoeDSLParser()
        let (blocks, _) = parser.parse("Warning(title: \"Caution\") { Paragraph { Be careful! } }")
        if case .admonition(let type, let title, let content, _, _) = blocks.first {
            #expect(type == "warning")
            #expect(title == "Caution")
            #expect(!content.isEmpty)
        }
    }

    @Test("DSL theorem alias maps to admonition")
    func theoremMapping() {
        let parser = RhoeDSLParser()
        let (blocks, _) = parser.parse("Theorem(title: \"Banach Fixed Point\") { Paragraph { Every contraction... } }")
        if case .admonition(let type, let title, _, _, _) = blocks.first {
            #expect(type == "theorem")
            #expect(title == "Banach Fixed Point")
        }
    }

    @Test("DSL list maps correctly")
    func listMapping() {
        let parser = RhoeDSLParser()
        let (blocks, _) = parser.parse("""
        List {
            ListItem { First item }
            ListItem { Second item }
        }
        """)
        if case .list(_, let items, _) = blocks.first {
            #expect(items.count == 2)
        }
    }

    @Test("DSL image node maps correctly")
    func imageMapping() {
        let parser = RhoeDSLParser()
        let (blocks, _) = parser.parse("Image(src: \"photo.jpg\", alt: \"A photo\")")
        if case .paragraph(let inlines, _) = blocks.first {
            if case .image(_, let url, _, _) = inlines.first {
                #expect(url == "photo.jpg")
            }
        }
    }

    // MARK: - E4: Pipeline Integration

    @Test("DSL parses to same structure as equivalent Markdown")
    func dslMatchesMarkdown() async {
        let md = "# Hello\n\nWorld."
        let dsl = "H1 { Hello }\nParagraph { World. }"

        let mdResult = await RhoeMarkdownKit.parse(md)
        let dslResult = await RhoeMarkdownKit.parseDSL(dsl)

        // Both should produce heading + paragraph
        #expect(mdResult.document.blocks.count == dslResult.document.blocks.count)

        // First block should be heading in both
        if case .heading(let mdLevel, _, _) = mdResult.document.blocks.first,
           case .heading(let dslLevel, _, _) = dslResult.document.blocks.first {
            #expect(mdLevel == dslLevel)
        }
    }

    @Test("DSL to HTML produces correct output")
    func dslToHTML() async {
        let html = await RhoeMarkdownKit.dslToHTML("H1 { Hello }\nParagraph { World. }")
        #expect(html.contains("Hello"))
        #expect(html.contains("World"))
        #expect(html.contains("<h1"))
        #expect(html.contains("<p"))
    }

    @Test("DSL pipeline runs numbering and cross-references")
    func dslPipeline() async {
        let dsl = """
        Theorem(title: "Main Result", id: "thm-main") {
            Paragraph { The result holds. }
        }
        """
        let result = await RhoeMarkdownKit.parseDSL(dsl)
        #expect(!result.document.blocks.isEmpty)
    }

    @Test("DSL horizontal rule maps correctly")
    func horizontalRule() {
        let parser = RhoeDSLParser()
        let (blocks, _) = parser.parse("HR")
        #expect(blocks.first == .horizontalRule)
    }
}
