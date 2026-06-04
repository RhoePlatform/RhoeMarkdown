import Foundation
import RhoeMarkdownModel

extension RhoeParser {

    /// Parse inline content from a grid table cell's text.
    ///
    /// Grid table cells may contain inline markdown (bold, italic, code, links, etc.)
    /// This method reuses the existing inline parsing infrastructure.
    func parseGridCellInlines(_ text: String) -> [Inline] {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        // Use the string-based inline parser for cell content
        return collectStringInlines(from: trimmed)
    }

    /// Parse block content from a grid table cell's text (for multi-paragraph cells).
    ///
    /// When a grid table cell spans multiple lines and contains block-level structures
    /// (paragraphs, lists, code blocks), this method parses the raw text as blocks.
    func parseGridCellBlocks(_ text: String) -> [Block] {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        // For simple content, wrap as a single paragraph
        let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        // Check if there are paragraph breaks (empty lines)
        let hasBlankLine = lines.contains { $0.trimmingCharacters(in: .whitespaces).isEmpty }

        if !hasBlankLine {
            // Single paragraph — parse as inlines
            let inlines = collectStringInlines(from: trimmed)
            return [.paragraph(inlines)]
        }

        // Multiple paragraphs — split on blank lines
        var blocks: [Block] = []
        var currentParagraph: [String] = []

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !currentParagraph.isEmpty {
                    let content = currentParagraph.joined(separator: " ")
                    let inlines = collectStringInlines(from: content)
                    blocks.append(.paragraph(inlines))
                    currentParagraph = []
                }
            } else {
                currentParagraph.append(line.trimmingCharacters(in: .whitespaces))
            }
        }

        if !currentParagraph.isEmpty {
            let content = currentParagraph.joined(separator: " ")
            let inlines = collectStringInlines(from: content)
            blocks.append(.paragraph(inlines))
        }

        return blocks
    }
}
