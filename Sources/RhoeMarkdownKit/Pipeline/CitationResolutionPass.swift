import Foundation
import RhoeMarkdownModel

/// Resolves citation inlines against the bibliography index.
///
/// Transforms `Inline.citation` nodes into `Inline.resolvedCitation`
/// with formatted text based on the bibliography entries collected by
/// `BibliographyCollectionPass`.
public struct CitationResolutionPass: DocumentPass, Sendable {
    public init() {}

    public func process(_ document: RhoeMarkdownKit.Document) -> RhoeMarkdownKit.Document {
        let bibliography = document.metadata.resolvedReferences.bibliography
        guard !bibliography.isEmpty else { return document }

        let citationAwareBlocks = document.blocks.map(normalizeCitationSyntax(in:))
        let resolvedBlocks = citationAwareBlocks.map { resolveInBlock($0, bibliography: bibliography) }

        // Track which keys were actually cited
        var citedKeys: [String] = []
        collectCitedKeys(from: resolvedBlocks, into: &citedKeys)

        var metadata = document.metadata
        metadata.resolvedReferences.citedKeys = citedKeys
        return RhoeMarkdownKit.Document(blocks: resolvedBlocks, metadata: metadata)
    }

    private func normalizeCitationSyntax(in block: Block) -> Block {
        switch block {
        case .paragraph(let inlines, let attrs):
            return .paragraph(normalizeCitationSyntax(in: inlines), attributes: attrs)
        case .heading(let level, let content, let attrs):
            return .heading(level: level, content: normalizeCitationSyntax(in: content), attributes: attrs)
        case .blockQuote(let blocks, let attrs):
            return .blockQuote(blocks.map(normalizeCitationSyntax(in:)), attributes: attrs)
        case .list(let type, let items, let attrs):
            let normalizedItems = items.map { item in
                ListItem(
                    content: item.content.map(normalizeCitationSyntax(in:)),
                    checked: item.checked,
                    isLoose: item.isLoose
                )
            }
            return .list(type: type, items: normalizedItems, attributes: attrs)
        case .div(let content, let attrs):
            return .div(content: content.map(normalizeCitationSyntax(in:)), attributes: attrs)
        default:
            return block
        }
    }

    private func normalizeCitationSyntax(in inlines: [Inline]) -> [Inline] {
        inlines.flatMap { inline -> [Inline] in
            switch inline {
            case .text(let text):
                return parseLiteralCitationSyntax(in: text)
            case .emphasis(let content):
                return [.emphasis(normalizeCitationSyntax(in: content))]
            case .strong(let content):
                return [.strong(normalizeCitationSyntax(in: content))]
            case .strikethrough(let content):
                return [.strikethrough(normalizeCitationSyntax(in: content))]
            case .superscript(let content):
                return [.superscript(normalizeCitationSyntax(in: content))]
            case .subscript(let content):
                return [.subscript(normalizeCitationSyntax(in: content))]
            case .highlight(let content):
                return [.highlight(normalizeCitationSyntax(in: content))]
            case .span(let content, let attributes):
                return [.span(content: normalizeCitationSyntax(in: content), attributes: attributes)]
            case .inlineFootnote(let content):
                return [.inlineFootnote(content: normalizeCitationSyntax(in: content))]
            default:
                return [inline]
            }
        }
    }

    private func parseLiteralCitationSyntax(in text: String) -> [Inline] {
        var output: [Inline] = []
        var literal = ""
        var index = text.startIndex

        func flushLiteral() {
            guard !literal.isEmpty else { return }
            output.append(.text(literal))
            literal = ""
        }

        while index < text.endIndex {
            if let parsed = parseBracketedCitation(in: text, at: index) {
                flushLiteral()
                output.append(.citation(items: parsed.items, mode: parsed.mode))
                index = parsed.endIndex
                continue
            }

            literal.append(text[index])
            index = text.index(after: index)
        }

        flushLiteral()
        return output
    }

    private func parseBracketedCitation(
        in text: String,
        at index: String.Index
    ) -> (items: [CitationItem], mode: CitationMode, endIndex: String.Index)? {
        guard text[index] == "[" else { return nil }

        let afterBracket = text.index(after: index)
        guard afterBracket < text.endIndex else { return nil }

        if text[afterBracket] == "@" {
            return parseBracketedCitationContent(in: text, opening: index, contentStart: afterBracket)
        }

        if text[afterBracket] == "-" {
            let afterDash = text.index(after: afterBracket)
            guard afterDash < text.endIndex, text[afterDash] == "@" else { return nil }
            return parseBracketedCitationContent(in: text, opening: index, contentStart: afterBracket)
        }

        return nil
    }

    private func parseBracketedCitationContent(
        in text: String,
        opening: String.Index,
        contentStart: String.Index
    ) -> (items: [CitationItem], mode: CitationMode, endIndex: String.Index)? {
        var scan = contentStart

        while scan < text.endIndex {
            if text[scan] == "\\" {
                let next = text.index(after: scan)
                guard next < text.endIndex else { return nil }
                scan = text.index(after: next)
                continue
            }

            if text[scan] == "]" {
                let content = String(text[contentStart..<scan])
                let items = parseCitationItems(content)
                guard !items.isEmpty else { return nil }
                let mode: CitationMode = items.allSatisfy(\.suppressAuthor) ? .suppressAuthor : .parenthetical
                return (items, mode, text.index(after: scan))
            }

            if text[scan] == "[" {
                return nil
            }

            scan = text.index(after: scan)
        }

        _ = opening
        return nil
    }

