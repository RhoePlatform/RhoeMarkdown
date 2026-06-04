import Foundation
import RhoeMarkdownModel

package struct SlideAttributeParser: Sendable {

    package init() {}

    package func parseAttributeMap(_ source: String) -> [String: String] {
        parseScannerAttributes(source, includeFlags: true)
    }

    package func parseAttributes(_ source: String) -> RhoeMarkdownKit.Attributes {
        parseScannerAttributesObject(source)
    }

    private func parseScannerAttributes(
        _ source: String,
        includeFlags: Bool
    ) -> [String: String] {
        var scanner = SlideAttributeScanner(source)
        var result: [String: String] = [:]

        while !scanner.isAtEnd {
            scanner.skipWhitespace()

            let key = scanner.readKey()
            guard !key.isEmpty else { break }

            scanner.skipWhitespace()

            guard scanner.consume("=") else {
                if includeFlags, !key.hasPrefix("#"), !key.hasPrefix(".") {
                    result[key] = "true"
                }
                continue
            }

            scanner.skipWhitespace()
            result[key] = scanner.readAttributeValue()
        }

        return result
    }

    private func parseScannerAttributesObject(_ source: String) -> RhoeMarkdownKit.Attributes {
        var scanner = SlideAttributeScanner(source)
        var id: String? = nil
        var classes: [String] = []
        var keyValues: [String: String] = [:]

        while !scanner.isAtEnd {
            scanner.skipWhitespace()

            let key = scanner.readKey()
            guard !key.isEmpty else { break }

            scanner.skipWhitespace()

            if key.hasPrefix("#") {
                id = String(key.dropFirst())
                continue
            }

            if key.hasPrefix(".") {
                classes.append(String(key.dropFirst()))
                continue
            }

            guard scanner.consume("=") else {
                continue
            }

            scanner.skipWhitespace()
            keyValues[key] = scanner.readAttributeValue()
        }

        return RhoeMarkdownKit.Attributes(id: id, classes: classes, keyValues: keyValues)
    }
}

private struct SlideAttributeScanner: Sendable {
    private let source: String
    private var index: String.Index

    init(_ source: String) {
        self.source = source
        self.index = source.startIndex
    }

    var isAtEnd: Bool {
        index >= source.endIndex
    }

    mutating func skipWhitespace() {
        while let character = peek(), character.isWhitespace {
            advance()
        }
    }

    mutating func consume(_ character: Character) -> Bool {
        guard peek() == character else { return false }
        advance()
        return true
    }

    mutating func readKey() -> String {
        let start = index

        while let character = peek(), character != "=", !character.isWhitespace {
            advance()
        }

        return String(source[start..<index])
    }

    mutating func readAttributeValue() -> String {
        guard let current = peek() else { return "" }

        if current == "\"" || current == "'" {
            return readQuotedValue(quote: current)
        }

        return readBareValue()
    }

    private mutating func readQuotedValue(quote: Character) -> String {
        _ = consume(quote)
        let start = index

        while let character = peek(), character != quote {
            advance()
        }

        let value = String(source[start..<index])
        _ = consume(quote)
        return value
    }

    private mutating func readBareValue() -> String {
        let start = index
        var parenDepth = 0

        while let character = peek() {
            if character == "(" {
                parenDepth += 1
            } else if character == ")" {
                parenDepth = max(0, parenDepth - 1)
            } else if character.isWhitespace, parenDepth == 0 {
                break
            }

            advance()
        }

        return String(source[start..<index])
    }

    private func peek() -> Character? {
        guard !isAtEnd else { return nil }
        return source[index]
    }

    private mutating func advance() {
        guard !isAtEnd else { return }
        index = source.index(after: index)
    }
}
