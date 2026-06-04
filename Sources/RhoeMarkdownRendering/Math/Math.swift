import Foundation
import RhoeMarkdownModel
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Frontier-level math expression support for RhoeMarkdownKit 🧮
public struct Math {
    
    // MARK: - Math Expression AST
    
    /// Mathematical expression tree
    public indirect enum Expression: Sendable, Equatable {
        case number(String)
        case identifier(String)
        case symbol(String)
        case unary(operator: String, operand: Expression)
        case binary(left: Expression, operator: String, right: Expression)
        case fraction(numerator: Expression, denominator: Expression)
        case superscript(base: Expression, exponent: Expression)
        case `subscript`(base: Expression, subscript: Expression)
        case radical(degree: Expression?, radicand: Expression)
        case parentheses(Expression)
        case brackets(Expression)
        case braces(Expression)
        case function(name: String, arguments: [Expression])
        case matrix(rows: [[Expression]])
        case integral(lower: Expression?, upper: Expression?, integrand: Expression)
        case sum(lower: Expression?, upper: Expression?, summand: Expression)
        case product(lower: Expression?, upper: Expression?, factor: Expression)
        case limit(variable: String, approaching: Expression, expression: Expression)
        case text(String)
        case space
        case newline
    }
    
    // MARK: - Public API
    
    /// Parse LaTeX math expression into AST
    public static func parse(_ latex: String) -> Expression {
        let parser = MathParser(input: latex)
        return parser.parse()
    }
    
    /// Render math expression to HTML with MathJax/KaTeX formatting
    public static func renderHTML(_ expression: Expression) -> String {
        let renderer = MathHTMLRenderer()
        return renderer.render(expression)
    }
    
    /// Render math expression to native MathML for modern browsers
    public static func renderMathML(_ expression: Expression, inline: Bool = true, latexSource: String? = nil) -> String {
        let renderer = MathMLRenderer()
        return renderer.render(expression, inline: inline, latexSource: latexSource)
    }
    
    // MARK: - LaTeX Macro Support

    /// A LaTeX macro definition parsed from `\newcommand` or `\renewcommand`.
    public struct MacroDefinition: Sendable, Equatable {
        public let name: String          // e.g., "\\R" or "\\vect"
        public let argCount: Int         // Number of arguments (0-9)
        public let expansion: String     // Replacement template with #1, #2, etc.

        public init(name: String, argCount: Int, expansion: String) {
            self.name = name
            self.argCount = argCount
            self.expansion = expansion
        }
    }

    /// Parse `\newcommand` and `\renewcommand` definitions from a LaTeX string.
    ///
    /// Recognized patterns:
    /// - `\newcommand{\name}{expansion}`
    /// - `\newcommand{\name}[argcount]{expansion}`
    /// - `\renewcommand{\name}{expansion}`
    /// - `\def\name{expansion}`
    public static func parseMacroDefinitions(from latex: String) -> [MacroDefinition] {
        var macros: [MacroDefinition] = []
        var remaining = latex[...]

        while !remaining.isEmpty {
            // Find \newcommand, \renewcommand, or \def
            guard let cmdRange = remaining.range(of: #"\\(?:re)?newcommand|\\def"#, options: .regularExpression) else {
                break
            }

            remaining = remaining[cmdRange.upperBound...]
            let isDefStyle = latex[cmdRange].hasSuffix("def")

            if isDefStyle {
                // \def\name{expansion}
                guard remaining.hasPrefix("\\") else { continue }
                remaining = remaining.dropFirst() // consume backslash
                // Read the macro name (letters only)
                var name = "\\"
                while let ch = remaining.first, ch.isLetter {
                    name.append(ch)
                    remaining = remaining.dropFirst()
                }
                guard name.count > 1 else { continue }
                // Read expansion in braces
                guard let expansion = extractBraceContent(&remaining) else { continue }
                macros.append(MacroDefinition(name: name, argCount: 0, expansion: expansion))
            } else {
                // \newcommand{\name}[argcount]{expansion}
                guard let name = extractBraceContent(&remaining) else { continue }
                guard name.hasPrefix("\\") else { continue }

                // Optional argument count [n]
                var argCount = 0
                if remaining.first == "[" {
                    remaining = remaining.dropFirst()
                    if let digit = remaining.first, digit.isNumber {
                        argCount = Int(String(digit)) ?? 0
                        remaining = remaining.dropFirst()
                    }
                    if remaining.first == "]" {
                        remaining = remaining.dropFirst()
                    }
                }

                guard let expansion = extractBraceContent(&remaining) else { continue }
                macros.append(MacroDefinition(name: name, argCount: argCount, expansion: expansion))
            }
        }

        return macros
    }

