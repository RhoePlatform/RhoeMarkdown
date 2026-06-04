import Foundation
import Testing
import RhoeMarkdownKit

@Suite("RhoeMarkdown Core Conformance")
struct RhoeMarkdownCoreConformanceTests {
    @Test("Core blocks and attributes fixture maps to the active AST and HTML surface")
    func coreBlocksAndAttributesFixture() async throws {
        let markdown = try ConformanceFixtures.loadText(
            relativePath: "Tests/Fixtures/spec/core/001-core-blocks-and-attributes.md"
        )

        let result = await RhoeMarkdownKit.parse(markdown)
        let document = result.document
        let html = RhoeMarkdownKit.renderHTML(document)

        // v4.0: The heading wraps all subsequent blocks into a Section node.
        // Document has 1 top-level section with 6 children.
        #expect(document.blocks.count == 1)
        guard document.blocks.count == 1 else { return }

        guard case .section(let level, let title, let children, let sectionAttrs) = document.blocks[0] else {
            #expect(Bool(false), "Expected section block")
            return
        }
        #expect(level == 1)
        #expect(inlinePlainText(title).trimmingCharacters(in: .whitespacesAndNewlines) == "Core Fixture Title")
        #expect(sectionAttrs.id == "core-title")
        #expect(sectionAttrs.classes.contains("hero"))

        #expect(children.count == 6)
        guard children.count == 6 else { return }

        if case .paragraph(let inlines, let attributes) = children[0] {
            #expect(attributes.id == "intro")
            #expect(attributes.classes.contains("lead"))

            let links = inlines.compactMap { inline -> (String, RhoeMarkdownKit.Attributes)? in
                guard case .link(let text, _, _, let linkAttributes) = inline else { return nil }
                return (inlinePlainText(text), linkAttributes)
            }

            #expect(links.count == 1)
            #expect(links.first?.0 == "link")
            #expect(links.first?.1.classes.contains("external") == true)
            #expect(links.first?.1.keyValues["target"] == "_blank")
        } else {
            #expect(Bool(false))
        }

        if case .blockQuote(let content, _) = children[1] {
            #expect(content.count >= 1)
        } else {
            #expect(Bool(false))
        }

        if case .list(let type, let items, _) = children[2] {
            #expect(type == .unordered)
            #expect(items.count == 2)
        } else {
            #expect(Bool(false))
        }

        if case .codeBlock(let language, let content, _) = children[3] {
            #expect(language == "swift")
            #expect(content.contains("print(\"Hello\")"))
        } else {
            #expect(Bool(false))
        }

        if case .table(let headers, let rows, _, _) = children[4] {
            #expect(headers.count == 2)
            #expect(rows.count == 1)
            #expect(headers[0].alignment == .left)
            #expect(headers[1].alignment == .right)
        } else {
            #expect(Bool(false))
        }

        if case .admonition(let type, let admonitionTitle, let content, let collapsible, _) = children[5] {
            #expect(type == "note")
            #expect(admonitionTitle == "Heads Up")
            #expect(collapsible == nil)
            #expect(content.count == 1)
        } else {
            #expect(Bool(false))
        }

        #expect(html.contains("id=\"core-title\""))
        #expect(html.contains("Core Fixture Title"))
        #expect(html.contains("id=\"intro\""))
        #expect(html.contains("class=\"external\""))
        #expect(html.contains("<blockquote"))
        #expect(html.contains("<ul"))
        #expect(html.contains("language-swift"))
        #expect(html.contains("<table"))
        #expect(html.contains("admonition-note"))
    }

