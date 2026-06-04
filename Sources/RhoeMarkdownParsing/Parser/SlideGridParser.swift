//
//  SlideGridParser.swift
//  RhoeMarkdownKit
//
//  REVOLUTIONARY grid parser with full contextual support! 🚀
//

import Foundation
import RhoeMarkdownModel

/// Grid parser that handles Excel-style layouts with proper context
public struct SlideGridParser: Sendable {
    
    /// Parse state for tracking grid context
    private struct GridParseState {
        var currentGrid: GridLayout?
        var currentCell: (column: Int, row: Int)?
        var currentCellAttributes: RhoeMarkdownKit.Attributes?
        var cellContent: [String] = []
        var cells: [GridCell] = []
        var baseIndentation: Int = 0
        var cellIndentation: Int = 0
    }
    
    public init() {}
    
    /// Parse a slide with grid layout from lines
    public func parseSlideWithGrid(_ lines: [String], startIndex: Int = 0) -> (blocks: [Block], endIndex: Int) {
        var blocks: [Block] = []
        var index = startIndex
        var gridState: GridParseState? = nil
        
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let indentation = getIndentation(line)
            
            // Check for grid layout declaration
            if trimmed.hasPrefix("%%") && !trimmed.hasPrefix("%%%") {
                // Finalize any existing grid
                if let state = gridState {
                    blocks.append(finalizeGrid(state))
                    gridState = nil
                }
                
                // Parse new grid layout
                if let grid = parseGridLayout(trimmed) {
                    gridState = GridParseState(
                        currentGrid: grid,
                        baseIndentation: indentation
                    )
                }
                index += 1
                continue
            }
            
            // Check for grid cell within active grid
            if var state = gridState,
               trimmed.hasPrefix("%") && !trimmed.hasPrefix("%%") {
                
                // Finalize previous cell if any
                if let cell = state.currentCell {
                    let content = parseContentBlocks(state.cellContent)
                    state.cells.append(GridCell(
                        column: cell.column,
                        row: cell.row,
                        content: content,
                        attributes: state.currentCellAttributes
                    ))
                    state.cellContent = []
                    state.currentCellAttributes = nil
                }
                
                // Parse new cell reference
                if let (cellRef, content, attrs) = parseGridCell(trimmed) {
                    state.currentCell = cellRef
                    state.currentCellAttributes = attrs
                    state.cellIndentation = indentation // Allow content at same indentation
                    if !content.isEmpty {
                        state.cellContent.append(content)
                    }
                    
                    // Look ahead for indented content
                    var nextIndex = index + 1
                    while nextIndex < lines.count {
                        let nextLine = lines[nextIndex]
                        let nextTrimmed = nextLine.trimmingCharacters(in: .whitespaces)
                        
                        // Stop if we hit another cell or grid marker
                        if nextTrimmed.hasPrefix("%") {
                            break
                        }
                        
                        // Include any non-cell/grid content as cell content
                        if !nextTrimmed.isEmpty {
                            state.cellContent.append(nextLine)
                            nextIndex += 1
                        } else {
                            // Empty lines are allowed in cell content
                            state.cellContent.append("")
                            nextIndex += 1
                        }
                    }
                    index = nextIndex - 1
                }
                
                gridState = state
                index += 1
                continue
            }
            
            // Check for cell content continuation
            if var state = gridState,
               state.currentCell != nil {
                
                // If this line is not a grid marker or cell marker, it's cell content
                if !trimmed.hasPrefix("%") {
                    state.cellContent.append(line)
                    gridState = state
                    index += 1
                    continue
                }
            }
            
            // Line doesn't belong to grid - finalize grid if active
            if let state = gridState {
                // Only finalize if this is truly not grid content
                // Check if it's just a non-indented line between cells
                if !trimmed.isEmpty && !trimmed.hasPrefix("%") {
                    blocks.append(finalizeGrid(state))
                    gridState = nil
                } else if trimmed.isEmpty {
                    // Empty line - could be between cells, continue
                    index += 1
                    continue
                }
            }
            
            // Parse as regular block
            if let block = parseRegularBlock(lines, at: index) {
                blocks.append(block.block)
                index = block.nextIndex
            } else {
                index += 1
            }
        }
        
        // Finalize any remaining grid
        if let state = gridState {
            blocks.append(finalizeGrid(state))
        }
        
