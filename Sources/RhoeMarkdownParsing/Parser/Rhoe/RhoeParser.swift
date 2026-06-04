import Foundation
import RhoeMarkdownModel

/// GitHub Flavored Markdown Parser - World-class parsing engine 🚀
public struct RhoeParser: Sendable {
    let lexer: RhoeLexer
    let configuration: RhoeMarkdownKit.Configuration

    public init(configuration: RhoeMarkdownKit.Configuration = .github) {
        self.configuration = configuration
        var lexer = RhoeLexer()
        lexer.enableFancyLists = configuration.enableFancyLists
        lexer.enableYAMLFrontmatter = configuration.enableYAMLFrontmatter
        self.lexer = lexer
    }

    public func parse(_ markdown: String) async -> RhoeMarkdownKit.ParseResult {
        parseMarkdown(markdown)
    }
}
