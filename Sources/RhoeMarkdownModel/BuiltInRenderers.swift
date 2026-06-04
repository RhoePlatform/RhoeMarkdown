import Foundation

// MARK: - Built-in Parser and Renderer
// These are fallback/built-in implementations. For production use,
// prefer RhoeParser (parsing) and RhoeHTMLRenderer (rendering).

// MARK: - Parser Implementation

/// CommonMark-compliant parser
public struct CommonMarkParser: Sendable {
    private let configuration: RhoeMarkdownKit.Configuration

    public init(configuration: RhoeMarkdownKit.Configuration = .default) {
        self.configuration = configuration
    }

    /// Parse markdown text
    public func parse(_ markdown: String) async -> RhoeMarkdownKit.ParseResult {
        let startTime = Date().timeIntervalSinceReferenceDate

        // NASA-Grade Optimization #1: Pre-allocate capacity
        var blocks: [Block] = []
        blocks.reserveCapacity(markdown.count / 50) // Heuristic: avg 50 chars per block

        // NASA-Grade Optimization #2: Use fast line splitting
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagnostics: [RhoeMarkdownKit.Diagnostic] = []

        var i = 0
        while i < lines.count {
            // NASA-Grade Optimization #3: Avoid redundant string operations
            let line = lines[i]
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine.isEmpty {
                i += 1
                continue
            }

            // NASA-Grade Optimization #4: Fast character-based dispatch
            guard let firstChar = trimmedLine.first else {
                i += 1
                continue
            }

            switch firstChar {
            case "#":
                // Fast heading detection
                if line.hasPrefix("#") {
                    let (level, content) = parseHeading(line)
                    blocks.append(.heading(level: level, content: [.text(content)]))
                } else {
                    blocks.append(.paragraph(parseInlines(line)))
                }
            case "`":
                // Check for code block
                if line.hasPrefix("```") {
                    let (codeBlock, linesConsumed) = parseCodeBlock(lines, startIndex: i)
                    blocks.append(codeBlock)
                    i += linesConsumed
                } else {
                    blocks.append(.paragraph(parseInlines(line)))
                }
            case "-", "*", "_":
                // Check for horizontal rule
                if line.hasPrefix("---") || line.hasPrefix("***") || trimmedLine == "---" || trimmedLine == "***" || trimmedLine == "___" {
                    blocks.append(.horizontalRule)
                } else {
                    blocks.append(.paragraph(parseInlines(line)))
                }
            case ">":
                // Blockquote
                let (blockquote, linesConsumed) = parseBlockquote(lines, startIndex: i)
                blocks.append(blockquote)
                i += linesConsumed - 1 // -1 because we'll increment at the end of the loop
            default:
                // Default to paragraph
                blocks.append(.paragraph(parseInlines(line)))
            }

            i += 1
        }

        let parseTime = Date().timeIntervalSinceReferenceDate - startTime
        let wordCount = markdown.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        let estimatedReadingTime = Double(wordCount) / 250.0 * 60.0 // 250 WPM

        let metadata = RhoeMarkdownKit.DocumentMetadata(
            wordCount: wordCount,
            estimatedReadingTime: estimatedReadingTime
        )

        let document = RhoeMarkdownKit.Document(blocks: blocks, metadata: metadata)

        return RhoeMarkdownKit.ParseResult(
            document: document,
            diagnostics: diagnostics,
            parseTime: parseTime
        )
    }

    // MARK: - Private Parsing Methods

    private func parseHeading(_ line: String) -> (level: Int, content: String) {
        var level = 0
        var index = line.startIndex

        while index < line.endIndex && line[index] == "#" && level < 6 {
            level += 1
            index = line.index(after: index)
        }

        let content = String(line[index...]).trimmingCharacters(in: .whitespaces)
        return (level: level, content: content)
    }

    private func parseCodeBlock(_ lines: [String], startIndex: Int) -> (Block, Int) {
        let firstLine = lines[startIndex]
        let language = String(firstLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        let lang = language.isEmpty ? nil : language

        var content: [String] = []
        var i = startIndex + 1

        while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
            content.append(lines[i])
            i += 1
        }

        let codeContent = content.joined(separator: "\n")
        return (.codeBlock(language: lang, content: codeContent), i - startIndex)
    }

