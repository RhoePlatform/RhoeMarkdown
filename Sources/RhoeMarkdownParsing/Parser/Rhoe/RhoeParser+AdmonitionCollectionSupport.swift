import Foundation
import RhoeMarkdownModel

extension RhoeParser {
    func collectAdmonitionBlocks(_ state: inout RhoeParserState) -> [Block] {
        collectBlocks(&state, until: { token, snapshot in
            shouldStopAdmonitionBlockCollection(before: token, snapshot: snapshot)
        })
    }

    func shouldStopAdmonitionBlockCollection(
        before token: RhoeLexer.Token,
        snapshot: RhoeParserState
    ) -> Bool {
        _ = snapshot

        if case .admonitionEnd = token.type { return true }
        if case .eof = token.type { return true }
        return false
    }

    func consumeAdmonitionEndIfPresent(_ state: inout RhoeParserState) {
        if let token = state.current, case .admonitionEnd = token.type {
            state.advance()
        }
    }
}
