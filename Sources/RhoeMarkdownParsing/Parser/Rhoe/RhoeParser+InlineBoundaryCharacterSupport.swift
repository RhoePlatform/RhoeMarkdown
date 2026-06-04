import Foundation
import RhoeMarkdownModel

extension RhoeParser {
    func hasMentionLikeBoundaryBefore(
        _ text: String,
        at position: String.Index
    ) -> Bool {
        guard position > text.startIndex else { return true }
        return isMentionBoundaryCharacter(text[text.index(before: position)])
    }

    func isWhitespaceInlineBoundary(_ character: Character) -> Bool {
        character == " " || character == "\n" || character == "\t"
    }

    func shouldStopBeforeTrailingURLPunctuation(
        in text: String,
        at position: String.Index
    ) -> Bool {
        let character = text[position]
        guard ".,;:!?".contains(character),
              position < text.index(before: text.endIndex) else {
            return false
        }

        let nextCharacter = text[text.index(after: position)]
        return nextCharacter == " " || nextCharacter == "\n"
    }

    func isEmailAutolinkStartBoundary(_ character: Character) -> Bool {
        character == " " ||
            character == "\n" ||
            character == "\t" ||
            character == "<" ||
            character == "(" ||
            character == "["
    }

    func isEmailAutolinkEndBoundary(_ character: Character) -> Bool {
        character == " " ||
            character == "\n" ||
            character == "\t" ||
            character == ">" ||
            character == ")" ||
            character == "]"
    }

    func isEmojiNameCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_" || character == "-" || character == "+"
    }

    fileprivate func isMentionBoundaryCharacter(_ character: Character) -> Bool {
        character == " " ||
            character == "\n" ||
            character == "\t" ||
            character == "(" ||
            character == "["
    }
}