    @Test("Frontmatter, footnotes, and math fixture parse correctly")
    func frontmatterDefinitionListAndFootnotesFixture() async throws {
        let markdown = try ConformanceFixtures.loadText(
            relativePath: "Tests/Fixtures/spec/core/002-frontmatter-footnotes.md"
        )

        let result = await RhoeMarkdownKit.parse(markdown)
        let document = result.document
        let html = RhoeMarkdownKit.renderHTML(document)

        let frontmatter = document.metadata.yamlFrontmatter
        #expect(frontmatter?["title"] == .string("Reference Document"))
        #expect(frontmatter?["draft"] == .bool(true))
        #expect(frontmatter?["count"] == .int(2))
        #expect(frontmatter?["tags"] == .array([.string("spec"), .string("qa")]))

        #expect(document.blocks.count == 2)
        guard document.blocks.count == 2 else { return }

        if case .paragraph(let inlines, _) = document.blocks[0] {
            let hasFootnoteRef = inlines.contains {
                if case .footnoteRef(let id) = $0 { return id == "note" }
                return false
            }
            let hasMath = inlines.contains {
                if case .inlineMath(let expression, _) = $0 { return expression.contains("E = mc^2") }
                return false
            }

            #expect(hasFootnoteRef)
            #expect(hasMath)
        } else {
            #expect(Bool(false))
        }

        if case .footnoteDefinition(let id, let content) = document.blocks[1] {
            #expect(id == "note")
            #expect(content.count >= 1)
        } else {
            #expect(Bool(false))
        }

        #expect(html.contains("<div class=\"footnote\" id=\"fn:note\">"))
        #expect(html.contains("E = mc^2"))
    }

    @Test("Definition list fixture parses multi-definition terms")
    func definitionListFixture() async throws {
        let markdown = try ConformanceFixtures.loadText(
            relativePath: "Tests/Fixtures/spec/core/003-definition-list.md"
        )

        let result = await RhoeMarkdownKit.parse(markdown)
        let html = RhoeMarkdownKit.renderHTML(result.document)

        #expect(result.document.blocks.count == 1)
        guard result.document.blocks.count == 1 else { return }

        if case .definitionList(let items, _) = result.document.blocks[0] {
            #expect(items.count == 1)
            #expect(inlinePlainText(items[0].term) == "Term One")
            #expect(items[0].definitions.count == 2)
        } else {
            #expect(Bool(false))
        }

        #expect(html.contains("<dl>"))
        #expect(html.contains("<dt>Term One</dt>"))
        #expect(html.contains("First definition"))
    }

    @Test("Horizontal rule fixture preserves CommonMark thematic breaks")
    func horizontalRuleFixture() async throws {
        let markdown = try ConformanceFixtures.loadText(
            relativePath: "Tests/Fixtures/spec/core/004-horizontal-rules.md"
        )

        let result = await RhoeMarkdownKit.parse(markdown)
        let html = RhoeMarkdownKit.renderHTML(result.document)

        #expect(result.document.blocks.count == 7)
        guard result.document.blocks.count == 7 else { return }

        #expect(paragraphPlainText(result.document.blocks[0])?.trimmingCharacters(in: .whitespacesAndNewlines) == "Alpha paragraph.")
        #expect(paragraphPlainText(result.document.blocks[2])?.trimmingCharacters(in: .whitespacesAndNewlines) == "Beta paragraph.")
        #expect(paragraphPlainText(result.document.blocks[3])?.trimmingCharacters(in: .whitespacesAndNewlines) == "+++")
        #expect(paragraphPlainText(result.document.blocks[4])?.trimmingCharacters(in: .whitespacesAndNewlines) == "Gamma paragraph.")
        #expect(paragraphPlainText(result.document.blocks[6])?.trimmingCharacters(in: .whitespacesAndNewlines) == "Delta paragraph.")

        if case .horizontalRule = result.document.blocks[1] {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }

        if case .horizontalRule = result.document.blocks[5] {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }

        #expect(html.components(separatedBy: "<hr>").count == 3)
    }

