import Foundation
import RhoeMarkdownModel

extension RhoeParser {
    /// Detect cross-reference from `@prefix-id` syntax.
    ///
    /// Cross-references use a recognized prefix followed by a hyphen and an
    /// identifier: `@fig-revenue`, `@tbl-quarterly`, `@eq-euler`, etc.
    ///
    /// Recognized prefixes (from ``CrossRefPrefix``):
    /// `fig`, `tbl`, `eq`, `sec`, `lst`, `note`,
    /// `thm`, `lem`, `def`, `prp`, `cor`, `exm`
    ///
    /// Disambiguation:
    /// - `@fig-name`   → cross-reference (recognized prefix + hyphen + id)
    /// - `@username`   → mention (no recognized prefix)
    /// - `[@key]`      → citation (bracket context, not bare)
    func detectCrossReference(
        in text: String,
        at position: String.Index
    ) -> (inline: Inline, endIndex: String.Index)? {
        guard configuration.enableCrossReferences else { return nil }
        guard text[position] == "@" else { return nil }

        let afterAt = text.index(after: position)
        guard afterAt < text.endIndex else { return nil }

        // The first character of the prefix must be a letter
        guard text[afterAt].isLetter else { return nil }

        // Consume the candidate prefix (letters only)
        var prefixEnd = afterAt
        while prefixEnd < text.endIndex && text[prefixEnd].isLetter {
            prefixEnd = text.index(after: prefixEnd)
        }

        // Must be followed by a hyphen
        guard prefixEnd < text.endIndex && text[prefixEnd] == "-" else {
            return nil
        }

        // Check if the prefix is a recognized cross-reference prefix
        let prefixStr = String(text[afterAt..<prefixEnd])
        guard let prefix = CrossRefPrefix(rawValue: prefixStr) else {
            return nil
        }

        // Consume the identifier after the hyphen
        let afterHyphen = text.index(after: prefixEnd)
        guard afterHyphen < text.endIndex else { return nil }

        // ID must start with a letter or digit
        guard text[afterHyphen].isLetter || text[afterHyphen].isNumber else {
            return nil
        }

        var idEnd = afterHyphen
        while idEnd < text.endIndex && isCrossRefIdCharacter(text[idEnd]) {
            idEnd = text.index(after: idEnd)
        }

        let id = String(text[afterHyphen..<idEnd])
        guard !id.isEmpty else { return nil }

        return (.crossReference(prefix: prefix, id: id), idEnd)
    }

    /// Check if a character is valid in a cross-reference identifier.
    ///
    /// Valid characters: letters, digits, hyphens, underscores
    private func isCrossRefIdCharacter(_ ch: Character) -> Bool {
        ch.isLetter || ch.isNumber || ch == "-" || ch == "_"
    }
}