    /// Apply macro definitions to a LaTeX expression, replacing occurrences
    /// with their expanded forms.
    public static func expandMacros(_ latex: String, macros: [MacroDefinition]) -> String {
        guard !macros.isEmpty else { return latex }

        var result = latex

        // Apply macros iteratively (up to a limit to prevent infinite loops)
        for _ in 0..<10 {
            var changed = false

            for macro in macros {
                if macro.argCount == 0 {
                    // Simple substitution: \name → expansion
                    let old = result
                    result = result.replacingOccurrences(of: macro.name, with: macro.expansion)
                    if result != old { changed = true }
                } else {
                    // Argument substitution: \name{arg1}{arg2} → expansion with #1, #2 replaced
                    while let range = result.range(of: macro.name) {
                        var pos = range.upperBound
                        var args: [String] = []
                        var validArgs = true

                        // Collect arguments
                        for _ in 0..<macro.argCount {
                            let remaining = result[pos...]
                            var sub = remaining[...]
                            if let arg = extractBraceContent(&sub) {
                                args.append(arg)
                                pos = sub.startIndex
                            } else {
                                validArgs = false
                                break
                            }
                        }

                        guard validArgs else { break }

                        // Build expanded text
                        var expanded = macro.expansion
                        for (i, arg) in args.enumerated() {
                            expanded = expanded.replacingOccurrences(of: "#\(i + 1)", with: arg)
                        }

                        result = String(result[..<range.lowerBound]) + expanded + String(result[pos...])
                        changed = true
                    }
                }
            }

            if !changed { break }
        }

        return result
    }

    /// Extract content between balanced braces `{...}`.
    private static func extractBraceContent(_ text: inout Substring) -> String? {
        // Skip whitespace
        while text.first?.isWhitespace == true { text = text.dropFirst() }

        guard text.first == "{" else { return nil }
        text = text.dropFirst() // consume opening brace

        var depth = 1
        var content = ""

        while !text.isEmpty && depth > 0 {
            let ch = text.removeFirst()
            if ch == "{" {
                depth += 1
                if depth > 1 { content.append(ch) }
            } else if ch == "}" {
                depth -= 1
                if depth > 0 { content.append(ch) }
            } else {
                content.append(ch)
            }
        }

        return depth == 0 ? content : nil
    }

    /// Convert LaTeX to properly formatted HTML
    public static func latexToHTML(_ latex: String, inline: Bool = true) -> String {
        let escaped = latex
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        
        if inline {
            return "<span class=\"math math-inline\">\\(\(escaped)\\)</span>"
        } else {
            return "<div class=\"math math-display\">\\[\(escaped)\\]</div>"
        }
    }
    
    /// Convert LaTeX to native MathML
    public static func latexToMathML(_ latex: String, inline: Bool = true) -> String {
        let expression = parse(latex)
        return renderMathML(expression, inline: inline, latexSource: latex)
    }
    
    /// Get CSS for math rendering (MathJax/KaTeX compatible)
    public static func getMathCSS() -> String {
        return """
        /* Math expression styling */
        .math {
            font-family: 'Latin Modern Math', 'STIX Two Math', serif;
        }
        
        .math-inline {
            display: inline;
            vertical-align: middle;
        }
        
        .math-display {
            display: block;
            text-align: center;
            margin: 1em 0;
            overflow-x: auto;
        }
        
        /* Fraction styling */
        .math-frac {
            display: inline-block;
            vertical-align: middle;
            text-align: center;
        }
        
        .math-frac-num {
            display: block;
            border-bottom: 1px solid currentColor;
            padding-bottom: 0.1em;
        }
        
        .math-frac-den {
            display: block;
            padding-top: 0.1em;
        }
        
        /* Superscript/subscript */
        .math-sup {
            font-size: 0.8em;
            vertical-align: super;
        }
        
        .math-sub {
            font-size: 0.8em;
            vertical-align: sub;
        }
        
        /* Matrix styling */
        .math-matrix {
            display: inline-table;
            vertical-align: middle;
            border-left: 1px solid currentColor;
            border-right: 1px solid currentColor;
            padding: 0.2em;
        }
        
        .math-matrix-row {
            display: table-row;
        }
        
        .math-matrix-cell {
            display: table-cell;
            padding: 0.1em 0.3em;
            text-align: center;
        }
        
        /* Integral, sum, product symbols */
        .math-bigop {
            font-size: 1.5em;
            vertical-align: middle;
        }
        
        .math-limits {
            display: inline-block;
            text-align: center;
            vertical-align: middle;
        }
        
        .math-limit-above {
            display: block;
            font-size: 0.7em;
        }
        
        .math-limit-below {
            display: block;
            font-size: 0.7em;
        }
        """
    }
}

// MARK: - Math Parser

private class MathParser {
    private let tokens: [MathToken]
    private var current = 0
    
