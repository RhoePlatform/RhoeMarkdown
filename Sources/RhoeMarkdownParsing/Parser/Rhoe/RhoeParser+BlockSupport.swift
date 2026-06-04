import Foundation
import RhoeMarkdownModel

extension RhoeParser {

    // MARK: Block Advance

    func consumeParsedBlockOrAdvance(
        _ state: inout RhoeParserState,
        into blocks: inout [Block]
    ) {
        if let block = parseBlock(&state) {
            blocks.append(block)
        } else {
            state.advance()
        }
    }

    // MARK: Block Continuation

    func collectBlocks(
        _ state: inout RhoeParserState,
        until shouldStop: (RhoeLexer.Token, RhoeParserState) -> Bool
    ) -> [Block] {
        collectBlocks(
            &state,
            until: shouldStop,
            using: { state, blocks in
                consumeParsedBlockOrAdvance(&state, into: &blocks)
            }
        )
    }

    func collectBlocks(
        _ state: inout RhoeParserState,
        until shouldStop: (RhoeLexer.Token, RhoeParserState) -> Bool,
        using appendNextBlock: (inout RhoeParserState, inout [Block]) -> Void
    ) -> [Block] {
        var blocks: [Block] = []

        while let token = state.current {
            let snapshot = state
            if shouldStop(token, snapshot) {
                break
            }

            appendNextBlock(&state, &blocks)
        }

        return blocks
    }

    // MARK: Block Fallback

    func parseFallbackBlock(
        for token: RhoeLexer.Token,
        state: inout RhoeParserState
    ) -> Block? {
        return parseFallbackParagraphBlock(for: token, state: &state)
    }

    // MARK: Block Fallback Policy

    func shouldParseFallbackParagraph(from token: RhoeLexer.Token) -> Bool {
        isInlineToken(token)
    }

    // MARK: Block Fallback Inline

    func parseFallbackParagraphBlock(
        for token: RhoeLexer.Token,
        state: inout RhoeParserState
    ) -> Block? {
        guard shouldParseFallbackParagraph(from: token) else {
            return nil
        }

        return parsePromotedTopLevelParagraphBlock(&state)
    }

    // MARK: Parser Support

    func countWords(in text: String) -> Int {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    // MARK: Parse Pipeline

    func parseMarkdown(_ markdown: String) -> RhoeMarkdownKit.ParseResult {
        let startTime = Date().timeIntervalSinceReferenceDate
        let referenceExtraction = extractLinkReferenceDefinitions(from: markdown)
        let source = referenceExtraction.markdown
        let tokens = lexer.tokenize(source)

        var state = RhoeParserState(tokens: tokens, source: source)
        let (parsedBlocks, yamlFrontmatter) = parseBlocksWithMetadata(&state)
        let blocks = resolveLinkReferences(
            in: parsedBlocks,
            definitions: referenceExtraction.definitions
        )

        let parseTime = Date().timeIntervalSinceReferenceDate - startTime
        let metadata = makeDocumentMetadata(
            for: markdown,
            yamlFrontmatter: yamlFrontmatter
        )
        let document = RhoeMarkdownKit.Document(blocks: blocks, metadata: metadata)

        return RhoeMarkdownKit.ParseResult(
            document: document,
            diagnostics: state.diagnostics,
            parseTime: parseTime
        )
    }

    fileprivate func makeDocumentMetadata(
        for markdown: String,
        yamlFrontmatter: [String: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue]?
    ) -> RhoeMarkdownKit.DocumentMetadata {
        let wordCount = countWords(in: markdown)
        let estimatedReadingTime = Double(wordCount) / 250.0 * 60.0

        return RhoeMarkdownKit.DocumentMetadata(
            wordCount: wordCount,
            estimatedReadingTime: estimatedReadingTime,
            yamlFrontmatter: yamlFrontmatter
        )
    }
}
