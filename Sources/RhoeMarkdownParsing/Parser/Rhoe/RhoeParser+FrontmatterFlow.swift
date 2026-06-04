import Foundation
import RhoeMarkdownModel

extension RhoeParser {
    func parseOptionalYAMLFrontmatter(
        _ state: inout RhoeParserState
    ) -> [String: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue]? {
        guard let token = state.current, case .yamlFrontmatterStart = token.type else {
            return nil
        }

        return parseYAMLFrontmatter(&state)
    }

    func parseYAMLFrontmatter(
        _ state: inout RhoeParserState
    ) -> [String: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue]? {
        guard let token = state.current, case .yamlFrontmatterStart = token.type else {
            return nil
        }
        state.advance()

        consumeLeadingFrontmatterNewlineIfPresent(&state)

        guard let token = state.current,
              case .yamlFrontmatterContent(let yamlContent) = token.type else {
            return [:]
        }
        state.advance()

        consumeFrontmatterEndDelimiterIfPresent(&state)
        consumeTrailingFrontmatterNewlineIfPresent(&state)

        return parseYAMLContent(yamlContent)
    }

    fileprivate func consumeLeadingFrontmatterNewlineIfPresent(_ state: inout RhoeParserState) {
        if let token = state.current, case .newline = token.type {
            state.advance()
        }
    }

    fileprivate func consumeFrontmatterEndDelimiterIfPresent(_ state: inout RhoeParserState) {
        if let token = state.current, case .yamlFrontmatterEnd = token.type {
            state.advance()
        }
    }

    fileprivate func consumeTrailingFrontmatterNewlineIfPresent(_ state: inout RhoeParserState) {
        if let token = state.current, case .newline = token.type {
            state.advance()
        }
    }
}