    init(input: String) {
        let tokenizer = MathTokenizer(input: input)
        self.tokens = tokenizer.tokenize()
    }
    
    func parse() -> Math.Expression {
        return parseExpression()
    }
    
    private func parseExpression() -> Math.Expression {
        var left = parseTerm()
        
        while !isAtEnd() {
            if match(.plus) {
                let right = parseTerm()
                left = .binary(left: left, operator: "+", right: right)
            } else if match(.minus) {
                let right = parseTerm()
                left = .binary(left: left, operator: "-", right: right)
            } else {
                break
            }
        }
        
        return left
    }
    
    private func parseTerm() -> Math.Expression {
        var left = parseFactor()
        
        while !isAtEnd() {
            if match(.times) {
                let right = parseFactor()
                left = .binary(left: left, operator: "×", right: right)
            } else if match(.divide) {
                let right = parseFactor()
                left = .binary(left: left, operator: "÷", right: right)
            } else if peek()?.type == .identifier || peek()?.type == .number || peek()?.type == .leftParen {
                // Implicit multiplication
                let right = parseFactor()
                left = .binary(left: left, operator: "", right: right)
            } else {
                break
            }
        }
        
        return left
    }
    
    private func parseFactor() -> Math.Expression {
        // Handle unary operators
        if match(.minus) {
            let operand = parseFactor()
            return .unary(operator: "-", operand: operand)
        }
        
        return parsePower()
    }
    
    private func parsePower() -> Math.Expression {
        var base = parseAtom()
        
        while !isAtEnd() {
            if match(.caret) {
                let exponent = parseAtom()
                base = .superscript(base: base, exponent: exponent)
            } else if match(.underscore) {
                let sub = parseAtom()
                base = .`subscript`(base: base, subscript: sub)
            } else {
                break
            }
        }
        
        return base
    }
    
    private func parseAtom() -> Math.Expression {
        // Numbers
        if let token = match(where: { $0.type == .number }) {
            return .number(token.value)
        }
        
        // Identifiers
        if let token = match(where: { $0.type == .identifier }) {
            // Check for functions
            if peek()?.type == .leftParen {
                advance() // consume (
                var args: [Math.Expression] = []
                
                while peek()?.type != .rightParen && !isAtEnd() {
                    args.append(parseExpression())
                    if peek()?.type == .comma {
                        advance()
                    }
                }
                
                if peek()?.type == .rightParen {
                    advance()
                }
                
                return .function(name: token.value, arguments: args)
            }
            
            return .identifier(token.value)
        }
        
        // Commands
        if let token = match(where: { $0.type == .command }) {
            return parseCommand(token.value)
        }
        
        // Parentheses
        if match(.leftParen) {
            let expr = parseExpression()
            _ = match(.rightParen)
            return .parentheses(expr)
        }
        
        // Brackets
        if match(.leftBracket) {
            let expr = parseExpression()
            _ = match(.rightBracket)
            return .brackets(expr)
        }
        
        // Braces
        if match(.leftBrace) {
            let expr = parseExpression()
            _ = match(.rightBrace)
            return expr // Braces are just grouping in LaTeX
        }
        
        return .text("")
    }
    
    private func parseCommand(_ command: String) -> Math.Expression {
        switch command {
        case "frac":
            let num = parseGroup()
            let den = parseGroup()
            return .fraction(numerator: num, denominator: den)
            
        case "sqrt":
            if peek()?.type == .leftBracket {
                advance()
                let degree = parseExpression()
                _ = match(.rightBracket)
                let radicand = parseGroup()
                return .radical(degree: degree, radicand: radicand)
            } else {
                let radicand = parseGroup()
                return .radical(degree: nil, radicand: radicand)
            }
            
        case "int":
            return parseIntegral()
            
        case "sum":
            return parseSum()
            
        case "prod":
            return parseProduct()
            
        case "lim":
            return parseLimit()
            
        case "begin":
            if let token = peek() {
                let envName = token.value
                switch envName {
                case "matrix", "pmatrix", "bmatrix", "vmatrix", "Vmatrix", "Bmatrix":
                    advance()
                    return parseMatrix()
                case "align", "align*", "equation", "equation*", "gather", "gather*",
                     "gathered", "aligned", "multline", "multline*", "split":
                    advance()
                    return parseAlignEnvironment(name: envName)
                case "cases":
                    advance()
                    return parseCasesEnvironment()
                default:
                    break
                }
            }
            return .text("")

        case "operatorname":
            let arg = parseGroup()
            return .function(name: "operatorname", arguments: [arg])

        case "text", "textrm", "textit", "textbf":
            let arg = parseGroup()
            return .text(renderExpressionToText(arg))

        default:
            // Greek letters and other symbols
            if let symbol = MathSymbols.symbol(for: command) {
                return .symbol(symbol)
            }
            // Named operators (sin, cos, log, etc.)
            if ["sin", "cos", "tan", "sec", "csc", "cot",
                "arcsin", "arccos", "arctan",
                "sinh", "cosh", "tanh",
                "log", "ln", "exp", "det", "dim", "ker",
                "deg", "hom", "gcd", "max", "min", "arg",
                "sup", "inf", "mod"].contains(command) {
                return .function(name: command, arguments: [])
            }
            return .text("\\\(command)")
        }
    }