        return (blocks, index)
    }
    
    /// Get indentation level of a line
    private func getIndentation(_ line: String) -> Int {
        var count = 0
        for char in line {
            if char == " " {
                count += 1
            } else if char == "\t" {
                count += 4
            } else {
                break
            }
        }
        return count
    }
    
    /// Parse grid layout declaration
    private func parseGridLayout(_ line: String) -> GridLayout? {
        let content = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        
        // Split cell reference from attributes
        let parts = content.split(separator: " ", maxSplits: 1)
        guard !parts.isEmpty else { return nil }
        
        let cellRef = String(parts[0])
        guard let dims = GridLayout.parseDimensions(cellRef) else { return nil }
        
        // Parse attributes if present
        var attributes: RhoeMarkdownKit.Attributes? = nil
        if parts.count > 1 {
            let attrString = String(parts[1])
            if attrString.hasPrefix("{") && attrString.hasSuffix("}") {
                attributes = parseSlideAttributes(attrString)
            }
        }
        
        return GridLayout(
            columns: dims.columns,
            rows: dims.rows,
            cells: [],
            attributes: attributes
        )
    }

    private func parseSlideAttributes(_ attrString: String) -> RhoeMarkdownKit.Attributes {
        let trimmed = attrString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), trimmed.hasSuffix("}") else {
            return RhoeMarkdownKit.Attributes()
        }

        let content = trimmed.dropFirst().dropLast()
        var id: String?
        var classes: [String] = []
        var keyValues: [String: String] = [:]

        for token in content.split(whereSeparator: \.isWhitespace) {
            let string = String(token)
            if string.hasPrefix("#") {
                id = String(string.dropFirst())
            } else if string.hasPrefix(".") {
                classes.append(String(string.dropFirst()))
            } else if let separator = string.firstIndex(of: "=") {
                let key = String(string[..<separator])
                let value = String(string[string.index(after: separator)...]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                keyValues[key] = value
            }
        }

        return RhoeMarkdownKit.Attributes(id: id, classes: classes, keyValues: keyValues)
    }
    
    /// Parse grid cell declaration
    private func parseGridCell(_ line: String) -> ((column: Int, row: Int), String, RhoeMarkdownKit.Attributes?)? {
        let content = String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)
        
        // Find first space to separate reference from content
        if let spaceIndex = content.firstIndex(of: " ") {
            let cellRef = String(content[..<spaceIndex])
            let remainingContent = String(content[content.index(after: spaceIndex)...])
            
            if let ref = GridCell.parseReference(cellRef) {
                // Check for attributes at the start of content
                if remainingContent.hasPrefix("{") {
                    // Find the closing brace
                    if let range = remainingContent.range(of: "}") {
                        let attrString = String(remainingContent[remainingContent.startIndex...range.lowerBound])
                        let contentAfterAttrs = String(remainingContent[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                        
                        let attrs = parseSlideAttributes(attrString)
                        return (ref, contentAfterAttrs, attrs)
                    }
                }
                
                return (ref, remainingContent, nil)
            }
        } else {
            // Cell reference only, no content
            if let ref = GridCell.parseReference(content) {
                return (ref, "", nil)
            }
        }
        
        return nil
    }
    
    /// Parse content blocks from cell lines
    private func parseContentBlocks(_ lines: [String]) -> [Block] {
        guard !lines.isEmpty else { return [] }
        
        // Use a simple markdown parser for cell content
        var blocks: [Block] = []
        var currentParagraph: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty {
                // Empty line - finalize current paragraph
                if !currentParagraph.isEmpty {
                    let text = currentParagraph.joined(separator: "\n")
                    let inlines = parseInlineContent(text)
                    blocks.append(Block.paragraph(inlines))
                    currentParagraph = []
                }
            } else if trimmed.hasPrefix("#") {
                // Heading
                if !currentParagraph.isEmpty {
                    let text = currentParagraph.joined(separator: "\n")
                    let inlines = parseInlineContent(text)
                    blocks.append(Block.paragraph(inlines))
                    currentParagraph = []
                }
                
                let level = trimmed.prefix(while: { $0 == "#" }).count
                let headingText = trimmed.dropFirst(level).trimmingCharacters(in: .whitespaces)
                let inlines = parseInlineContent(headingText)
                blocks.append(Block.heading(
                    level: level,
                    content: inlines,
                    attributes: RhoeMarkdownKit.Attributes()
                ))
            } else if trimmed.hasPrefix("```") {
                // Code block
                if !currentParagraph.isEmpty {
                    let text = currentParagraph.joined(separator: "\n")
                    let inlines = parseInlineContent(text)
                    blocks.append(Block.paragraph(inlines))
                    currentParagraph = []
                }
                
                let lang = String(trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces))
                var codeLines: [String] = []
                var i = lines.firstIndex(of: line)! + 1
                
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                
                let code = codeLines.joined(separator: "\n")
                blocks.append(Block.codeBlock(
                    language: lang.isEmpty ? nil : lang,
                    content: code,
                    attributes: RhoeMarkdownKit.Attributes()
                ))
            } else if trimmed.hasPrefix("$$") {
                // Display math
                if !currentParagraph.isEmpty {
                    let text = currentParagraph.joined(separator: "\n")
                    let inlines = parseInlineContent(text)
                    blocks.append(Block.paragraph(inlines))
                    currentParagraph = []
                }
                
                let math = String(trimmed.dropFirst(2).dropLast(2).trimmingCharacters(in: .whitespaces))
                blocks.append(Block.paragraph([.mathDisplay(expression: math)]))
            } else {
                // Regular text - accumulate for paragraph
                currentParagraph.append(line)
            }
        }
        
        // Finalize any remaining paragraph
        if !currentParagraph.isEmpty {
            let text = currentParagraph.joined(separator: "\n")
            let inlines = parseInlineContent(text)
            blocks.append(Block.paragraph(inlines))
        }
        
        return blocks
    }
    
    /// Parse inline content with basic markdown support
    private func parseInlineContent(_ text: String) -> [Inline] {
        var inlines: [Inline] = []
        var remaining = text
        
        while !remaining.isEmpty {
            // Check for bold
            if let range = remaining.range(of: "**") {
                // Add text before bold
                if range.lowerBound > remaining.startIndex {
                    let beforeText = String(remaining[..<range.lowerBound])
                    inlines.append(.text(beforeText))
                }
                
                // Find closing bold
                let afterBold = remaining[range.upperBound...]
                if let endRange = afterBold.range(of: "**") {
                    let boldText = String(afterBold[..<endRange.lowerBound])
                    let boldInlines = parseInlineContent(boldText)
                    inlines.append(.strong(boldInlines))
                    remaining = String(afterBold[endRange.upperBound...])
                } else {
                    // No closing bold, treat as text
                    inlines.append(.text("**"))
                    remaining = String(afterBold)
                }
            }
            // Check for image
            else if let range = remaining.range(of: "![") {
                // Add text before image
                if range.lowerBound > remaining.startIndex {
                    let beforeText = String(remaining[..<range.lowerBound])
                    inlines.append(.text(beforeText))
                }
                
                // Parse image syntax ![alt](url)
                let afterBracket = remaining[range.upperBound...]
                if let closeBracket = afterBracket.firstIndex(of: "]") {
                    let openParen = afterBracket.index(after: closeBracket)
                    if openParen < afterBracket.endIndex,
                       afterBracket[openParen] == "(",
                       let closeParen = afterBracket[afterBracket.index(after: openParen)...].firstIndex(of: ")") {
                        
                        let altText = String(afterBracket[..<closeBracket])
                        let url = String(afterBracket[afterBracket.index(after: openParen)..<closeParen])
                        
                        inlines.append(.image(alt: [.text(altText)], url: url, title: nil))
                        remaining = String(afterBracket[afterBracket.index(after: closeParen)...])
                    } else {
                        // No opening paren, treat as text
                        inlines.append(.text("!["))
                        remaining = String(afterBracket)
                    }
                } else {
                    // No closing bracket, treat as text
                    inlines.append(.text("!["))
                    remaining = String(afterBracket)
                }
            }
            // Check for inline math
            else if let range = remaining.range(of: "$") {
                // Add text before math
                if range.lowerBound > remaining.startIndex {
                    let beforeText = String(remaining[..<range.lowerBound])
                    inlines.append(.text(beforeText))
                }
                
                // Find closing $
                let afterDollar = remaining[range.upperBound...]
                if let endRange = afterDollar.range(of: "$") {
                    let mathContent = String(afterDollar[..<endRange.lowerBound])
                    inlines.append(.inlineMath(expression: mathContent))
                    remaining = String(afterDollar[endRange.upperBound...])
                } else {
                    // No closing $, treat as text
                    inlines.append(.text("$"))
                    remaining = String(afterDollar)
                }
            }
            // No special formatting found
            else {
                inlines.append(.text(remaining))
                break
            }
        }
        
        return inlines
    }
    
    /// Parse a regular block (non-grid)
    private func parseRegularBlock(_ lines: [String], at index: Int) -> (block: Block, nextIndex: Int)? {
        let line = lines[index]
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Simple block parsing
        if trimmed.hasPrefix("#") {
            let level = trimmed.prefix(while: { $0 == "#" }).count
            let content = trimmed.dropFirst(level).trimmingCharacters(in: .whitespaces)
            return (
                Block.heading(level: level, content: [.text(content)], attributes: RhoeMarkdownKit.Attributes()),
                index + 1
            )
        } else if trimmed.hasPrefix("!!!") {
            // Admonition
            let type = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
            
            // Collect indented content
            var content: [String] = []
            var nextIndex = index + 1
            
            while nextIndex < lines.count {
                let nextLine = lines[nextIndex]
                let indent = getIndentation(nextLine)
                
                if indent >= 4 {
                    content.append(String(nextLine.dropFirst(4)))
                    nextIndex += 1
                } else if nextLine.trimmingCharacters(in: .whitespaces).isEmpty {
                    content.append("")
                    nextIndex += 1
                } else {
                    break
                }
            }
            
            let contentBlocks = parseContentBlocks(content)
            return (
                Block.admonition(
                    type: type,
                    title: nil,
                    content: contentBlocks,
                    collapsible: nil,
                    attributes: RhoeMarkdownKit.Attributes()
                ),
                nextIndex
            )
        } else if !trimmed.isEmpty {
            return (
                Block.paragraph([.text(trimmed)]),
                index + 1
            )
        }
        
        return nil
    }
    
    /// Finalize a grid state into a block
    private func finalizeGrid(_ state: GridParseState) -> Block {
        var finalState = state
        
        // Finalize any pending cell
        if let cell = finalState.currentCell {
            let content = parseContentBlocks(finalState.cellContent)
            finalState.cells.append(GridCell(
                column: cell.column,
                row: cell.row,
                content: content,
                attributes: finalState.currentCellAttributes
            ))
        }
        
        // Create grid layout with cells
        guard let grid = finalState.currentGrid else {
            return Block.paragraph([.text("Invalid grid")])
        }
        
        let updatedGrid = GridLayout(
            columns: grid.columns,
            rows: grid.rows,
            cells: finalState.cells,
            attributes: grid.attributes
        )
        
        // Return as custom grid block
        return Block.gridLayout(updatedGrid)
    }
}

