import Foundation
import RhoeMarkdownModel

// MARK: - HTMLInlineRenderer (Visitor)

struct HTMLInlineRenderer: InlineVisitor {
    let renderer: RhoeHTMLRenderer
    var result: String = ""

    mutating func visitText(_ text: String) {
        result = renderer.renderTextPreservingSimpleRawHTML(text)
    }

    mutating func visitEmphasis(_ inlines: [Inline]) {
        result = "<em>\(renderer.renderInlines(inlines))</em>"
    }

    mutating func visitStrong(_ inlines: [Inline]) {
        result = "<strong>\(renderer.renderInlines(inlines))</strong>"
    }

    mutating func visitStrikethrough(_ inlines: [Inline]) {
        result = "<del>\(renderer.renderInlines(inlines))</del>"
    }

    mutating func visitCodeSpan(_ code: String, attributes: RhoeMarkdownKit.Attributes) {
        result = "<code\(attributes.toHTMLAttributes())>\(renderer.htmlEscape(code))</code>"
    }

    mutating func visitLink(text: [Inline], url: String, title: String?, attributes: RhoeMarkdownKit.Attributes) {
        var keyValues = attributes.keyValues
        keyValues["href"] = url
        if let title = title {
            keyValues["title"] = title
        }
        let mergedAttrs = RhoeMarkdownKit.Attributes(id: attributes.id, classes: attributes.classes, keyValues: keyValues)
        result = "<a\(mergedAttrs.toHTMLAttributes())>\(renderer.renderInlines(text))</a>"
    }

    mutating func visitImage(alt: [Inline], url: String, title: String?, attributes: RhoeMarkdownKit.Attributes) {
        var keyValues = attributes.keyValues
        keyValues["src"] = url
        // Decorative images get empty alt text.
        let isDecorative = keyValues["decorative"] == "true"
        keyValues["alt"] = isDecorative ? "" : alt.map { renderer.extractText(from: $0) }.joined()
        if isDecorative {
            keyValues["role"] = "presentation"
            keyValues.removeValue(forKey: "decorative") // Don't emit as HTML attribute
        }
        if let title = title {
            keyValues["title"] = title
        }
        let mergedAttrs = RhoeMarkdownKit.Attributes(id: attributes.id, classes: attributes.classes, keyValues: keyValues)
        result = "<img\(mergedAttrs.toHTMLAttributes())>"
    }

    mutating func visitFootnoteRef(id: String) {
        result = "<sup><a href=\"#fn:\(id)\" id=\"fnref:\(id)\" class=\"footnote-ref\">\(id)</a></sup>"
    }

    mutating func visitInlineMath(expression: String, attributes: RhoeMarkdownKit.Attributes) {
        result = renderer.renderMathExpression(expression, inline: true, attributes: attributes)
    }

    mutating func visitMathDisplay(expression: String, attributes: RhoeMarkdownKit.Attributes) {
        result = renderer.renderMathExpression(expression, inline: false, attributes: attributes)
    }

    mutating func visitInlineHTML(_ html: String) {
        result = html
    }

    mutating func visitHardBreak() {
        result = "<br>\n"
    }

    mutating func visitSoftBreak() {
        result = "\n"
    }

    mutating func visitSuperscript(_ inlines: [Inline]) {
        result = "<sup>\(renderer.renderInlines(inlines))</sup>"
    }

    mutating func visitSubscript(_ inlines: [Inline]) {
        result = "<sub>\(renderer.renderInlines(inlines))</sub>"
    }

    mutating func visitHighlight(_ inlines: [Inline]) {
        result = "<mark>\(renderer.renderInlines(inlines))</mark>"
    }

    mutating func visitSpan(content: [Inline], attributes: RhoeMarkdownKit.Attributes) {
        result = "<span\(attributes.toHTMLAttributes())>\(renderer.renderInlines(content))</span>"
    }

    mutating func visitInlineFootnote(content: [Inline]) {
        result = "<sup class=\"inline-footnote\">\(renderer.renderInlines(content))</sup>"
    }

    mutating func visitCitation(items: [CitationItem], mode: CitationMode) {
        result = renderer.renderCitation(items: items, mode: mode)
    }

    mutating func visitCrossReference(prefix: CrossRefPrefix, id: String) {
        result = "<a href=\"#\(prefix.rawValue)-\(renderer.htmlEscape(id))\" class=\"crossref\">\(prefix.rawValue)-\(renderer.htmlEscape(id))</a>"
    }

    mutating func visitResolvedCitation(text: String, keys: [String], mode: CitationMode) {
        result = "<span class=\"citation\">\(renderer.htmlEscape(text))</span>"
    }

    mutating func visitResolvedCrossReference(text: String, targetId: String) {
        result = "<a href=\"#\(renderer.htmlEscape(targetId))\" class=\"crossref\">\(renderer.htmlEscape(text))</a>"
    }

    mutating func visitRawInline(content: String, format: String) {
            // Pass through raw content for matching format, skip for others.
        if format == "html" || format == "htm" {
            result = content // Pass through unescaped
        } else {
            result = "" // Non-HTML raw inlines are skipped in HTML output
        }
    }

    mutating func visitWikilink(target: String, display: [Inline]?) {
        let text = display.map { renderer.renderInlines($0) } ?? renderer.htmlEscape(target)
        result = "<a href=\"\(renderer.htmlEscape(target))\" class=\"wikilink\">\(text)</a>"
    }

    mutating func visitTransclusionInline(target: String, fragment: String?, mode: TransclusionMode?, attributes: RhoeMarkdownKit.Attributes) {
        let fragSuffix = fragment.map { "#\($0)" } ?? ""
        let display = renderer.htmlEscape("\(target)\(fragSuffix)")
        result = "<span class=\"rhoe-transclusion-inline\" data-target=\"\(renderer.htmlEscape(target))\">[Transclusion: \(display)]</span>"
    }

    mutating func visitAnnotationInline(kind: AnnotationKind, text: String) {
        result = "" // Non-rendering
    }

    mutating func visitParamRef(name: String) {
        result = "<span class=\"rhoe-unresolved-param\">&lt;&lt;param \(name)&gt;&gt;</span>"
    }

    mutating func visitSlotRef(name: String?) {
        let label = name ?? "default"
        result = "<span class=\"rhoe-unresolved-slot\">&lt;&lt;slot \(label)&gt;&gt;</span>"
    }

    mutating func visitPlaceholderInline(fields: [String: String]) {
        let display: String
        if let name = fields["name"] {
            display = renderer.htmlEscape(name)
        } else {
            display = fields.map { "\(renderer.htmlEscape($0.key))=\(renderer.htmlEscape($0.value))" }.joined(separator: ", ")
        }
        result = "<span class=\"rhoe-placeholder\">[\(display)]</span>"
    }

    mutating func visitExpressionInline(expr: String) {
        result = "<span class=\"rhoe-expression\">\(renderer.htmlEscape(expr))</span>"
    }

    mutating func visitInputFieldInline(name: String, fieldType: String, attributes: RhoeMarkdownKit.Attributes) {
        result = "<label>\(renderer.htmlEscape(name))</label><input type=\"\(renderer.htmlEscape(fieldType))\">"
    }

    mutating func visitEmoji(name: String, unicode: String?) {
        if let unicode {
            result = unicode
        } else {
            result = ":\(renderer.htmlEscape(name)):"
        }
    }
}