    /// Parse an alignment environment (align, equation, gather, etc.)
    private func parseAlignEnvironment(name: String) -> Math.Expression {
        var rows: [[Math.Expression]] = []
        var currentRow: [Math.Expression] = []
        var currentCell = [Math.Expression]()

        while let token = peek() {
            if token.type == .command && token.value == "end" {
                advance()
                if peek()?.value == name { advance() }
                break
            } else if token.type == .command && (token.value == "\\\\" || token.value == "newline") {
                advance()
                if !currentCell.isEmpty {
                    currentRow.append(currentCell.count == 1 ? currentCell[0] : .text(""))
                }
                if !currentRow.isEmpty { rows.append(currentRow) }
                currentRow = []
                currentCell = []
            } else if token.type == .other && token.value == "&" {
                advance()
                if !currentCell.isEmpty {
                    currentRow.append(currentCell.count == 1 ? currentCell[0] : .text(""))
                }
                currentCell = []
            } else {
                currentCell.append(parseAtom())
            }
        }

        if !currentCell.isEmpty {
            currentRow.append(currentCell.count == 1 ? currentCell[0] : .text(""))
        }
        if !currentRow.isEmpty { rows.append(currentRow) }

        return .matrix(rows: rows)
    }

    /// Parse a cases environment { x if condition \\ y otherwise }
    private func parseCasesEnvironment() -> Math.Expression {
        return parseAlignEnvironment(name: "cases")
    }

    /// Simple expression-to-text conversion for \text{} commands
    private func renderExpressionToText(_ expr: Math.Expression) -> String {
        switch expr {
        case .text(let t): return t
        case .identifier(let i): return i
        case .number(let n): return n
        default: return ""
        }
    }

    private func parseGroup() -> Math.Expression {
        if match(.leftBrace) {
            let expr = parseExpression()
            _ = match(.rightBrace)
            return expr
        }
        return parseAtom()
    }
    
    private func parseIntegral() -> Math.Expression {
        var lower: Math.Expression?
        var upper: Math.Expression?
        
        if match(.underscore) {
            lower = parseGroup()
        }
        if match(.caret) {
            upper = parseGroup()
        }
        
        let integrand = parseExpression()
        return .integral(lower: lower, upper: upper, integrand: integrand)
    }
    
    private func parseSum() -> Math.Expression {
        var lower: Math.Expression?
        var upper: Math.Expression?
        
        if match(.underscore) {
            lower = parseGroup()
        }
        if match(.caret) {
            upper = parseGroup()
        }
        
        let summand = parseExpression()
        return .sum(lower: lower, upper: upper, summand: summand)
    }
    
    private func parseProduct() -> Math.Expression {
        var lower: Math.Expression?
        var upper: Math.Expression?
        
        if match(.underscore) {
            lower = parseGroup()
        }
        if match(.caret) {
            upper = parseGroup()
        }
        
        let factor = parseExpression()
        return .product(lower: lower, upper: upper, factor: factor)
    }
    
    private func parseLimit() -> Math.Expression {
        _ = match(.underscore)
        
        // Parse variable and approaching value
        let varExpr = parseGroup()
        var variable = "x"
        var approaching = Math.Expression.number("0")
        
        if case .binary(let left, "→", let right) = varExpr {
            if case .identifier(let v) = left {
                variable = v
            }
            approaching = right
        }
        
        let expression = parseExpression()
        return .limit(variable: variable, approaching: approaching, expression: expression)
    }
    
    private func parseMatrix() -> Math.Expression {
        var rows: [[Math.Expression]] = []
        var currentRow: [Math.Expression] = []
        
        while !isAtEnd() {
            if let token = peek() {
                if token.type == .command && token.value == "end" {
                    advance() // consume \end
                    advance() // consume {matrix}
                    break
                }
                
                if token.value == "\\\\" {
                    advance()
                    if !currentRow.isEmpty {
                        rows.append(currentRow)
                        currentRow = []
                    }
                    continue
                }
                
                if token.value == "&" {
                    advance()
                    continue
                }
            }
            
            currentRow.append(parseExpression())
        }
        
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        return .matrix(rows: rows)
    }
    
    // MARK: - Parser Helpers
    
