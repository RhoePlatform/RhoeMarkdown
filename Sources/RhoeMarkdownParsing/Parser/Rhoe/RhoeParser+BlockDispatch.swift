import Foundation
import RhoeMarkdownModel

// MARK: - Block Dispatch Outcome

enum BlockDispatchOutcome {
    case parsed(Block?)
    case unhandled
}

// MARK: - Simple Block Kind

enum SimpleBlockKind {
    case paragraph
    case explicitTable
    case ignorableWhitespace
}

// MARK: - Block Dispatch

extension RhoeParser {

    // MARK: Block Parsing Entry

    func parseBlocks(_ state: inout RhoeParserState) -> [Block] {
        let (blocks, _) = parseBlocksWithMetadata(&state)
        return blocks
    }

    func parseBlock(_ state: inout RhoeParserState) -> Block? {
        DebugLogger.trackMethod("parseBlock")
        guard let token = state.current else { return nil }

        DebugLogger.log("parseBlock at index \(state.currentIndex), token: \(token.type)")

        switch dispatchBlock(for: token, state: &state) {
        case .parsed(let block):
            return block
        case .unhandled:
            return parseFallbackBlock(for: token, state: &state)
        }
    }

    fileprivate func dispatchBlock(
        for token: RhoeLexer.Token,
        state: inout RhoeParserState
    ) -> BlockDispatchOutcome {
        if let outcome = dispatchStructuralBlock(for: token, state: &state) {
            return outcome
        }

        if let outcome = dispatchReferenceBlock(for: token, state: &state) {
            return outcome
        }

        if let outcome = dispatchSimpleBlock(for: token, state: &state) {
            return outcome
        }

        return .unhandled
    }

    // MARK: Simple Dispatch

    func dispatchSimpleBlock(
        for token: RhoeLexer.Token,
        state: inout RhoeParserState
    ) -> BlockDispatchOutcome? {
        guard let kind = simpleBlockKind(for: token) else {
            return nil
        }

        switch kind {
        case .paragraph:
            return .parsed(parsePromotedTopLevelParagraphBlock(&state))

        case .explicitTable:
            return .parsed(parseTable(&state))

        case .ignorableWhitespace:
            state.advance()
            return .parsed(nil)
        }
    }

    // MARK: Structural Dispatch

    func dispatchStructuralBlock(
        for token: RhoeLexer.Token,
        state: inout RhoeParserState
    ) -> BlockDispatchOutcome? {
        if isAtIndentedCodeBlockStart(token, state: state) {
            return .parsed(parseIndentedCodeBlock(&state))
        }

        switch token.type {
        case .heading(let level):
            return .parsed(parseHeading(&state, level: level))

        case .blockQuoteMarker(let depth):
            return .parsed(parseBlockQuote(&state, depth: depth))

        case .listMarker(let markerType, let indent):
            return .parsed(parseList(&state, firstMarkerType: markerType, baseIndent: indent))

        case .codeBlockDelimiter(let language):
            return .parsed(parseCodeBlock(&state, language: language))

        case .horizontalRule:
            state.advance()
            return .parsed(.horizontalRule)

        default:
            return nil
        }
    }

    // MARK: Reference Dispatch

    func dispatchReferenceBlock(
        for token: RhoeLexer.Token,
        state: inout RhoeParserState
    ) -> BlockDispatchOutcome? {
        switch token.type {
        case .definitionTerm:
            return .parsed(parseDefinitionList(&state))

        case .footnoteDefinition:
            return .parsed(parseFootnoteDefinition(&state))

        case .admonitionStart(let type, let title, let collapsible):
            return .parsed(parseAdmonition(&state, type: type, title: title, collapsible: collapsible))

        case .fencedDivStart(let name, let colons):
            guard configuration.enableFencedDivs else { return nil }
            return .parsed(parseFencedDiv(&state, name: name, colons: colons))

        case .compositionDirectiveOpen(let keyword, let argument):
            return .parsed(parseCompositionDirective(&state, keyword: keyword, argument: argument))

        case .phase2DirectiveOpen(let command, let arguments):
            return .parsed(parsePhase2Directive(&state, command: command, arguments: arguments))

        case .placeholderToken(let fields):
            return .parsed(parsePlaceholder(&state, rawFields: fields))

        default:
            return nil
        }
    }

    // MARK: Token Classification

    func isBlockStartToken(_ token: RhoeLexer.Token) -> Bool {
        switch token.type {
        case .heading(_), .blockQuoteMarker(_), .listMarker(_, _),
             .codeBlockDelimiter(_), .horizontalRule, .definitionTerm:
            return true
        default:
            return false
        }
    }

    func isIndented(_ token: RhoeLexer.Token) -> Bool {
        if case .space(let count) = token.type {
            return count >= 4
        }
        return false
    }

    // MARK: Block Start Policy

    func isBlockBoundaryToken(_ token: RhoeLexer.Token) -> Bool {
        isBlockStartToken(token) || token.type == .eof
    }

    func shouldStopIndentedContinuation(
        before token: RhoeLexer.Token,
        snapshot: RhoeParserState
    ) -> Bool {
        snapshot.isStartOfLine && !isIndented(token)
    }

    func shouldContinueBlockQuoteLine(
        with next: RhoeLexer.Token,
        currentDepth: Int
    ) -> Bool {
        if case .blockQuoteMarker(let nextDepth) = next.type {
            return nextDepth >= currentDepth
        }

        return shouldTreatAsBlockQuoteTextContinuation(next)
    }

    func shouldTreatAsBlockQuoteTextContinuation(_ token: RhoeLexer.Token) -> Bool {
        guard !isBlockBoundaryToken(token) else {
            return false
        }

        if case .text = token.type {
            return true
        }

        return false
    }

    // MARK: Simple Block Policy

    func simpleBlockKind(for token: RhoeLexer.Token) -> SimpleBlockKind? {
        switch token.type {
        case .paragraph:
            return .paragraph
        case .tableSeparator:
            return .explicitTable
        case .newline, .space:
            return .ignorableWhitespace
        default:
            return nil
        }
    }
}