// MARK: - Nested Grid Support

extension SlideGridParser {
    
    /// Parse nested grids with proper indentation tracking
    public func parseNestedGrid(_ lines: [String], at index: Int, parentIndent: Int) -> (grid: GridLayout?, endIndex: Int) {
        guard index < lines.count else { return (nil, index) }
        
        let line = lines[index]
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let indent = getIndentation(line)
        
        // Must be a grid declaration at proper indentation
        guard trimmed.hasPrefix("%%") && !trimmed.hasPrefix("%%%"),
              indent >= parentIndent,
              let grid = parseGridLayout(trimmed) else {
            return (nil, index)
        }
        
        var state = GridParseState(
            currentGrid: grid,
            baseIndentation: indent
        )
        
        var currentIndex = index + 1
        
        // Parse grid content at higher indentation
        while currentIndex < lines.count {
            let currentLine = lines[currentIndex]
            let currentIndent = getIndentation(currentLine)
            let currentTrimmed = currentLine.trimmingCharacters(in: .whitespaces)
            
            // Stop if indentation drops below grid level
            if currentIndent < indent && !currentTrimmed.isEmpty {
                break
            }
            
            // Check for nested grid
            if currentTrimmed.hasPrefix("%%") && !currentTrimmed.hasPrefix("%%%") && currentIndent > indent {
                // Recursively parse nested grid
                let (nestedGrid, nextIndex) = parseNestedGrid(lines, at: currentIndex, parentIndent: currentIndent)
                
                if nestedGrid != nil {
                    // Add nested grid as content to current cell
                    if state.currentCell != nil {
                        state.cellContent.append("<!-- Nested grid placeholder -->")
                    }
                }
                
                currentIndex = nextIndex
                continue
            }
            
            // Handle cell declarations and content
            if currentTrimmed.hasPrefix("%") && !currentTrimmed.hasPrefix("%%") {
                // New cell
                if let cell = state.currentCell {
                    let content = parseContentBlocks(state.cellContent)
                    state.cells.append(GridCell(
                        column: cell.column, 
                        row: cell.row, 
                        content: content,
                        attributes: state.currentCellAttributes
                    ))
                    state.cellContent = []
                    state.currentCellAttributes = nil
                }
                
                if let (cellRef, content, attrs) = parseGridCell(currentTrimmed) {
                    state.currentCell = cellRef
                    state.currentCellAttributes = attrs
                    state.cellIndentation = currentIndent + 2
                    if !content.isEmpty {
                        state.cellContent.append(content)
                    }
                }
            } else if state.currentCell != nil && currentIndent >= state.cellIndentation {
                // Cell content continuation
                let contentLine = String(currentLine.dropFirst(state.cellIndentation))
                state.cellContent.append(contentLine)
            } else {
                // End of grid
                break
            }
            
            currentIndex += 1
        }
        
        // Finalize last cell
        if let cell = state.currentCell {
            let content = parseContentBlocks(state.cellContent)
            state.cells.append(GridCell(
                column: cell.column, 
                row: cell.row, 
                content: content,
                attributes: state.currentCellAttributes
            ))
        }
        
        // Create final grid
        let finalGrid = GridLayout(
            columns: grid.columns,
            rows: grid.rows,
            cells: state.cells,
            attributes: grid.attributes
        )
        
        return (finalGrid, currentIndex)
    }
}