    private func match(_ type: MathToken.TokenType) -> Bool {
        if peek()?.type == type {
            advance()
            return true
        }
        return false
    }
    
    private func match(where predicate: (MathToken) -> Bool) -> MathToken? {
        if let token = peek(), predicate(token) {
            advance()
            return token
        }
        return nil
    }
    
    private func peek() -> MathToken? {
        guard current < tokens.count else { return nil }
        return tokens[current]
    }
    
    private func advance() {
        if current < tokens.count {
            current += 1
        }
    }
    
    private func isAtEnd() -> Bool {
        return current >= tokens.count
    }
}

// MARK: - Math Tokenizer

private struct MathToken {
    enum TokenType {
        case number
        case identifier
        case command
        case plus, minus, times, divide
        case caret, underscore
        case leftParen, rightParen
        case leftBracket, rightBracket
        case leftBrace, rightBrace
        case comma
        case other
    }
    
    let type: TokenType
    let value: String
}

private class MathTokenizer {
    private let input: String
    private var current: String.Index
    
    init(input: String) {
        self.input = input
        self.current = input.startIndex
    }
    
    func tokenize() -> [MathToken] {
        var tokens: [MathToken] = []
        
        while !isAtEnd() {
            skipWhitespace()
            if isAtEnd() { break }
            
            if let token = nextToken() {
                tokens.append(token)
            }
        }
        
        return tokens
    }
    
    private func nextToken() -> MathToken? {
        let char = peek()
        
        switch char {
        case "+": advance(); return MathToken(type: .plus, value: "+")
        case "-": advance(); return MathToken(type: .minus, value: "-")
        case "*": advance(); return MathToken(type: .times, value: "*")
        case "/": advance(); return MathToken(type: .divide, value: "/")
        case "^": advance(); return MathToken(type: .caret, value: "^")
        case "_": advance(); return MathToken(type: .underscore, value: "_")
        case "(": advance(); return MathToken(type: .leftParen, value: "(")
        case ")": advance(); return MathToken(type: .rightParen, value: ")")
        case "[": advance(); return MathToken(type: .leftBracket, value: "[")
        case "]": advance(); return MathToken(type: .rightBracket, value: "]")
        case "{": advance(); return MathToken(type: .leftBrace, value: "{")
        case "}": advance(); return MathToken(type: .rightBrace, value: "}")
        case ",": advance(); return MathToken(type: .comma, value: ",")
        case "\\":
            advance()
            if isAtEnd() { return nil }
            
            // Check for special sequences
            if peek() == "\\" {
                advance()
                return MathToken(type: .other, value: "\\\\")
            }
            
            let command = readWhile { $0.isLetter }
            return MathToken(type: .command, value: command)
            
        default:
            if char.isNumber || char == "." {
                let number = readWhile { $0.isNumber || $0 == "." }
                return MathToken(type: .number, value: number)
            } else if char.isLetter {
                let identifier = readWhile { $0.isLetter || $0.isNumber }
                return MathToken(type: .identifier, value: identifier)
            } else {
                advance()
                return MathToken(type: .other, value: String(char))
            }
        }
    }
    
    private func skipWhitespace() {
        while !isAtEnd() && peek().isWhitespace {
            advance()
        }
    }
    
    private func readWhile(_ predicate: (Character) -> Bool) -> String {
        var result = ""
        while !isAtEnd() && predicate(peek()) {
            result.append(peek())
            advance()
        }
        return result
    }
    
    private func peek() -> Character {
        return input[current]
    }
    
    private func advance() {
        if !isAtEnd() {
            current = input.index(after: current)
        }
    }
    
    private func isAtEnd() -> Bool {
        return current >= input.endIndex
    }
}

// MARK: - Math HTML Renderer

