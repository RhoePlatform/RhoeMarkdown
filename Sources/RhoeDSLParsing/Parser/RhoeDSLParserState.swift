import Foundation

/// Cursor state for the RhoeDSL parser.
struct RhoeDSLParserState {
    let tokens: [RhoeDSLLexer.Token]
    var currentIndex: Int = 0
    var diagnostics: [DSLDiagnostic] = []

    var current: RhoeDSLLexer.Token? {
        guard currentIndex < tokens.count else { return nil }
        return tokens[currentIndex]
    }

    var isAtEnd: Bool {
        guard let current else { return true }
        if case .eof = current.type { return true }
        return false
    }

    mutating func advance() {
        if currentIndex < tokens.count { currentIndex += 1 }
    }

    mutating func skipNewlines() {
        while let token = current, case .newline = token.type {
            advance()
        }
    }

    func peek(offset: Int = 0) -> RhoeDSLLexer.Token? {
        let index = currentIndex + offset
        guard index < tokens.count else { return nil }
        return tokens[index]
    }

    mutating func expect(_ expected: RhoeDSLLexer.TokenType) -> Bool {
        guard let token = current, token.type == expected else { return false }
        advance()
        return true
    }

    mutating func addDiagnostic(_ message: String, line: Int? = nil, column: Int? = nil) {
        diagnostics.append(DSLDiagnostic(
            message: message,
            line: line ?? current?.line ?? 0,
            column: column ?? current?.column ?? 0
        ))
    }
}

/// Diagnostic emitted during DSL parsing.
public struct DSLDiagnostic: Sendable, Equatable {
    public let message: String
    public let line: Int
    public let column: Int
}
