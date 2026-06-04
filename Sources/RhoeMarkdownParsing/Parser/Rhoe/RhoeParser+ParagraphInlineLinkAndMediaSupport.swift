import Foundation
import RhoeMarkdownModel

extension RhoeParser {
    func appendParagraphStyleLinkInline(
        state: inout RhoeParserState,
        inlines: inout [Inline],
        mode: ParagraphInlineMode
    ) {
        let openingIndex = state.currentIndex
        state.advance()
        let label = collectBracketedInlineTokensWithClosure(&state)
        guard label.closed else {
            state.currentIndex = min(openingIndex + 1, state.tokens.count)
            inlines.append(.text("["))
            return
        }

        let rawLabel = label.tokens.map(\.content).joined()
        var labelState = RhoeParserState(tokens: label.tokens)
        let linkTextInlines = parseInlines(&labelState, until: { $0.type == .eof })

        if let destination = consumeParenthesizedLinkDestination(&state) {
            if containsLinkInline(linkTextInlines) {
                inlines.append(.text("["))
                inlines.append(contentsOf: linkTextInlines)
                inlines.append(.text("]"))
                inlines.append(.text(destination.rawText))
            } else {
                let attributes: RhoeMarkdownKit.Attributes
                if mode == .paragraph {
                    attributes = consumeAttributeList(&state) ?? RhoeMarkdownKit.Attributes()
                } else {
                    attributes = RhoeMarkdownKit.Attributes()
                }
                inlines.append(.link(text: linkTextInlines, url: destination.url, title: destination.title, attributes: attributes))
            }
        } else if mode == .paragraph,
                  let nextToken = state.current,
                  case .attributeList(let content) = nextToken.type {
            state.advance()
            let attributes = parseAttributes(from: content)
            inlines.append(.span(content: linkTextInlines, attributes: attributes))
        } else if let citation = citationInlineFromRawBracketLabel(rawLabel) {
            inlines.append(citation)
        } else if let nextToken = state.current,
                  case .text(let text) = nextToken.type,
                  text.hasPrefix("(") {
            state.currentIndex = min(openingIndex + 1, state.tokens.count)
            inlines.append(.text("["))
        } else if let nextToken = state.current,
                  nextToken.type != .linkStart,
                  shouldRollbackPlainLiteralLabel(rawLabel, linkTextInlines: linkTextInlines) {
            state.currentIndex = min(openingIndex + 1, state.tokens.count)
            inlines.append(.text("["))
        } else {
            inlines.append(.text("[\(rawLabel)]"))
        }
    }

    func citationInlineFromRawBracketLabel(_ rawLabel: String) -> Inline? {
        guard configuration.enableCitations else { return nil }
        let bracketed = "[\(rawLabel)]"
        var position = bracketed.startIndex
        guard let citation = parseCitationFromText(bracketed, at: &position),
              position == bracketed.endIndex
        else {
            return nil
        }
        return citation
    }

    func containsLinkInline(_ inlines: [Inline]) -> Bool {
        inlines.contains { inline in
            switch inline {
            case .link:
                return true
            case .emphasis(let content),
                 .strong(let content),
                 .strikethrough(let content),
                 .superscript(let content),
                 .subscript(let content),
                 .highlight(let content),
                 .span(let content, _),
                 .inlineFootnote(let content):
                return containsLinkInline(content)
            default:
                return false
            }
        }
    }

    func shouldRollbackPlainLiteralLabel(_ rawLabel: String, linkTextInlines: [Inline]) -> Bool {
        guard !rawLabel.contains("\\"),
              !rawLabel.contains("["),
              !rawLabel.contains("]"),
              !rawLabel.hasSuffix("*"),
              !rawLabel.hasSuffix("_")
        else {
            return false
        }
        return !containsReferenceSensitiveInline(linkTextInlines)
    }

    func containsReferenceSensitiveInline(_ inlines: [Inline]) -> Bool {
        inlines.contains { inline in
            switch inline {
            case .emphasis,
                 .strong,
                 .strikethrough,
                 .codeSpan,
                 .link,
                 .image,
                 .html,
                 .hardBreak,
                 .softBreak:
                return true
            case .superscript(let content),
                 .subscript(let content),
                 .highlight(let content),
                 .span(let content, _),
                 .inlineFootnote(let content):
                return containsReferenceSensitiveInline(content)
            default:
                return false
            }
        }
    }

    func appendParagraphStyleImageInline(
        _ token: RhoeLexer.Token,
        state: inout RhoeParserState,
        inlines: inout [Inline],
        mode: ParagraphInlineMode
    ) {
        if mode == .paragraph {
            state.advance()
            let altTextTokens = collectBracketedInlineTokens(&state)
            let rawAltText = altTextTokens.map(\.content).joined()

            var altTextInlines: [Inline] = []
            if !altTextTokens.isEmpty {
                var altState = RhoeParserState(tokens: altTextTokens)
                altTextInlines = parseInlines(&altState, until: { _ in false })
            }

            if let destination = consumeParenthesizedLinkDestination(&state) {
                inlines.append(.image(alt: altTextInlines, url: destination.url, title: destination.title))
            } else {
                inlines.append(.text("![\(rawAltText)]"))
            }
        } else {
            inlines.append(.text(token.content))
            state.advance()
        }
    }
}
