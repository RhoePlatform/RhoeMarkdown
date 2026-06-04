import Foundation
import RhoeMarkdownModel

/// Parses RhoeDSL source into the canonical RhoeMarkdown AST.
///
/// RhoeDSL is a structured alternative syntax:
/// ```
/// Section(id: "intro") {
///     H1 { Introduction }
///     Paragraph { Hello **world**. }
/// }
/// ```
///
/// The parser produces the same `Block` and `Inline` types as the
/// classic RhoeMarkdown parser.
public struct RhoeDSLParser: Sendable {
    private let configuration: RhoeMarkdownKit.Configuration

    public init(configuration: RhoeMarkdownKit.Configuration = .default) {
        self.configuration = configuration
    }

    /// Parse DSL source into a list of blocks.
    public func parse(_ dsl: String) -> ([Block], [DSLDiagnostic]) {
        let lexer = RhoeDSLLexer()
        let tokens = lexer.tokenize(dsl)
        var state = RhoeDSLParserState(tokens: tokens)

        var blocks: [Block] = []

        state.skipNewlines()
        while !state.isAtEnd {
            if let block = parseNodeDeclaration(&state) {
                blocks.append(block)
            }
            state.skipNewlines()
        }

        return (blocks, state.diagnostics)
    }

    // MARK: - Node Declaration Parsing

    /// Parse: `Identifier ParameterList? Body? TrailingChain?`
    func parseNodeDeclaration(_ state: inout RhoeDSLParserState) -> Block? {
        state.skipNewlines()

        // Expect identifier (node name)
        guard let token = state.current,
              case .identifier(let name) = token.type else {
            if !state.isAtEnd {
                state.addDiagnostic("Expected node name, got \(state.current?.type ?? .eof)")
                state.advance()
            }
            return nil
        }
        state.advance()

        // Parse optional parameter list
        var params: [String: DSLValue] = [:]
        state.skipNewlines()
        if let token = state.current, case .leftParen = token.type {
            params = parseParameterList(&state)
        }

        // Parse optional body
        var bodyBlocks: [Block] = []
        var bodyText: String? = nil
        state.skipNewlines()
        if let token = state.current, case .leftBrace = token.type {
            let bodyType = DSLNodeRegistry.bodyType(for: name)
            switch bodyType {
            case .structural:
                bodyBlocks = parseStructuralBody(&state)
            case .leafProse:
                bodyText = parseLeafProseBody(&state)
            case .rawText:
                bodyText = parseRawTextBody(&state)
            case .noBody:
                // Consume braces even though body isn't expected
                state.advance() // {
                state.skipNewlines()
                if let t = state.current, case .rightBrace = t.type { state.advance() }
                state.addDiagnostic("Node '\(name)' does not accept a body")
            }
        }

        // Parse optional trailing chain
        state.skipNewlines()
        while let token = state.current, case .dot = token.type {
            let (key, value) = parseTrailingModifier(&state)
            if let key {
                params[key] = value
            }
        }

        // Map DSL node to AST block
        return DSLNodeMapper.mapToBlock(
            name: name,
            params: params,
            bodyBlocks: bodyBlocks,
            bodyText: bodyText,
            configuration: configuration
        )
    }

    // MARK: - Parameter List

    /// Parse: `"(" Parameter { "," Parameter } ")"`
    func parseParameterList(_ state: inout RhoeDSLParserState) -> [String: DSLValue] {
        guard state.expect(.leftParen) else { return [:] }

        var params: [String: DSLValue] = [:]

        state.skipNewlines()
        while let token = state.current, token.type != .rightParen {
            // Parse: Identifier ":" Value
            guard case .identifier(let key) = token.type else {
                state.addDiagnostic("Expected parameter name")
                state.advance()
                continue
            }
            state.advance()
            state.skipNewlines()

            guard state.expect(.colon) else {
                state.addDiagnostic("Expected ':' after parameter name '\(key)'")
                continue
            }
            state.skipNewlines()

            let value = parseValue(&state)
            params[key] = value

            state.skipNewlines()
            // Consume optional comma
            if let t = state.current, case .comma = t.type { state.advance() }
            state.skipNewlines()
        }

        _ = state.expect(.rightParen)
        return params
    }

    // MARK: - Value Parsing

    /// Parse a DSL value: string, number, boolean, null, array, or object.
    func parseValue(_ state: inout RhoeDSLParserState) -> DSLValue {
        guard let token = state.current else { return .null }

        switch token.type {
        case .stringLiteral(let s):
            state.advance()
            return .string(s)
        case .numberLiteral(let n):
            state.advance()
            return .number(n)
        case .booleanLiteral(let b):
            state.advance()
            return .boolean(b)
        case .nullLiteral:
            state.advance()
            return .null
        case .leftBracket:
            return parseArrayLiteral(&state)
        case .leftBrace:
            return parseObjectLiteral(&state)
        case .identifier(let name):
            // Bare identifier treated as string (convenience)
            state.advance()
            return .string(name)
        default:
            state.addDiagnostic("Expected value, got \(token.type)")
            state.advance()
            return .null
        }
    }

