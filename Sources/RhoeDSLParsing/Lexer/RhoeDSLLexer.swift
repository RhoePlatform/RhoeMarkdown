import Foundation

/// Tokenizes RhoeDSL source into a stream of typed tokens.
///
/// The DSL syntax is brace-delimited and whitespace-agnostic:
/// ```
/// Section(id: "intro") {
///     H1 { Introduction }
///     Paragraph { Hello **world**. }
/// }
/// ```
public struct RhoeDSLLexer: Sendable {

    // MARK: - Token Types

    public enum TokenType: Sendable, Equatable {
        case identifier(String)       // Node names, parameter names
        case stringLiteral(String)    // "hello world" with escapes
        case numberLiteral(Double)    // 42, 3.14, -1
        case booleanLiteral(Bool)     // true, false
        case nullLiteral              // null
        case leftParen                // (
        case rightParen               // )
        case leftBrace                // {
        case rightBrace               // }
        case leftBracket              // [
        case rightBracket             // ]
        case colon                    // :
        case comma                    // ,
        case dot                      // .
        case newline
        case eof
    }

    public struct Token: Sendable, Equatable {
        public let type: TokenType
        public let line: Int
        public let column: Int
    }

    // MARK: - Lexer State

    private struct LexerState {
        let source: String
        var index: String.Index
        var line: Int = 1
        var column: Int = 1
        var tokens: [Token] = []

        init(source: String) {
            self.source = source
            self.index = source.startIndex
        }

        var isAtEnd: Bool { index >= source.endIndex }

        func peek() -> Character? {
            guard !isAtEnd else { return nil }
            return source[index]
        }

        func peek(offset: Int) -> Character? {
            guard let idx = source.index(index, offsetBy: offset, limitedBy: source.endIndex) else { return nil }
            guard idx < source.endIndex else { return nil }
            return source[idx]
        }

        mutating func advance() {
            guard !isAtEnd else { return }
            let char = source[index]
            index = source.index(after: index)
            if char == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }

        mutating func emit(_ type: TokenType, line: Int, column: Int) {
            tokens.append(Token(type: type, line: line, column: column))
        }
    }

    // MARK: - Public API

    public init() {}

    public func tokenize(_ source: String) -> [Token] {
        var state = LexerState(source: source)

        while !state.isAtEnd {
            guard let char = state.peek() else { break }

            switch char {
            case " ", "\t", "\r":
                state.advance() // Skip whitespace

            case "\n":
                let line = state.line
                let col = state.column
                state.advance()
                state.emit(.newline, line: line, column: col)

            case "(": emit(&state, .leftParen)
            case ")": emit(&state, .rightParen)
            case "{": emit(&state, .leftBrace)
            case "}": emit(&state, .rightBrace)
            case "[": emit(&state, .leftBracket)
            case "]": emit(&state, .rightBracket)
            case ":": emit(&state, .colon)
            case ",": emit(&state, .comma)
            case ".": emit(&state, .dot)

            case "\"":
                lexStringLiteral(&state)

            case "/":
                if state.peek(offset: 1) == "/" {
                    lexLineComment(&state)
                } else if state.peek(offset: 1) == "*" {
                    lexBlockComment(&state)
                } else {
                    state.advance() // Skip unknown
                }

            case "-" where state.peek(offset: 1)?.isNumber == true:
                lexNumberLiteral(&state)

            default:
                if char.isNumber {
                    lexNumberLiteral(&state)
                } else if char.isLetter || char == "_" {
                    lexIdentifierOrKeyword(&state)
                } else {
                    state.advance() // Skip unknown characters
                }
            }
        }

        state.emit(.eof, line: state.line, column: state.column)
        return state.tokens
    }

    // MARK: - Lexer Helpers

    private func emit(_ state: inout LexerState, _ type: TokenType) {
        state.emit(type, line: state.line, column: state.column)
        state.advance()
    }

    private func lexIdentifierOrKeyword(_ state: inout LexerState) {
        let line = state.line
        let col = state.column
        var name = ""

        while let char = state.peek(), char.isLetter || char.isNumber || char == "_" || char == "-" {
            name.append(char)
            state.advance()
        }

        switch name {
        case "true": state.emit(.booleanLiteral(true), line: line, column: col)
        case "false": state.emit(.booleanLiteral(false), line: line, column: col)
        case "null": state.emit(.nullLiteral, line: line, column: col)
        default: state.emit(.identifier(name), line: line, column: col)
        }
    }

    private func lexStringLiteral(_ state: inout LexerState) {
        let line = state.line
        let col = state.column
        state.advance() // consume opening "

        var value = ""
        while let char = state.peek(), char != "\"" {
            if char == "\\" {
                state.advance() // consume backslash
                if let escaped = state.peek() {
                    switch escaped {
                    case "\"": value.append("\"")
                    case "\\": value.append("\\")
                    case "n": value.append("\n")
                    case "t": value.append("\t")
                    case "r": value.append("\r")
                    case "0": value.append("\0")
                    default: value.append(escaped)
                    }
                    state.advance()
                }
            } else {
                value.append(char)
                state.advance()
            }
        }

        if state.peek() == "\"" {
            state.advance() // consume closing "
        }

        state.emit(.stringLiteral(value), line: line, column: col)
    }

    private func lexNumberLiteral(_ state: inout LexerState) {
        let line = state.line
        let col = state.column
        var numStr = ""

        // Optional negative sign
        if state.peek() == "-" {
            numStr.append("-")
            state.advance()
        }

        // Integer part
        while let char = state.peek(), char.isNumber {
            numStr.append(char)
            state.advance()
        }

        // Decimal part
        if state.peek() == "." && state.peek(offset: 1)?.isNumber == true {
            numStr.append(".")
            state.advance()
            while let char = state.peek(), char.isNumber {
                numStr.append(char)
                state.advance()
            }
        }

        if let value = Double(numStr) {
            state.emit(.numberLiteral(value), line: line, column: col)
        }
    }

    private func lexLineComment(_ state: inout LexerState) {
        state.advance() // /
        state.advance() // /
        while let char = state.peek(), char != "\n" {
            state.advance()
        }
    }

    private func lexBlockComment(_ state: inout LexerState) {
        state.advance() // /
        state.advance() // *
        while !state.isAtEnd {
            if state.peek() == "*" && state.peek(offset: 1) == "/" {
                state.advance() // *
                state.advance() // /
                return
            }
            state.advance()
        }
    }
}