private struct MathHTMLRenderer {
    func render(_ expression: Math.Expression) -> String {
        switch expression {
        case .number(let n):
            return n
            
        case .identifier(let id):
            return "<span class=\"math-var\">\(id)</span>"
            
        case .symbol(let sym):
            return sym
            
        case .unary(let op, let operand):
            return "\(op)\(render(operand))"
            
        case .binary(let left, let op, let right):
            return "\(render(left))\(op.isEmpty ? "" : " \(op) ")\(render(right))"
            
        case .fraction(let num, let den):
            return """
            <span class="math-frac">
                <span class="math-frac-num">\(render(num))</span>
                <span class="math-frac-den">\(render(den))</span>
            </span>
            """
            
        case .superscript(let base, let exp):
            return "\(render(base))<sup class=\"math-sup\">\(render(exp))</sup>"
            
        case .`subscript`(let base, let sub):
            return "\(render(base))<sub class=\"math-sub\">\(render(sub))</sub>"
            
        case .radical(let degree, let radicand):
            if let degree = degree {
                return "<span class=\"math-radical\"><sup>\(render(degree))</sup>√<span class=\"math-radicand\">\(render(radicand))</span></span>"
            } else {
                return "<span class=\"math-radical\">√<span class=\"math-radicand\">\(render(radicand))</span></span>"
            }
            
        case .parentheses(let expr):
            return "(\(render(expr)))"
            
        case .brackets(let expr):
            return "[\(render(expr))]"
            
        case .braces(let expr):
            return "{\(render(expr))}"
            
        case .function(let name, let args):
            let argStr = args.map { render($0) }.joined(separator: ", ")
            return "\(name)(\(argStr))"
            
        case .matrix(let rows):
            var html = "<span class=\"math-matrix\">"
            for row in rows {
                html += "<span class=\"math-matrix-row\">"
                for (index, cell) in row.enumerated() {
                    if index > 0 { html += " " }
                    html += "<span class=\"math-matrix-cell\">\(render(cell))</span>"
                }
                html += "</span>"
            }
            html += "</span>"
            return html
            
        case .integral(let lower, let upper, let integrand):
            var html = "<span class=\"math-integral\">"
            html += "<span class=\"math-bigop\">∫</span>"
            if let lower = lower, let upper = upper {
                html += "<span class=\"math-limits\">"
                html += "<span class=\"math-limit-above\">\(render(upper))</span>"
                html += "<span class=\"math-limit-below\">\(render(lower))</span>"
                html += "</span>"
            }
            html += " \(render(integrand))"
            html += "</span>"
            return html
            
        case .sum(let lower, let upper, let summand):
            var html = "<span class=\"math-sum\">"
            html += "<span class=\"math-bigop\">Σ</span>"
            if let lower = lower, let upper = upper {
                html += "<span class=\"math-limits\">"
                html += "<span class=\"math-limit-above\">\(render(upper))</span>"
                html += "<span class=\"math-limit-below\">\(render(lower))</span>"
                html += "</span>"
            }
            html += " \(render(summand))"
            html += "</span>"
            return html
            
        case .product(let lower, let upper, let factor):
            var html = "<span class=\"math-product\">"
            html += "<span class=\"math-bigop\">Π</span>"
            if let lower = lower, let upper = upper {
                html += "<span class=\"math-limits\">"
                html += "<span class=\"math-limit-above\">\(render(upper))</span>"
                html += "<span class=\"math-limit-below\">\(render(lower))</span>"
                html += "</span>"
            }
            html += " \(render(factor))"
            html += "</span>"
            return html
            
        case .limit(let variable, let approaching, let expr):
            return "<span class=\"math-limit\">lim<sub>\(variable)→\(render(approaching))</sub> \(render(expr))</span>"
            
        case .text(let text):
            return text
            
        case .space:
            return " "
            
        case .newline:
            return "<br>"
        }
    }
}

// MARK: - Math MathML Renderer

/// Native MathML renderer for modern browser support
private struct MathMLRenderer {
    func render(_ expression: Math.Expression, inline: Bool = true, latexSource: String? = nil) -> String {
        let mathContent = renderExpression(expression)

        let annotation: String
        if let latexSource = latexSource {
            annotation = "<annotation encoding=\"application/x-tex\">\(xmlEscape(latexSource))</annotation>"
        } else {
            annotation = ""
        }
        let semanticsContent = "<semantics>\(mathContent)\(annotation)</semantics>"

        if inline {
            return "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\(semanticsContent)</math>"
        } else {
            return "<math xmlns=\"http://www.w3.org/1998/Math/MathML\" display=\"block\">\(semanticsContent)</math>"
        }
    }
    