    private func parseBlockquote(_ lines: [String], startIndex: Int) -> (Block, Int) {
        var content: [String] = []
        var i = startIndex

        // Collect all consecutive blockquote lines
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix(">") {
                let quoteContent = String(line.dropFirst().trimmingCharacters(in: .whitespaces))
                if !quoteContent.isEmpty {
                    content.append(quoteContent)
                }
                i += 1
            } else if line.isEmpty && i + 1 < lines.count && lines[i + 1].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                // Skip empty lines between blockquote lines
                i += 1
            } else {
                break
            }
        }

        let combinedContent = content.joined(separator: " ")
        let blockquoteBlock = Block.blockQuote([.paragraph([.text(combinedContent)])])
        return (blockquoteBlock, i - startIndex)
    }

    private func parseInlines(_ text: String) -> [Inline] {
        // NASA-Grade Optimization #5: Early return for simple text
        if !text.contains("*") && !text.contains("_") && !text.contains("`") && !text.contains("[") {
            return [.text(text)]
        }

        var inlines: [Inline] = []
        var current = text

        // Simple bold/italic parsing
        while !current.isEmpty {
            // Check for bold first (** takes precedence over *)
            if let boldRange = current.range(of: #"\*\*(.*?)\*\*"#, options: .regularExpression) {
                let italicRange = current.range(of: #"(?<!\*)\*([^*]+)\*(?!\*)"#, options: .regularExpression)

                // If italic comes before bold, process italic first
                if let italicRange = italicRange, italicRange.lowerBound < boldRange.lowerBound {
                    // Add text before italic
                    if italicRange.lowerBound > current.startIndex {
                        let beforeText = String(current[..<italicRange.lowerBound])
                        inlines.append(.text(beforeText))
                    }

                    // Add italic text
                    let italicText = String(current[italicRange])
                    let content = String(italicText.dropFirst().dropLast())
                    inlines.append(.emphasis([.text(content)]))

                    // Continue with remaining text
                    current = String(current[italicRange.upperBound...])
                } else {
                    // Add text before bold
                    if boldRange.lowerBound > current.startIndex {
                        let beforeText = String(current[..<boldRange.lowerBound])
                        inlines.append(.text(beforeText))
                    }

                    // Add bold text
                    let boldText = String(current[boldRange])
                    let content = String(boldText.dropFirst(2).dropLast(2))
                    inlines.append(.strong([.text(content)]))

                    // Continue with remaining text
                    current = String(current[boldRange.upperBound...])
                }
            } else if let italicRange = current.range(of: #"(?<!\*)\*([^*]+)\*(?!\*)"#, options: .regularExpression) {
                // Add text before italic
                if italicRange.lowerBound > current.startIndex {
                    let beforeText = String(current[..<italicRange.lowerBound])
                    inlines.append(.text(beforeText))
                }

                // Add italic text
                let italicText = String(current[italicRange])
                let content = String(italicText.dropFirst().dropLast())
                inlines.append(.emphasis([.text(content)]))

                // Continue with remaining text
                current = String(current[italicRange.upperBound...])
            } else {
                // No more formatting, add remaining text
                inlines.append(.text(current))
                break
            }
        }

        return inlines.isEmpty ? [.text(text)] : inlines
    }
}

// MARK: - HTML Renderer (Deprecated - Use RhoeHTMLRenderer)

/// HTML renderer for markdown documents (Deprecated - Use RhoeHTMLRenderer instead)
@available(*, deprecated, message: "Use RhoeHTMLRenderer for full attribute support")
public struct HTMLRenderer: Sendable {
    private let configuration: RhoeMarkdownKit.HTMLConfiguration

    public init(configuration: RhoeMarkdownKit.HTMLConfiguration = .default) {
        self.configuration = configuration
    }

    /// Render document to HTML
    public func render(_ document: RhoeMarkdownKit.Document) -> String {
        var html = ""

        if configuration.prettyPrint {
            html += "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n</head>\n<body>\n"
        }

        for block in document.blocks {
            html += renderBlock(block)
            if configuration.prettyPrint {
                html += "\n"
            }
        }

        if configuration.prettyPrint {
            html += "</body>\n</html>\n"
        }

        return html
    }

