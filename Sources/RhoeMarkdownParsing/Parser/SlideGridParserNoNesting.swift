//
//  SlideGridParserNoNesting.swift
//  RhoeMarkdownKit
//
//  Slide grid parser that explicitly prevents nesting (architectural decision)
//

import Foundation
import RhoeMarkdownModel

/// Grid parser that handles Excel-style layouts WITHOUT nesting support
/// This is by design - nesting is handled by the Grid Shape (!!! Grid)
public struct SlideGridParserNoNesting: Sendable {
    
    public init() {}
    
    /// Parse a slide with grid layout - NO NESTING ALLOWED
    public func parseSlideGrid(_ lines: [String], startIndex: Int = 0) -> (blocks: [Block], endIndex: Int) {
        var blocks: [Block] = []
        var index = startIndex
        var gridLayout: GridLayout? = nil
        var cells: [GridCell] = []
        var currentCell: (column: Int, row: Int)? = nil
        var currentCellContent: [String] = []
        var currentCellAttributes: Attributes? = nil
        
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for slide break
            if trimmed.hasPrefix("%%%") {
                break
            }
            
            // Check for grid layout declaration
            if trimmed.hasPrefix("%%") && !trimmed.hasPrefix("%%%") {
                // If we encounter another grid declaration within a grid, IGNORE IT
                if gridLayout != nil {
                    // Nested grids not allowed — silently ignore
                    index += 1
                    continue
                }
                
                // Parse grid layout
                if let grid = parseGridLayout(trimmed) {
                    gridLayout = grid
                }
                index += 1
                continue
            }
            
            // Check for grid cell
            if trimmed.hasPrefix("%") && !trimmed.hasPrefix("%%") && gridLayout != nil {
                // Save previous cell if any
                if let cell = currentCell {
                    let content = parseContentBlocks(currentCellContent)
                    cells.append(GridCell(
                        column: cell.column,
                        row: cell.row,
                        content: content,
                        attributes: currentCellAttributes
                    ))
                }
                
                // Parse new cell
                if let (cellRef, content, attrs) = parseGridCell(trimmed) {
                    currentCell = cellRef
                    currentCellAttributes = attrs
                    currentCellContent = []
                    if !content.isEmpty {
                        currentCellContent.append(content)
                    }
                }
                index += 1
                continue
            }
            
            // If we're in a cell, add content
            if currentCell != nil && gridLayout != nil {
                // Check if line starts a nested grid - PREVENT IT
                if trimmed.hasPrefix("%%") && !trimmed.hasPrefix("%%%") {
                    // Convert to text warning instead of parsing as grid
                    currentCellContent.append("⚠️ Nested grids not allowed in slide layout. Use !!! Grid shape instead.")
                } else {
                    currentCellContent.append(line)
                }
                index += 1
                continue
            }
            
            // Regular content outside grid
            blocks.append(.paragraph([.text(line)]))
            index += 1
        }
        
        // Finalize any pending cell
        if let cell = currentCell {
            let content = parseContentBlocks(currentCellContent)
            cells.append(GridCell(
                column: cell.column,
                row: cell.row,
                content: content,
                attributes: currentCellAttributes
            ))
        }
        
        // Create grid block if we have a layout
        if let layout = gridLayout, !cells.isEmpty {
            let finalizedLayout = GridLayout(
                columns: layout.columns,
                rows: layout.rows,
                cells: cells,
                attributes: layout.attributes
            )
            blocks.append(.gridLayout(finalizedLayout))
        }
        
        return (blocks, index)
    }
    
    /// Parse grid layout declaration (e.g., "%% D5")
    private func parseGridLayout(_ line: String) -> GridLayout? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("%%") else { return nil }
        
        let content = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return nil }
        
        // Parse column and row (e.g., "D5" -> 4 columns, 5 rows)
        if let (col, row) = GridCell.parseReference(content) {
            return GridLayout(columns: col, rows: row)
        }
        
        return nil
    }
    
    /// Parse grid cell reference and content
    private func parseGridCell(_ line: String) -> (ref: (column: Int, row: Int), content: String, attrs: Attributes?)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("%") else { return nil }
        
        let content = trimmed.dropFirst(1).trimmingCharacters(in: .whitespaces)
        
        // Find cell reference
        let parts = content.split(separator: " ", maxSplits: 1)
        guard !parts.isEmpty else { return nil }
        
        let cellPart = String(parts[0])
        
        // Handle range (A1:C3) or single cell (A1)
        if cellPart.contains(":") {
            let rangeParts = cellPart.split(separator: ":")
            if rangeParts.count == 2,
               let (startCol, startRow) = GridCell.parseReference(String(rangeParts[0])),
               GridCell.parseReference(String(rangeParts[1])) != nil {
                // For now, use top-left of range
                let cellContent = parts.count > 1 ? String(parts[1]) : ""
                return ((startCol, startRow), cellContent, nil)
            }
        } else if let (col, row) = GridCell.parseReference(cellPart) {
            let cellContent = parts.count > 1 ? String(parts[1]) : ""
            return ((col, row), cellContent, nil)
        }
        
        return nil
    }
    
    /// Parse content blocks from lines
    private func parseContentBlocks(_ lines: [String]) -> [Block] {
        guard !lines.isEmpty else { return [] }
        
        // For now, treat all content as paragraphs
        // In a full implementation, this would parse markdown
        let text = lines.joined(separator: "\n")
        return [.paragraph([.text(text)])]
    }
}

// MARK: - Grid Layout Structure

/// Grid layout definition
public struct GridLayout: Sendable, Equatable {
    public let columns: Int
    public let rows: Int
    public let cells: [GridCell]
    public let attributes: Attributes?
    
    public init(
        columns: Int,
        rows: Int,
        cells: [GridCell] = [],
        attributes: Attributes? = nil
    ) {
        self.columns = columns
        self.rows = rows
        self.cells = cells
        self.attributes = attributes
    }

    static func parseDimensions(_ ref: String) -> (columns: Int, rows: Int)? {
        GridCell.parseReference(ref).map { (columns: $0.column, rows: $0.row) }
    }
}

/// Grid cell with content
public struct GridCell: Sendable, Equatable {
    public let column: Int
    public let row: Int
    public let content: [Block]
    public let attributes: Attributes?
    
    public init(column: Int, row: Int, content: [Block], attributes: Attributes? = nil) {
        self.column = column
        self.row = row
        self.content = content
        self.attributes = attributes
    }
    
    /// Parse cell reference like "A1" into (column, row)
    static func parseReference(_ ref: String) -> (column: Int, row: Int)? {
        let pattern = /^([A-Z]+)(\d+)$/
        guard let match = try? pattern.firstMatch(in: ref) else {
            return nil
        }
        
        let columnStr = String(match.1)
        let rowStr = String(match.2)
        
        guard let row = Int(rowStr), row > 0 else {
            return nil
        }
        
        // Convert column letters to number (A=1, B=2, ..., Z=26, AA=27, etc.)
        var column = 0
        for char in columnStr {
            guard let value = char.asciiValue,
                  value >= 65 && value <= 90 else {
                return nil
            }
            column = column * 26 + Int(value - 64)
        }
        
        return (column, row)
    }
}

extension Block {
    public static func gridLayout(_ layout: GridLayout) -> Block {
        .html("<!-- grid-layout \(layout.columns)x\(layout.rows) cells=\(layout.cells.count) -->")
    }
}
