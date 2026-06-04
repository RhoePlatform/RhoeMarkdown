//
//  GridShape.swift
//  RhoeMarkdownKit
//
//  Grid as a Shape - enabling infinite composability
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

// MARK: - Grid Shape Types

/// A grid shape that can contain positioned content
public struct GridShape: Sendable, Equatable {
    public let size: GridShapeSize
    public let defaultAlignment: CellAlignment
    public let cells: [GridShapeCell]
    public let attributes: SlideAttributes?
    
    public init(
        size: GridShapeSize,
        defaultAlignment: CellAlignment = .center,
        cells: [GridShapeCell],
        attributes: SlideAttributes? = nil
    ) {
        self.size = size
        self.defaultAlignment = defaultAlignment
        self.cells = cells
        self.attributes = attributes
    }
}

/// Size specification for grid shape
public struct GridShapeSize: Sendable, Equatable {
    public let columns: Int
    public let rows: Int
    
    /// Parse from notation like "D3" (4 columns, 3 rows)
    public init?(from notation: String) {
        guard let (col, row) = GridCell.parseReference(notation) else {
            return nil
        }
        self.columns = col
        self.rows = row
    }
    
    public init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
    }
    
    /// Get notation string
    public var notation: String {
        return "\(GridCell.columnLetter(columns))\(rows)"
    }
}

/// A cell within a grid shape
public struct GridShapeCell: Sendable, Equatable {
    public let position: CellReference
    public let alignment: CellAlignment?
    public let content: [Block]
    
    public init(
        position: CellReference,
        alignment: CellAlignment? = nil,
        content: [Block]
    ) {
        self.position = position
        self.alignment = alignment
        self.content = content
    }
}

// MARK: - Grid Content Extension

extension ShapeContent {
    /// Check if this shape content is a grid.
    public var isGridShape: Bool {
        guard case .basic(.grid) = shape else {
            return false
        }
        return true
    }

    /// Extract a grid configuration from the current shape content.
    public func extractGridConfiguration() -> GridShape? {
        guard case .basic(.grid) = shape else {
            return nil
        }

        var gridSize = GridShapeSize(columns: 3, rows: 3)
        var defaultAlignment = CellAlignment.center
        var contentStartIndex = 0

        if let firstBlock = content.first,
           case .paragraph(let inlines, _) = firstBlock,
           let firstInline = inlines.first,
           case .text(let text) = firstInline,
           let (size, alignment) = parseGridSpec(text) {
            gridSize = size
            defaultAlignment = alignment
            contentStartIndex = 1
        }

        let cells = parseGridCells(from: Array(content.dropFirst(contentStartIndex)))

        return GridShape(
            size: gridSize,
            defaultAlignment: defaultAlignment,
            cells: cells,
            attributes: attributes
        )
    }
    
    /// Parse grid specification like "D3.TL"
    private func parseGridSpec(_ text: String) -> (GridShapeSize, CellAlignment)? {
        let parts = text.split(separator: ".")
        
        // Just size
        if parts.count == 1 {
            if let size = GridShapeSize(from: String(parts[0])) {
                return (size, .center)
            }
        }
        // Size and alignment
        else if parts.count == 2 {
            if let size = GridShapeSize(from: String(parts[0])),
               let align = CellAlignment(rawValue: String(parts[1])) {
                return (size, align)
            }
        }
        
        return nil
    }
    
    /// Parse cells from blocks
    private func parseGridCells(from blocks: [Block]) -> [GridShapeCell] {
        var cells: [GridShapeCell] = []
        var currentCell: (position: String, alignment: CellAlignment?, content: [Block])?
        
        for block in blocks {
            switch block {
            case .paragraph(let inlines, _):
                // Check if this starts a new cell
                if let firstInline = inlines.first,
                   case .text(let text) = firstInline {
                    let trimmed = text.trimmingCharacters(in: .whitespaces)
                    
                    // Check for cell reference (e.g., "A1" or "A1.TL")
                    if let cellInfo = parseCellReference(trimmed) {
                        // Save previous cell if exists
                        if let cell = currentCell,
                           let ref = CellReference(from: cell.position) {
                            cells.append(GridShapeCell(
                                position: ref,
                                alignment: cell.alignment,
                                content: cell.content
                            ))
                        }
                        
                        // Start new cell
                        currentCell = (cellInfo.position, cellInfo.alignment, [])
                        
                        // Add remaining content from this paragraph
                        let remainingInlines = Array(inlines.dropFirst())
                        if !remainingInlines.isEmpty {
                            currentCell?.content.append(.paragraph(remainingInlines))
                        }
                        
                        continue
                    }
                }
                
                // Add to current cell content
                currentCell?.content.append(block)
                
            default:
                // Add to current cell content
                currentCell?.content.append(block)
            }
        }
        
        // Save last cell
        if let cell = currentCell,
           let ref = CellReference(from: cell.position) {
            cells.append(GridShapeCell(
                position: ref,
                alignment: cell.alignment,
                content: cell.content
            ))
        }
        
        return cells
    }
    
    /// Parse cell reference like "A1" or "A1.TL"
    private func parseCellReference(_ text: String) -> (position: String, alignment: CellAlignment?)? {
        let parts = text.split(separator: ".", maxSplits: 1)
        
        guard !parts.isEmpty else { return nil }
        
        let position = String(parts[0])
        
        // Validate it's a valid cell reference
        guard GridCell.parseReference(position) != nil else { return nil }
        
        // Parse alignment if present
        var alignment: CellAlignment? = nil
        if parts.count > 1 {
            alignment = CellAlignment(rawValue: String(parts[1]))
        }
        
        return (position, alignment)
    }
}

// MARK: - Grid Shape Parser

/// Parser for grid shape content
public struct GridShapeParser {
    
    /// Parse a grid shape from shape content
    public static func parse(from shapeContent: ShapeContent) -> GridShape? {
        return shapeContent.extractGridConfiguration()
    }
    
    /// Create a simple grid with text content
    public static func simpleGrid(
        size: GridShapeSize,
        cells: [(position: String, text: String)]
    ) -> GridShape {
        let gridCells = cells.compactMap { cell -> GridShapeCell? in
            guard let ref = CellReference(from: cell.position) else { return nil }
            
            return GridShapeCell(
                position: ref,
                alignment: nil,
                content: [.paragraph([.text(cell.text)])]
            )
        }
        
        return GridShape(
            size: size,
            defaultAlignment: .center,
            cells: gridCells
        )
    }
}