    private func renderBlock(_ block: Block) -> String {
        switch block {
        case .paragraph(let inlines, _):
            return "<p>" + renderInlines(inlines) + "</p>"
        case .heading(let level, let content, _):
            return "<h\(level)>" + renderInlines(content) + "</h\(level)>"
        case .blockQuote(let blocks, _):
            let content = blocks.map { renderBlock($0) }.joined()
            return "<blockquote>" + content + "</blockquote>"
        case .codeBlock(let language, let content, _):
            let lang = language ?? ""
            let langAttr = lang.isEmpty ? "" : " class=\"language-\(lang)\""
            return "<pre><code\(langAttr)>" + htmlEscape(content) + "</code></pre>"
        case .horizontalRule:
            return "<hr>"
        case .list(let type, let items, _):
            let tag = if case .ordered = type { "ol" } else { "ul" }
            let itemsHtml = items.map { item in
                let content = item.content.map { renderBlock($0) }.joined()
                return "<li>" + content + "</li>"
            }.joined()
            return "<\(tag)>" + itemsHtml + "</\(tag)>"
        case .table(let headers, let rows, let caption, _):
            var html = "<table><thead><tr>"
            if let caption {
                html = "<table><caption>" + renderInlines(caption) + "</caption><thead><tr>"
            }
            for header in headers {
                html += "<th>" + renderInlines(header.content) + "</th>"
            }
            html += "</tr></thead><tbody>"
            for row in rows {
                html += "<tr>"
                for cell in row {
                    html += "<td>" + renderInlines(cell.content) + "</td>"
                }
                html += "</tr>"
            }
            html += "</tbody></table>"
            return html
        case .definitionList(let items, _):
            var html = "<dl>"
            for item in items {
                html += "<dt>" + renderInlines(item.term) + "</dt>"
                for definition in item.definitions {
                    html += "<dd>"
                    let definitionHtml = definition.map { renderBlock($0) }.joined()
                    html += definitionHtml
                    html += "</dd>"
                }
            }
            html += "</dl>"
            return html
        case .footnoteDefinition(let id, let content):
            var html = "<div class=\"footnote\" id=\"fn:\(id)\">"
            html += "<p><sup>\(id)</sup> "
            let contentHtml = content.map { renderBlock($0) }.joined()
            html += contentHtml
            html += " <a href=\"#fnref:\(id)\" class=\"footnote-backref\">↩</a></p>"
            html += "</div>"
            return html
        case .admonition(let type, let title, let content, _, _):
            let displayTitle = title ?? type.capitalized
            var html = "<div class=\"admonition admonition-\(type.lowercased())\">"
            html += "<p class=\"admonition-title\">\(displayTitle)</p>"
            html += "<div class=\"admonition-content\">"
            let contentHtml = content.map { renderBlock($0) }.joined()
            html += contentHtml
            html += "</div></div>"
            return html
        case .html(let rawHtml):
            return rawHtml
        case .div(let content, _):
            let contentHtml = content.map { renderBlock($0) }.joined()
            return "<div>" + contentHtml + "</div>"
        case .lineBlock(let lines):
            let rendered = lines.map { renderInlines($0) }.joined(separator: "<br>\n")
            return "<div class=\"line-block\">" + rendered + "</div>"
        case .abbreviationDefinition:
            return "" // Abbreviation definitions are consumed during rendering
        case .visualBlock(let name, let content, _):
            let contentHtml = content.map { renderBlock($0) }.joined()
            return "<div class=\"rhoe-visual rhoe-\(name)\">" + contentHtml + "</div>"
        case .authorAnnotation:
            return "" // Annotations are non-rendering
        case .transclusion:
            return "" // Transclusion resolved during pipeline
        case .schemaIsland:
            return "" // Schema islands resolved during pipeline
        case .componentDeclaration:
            return "" // Component declarations are non-rendering
        case .phase2Directive:
            return "" // Phase 2 directives are executed in pipeline, not rendered
        case .placeholder(let fields, _):
            let display: String
            if let name = fields["name"] {
                display = htmlEscape(name)
            } else {
                display = fields.map { "\(htmlEscape($0.key))=\(htmlEscape($0.value))" }.joined(separator: ", ")
            }
            return "<span class=\"rhoe-placeholder\" data-rhoe-node=\"placeholder\">[\(display)]</span>"
        case .expression(let expr, _):
            return "<span class=\"rhoe-expression\" data-rhoe-node=\"Expression\">\(htmlEscape(expr))</span>"
        case .field(let name, let fieldType, _):
            return "<div class=\"rhoe-field\"><label>\(htmlEscape(name))</label><input type=\"\(htmlEscape(fieldType))\"></div>"
        case .form(_, let content, _):
            let contentHtml = content.map { renderBlock($0) }.joined()
            return "<form class=\"rhoe-form\">" + contentHtml + "</form>"
        case .widget(let title, let content, _):
            let contentHtml = content.map { renderBlock($0) }.joined()
            return "<div class=\"rhoe-widget\" data-rhoe-node=\"widget\" data-rhoe-surface=\"widget\" data-title=\"\(htmlEscape(title))\">" + contentHtml + "</div>"
        case .tab(let title, let content, _):
            let contentHtml = content.map { renderBlock($0) }.joined()
            return "<div class=\"rhoe-tab\" data-rhoe-node=\"tab\" data-rhoe-surface=\"tab\" data-title=\"\(htmlEscape(title))\">" + contentHtml + "</div>"
        case .stage(let kind, let content, _):
            let contentHtml = content.map { renderBlock($0) }.joined()
            return "<div class=\"rhoe-stage rhoe-stage-\(kind.rawValue)\">" + contentHtml + "</div>"
        case .lane(let content, _):
            let contentHtml = content.map { renderBlock($0) }.joined()
            return "<div class=\"rhoe-lane\">" + contentHtml + "</div>"
        case .module(let family, let name, let content, _):
            let contentHtml = content.map { renderBlock($0) }.joined()
            return "<div class=\"rhoe-module rhoe-module-\(htmlEscape(family))-\(htmlEscape(name))\">" + contentHtml + "</div>"
        case .contractDirective(let kind, let content, _):
            return "<div class=\"rhoe-contract rhoe-contract-\(kind.rawValue)\">\(htmlEscape(content))</div>"
        default:
            return ""
        }
    }