    func parseArrayLiteral(_ state: inout RhoeDSLParserState) -> DSLValue {
        guard state.expect(.leftBracket) else { return .array([]) }
        var elements: [DSLValue] = []
        state.skipNewlines()
        while let token = state.current, token.type != .rightBracket {
            elements.append(parseValue(&state))
            state.skipNewlines()
            if let t = state.current, case .comma = t.type { state.advance() }
            state.skipNewlines()
        }
        _ = state.expect(.rightBracket)
        return .array(elements)
    }

    func parseObjectLiteral(_ state: inout RhoeDSLParserState) -> DSLValue {
        guard state.expect(.leftBrace) else { return .object([:]) }
        var fields: [String: DSLValue] = [:]
        state.skipNewlines()
        while let token = state.current, token.type != .rightBrace {
            guard case .identifier(let key) = token.type else {
                state.advance()
                continue
            }
            state.advance()
            state.skipNewlines()
            _ = state.expect(.colon)
            state.skipNewlines()
            fields[key] = parseValue(&state)
            state.skipNewlines()
            if let t = state.current, case .comma = t.type { state.advance() }
            state.skipNewlines()
        }
        _ = state.expect(.rightBrace)
        return .object(fields)
    }

    // MARK: - Body Parsing

    /// Parse structural body: `"{" NodeDeclaration* "}"`
    func parseStructuralBody(_ state: inout RhoeDSLParserState) -> [Block] {
        guard state.expect(.leftBrace) else { return [] }
        var blocks: [Block] = []
        state.skipNewlines()
        while let token = state.current, token.type != .rightBrace {
            if state.isAtEnd { break }
            if let block = parseNodeDeclaration(&state) {
                blocks.append(block)
            }
            state.skipNewlines()
        }
        _ = state.expect(.rightBrace)
        return blocks
    }

    /// Parse leaf-prose body: `"{" text "}"`
    /// Extracts text between braces, which will be parsed as inline Markdown.
    func parseLeafProseBody(_ state: inout RhoeDSLParserState) -> String {
        guard state.expect(.leftBrace) else { return "" }
        var text = ""
        var depth = 1

        // Collect all tokens until matching }
        var lastWasContent = false
        while let token = state.current, depth > 0 {
            let needsSpace = lastWasContent && token.type != .rightBrace && token.type != .dot && token.type != .comma
            switch token.type {
            case .leftBrace: depth += 1; text += "{"; lastWasContent = false
            case .rightBrace:
                depth -= 1
                if depth > 0 { text += "}" }
                lastWasContent = false
            case .identifier(let s):
                if needsSpace { text += " " }
                text += s
                lastWasContent = true
            case .stringLiteral(let s): text += "\"\(s)\""; lastWasContent = true
            case .numberLiteral(let n):
                if needsSpace { text += " " }
                text += n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n)
                lastWasContent = true
            case .booleanLiteral(let b):
                if needsSpace { text += " " }
                text += b ? "true" : "false"
                lastWasContent = true
            case .nullLiteral: text += "null"; lastWasContent = true
            case .leftParen: text += "("; lastWasContent = false
            case .rightParen: text += ")"; lastWasContent = true
            case .leftBracket: text += "["; lastWasContent = false
            case .rightBracket: text += "]"; lastWasContent = true
            case .colon: text += ":"; lastWasContent = false
            case .comma: text += ","; lastWasContent = false
            case .dot: text += "."; lastWasContent = true
            case .newline: text += " "; lastWasContent = false
            case .eof: break
            }
            state.advance()
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parse raw text body (for Code, Text nodes): same as leaf-prose but without Markdown parsing.
    func parseRawTextBody(_ state: inout RhoeDSLParserState) -> String {
        return parseLeafProseBody(&state) // Same extraction, different downstream handling
    }

    // MARK: - Trailing Chain

    /// Parse: `"." Identifier "(" Value ")"`
    func parseTrailingModifier(_ state: inout RhoeDSLParserState) -> (String?, DSLValue) {
        guard state.expect(.dot) else { return (nil, .null) }
        guard let token = state.current, case .identifier(let key) = token.type else {
            return (nil, .null)
        }
        state.advance()

        // Parse optional value in parens
        if let t = state.current, case .leftParen = t.type {
            state.advance()
            state.skipNewlines()
            let value: DSLValue
            if let t2 = state.current, case .rightParen = t2.type {
                value = .boolean(true) // `.flag()` → flag=true
            } else {
                value = parseValue(&state)
            }
            state.skipNewlines()
            _ = state.expect(.rightParen)
            return (key, value)
        }

        return (key, .boolean(true))
    }
}

/// DSL parameter value types.
public enum DSLValue: Sendable, Equatable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null
    case array([DSLValue])
    case object([String: DSLValue])

    /// Extract as string, converting non-string types.
    public var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .number(let n): return n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n)
        case .boolean(let b): return b ? "true" : "false"
        default: return nil
        }
    }

    /// Extract as array of strings.
    public var stringArrayValue: [String]? {
        guard case .array(let arr) = self else { return nil }
        return arr.compactMap(\.stringValue)
    }
}
