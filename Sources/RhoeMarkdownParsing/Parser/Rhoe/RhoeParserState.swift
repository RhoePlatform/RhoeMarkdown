import Foundation
import RhoeMarkdownModel

struct RhoeParserState {
    var tokens: [RhoeLexer.Token]
    var currentIndex: Int = 0
    var diagnostics: [RhoeMarkdownKit.Diagnostic] = []
    let sourceLines: [String]

    init(tokens: [RhoeLexer.Token], source: String = "") {
        self.tokens = tokens
        self.sourceLines = source.components(separatedBy: "\n")
    }

    @inline(__always)
    var isStartOfLine: Bool {
        if currentIndex > 0 {
            let previousToken = tokens[currentIndex - 1]
            return previousToken.type == .newline
        }
        return currentIndex == 0
    }

    @inline(__always)
    var current: RhoeLexer.Token? {
        currentIndex < tokens.count ? tokens[currentIndex] : nil
    }

    @inline(__always)
    func peek(offset: Int = 1) -> RhoeLexer.Token? {
        let index = currentIndex + offset
        return index < tokens.count ? tokens[index] : nil
    }

    @inline(__always)
    mutating func advance() {
        if currentIndex < tokens.count {
            currentIndex += 1
        }
    }

    @inline(__always)
    mutating func consume(_ type: RhoeLexer.TokenType) -> RhoeLexer.Token? {
        if let token = current, token.type == type {
            advance()
            return token
        }
        return nil
    }

    mutating func consumeWhile(_ predicate: (RhoeLexer.Token) -> Bool) -> [RhoeLexer.Token] {
        var consumed: [RhoeLexer.Token] = []
        while let token = current, predicate(token) {
            consumed.append(token)
            advance()
        }
        return consumed
    }

    mutating func addDiagnostic(_ diagnostic: RhoeMarkdownKit.Diagnostic) {
        diagnostics.append(diagnostic)
    }
}