    private func parseCitationItems(_ content: String) -> [CitationItem] {
        content
            .split(separator: ";", omittingEmptySubsequences: true)
            .compactMap { parseCitationItem(String($0).trimmingCharacters(in: .whitespaces)) }
    }

    private func parseCitationItem(_ text: String) -> CitationItem? {
        var remaining = text[...]
        var suppressAuthor = false

        if remaining.hasPrefix("-@") {
            suppressAuthor = true
            remaining = remaining.dropFirst(2)
        } else if remaining.hasPrefix("@") {
            remaining = remaining.dropFirst()
        } else {
            return nil
        }

        var keyEnd = remaining.startIndex
        while keyEnd < remaining.endIndex && isCitationKeyCharacter(remaining[keyEnd]) {
            keyEnd = remaining.index(after: keyEnd)
        }

        let key = String(remaining[remaining.startIndex..<keyEnd])
        guard !key.isEmpty else { return nil }

        let afterKey = remaining[keyEnd...]
        let locator: String?
        if afterKey.hasPrefix(",") {
            let locatorText = afterKey.dropFirst().trimmingCharacters(in: .whitespaces)
            locator = locatorText.isEmpty ? nil : locatorText
        } else {
            locator = nil
        }

        return CitationItem(key: key, locator: locator, suppressAuthor: suppressAuthor)
    }

    private func isCitationKeyCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_" || character == "-" || character == ":" || character == "."
    }

    private func resolveInBlock(
        _ block: Block,
        bibliography: [String: BibliographyEntry]
    ) -> Block {
        switch block {
        case .paragraph(let inlines, let attrs):
            return .paragraph(resolveInInlines(inlines, bibliography: bibliography), attributes: attrs)
        case .heading(let level, let content, let attrs):
            return .heading(level: level, content: resolveInInlines(content, bibliography: bibliography), attributes: attrs)
        case .blockQuote(let blocks, let attrs):
            return .blockQuote(blocks.map { resolveInBlock($0, bibliography: bibliography) }, attributes: attrs)
        case .list(let type, let items, let attrs):
            let resolvedItems = items.map { item in
                ListItem(
                    content: item.content.map { resolveInBlock($0, bibliography: bibliography) },
                    checked: item.checked,
                    isLoose: item.isLoose
                )
            }
            return .list(type: type, items: resolvedItems, attributes: attrs)
        case .div(let content, let attrs):
            return .div(content: content.map { resolveInBlock($0, bibliography: bibliography) }, attributes: attrs)
        default:
            return block
        }
    }

    private func resolveInInlines(
        _ inlines: [Inline],
        bibliography: [String: BibliographyEntry]
    ) -> [Inline] {
        inlines.map { inline in
            switch inline {
            case .citation(let items, let mode):
                return resolveCitation(items: items, mode: mode, bibliography: bibliography)
            case .emphasis(let content):
                return .emphasis(resolveInInlines(content, bibliography: bibliography))
            case .strong(let content):
                return .strong(resolveInInlines(content, bibliography: bibliography))
            case .strikethrough(let content):
                return .strikethrough(resolveInInlines(content, bibliography: bibliography))
            default:
                return inline
            }
        }
    }

    private func resolveCitation(
        items: [CitationItem],
        mode: CitationMode,
        bibliography: [String: BibliographyEntry]
    ) -> Inline {
        let keys = items.map(\.key)

        let formattedParts = items.map { item -> String in
            guard let entry = bibliography[item.key] else {
                return "\(item.key)?"
            }
            return entry.formatCitation(
                suppressAuthor: item.suppressAuthor || mode == .suppressAuthor,
                locator: item.locator
            )
        }

        let text: String
        switch mode {
        case .parenthetical, .suppressAuthor:
            text = "(\(formattedParts.joined(separator: "; ")))"
        case .inText:
            // In-text: "Author (Year)" for first item
            if let firstItem = items.first,
               let entry = bibliography[firstItem.key] {
                let author = entry.author ?? entry.id
                let yearPart = entry.year.map { "(\($0))" } ?? ""
                let locPart = firstItem.locator.map { ", \($0)" } ?? ""
                text = "\(author) \(yearPart)\(locPart)"
            } else {
                text = formattedParts.joined(separator: "; ")
            }
        }

        return .resolvedCitation(text: text, keys: keys, mode: mode)
    }

    private func collectCitedKeys(from blocks: [Block], into keys: inout [String]) {
        for block in blocks {
            switch block {
            case .paragraph(let inlines, _), .heading(_, let inlines, _):
                collectCitedKeysFromInlines(inlines, into: &keys)
            case .blockQuote(let nested, _), .div(let nested, _):
                collectCitedKeys(from: nested, into: &keys)
            case .list(_, let items, _):
                for item in items {
                    collectCitedKeys(from: item.content, into: &keys)
                }
            default:
                break
            }
        }
    }

    private func collectCitedKeysFromInlines(_ inlines: [Inline], into keys: inout [String]) {
        for inline in inlines {
            if case .resolvedCitation(_, let citedKeys, _) = inline {
                for key in citedKeys where !keys.contains(key) {
                    keys.append(key)
                }
            }
        }
    }
}