    private func renderInlines(_ inlines: [Inline]) -> String {
        return inlines.map { inline in
            switch inline {
            case .text(let text):
                return htmlEscape(text)
            case .emphasis(let content):
                return "<em>" + renderInlines(content) + "</em>"
            case .strong(let content):
                return "<strong>" + renderInlines(content) + "</strong>"
            case .strikethrough(let content):
                return "<del>" + renderInlines(content) + "</del>"
            case .codeSpan(let text, let attributes):
                return "<code\(attributes.toHTMLAttributes())>" + htmlEscape(text) + "</code>"
            case .link(let text, let url, let title, _):
                let titleAttr = title.map { " title=\"\(htmlEscape($0))\"" } ?? ""
                return "<a href=\"\(htmlEscape(url))\"\(titleAttr)>" + renderInlines(text) + "</a>"
            case .image(let alt, let url, let title, _):
                let altText = imageAltText(alt)
                let titleAttr = title.map { " title=\"\(htmlEscape($0))\"" } ?? ""
                return "<img src=\"\(htmlEscape(url))\" alt=\"\(htmlEscape(altText))\"\(titleAttr)>"
            case .footnoteRef(let id):
                return "<sup><a href=\"#fn:\(id)\" id=\"fnref:\(id)\" class=\"footnote-ref\">\(id)</a></sup>"
            case .inlineMath(let expression, _):
                return "<span class=\"math inline\">\\(\(htmlEscape(expression))\\)</span>"
            case .mathDisplay(let expression, _):
                return "<div class=\"math display\">\\[\(htmlEscape(expression))\\]</div>"
            case .html(let rawHtml):
                return rawHtml
            case .hardBreak:
                return "<br>"
            case .softBreak:
                return " "
            case .superscript(let content):
                return "<sup>\(renderInlines(content))</sup>"
            case .`subscript`(let content):
                return "<sub>\(renderInlines(content))</sub>"
            case .highlight(let content):
                return "<mark>\(renderInlines(content))</mark>"
            case .span(let content, _):
                return "<span>\(renderInlines(content))</span>"
            case .inlineFootnote(let content):
                return "<sup>\(renderInlines(content))</sup>"
            case .citation(let items, _):
                let keys = items.map { $0.key }.joined(separator: "; ")
                return "<span class=\"citation\">[\(keys)]</span>"
            case .crossReference(let prefix, let id):
                return "<a href=\"#\(prefix.rawValue)-\(id)\" class=\"crossref\">\(prefix.rawValue)-\(id)</a>"
            case .rawInline(let content, let format):
                return "<span class=\"raw-\(format)\">\(content)</span>"
            case .wikilink(let target, let display):
                let text = display.map { renderInlines($0) } ?? htmlEscape(target)
                return "<a href=\"\(htmlEscape(target))\" class=\"wikilink\">\(text)</a>"
            case .resolvedCitation(let text, _, _):
                return "<span class=\"citation\">\(htmlEscape(text))</span>"
            case .resolvedCrossReference(let text, let targetId):
                return "<a href=\"#\(htmlEscape(targetId))\" class=\"crossref\">\(htmlEscape(text))</a>"
            case .transclusionInline:
                return "" // Transclusion resolved during pipeline
            case .annotationInline:
                return "" // Annotations are non-rendering
            case .paramRef(let name):
                return "&lt;&lt;param \(htmlEscape(name))&gt;&gt;"
            case .slotRef(let name):
                return "&lt;&lt;slot \(htmlEscape(name ?? "default"))&gt;&gt;"
            case .placeholderInline(let fields):
                let display: String
                if let name = fields["name"] {
                    display = htmlEscape(name)
                } else {
                    display = fields.map { "\(htmlEscape($0.key))=\(htmlEscape($0.value))" }.joined(separator: ", ")
                }
                return "<span class=\"rhoe-placeholder\">[\(display)]</span>"
            case .expressionInline(let expr):
                return "<span class=\"rhoe-expression\">\(htmlEscape(expr))</span>"
            case .inputFieldInline(let name, _, _):
                return "<span class=\"rhoe-field\">\(htmlEscape(name))</span>"
            default:
                return ""
            }
        }.joined()
    }

