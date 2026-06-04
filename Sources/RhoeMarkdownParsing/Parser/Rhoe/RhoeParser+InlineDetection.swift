import Foundation
import RhoeMarkdownModel

let gfmExtendedAutolinkProtocols = ["http://", "https://", "ftp://"]

extension RhoeParser {

    // MARK: - Autolink Detection

    func detectExtendedAutolink(
        in text: String,
        at position: String.Index
    ) -> (inline: Inline, endIndex: String.Index)? {
        if position > text.startIndex,
           text[text.index(before: position)] == "<" {
            return nil
        }

        for proto in gfmExtendedAutolinkProtocols {
            if text[position...].hasPrefix(proto) {
                let endPos = consumeURLLikeEnd(
                    in: text,
                    from: text.index(position, offsetBy: proto.count)
                )
                let url = String(text[position..<endPos])
                return (.link(text: [.text(url)], url: url, title: nil), endPos)
            }
        }

        if text[position...].hasPrefix("www.") {
            let endPos = consumeURLLikeEnd(
                in: text,
                from: text.index(position, offsetBy: 4)
            )
            let url = String(text[position..<endPos])
            let fullUrl = "http://" + url
            return (.link(text: [.text(url)], url: fullUrl, title: nil), endPos)
        }

        if position > text.startIndex {
            let (startPos, hasAt) = scanEmailAutolinkStart(in: text, from: position)

            if hasAt || text[position] == "@" {
                let (endPos, foundAt) = scanEmailAutolinkEnd(in: text, from: position)

                if foundAt && endPos > text.index(after: position) {
                    let email = String(text[startPos..<endPos])
                    if email.contains("@") && email.contains(".") {
                        if startPos == position {
                            return (.link(text: [.text(email)], url: "mailto:" + email, title: nil), endPos)
                        }
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Reference Detection (Mentions & Issues)

    func detectMention(in text: String, at position: String.Index) -> (inline: Inline, endIndex: String.Index)? {
        guard text[position] == "@" else { return nil }
        guard hasMentionLikeBoundaryBefore(text, at: position) else { return nil }

        let endPos = consumeMentionIdentifierEnd(
            in: text,
            from: text.index(after: position)
        )

        if endPos > text.index(after: position) {
            let mention = String(text[position..<endPos])
            let username = String(mention.dropFirst())
            return (.link(text: [.text(mention)], url: "https://github.com/\(username)", title: nil), endPos)
        }

        return nil
    }

    func detectIssueReference(in text: String, at position: String.Index) -> (inline: Inline, endIndex: String.Index)? {
        guard text[position] == "#" else { return nil }
        guard hasMentionLikeBoundaryBefore(text, at: position) else { return nil }

        let (endPos, hasDigit) = consumeIssueReferenceEnd(
            in: text,
            from: text.index(after: position)
        )

        if hasDigit && endPos > text.index(after: position) {
            let reference = String(text[position..<endPos])
            let issueNumber = String(reference.dropFirst())
            return (.link(text: [.text(reference)], url: "#issue-\(issueNumber)", title: nil), endPos)
        }

        return nil
    }

    // MARK: - Reference Scan Support

    func consumeMentionIdentifierEnd(
        in text: String,
        from position: String.Index
    ) -> String.Index {
        var endPosition = position

        while endPosition < text.endIndex {
            let character = text[endPosition]
            if !character.isLetter && !character.isNumber && character != "-" && character != "_" {
                break
            }
            endPosition = text.index(after: endPosition)
        }

        return endPosition
    }

    func consumeIssueReferenceEnd(
        in text: String,
        from position: String.Index
    ) -> (end: String.Index, hasDigit: Bool) {
        var endPosition = position
        var hasDigit = false

        while endPosition < text.endIndex {
            let character = text[endPosition]
            if character.isNumber {
                hasDigit = true
                endPosition = text.index(after: endPosition)
            } else {
                break
            }
        }

        return (endPosition, hasDigit)
    }

    // MARK: - URL and Email Scan Support

    func consumeURLLikeEnd(
        in text: String,
        from position: String.Index
    ) -> String.Index {
        var endPosition = position

        while endPosition < text.endIndex {
            let character = text[endPosition]
            if isWhitespaceInlineBoundary(character) {
                break
            }

            if shouldStopBeforeTrailingURLPunctuation(in: text, at: endPosition) {
                break
            }

            endPosition = text.index(after: endPosition)
        }

        return endPosition
    }

    func scanEmailAutolinkStart(
        in text: String,
        from position: String.Index
    ) -> (start: String.Index, hasAt: Bool) {
        var startPosition = position
        var hasAt = false

        while startPosition > text.startIndex {
            let previousIndex = text.index(before: startPosition)
            let character = text[previousIndex]
            if isEmailAutolinkStartBoundary(character) {
                break
            }
            if character == "@" {
                hasAt = true
            }
            startPosition = previousIndex
        }

        return (startPosition, hasAt)
    }

    func scanEmailAutolinkEnd(
        in text: String,
        from position: String.Index
    ) -> (end: String.Index, foundAt: Bool) {
        var endPosition = position
        var foundAt = text[position] == "@"

        while endPosition < text.endIndex {
            let character = text[endPosition]
            if character == "@" {
                foundAt = true
            }
            if isEmailAutolinkEndBoundary(character) {
                break
            }
            endPosition = text.index(after: endPosition)
        }

        return (endPosition, foundAt)
    }
}
