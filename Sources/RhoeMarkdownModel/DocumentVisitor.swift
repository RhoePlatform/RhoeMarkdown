import Foundation

// MARK: - Block Visitor Protocol

/// Protocol for visiting Block nodes in the Rhoe AST.
///
/// Each Block enum case has a corresponding visitor method with a default no-op
/// implementation. Conformers override only the cases they handle. The centralized
/// `Block.accept(_:)` method dispatches to the correct visitor method, eliminating
/// the need for exhaustive switch statements throughout the codebase.
public protocol BlockVisitor {
    mutating func visitParagraph(_ inlines: [Inline], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitHeading(level: Int, content: [Inline], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitBlockQuote(_ blocks: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitList(type: ListType, items: [ListItem], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitCodeBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitHorizontalRule()
    mutating func visitTable(headers: [TableCell], rows: [[TableCell]], caption: [Inline]?, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitDefinitionList(items: [DefinitionListItem], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitFootnoteDefinition(id: String, content: [Block])
    mutating func visitAdmonition(type: String, title: String?, content: [Block], collapsible: AdmonitionCollapsible?, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitBlockHTML(_ html: String)
    mutating func visitDiv(content: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitLineBlock(lines: [[Inline]])
    mutating func visitAbbreviationDefinition(abbreviation: String, expansion: String)
    mutating func visitVisualBlock(name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitAuthorAnnotation(kind: AnnotationKind, text: String, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitTransclusion(target: String, fragment: String?, mode: TransclusionMode?, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitSchemaIsland(schema: String, body: String, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitComponentDeclaration(family: BlockFamily, name: String, args: String?, slots: String?, body: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitPhase2Directive(command: String, arguments: [String: String], body: String?, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitPlaceholder(fields: [String: String], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitExpression(expr: String, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitField(name: String, fieldType: String, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitForm(name: String?, content: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitWidget(title: String, content: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitTab(title: String, content: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitStage(kind: StageKind, content: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitLane(content: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitModule(family: String, name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitContractDirective(kind: ContractKind, content: String, attributes: RhoeMarkdownKit.Attributes)
    // Canonical node kinds
    mutating func visitSection(level: Int, title: [Inline], children: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitFormalBlock(family: String, title: [Inline]?, number: String?, content: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitSpeakerNotes(content: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitGrid(content: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitColumns(content: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitFigure(content: [Block], caption: [Inline]?, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitDiagramBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitShape(content: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitTableHead(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitTableBody(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitTableFoot(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitTableRow(cells: [TableCell], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitExecutableCodeBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitMathBlock(expression: String, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitDeck(slides: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitSlide(title: [Inline]?, content: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitSlotContent(name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitExtension(vendor: String, name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitRawBlock(content: String, format: String, attributes: RhoeMarkdownKit.Attributes)
}

// MARK: - Block Visitor Default Implementations

public extension BlockVisitor {
    mutating func visitParagraph(_ inlines: [Inline], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitHeading(level: Int, content: [Inline], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitBlockQuote(_ blocks: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitList(type: ListType, items: [ListItem], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitCodeBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitHorizontalRule() {}
    mutating func visitTable(headers: [TableCell], rows: [[TableCell]], caption: [Inline]?, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitDefinitionList(items: [DefinitionListItem], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitFootnoteDefinition(id: String, content: [Block]) {}
    mutating func visitAdmonition(type: String, title: String?, content: [Block], collapsible: AdmonitionCollapsible?, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitBlockHTML(_ html: String) {}
    mutating func visitDiv(content: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitLineBlock(lines: [[Inline]]) {}
    mutating func visitAbbreviationDefinition(abbreviation: String, expansion: String) {}
    mutating func visitVisualBlock(name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitAuthorAnnotation(kind: AnnotationKind, text: String, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitTransclusion(target: String, fragment: String?, mode: TransclusionMode?, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitSchemaIsland(schema: String, body: String, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitComponentDeclaration(family: BlockFamily, name: String, args: String?, slots: String?, body: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitPhase2Directive(command: String, arguments: [String: String], body: String?, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitPlaceholder(fields: [String: String], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitExpression(expr: String, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitField(name: String, fieldType: String, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitForm(name: String?, content: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitWidget(title: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitTab(title: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitStage(kind: StageKind, content: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitLane(content: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitModule(family: String, name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitContractDirective(kind: ContractKind, content: String, attributes: RhoeMarkdownKit.Attributes) {}
    // Canonical node kinds
    mutating func visitSection(level: Int, title: [Inline], children: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitFormalBlock(family: String, title: [Inline]?, number: String?, content: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitSpeakerNotes(content: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitGrid(content: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitColumns(content: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitFigure(content: [Block], caption: [Inline]?, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitDiagramBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitShape(content: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitTableHead(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitTableBody(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitTableFoot(rows: [[TableCell]], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitTableRow(cells: [TableCell], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitExecutableCodeBlock(language: String?, content: String, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitMathBlock(expression: String, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitDeck(slides: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitSlide(title: [Inline]?, content: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitSlotContent(name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitExtension(vendor: String, name: String, content: [Block], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitRawBlock(content: String, format: String, attributes: RhoeMarkdownKit.Attributes) {}
}

// MARK: - Inline Visitor Protocol

/// Protocol for visiting Inline nodes in the Rhoe AST.
public protocol InlineVisitor {
    mutating func visitText(_ text: String)
    mutating func visitEmphasis(_ inlines: [Inline])
    mutating func visitStrong(_ inlines: [Inline])
    mutating func visitStrikethrough(_ inlines: [Inline])
    mutating func visitCodeSpan(_ code: String, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitLink(text: [Inline], url: String, title: String?, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitImage(alt: [Inline], url: String, title: String?, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitFootnoteRef(id: String)
    mutating func visitInlineMath(expression: String, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitMathDisplay(expression: String, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitInlineHTML(_ html: String)
    mutating func visitHardBreak()
    mutating func visitSoftBreak()
    mutating func visitSuperscript(_ inlines: [Inline])
    mutating func visitSubscript(_ inlines: [Inline])
    mutating func visitHighlight(_ inlines: [Inline])
    mutating func visitSpan(content: [Inline], attributes: RhoeMarkdownKit.Attributes)
    mutating func visitInlineFootnote(content: [Inline])
    mutating func visitCitation(items: [CitationItem], mode: CitationMode)
    mutating func visitCrossReference(prefix: CrossRefPrefix, id: String)
    mutating func visitResolvedCitation(text: String, keys: [String], mode: CitationMode)
    mutating func visitResolvedCrossReference(text: String, targetId: String)
    mutating func visitRawInline(content: String, format: String)
    mutating func visitWikilink(target: String, display: [Inline]?)
    mutating func visitEmoji(name: String, unicode: String?)
    mutating func visitTransclusionInline(target: String, fragment: String?, mode: TransclusionMode?, attributes: RhoeMarkdownKit.Attributes)
    mutating func visitAnnotationInline(kind: AnnotationKind, text: String)
    mutating func visitParamRef(name: String)
    mutating func visitSlotRef(name: String?)
    mutating func visitPlaceholderInline(fields: [String: String])
    mutating func visitExpressionInline(expr: String)
    mutating func visitInputFieldInline(name: String, fieldType: String, attributes: RhoeMarkdownKit.Attributes)
}

// MARK: - Inline Visitor Default Implementations

public extension InlineVisitor {
    mutating func visitText(_ text: String) {}
    mutating func visitEmphasis(_ inlines: [Inline]) {}
    mutating func visitStrong(_ inlines: [Inline]) {}
    mutating func visitStrikethrough(_ inlines: [Inline]) {}
    mutating func visitCodeSpan(_ code: String, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitLink(text: [Inline], url: String, title: String?, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitImage(alt: [Inline], url: String, title: String?, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitFootnoteRef(id: String) {}
    mutating func visitInlineMath(expression: String, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitMathDisplay(expression: String, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitInlineHTML(_ html: String) {}
    mutating func visitHardBreak() {}
    mutating func visitSoftBreak() {}
    mutating func visitSuperscript(_ inlines: [Inline]) {}
    mutating func visitSubscript(_ inlines: [Inline]) {}
    mutating func visitHighlight(_ inlines: [Inline]) {}
    mutating func visitSpan(content: [Inline], attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitInlineFootnote(content: [Inline]) {}
    mutating func visitCitation(items: [CitationItem], mode: CitationMode) {}
    mutating func visitCrossReference(prefix: CrossRefPrefix, id: String) {}
    mutating func visitResolvedCitation(text: String, keys: [String], mode: CitationMode) {}
    mutating func visitResolvedCrossReference(text: String, targetId: String) {}
    mutating func visitRawInline(content: String, format: String) {}
    mutating func visitWikilink(target: String, display: [Inline]?) {}
    mutating func visitEmoji(name: String, unicode: String?) {}
    mutating func visitTransclusionInline(target: String, fragment: String?, mode: TransclusionMode?, attributes: RhoeMarkdownKit.Attributes) {}
    mutating func visitAnnotationInline(kind: AnnotationKind, text: String) {}
    mutating func visitParamRef(name: String) {}
    mutating func visitSlotRef(name: String?) {}
    mutating func visitPlaceholderInline(fields: [String: String]) {}
    mutating func visitExpressionInline(expr: String) {}
    mutating func visitInputFieldInline(name: String, fieldType: String, attributes: RhoeMarkdownKit.Attributes) {}
}

// MARK: - Document Visitor (combines Block + Inline)

/// Combined visitor for walking entire documents. Provides default recursive
/// traversal into child blocks and inlines.
public protocol DocumentVisitor: BlockVisitor, InlineVisitor {
    mutating func visitDocument(_ document: RhoeMarkdownKit.Document)
}

public extension DocumentVisitor {
    mutating func visitDocument(_ document: RhoeMarkdownKit.Document) {
        for block in document.blocks {
            block.accept(&self)
        }
    }
}

// MARK: - Accept Methods

public extension Block {
    /// Dispatches to the appropriate visitor method. This is the single centralized
    /// switch statement for Block — all downstream code routes through here.
    func accept<V: BlockVisitor>(_ visitor: inout V) {
        switch self {
        case let .paragraph(inlines, attributes):
            visitor.visitParagraph(inlines, attributes: attributes)
        case let .heading(level, content, attributes):
            visitor.visitHeading(level: level, content: content, attributes: attributes)
        case let .blockQuote(blocks, attributes):
            visitor.visitBlockQuote(blocks, attributes: attributes)
        case let .list(type, items, attributes):
            visitor.visitList(type: type, items: items, attributes: attributes)
        case let .codeBlock(language, content, attributes):
            visitor.visitCodeBlock(language: language, content: content, attributes: attributes)
        case .horizontalRule:
            visitor.visitHorizontalRule()
        case let .table(headers, rows, caption, attributes):
            visitor.visitTable(headers: headers, rows: rows, caption: caption, attributes: attributes)
        case let .definitionList(items, attributes):
            visitor.visitDefinitionList(items: items, attributes: attributes)
        case let .footnoteDefinition(id, content):
            visitor.visitFootnoteDefinition(id: id, content: content)
        case let .admonition(type, title, content, collapsible, attributes):
            visitor.visitAdmonition(type: type, title: title, content: content, collapsible: collapsible, attributes: attributes)
        case let .html(html):
            visitor.visitBlockHTML(html)
        case let .div(content, attributes):
            visitor.visitDiv(content: content, attributes: attributes)
        case let .lineBlock(lines):
            visitor.visitLineBlock(lines: lines)
        case let .abbreviationDefinition(abbreviation, expansion):
            visitor.visitAbbreviationDefinition(abbreviation: abbreviation, expansion: expansion)
        case let .visualBlock(name, content, attributes):
            visitor.visitVisualBlock(name: name, content: content, attributes: attributes)
        case let .authorAnnotation(kind, text, attributes):
            visitor.visitAuthorAnnotation(kind: kind, text: text, attributes: attributes)
        case let .transclusion(target, fragment, mode, attributes):
            visitor.visitTransclusion(target: target, fragment: fragment, mode: mode, attributes: attributes)
        case let .schemaIsland(schema, body, attributes):
            visitor.visitSchemaIsland(schema: schema, body: body, attributes: attributes)
        case let .componentDeclaration(family, name, args, slots, body, attributes):
            visitor.visitComponentDeclaration(family: family, name: name, args: args, slots: slots, body: body, attributes: attributes)
        case let .phase2Directive(command, arguments, body, attributes):
            visitor.visitPhase2Directive(command: command, arguments: arguments, body: body, attributes: attributes)
        case let .placeholder(fields, attributes):
            visitor.visitPlaceholder(fields: fields, attributes: attributes)
        case let .expression(expr, attributes):
            visitor.visitExpression(expr: expr, attributes: attributes)
        case let .field(name, fieldType, attributes):
            visitor.visitField(name: name, fieldType: fieldType, attributes: attributes)
        case let .form(name, content, attributes):
            visitor.visitForm(name: name, content: content, attributes: attributes)
        case let .widget(title, content, attributes):
            visitor.visitWidget(title: title, content: content, attributes: attributes)
        case let .tab(title, content, attributes):
            visitor.visitTab(title: title, content: content, attributes: attributes)
        case let .stage(kind, content, attributes):
            visitor.visitStage(kind: kind, content: content, attributes: attributes)
        case let .lane(content, attributes):
            visitor.visitLane(content: content, attributes: attributes)
        case let .module(family, name, content, attributes):
            visitor.visitModule(family: family, name: name, content: content, attributes: attributes)
        case let .contractDirective(kind, content, attributes):
            visitor.visitContractDirective(kind: kind, content: content, attributes: attributes)
        // Canonical node kinds
        case let .section(level, title, children, attributes):
            visitor.visitSection(level: level, title: title, children: children, attributes: attributes)
        case let .formalBlock(family, title, number, content, attributes):
            visitor.visitFormalBlock(family: family, title: title, number: number, content: content, attributes: attributes)
        case let .speakerNotes(content, attributes):
            visitor.visitSpeakerNotes(content: content, attributes: attributes)
        case let .grid(content, attributes):
            visitor.visitGrid(content: content, attributes: attributes)
        case let .columns(content, attributes):
            visitor.visitColumns(content: content, attributes: attributes)
        case let .figure(content, caption, attributes):
            visitor.visitFigure(content: content, caption: caption, attributes: attributes)
        case let .diagramBlock(language, content, attributes):
            visitor.visitDiagramBlock(language: language, content: content, attributes: attributes)
        case let .shape(content, attributes):
            visitor.visitShape(content: content, attributes: attributes)
        case let .tableHead(rows, attributes):
            visitor.visitTableHead(rows: rows, attributes: attributes)
        case let .tableBody(rows, attributes):
            visitor.visitTableBody(rows: rows, attributes: attributes)
        case let .tableFoot(rows, attributes):
            visitor.visitTableFoot(rows: rows, attributes: attributes)
        case let .tableRow(cells, attributes):
            visitor.visitTableRow(cells: cells, attributes: attributes)
        case let .executableCodeBlock(language, content, attributes):
            visitor.visitExecutableCodeBlock(language: language, content: content, attributes: attributes)
        case let .mathBlock(expression, attributes):
            visitor.visitMathBlock(expression: expression, attributes: attributes)
        case let .deck(slides, attributes):
            visitor.visitDeck(slides: slides, attributes: attributes)
        case let .slide(title, content, attributes):
            visitor.visitSlide(title: title, content: content, attributes: attributes)
        case let .slotContent(name, content, attributes):
            visitor.visitSlotContent(name: name, content: content, attributes: attributes)
        case let .extension_(vendor, name, content, attributes):
            visitor.visitExtension(vendor: vendor, name: name, content: content, attributes: attributes)
        case let .rawBlock(content, format, attributes):
            visitor.visitRawBlock(content: content, format: format, attributes: attributes)
        }
    }
}

public extension Inline {
    /// Dispatches to the appropriate visitor method. This is the single centralized
    /// switch statement for Inline — all downstream code routes through here.
    func accept<V: InlineVisitor>(_ visitor: inout V) {
        switch self {
        case let .text(text):
            visitor.visitText(text)
        case let .emphasis(inlines):
            visitor.visitEmphasis(inlines)
        case let .strong(inlines):
            visitor.visitStrong(inlines)
        case let .strikethrough(inlines):
            visitor.visitStrikethrough(inlines)
        case let .codeSpan(code, attributes):
            visitor.visitCodeSpan(code, attributes: attributes)
        case let .link(text, url, title, attributes):
            visitor.visitLink(text: text, url: url, title: title, attributes: attributes)
        case let .image(alt, url, title, attributes):
            visitor.visitImage(alt: alt, url: url, title: title, attributes: attributes)
        case let .footnoteRef(id):
            visitor.visitFootnoteRef(id: id)
        case let .inlineMath(expression, attributes):
            visitor.visitInlineMath(expression: expression, attributes: attributes)
        case let .mathDisplay(expression, attributes):
            visitor.visitMathDisplay(expression: expression, attributes: attributes)
        case let .html(html):
            visitor.visitInlineHTML(html)
        case .hardBreak:
            visitor.visitHardBreak()
        case .softBreak:
            visitor.visitSoftBreak()
        case let .superscript(inlines):
            visitor.visitSuperscript(inlines)
        case let .subscript(inlines):
            visitor.visitSubscript(inlines)
        case let .highlight(inlines):
            visitor.visitHighlight(inlines)
        case let .span(content, attributes):
            visitor.visitSpan(content: content, attributes: attributes)
        case let .inlineFootnote(content):
            visitor.visitInlineFootnote(content: content)
        case let .citation(items, mode):
            visitor.visitCitation(items: items, mode: mode)
        case let .crossReference(prefix, id):
            visitor.visitCrossReference(prefix: prefix, id: id)
        case let .resolvedCitation(text, keys, mode):
            visitor.visitResolvedCitation(text: text, keys: keys, mode: mode)
        case let .resolvedCrossReference(text, targetId):
            visitor.visitResolvedCrossReference(text: text, targetId: targetId)
        case let .rawInline(content, format):
            visitor.visitRawInline(content: content, format: format)
        case let .wikilink(target, display):
            visitor.visitWikilink(target: target, display: display)
        case let .emoji(name, unicode):
            visitor.visitEmoji(name: name, unicode: unicode)
        case let .transclusionInline(target, fragment, mode, attributes):
            visitor.visitTransclusionInline(target: target, fragment: fragment, mode: mode, attributes: attributes)
        case let .annotationInline(kind, text):
            visitor.visitAnnotationInline(kind: kind, text: text)
        case let .paramRef(name):
            visitor.visitParamRef(name: name)
        case let .slotRef(name):
            visitor.visitSlotRef(name: name)
        case let .placeholderInline(fields):
            visitor.visitPlaceholderInline(fields: fields)
        case let .expressionInline(expr):
            visitor.visitExpressionInline(expr: expr)
        case let .inputFieldInline(name, fieldType, attributes):
            visitor.visitInputFieldInline(name: name, fieldType: fieldType, attributes: attributes)
        }
    }
}

// MARK: - Recursive Walking Helpers

public extension BlockVisitor where Self: InlineVisitor {
    /// Walk all child inlines within a block's inline content.
    mutating func walkInlines(_ inlines: [Inline]) {
        for inline in inlines {
            inline.accept(&self)
        }
    }

    /// Walk all child blocks within a block's block content.
    mutating func walkBlocks(_ blocks: [Block]) {
        for block in blocks {
            block.accept(&self)
        }
    }
}
