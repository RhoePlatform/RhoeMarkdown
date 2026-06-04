import Foundation

extension RhoeParser {
    func decodeCommonMarkCharacterReferences(_ text: String) -> String {
        guard text.contains("&") else {
            return text
        }

        var output = ""
        var index = text.startIndex

        while index < text.endIndex {
            guard text[index] == "&" else {
                output.append(text[index])
                index = text.index(after: index)
                continue
            }

            if let decoded = decodeCharacterReference(in: text, from: index) {
                output.append(decoded.value)
                index = decoded.endIndex
            } else {
                output.append(text[index])
                index = text.index(after: index)
            }
        }

        return output
    }

    private func decodeCharacterReference(
        in text: String,
        from ampersand: String.Index
    ) -> (value: String, endIndex: String.Index)? {
        let next = text.index(after: ampersand)
        guard next < text.endIndex else {
            return nil
        }

        if text[next] == "#" {
            return decodeNumericCharacterReference(in: text, from: ampersand, afterHash: text.index(after: next))
        }

        var cursor = next
        var name = ""
        while cursor < text.endIndex, text[cursor].isASCIIAlphanumeric {
            name.append(text[cursor])
            cursor = text.index(after: cursor)
        }

        guard cursor < text.endIndex, text[cursor] == ";",
              let value = commonMarkNamedCharacterReferences[name]
        else {
            return nil
        }

        return (value, text.index(after: cursor))
    }

    private func decodeNumericCharacterReference(
        in text: String,
        from ampersand: String.Index,
        afterHash: String.Index
    ) -> (value: String, endIndex: String.Index)? {
        guard afterHash < text.endIndex else {
            return nil
        }

        let radix: Int
        var cursor = afterHash
        if text[cursor] == "x" || text[cursor] == "X" {
            radix = 16
            cursor = text.index(after: cursor)
        } else {
            radix = 10
        }

        var digits = ""
        while cursor < text.endIndex, text[cursor].isDigit(forRadix: radix) {
            digits.append(text[cursor])
            cursor = text.index(after: cursor)
        }

        let maxDigits = radix == 16 ? 6 : 7
        guard !digits.isEmpty, digits.count <= maxDigits,
              cursor < text.endIndex, text[cursor] == ";",
              let value = UInt32(digits, radix: radix)
        else {
            return nil
        }

        let scalar = UnicodeScalar.validCommonMarkReferenceScalar(for: value)
        return (String(scalar), text.index(after: cursor))
    }
}

private let commonMarkNamedCharacterReferences: [String: String] = [
    "AElig": "\u{00C6}",
    "Auml": "\u{00C4}",
    "ClockwiseContourIntegral": "\u{2232}",
    "Dcaron": "\u{010E}",
    "DifferentialD": "\u{2146}",
    "HilbertSpace": "\u{210B}",
    "amp": "&",
    "auml": "\u{00E4}",
    "copy": "\u{00A9}",
    "frac34": "\u{00BE}",
    "gt": ">",
    "lt": "<",
    "nbsp": "\u{00A0}",
    "ngE": "\u{2267}\u{0338}",
    "ouml": "\u{00F6}",
    "quot": "\"",
]

private extension Character {
    var isASCIIAlphanumeric: Bool {
        guard unicodeScalars.count == 1,
              let scalar = unicodeScalars.first
        else {
            return false
        }

        return (scalar.value >= 48 && scalar.value <= 57) ||
            (scalar.value >= 65 && scalar.value <= 90) ||
            (scalar.value >= 97 && scalar.value <= 122)
    }

    func isDigit(forRadix radix: Int) -> Bool {
        guard unicodeScalars.count == 1,
              let value = unicodeScalars.first?.value
        else {
            return false
        }

        switch radix {
        case 10:
            return value >= 48 && value <= 57
        case 16:
            return (value >= 48 && value <= 57) ||
                (value >= 65 && value <= 70) ||
                (value >= 97 && value <= 102)
        default:
            return false
        }
    }
}

private extension UnicodeScalar {
    static func validCommonMarkReferenceScalar(for value: UInt32) -> UnicodeScalar {
        if value == 0 ||
            value > 0x10FFFF ||
            (value >= 0xD800 && value <= 0xDFFF) {
            return "\u{FFFD}"
        }

        return UnicodeScalar(value) ?? "\u{FFFD}"
    }
}