    private func renderExpression(_ expression: Math.Expression) -> String {
        switch expression {
        case .number(let n):
            return "<mn>\(xmlEscape(n))</mn>"
            
        case .identifier(let id):
            return "<mi>\(xmlEscape(id))</mi>"
            
        case .symbol(let sym):
            return "<mo>\(xmlEscape(sym))</mo>"
            
        case .text(let text):
            return "<mtext>\(xmlEscape(text))</mtext>"
            
        case .unary(let op, let operand):
            return "<mrow><mo>\(xmlEscape(op))</mo>\(renderExpression(operand))</mrow>"
            
        case .binary(let left, let op, let right):
            if op.isEmpty {
                // Implicit multiplication
                return "<mrow>\(renderExpression(left))\(renderExpression(right))</mrow>"
            } else {
                return "<mrow>\(renderExpression(left))<mo>\(xmlEscape(op))</mo>\(renderExpression(right))</mrow>"
            }
            
        case .fraction(let num, let den):
            return "<mfrac>\(renderExpression(num))\(renderExpression(den))</mfrac>"
            
        case .superscript(let base, let exp):
            return "<msup>\(renderExpression(base))\(renderExpression(exp))</msup>"
            
        case .`subscript`(let base, let sub):
            return "<msub>\(renderExpression(base))\(renderExpression(sub))</msub>"
            
        case .radical(let degree, let radicand):
            if let degree = degree {
                return "<mroot>\(renderExpression(radicand))\(renderExpression(degree))</mroot>"
            } else {
                return "<msqrt>\(renderExpression(radicand))</msqrt>"
            }
            
        case .parentheses(let expr):
            return "<mrow><mo>(</mo>\(renderExpression(expr))<mo>)</mo></mrow>"
            
        case .brackets(let expr):
            return "<mrow><mo>[</mo>\(renderExpression(expr))<mo>]</mo></mrow>"
            
        case .braces(let expr):
            return "<mrow><mo>{</mo>\(renderExpression(expr))<mo>}</mo></mrow>"
            
        case .function(let name, let args):
            var mathml = "<mi>\(xmlEscape(name))</mi><mo>(</mo>"
            for (index, arg) in args.enumerated() {
                if index > 0 {
                    mathml += "<mo>,</mo>"
                }
                mathml += renderExpression(arg)
            }
            mathml += "<mo>)</mo>"
            return "<mrow>\(mathml)</mrow>"
            
        case .matrix(let rows):
            var mathml = "<mtable>"
            for row in rows {
                mathml += "<mtr>"
                for cell in row {
                    mathml += "<mtd>\(renderExpression(cell))</mtd>"
                }
                mathml += "</mtr>"
            }
            mathml += "</mtable>"
            return "<mrow><mo>(</mo>\(mathml)<mo>)</mo></mrow>"
            
        case .integral(let lower, let upper, let integrand):
            var mathml = "<mo>∫</mo>"
            if let lower = lower, let upper = upper {
                mathml = "<msubsup><mo>∫</mo>\(renderExpression(lower))\(renderExpression(upper))</msubsup>"
            } else if let lower = lower {
                mathml = "<msub><mo>∫</mo>\(renderExpression(lower))</msub>"
            } else if let upper = upper {
                mathml = "<msup><mo>∫</mo>\(renderExpression(upper))</msup>"
            }
            return "<mrow>\(mathml)\(renderExpression(integrand))</mrow>"
            
        case .sum(let lower, let upper, let summand):
            var mathml = "<mo>∑</mo>"
            if let lower = lower, let upper = upper {
                mathml = "<msubsup><mo>∑</mo>\(renderExpression(lower))\(renderExpression(upper))</msubsup>"
            } else if let lower = lower {
                mathml = "<msub><mo>∑</mo>\(renderExpression(lower))</msub>"
            } else if let upper = upper {
                mathml = "<msup><mo>∑</mo>\(renderExpression(upper))</msup>"
            }
            return "<mrow>\(mathml)\(renderExpression(summand))</mrow>"
            
        case .product(let lower, let upper, let factor):
            var mathml = "<mo>∏</mo>"
            if let lower = lower, let upper = upper {
                mathml = "<msubsup><mo>∏</mo>\(renderExpression(lower))\(renderExpression(upper))</msubsup>"
            } else if let lower = lower {
                mathml = "<msub><mo>∏</mo>\(renderExpression(lower))</msub>"
            } else if let upper = upper {
                mathml = "<msup><mo>∏</mo>\(renderExpression(upper))</msup>"
            }
            return "<mrow>\(mathml)\(renderExpression(factor))</mrow>"
            
        case .limit(let variable, let approaching, let expr):
            let limitExpr = "<munder><mo>lim</mo><mrow><mi>\(xmlEscape(variable))</mi><mo>→</mo>\(renderExpression(approaching))</mrow></munder>"
            return "<mrow>\(limitExpr)\(renderExpression(expr))</mrow>"
            
        case .space:
            return "<mspace width=\"0.3em\"/>"
            
        case .newline:
            return "<mspace linebreak=\"newline\"/>"
        }
    }
    
