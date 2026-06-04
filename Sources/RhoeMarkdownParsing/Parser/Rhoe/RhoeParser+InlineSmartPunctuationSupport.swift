import Foundation
import RhoeMarkdownModel

extension RhoeParser {
    /// Apply smart punctuation transformations to a text string.
    ///
    /// Converts ASCII punctuation to Unicode typographic equivalents:
    /// - `"text"` → \u{201C}text\u{201D} (curly double quotes)
    /// - `'text'` → \u{2018}text\u{2019} (curly single quotes)
    /// - `---` (inline) → \u{2014} (em-dash)
    /// - `--` (inline) → \u{2013} (en-dash)
    /// - `...` → \u{2026} (horizontal ellipsis)
    /// - Apostrophes in contractions → \u{2019} (right single quote)
    ///
    /// Only active when `enableSmartPunctuation` is `true`.
    func applySmartPunctuation(to text: String) -> String {
        guard configuration.enableSmartPunctuation else { return text }

        var result = ""
        result.reserveCapacity(text.count)
        var pos = text.startIndex
        var inDoubleQuote = false
        var inSingleQuote = false

        while pos < text.endIndex {
            let ch = text[pos]
            let nextPos = text.index(after: pos)

            switch ch {
            case "\"":
                if inDoubleQuote {
                    result.append("\u{201D}") // right double quote
                    inDoubleQuote = false
                } else {
                    result.append("\u{201C}") // left double quote
                    inDoubleQuote = true
                }
                pos = nextPos

            case "'":
                // Check if this is an apostrophe in a contraction (letter before and after)
                let hasPrecedingLetter = pos > text.startIndex && text[text.index(before: pos)].isLetter
                let hasFollowingLetter = nextPos < text.endIndex && text[nextPos].isLetter
                if hasPrecedingLetter && hasFollowingLetter {
                    result.append("\u{2019}") // right single quote (apostrophe)
                } else if inSingleQuote {
                    result.append("\u{2019}") // right single quote
                    inSingleQuote = false
                } else {
                    result.append("\u{2018}") // left single quote
                    inSingleQuote = true
                }
                pos = nextPos

            case "-":
                // Check for em-dash (---) or en-dash (--)
                if nextPos < text.endIndex && text[nextPos] == "-" {
                    let afterSecond = text.index(after: nextPos)
                    if afterSecond < text.endIndex && text[afterSecond] == "-" {
                        result.append("\u{2014}") // em-dash
                        pos = text.index(after: afterSecond)
                    } else {
                        result.append("\u{2013}") // en-dash
                        pos = afterSecond
                    }
                } else {
                    result.append(ch)
                    pos = nextPos
                }

            case ".":
                // Check for ellipsis (...)
                if nextPos < text.endIndex && text[nextPos] == "." {
                    let afterSecond = text.index(after: nextPos)
                    if afterSecond < text.endIndex && text[afterSecond] == "." {
                        result.append("\u{2026}") // horizontal ellipsis
                        pos = text.index(after: afterSecond)
                    } else {
                        result.append(ch)
                        pos = nextPos
                    }
                } else {
                    result.append(ch)
                    pos = nextPos
                }

            default:
                result.append(ch)
                pos = nextPos
            }
        }

        return result
    }
}