    @Test("Inline helper table fixture parses helper links in table cells but keeps paragraph text literal")
    func inlineHelperTableFixture() async throws {
        let markdown = try ConformanceFixtures.loadText(
            relativePath: "Tests/Fixtures/spec/core/005-inline-helpers-table.md"
        )

        let result = await RhoeMarkdownKit.parse(markdown)
        let document = result.document
        let html = RhoeMarkdownKit.renderHTML(document)

        #expect(document.blocks.count == 2)
        guard document.blocks.count == 2 else { return }

        if case .table(let headers, let rows, _, _) = document.blocks[0] {
            #expect(headers.count == 2)
            #expect(rows.count == 2)

            if case .link(let text, let url, _, _) = rows[0][0].content.first {
                #expect(inlinePlainText(text) == "www.example.com")
                #expect(url == "http://www.example.com")
            } else {
                #expect(Bool(false))
            }

            if case .link(let text, let url, _, _) = rows[0][1].content.first {
                #expect(inlinePlainText(text) == "@thor")
                #expect(url == "https://github.com/thor")
            } else {
                #expect(Bool(false))
            }

            if case .link(let text, let url, _, _) = rows[1][0].content.first {
                #expect(inlinePlainText(text) == "#42")
                #expect(url == "#issue-42")
            } else {
                #expect(Bool(false))
            }

            #expect(rows[1][1].content == [.emoji(name: "rocket", unicode: "🚀")])
        } else {
            #expect(Bool(false))
        }

        if case .paragraph(let inlines, _) = document.blocks[1] {
            let paragraphText = inlinePlainText(inlines).trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(paragraphText == "Outside table: www.example.com @thor #42 🚀")
            #expect(inlines.allSatisfy {
                if case .link = $0 { return false }
                return true
            })
        } else {
            #expect(Bool(false))
        }

        #expect(html.contains("href=\"http://www.example.com\""))
        #expect(html.contains("href=\"https://github.com/thor\""))
        #expect(html.contains("href=\"#issue-42\""))
        #expect(html.contains(">🚀</td>"))
        #expect(html.contains("Outside table: www.example.com @thor #42 🚀"))
    }

    @Test("Definition list inline helper fixture parses helper links in term text")
    func definitionListInlineHelperFixture() async throws {
        let markdown = try ConformanceFixtures.loadText(
            relativePath: "Tests/Fixtures/spec/core/006-definition-list-inline-helpers.md"
        )

        let result = await RhoeMarkdownKit.parse(markdown)
        let html = RhoeMarkdownKit.renderHTML(result.document)

        #expect(result.document.blocks.count == 1)
        guard result.document.blocks.count == 1 else { return }

        if case .definitionList(let items, _) = result.document.blocks[0] {
            #expect(items.count == 1)
            #expect(items[0].definitions.count == 1)

            let term = items[0].term
            #expect(term.count == 7)

            if case .link(let text, let url, _, _) = term[0] {
                #expect(inlinePlainText(text) == "www.example.com")
                #expect(url == "http://www.example.com")
            } else {
                #expect(Bool(false))
            }

            if case .link(let text, let url, _, _) = term[2] {
                #expect(inlinePlainText(text) == "@thor")
                #expect(url == "https://github.com/thor")
            } else {
                #expect(Bool(false))
            }

            if case .link(let text, let url, _, _) = term[4] {
                #expect(inlinePlainText(text) == "#42")
                #expect(url == "#issue-42")
            } else {
                #expect(Bool(false))
            }

            #expect(term[6] == .emoji(name: "rocket", unicode: "🚀"))
            #expect(
                paragraphPlainText(items[0].definitions[0][0])?
                    .trimmingCharacters(in: .whitespacesAndNewlines) == "Definition body"
            )
        } else {
            #expect(Bool(false))
        }

        #expect(html.contains("<dt><a href=\"http://www.example.com\">www.example.com</a>"))
        #expect(html.contains("href=\"https://github.com/thor\""))
        #expect(html.contains("href=\"#issue-42\""))
        #expect(html.contains("🚀"))
    }
}