    private func xmlEscape(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

// MARK: - Math Symbols

struct MathSymbols {
    static func symbol(for command: String) -> String? {
        let symbols: [String: String] = [
            // Greek letters
            "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ",
            "epsilon": "ε", "zeta": "ζ", "eta": "η", "theta": "θ",
            "iota": "ι", "kappa": "κ", "lambda": "λ", "mu": "μ",
            "nu": "ν", "xi": "ξ", "omicron": "ο", "pi": "π",
            "rho": "ρ", "sigma": "σ", "tau": "τ", "upsilon": "υ",
            "phi": "φ", "chi": "χ", "psi": "ψ", "omega": "ω",
            
            // Capital Greek
            "Alpha": "Α", "Beta": "Β", "Gamma": "Γ", "Delta": "Δ",
            "Epsilon": "Ε", "Zeta": "Ζ", "Eta": "Η", "Theta": "Θ",
            "Iota": "Ι", "Kappa": "Κ", "Lambda": "Λ", "Mu": "Μ",
            "Nu": "Ν", "Xi": "Ξ", "Omicron": "Ο", "Pi": "Π",
            "Rho": "Ρ", "Sigma": "Σ", "Tau": "Τ", "Upsilon": "Υ",
            "Phi": "Φ", "Chi": "Χ", "Psi": "Ψ", "Omega": "Ω",
            
            // Math operators
            "pm": "±", "mp": "∓", "times": "×", "div": "÷",
            "cdot": "·", "ast": "∗", "star": "⋆", "circ": "∘",
            "bullet": "•", "oplus": "⊕", "ominus": "⊖", "otimes": "⊗",
            "oslash": "⊘", "odot": "⊙", "wedge": "∧", "vee": "∨",
            
            // Relations
            "leq": "≤", "geq": "≥", "neq": "≠", "approx": "≈",
            "equiv": "≡", "sim": "∼", "simeq": "≃", "propto": "∝",
            "subset": "⊂", "supset": "⊃", "subseteq": "⊆", "supseteq": "⊇",
            "in": "∈", "notin": "∉", "ni": "∋",
            
            // Arrows
            "leftarrow": "←", "rightarrow": "→", "uparrow": "↑", "downarrow": "↓",
            "leftrightarrow": "↔", "Leftarrow": "⇐", "Rightarrow": "⇒",
            "Uparrow": "⇑", "Downarrow": "⇓", "Leftrightarrow": "⇔",
            "to": "→", "mapsto": "↦",
            
            // Other symbols
            "infty": "∞", "partial": "∂", "nabla": "∇", "forall": "∀",
            "exists": "∃", "emptyset": "∅", "varnothing": "∅",
            "neg": "¬", "prime": "′", "angle": "∠", "triangle": "△",
            "square": "□", "clubsuit": "♣", "diamondsuit": "♦",
            "heartsuit": "♥", "spadesuit": "♠",
            
            // Dots
            "ldots": "…", "cdots": "⋯", "vdots": "⋮", "ddots": "⋱",

            // Mathematical fonts (font-style commands)
            "mathbb": "𝔹",     // Blackboard bold (placeholder — rendered as command)
            "mathcal": "𝒞",    // Calligraphic
            "mathfrak": "𝔉",   // Fraktur
            "mathrm": "",       // Roman (no symbol, styling only)
            "mathbf": "",       // Bold (styling only)
            "mathit": "",       // Italic (styling only)
            "mathsf": "",       // Sans-serif (styling only)
            "mathtt": "",       // Typewriter (styling only)

            // Named operators
            "sin": "sin", "cos": "cos", "tan": "tan",
            "sec": "sec", "csc": "csc", "cot": "cot",
            "arcsin": "arcsin", "arccos": "arccos", "arctan": "arctan",
            "sinh": "sinh", "cosh": "cosh", "tanh": "tanh",
            "log": "log", "ln": "ln", "exp": "exp",
            "lim": "lim", "sup": "sup", "inf": "inf",
            "max": "max", "min": "min", "arg": "arg",
            "det": "det", "dim": "dim", "ker": "ker",
            "deg": "deg", "hom": "hom", "gcd": "gcd",
            "mod": "mod",

            // Additional relations
            "ll": "≪", "gg": "≫", "prec": "≺", "succ": "≻",
            "preceq": "⪯", "succeq": "⪰",
            "cong": "≅", "doteq": "≐",
            "perp": "⊥", "mid": "∣", "parallel": "∥",
            "nmid": "∤", "nparallel": "∦",

            // Set theory
            "cap": "∩", "cup": "∪", "setminus": "∖",
            "complement": "∁", "powerset": "𝒫",

            // Logic
            "land": "∧", "lor": "∨", "lnot": "¬",
            "implies": "⟹", "iff": "⟺",
            "top": "⊤", "bot": "⊥",
            "vdash": "⊢", "models": "⊨", "vDash": "⊨",

            // Miscellaneous
            "hbar": "ℏ", "ell": "ℓ", "wp": "℘",
            "Re": "ℜ", "Im": "ℑ", "aleph": "ℵ",
            "beth": "ℶ", "gimel": "ℷ",

            // Delimiters
            "langle": "⟨", "rangle": "⟩",
            "lceil": "⌈", "rceil": "⌉",
            "lfloor": "⌊", "rfloor": "⌋",
            "lvert": "|", "rvert": "|",
            "lVert": "‖", "rVert": "‖",

            // Spacing
            "quad": " ", "qquad": "  ",
            ",": " ", ";": " ", "!": ""
        ]

        return symbols[command]
    }
}