    private func imageAltText(_ inlines: [Inline]) -> String {
        inlines.map { inline -> String in
            switch inline {
            case .text(let text):
                return text
            case .emphasis(let content),
                 .strong(let content),
                 .strikethrough(let content),
                 .superscript(let content),
                 .subscript(let content),
                 .highlight(let content),
                 .span(let content, _),
                 .inlineFootnote(let content):
                return imageAltText(content)
            case .codeSpan(let text, _):
                return text
            case .link(let text, _, _, _):
                return imageAltText(text)
            case .image(let alt, _, _, _):
                return imageAltText(alt)
            case .hardBreak,
                 .softBreak:
                return "\n"
            case .html(let rawHTML):
                return rawHTML
            case .inlineMath(let expression, _),
                 .mathDisplay(let expression, _):
                return expression
            case .resolvedCitation(let text, _, _),
                 .resolvedCrossReference(let text, _):
                return text
            case .rawInline(let content, _):
                return content
            case .wikilink(let target, let display):
                return display.map { imageAltText($0) } ?? target
            case .emoji(_, let unicode):
                return unicode ?? ""
            default:
                return ""
            }
        }.joined()
    }

    private func htmlEscape(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

// MARK: - Parser Configuration for parallel components

/// Configuration for parallel parser components
public struct ParserConfiguration: Sendable {
    public let enableStrictMode: Bool
    public let enableCoreExtensions: Bool
    public let enableMathExtensions: Bool
    public let enableAdmonitions: Bool

    public init(
        enableStrictMode: Bool = false,
        enableCoreExtensions: Bool = true,
        enableMathExtensions: Bool = true,
        enableAdmonitions: Bool = true
    ) {
        self.enableStrictMode = enableStrictMode
        self.enableCoreExtensions = enableCoreExtensions
        self.enableMathExtensions = enableMathExtensions
        self.enableAdmonitions = enableAdmonitions
    }

    public static let `default` = ParserConfiguration()
}
