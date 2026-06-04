//
//  GridShapeRenderer.swift
//  RhoeMarkdownKit
//
//  Renders grid shapes with nested content
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// Renders grid shapes
public struct GridShapeRenderer {
    
    /// Render a grid shape to HTML
    public static func renderToHTML(
        grid: GridShape,
        size: CGSize,
        renderer: (any SlideRenderer)? = nil
    ) -> String {
        var html = ""
        
        // Create grid container
        let gridStyle = generateGridStyle(grid: grid, size: size)
        html += "<div class=\"rhoemd-grid\" style=\"\(gridStyle)\">\n"
        
        // Render each cell
        for cell in grid.cells {
            let cellHTML = renderCell(
                cell: cell,
                grid: grid,
                size: size,
                renderer: renderer
            )
            html += cellHTML
        }
        
        html += "</div>\n"
        
        return html
    }
    
    /// Generate CSS Grid style
    private static func generateGridStyle(grid: GridShape, size: CGSize) -> String {
        var styles: [String] = []
        
        // Grid display
        styles.append("display: grid")
        
        // Grid template
        styles.append("grid-template-columns: repeat(\(grid.size.columns), 1fr)")
        styles.append("grid-template-rows: repeat(\(grid.size.rows), 1fr)")
        
        // Size
        styles.append("width: \(size.width)px")
        styles.append("height: \(size.height)px")
        
        // Gap (optional)
        styles.append("gap: 4px")
        
        // Apply grid attributes if any
        if let attrs = grid.attributes {
            let resolvedStyles = attrs.resolvedStyles()
            for (key, value) in resolvedStyles {
                if key != "@import" {
                    styles.append("\(key): \(value)")
                }
            }
        }
        
        return styles.joined(separator: "; ")
    }
    
    /// Render a single cell
    private static func renderCell(
        cell: GridShapeCell,
        grid: GridShape,
        size: CGSize,
        renderer: (any SlideRenderer)?
    ) -> String {
        var html = ""
        
        // Calculate grid position
        let (colStart, rowStart, colEnd, rowEnd) = calculateGridPosition(cell.position)
        
        // Cell styles
        var cellStyles: [String] = []
        cellStyles.append("grid-column: \(colStart) / \(colEnd)")
        cellStyles.append("grid-row: \(rowStart) / \(rowEnd)")
        
        // Alignment
        let alignment = cell.alignment ?? grid.defaultAlignment
        let (justifyContent, alignItems) = alignmentToCSS(alignment)
        cellStyles.append("display: flex")
        cellStyles.append("justify-content: \(justifyContent)")
        cellStyles.append("align-items: \(alignItems)")
        cellStyles.append("padding: 8px")
        
        html += "<div class=\"rhoemd-grid-cell\" style=\"\(cellStyles.joined(separator: "; "))\">\n"
        
        // Render cell content
        if let renderer = renderer {
            for block in cell.content {
                html += renderBlock(block, with: renderer)
            }
        } else {
            // Fallback rendering
            html += "<div class=\"cell-content\">\n"
            for block in cell.content {
                html += renderBlockFallback(block)
            }
            html += "</div>\n"
        }
        
        html += "</div>\n"
        
        return html
    }
    
    /// Calculate CSS grid position from cell reference
    private static func calculateGridPosition(_ ref: CellReference) -> (Int, Int, Int, Int) {
        switch ref {
        case .single(let col, let row):
            return (col, row, col + 1, row + 1)
        case .range(let startCol, let startRow, let endCol, let endRow):
            return (startCol, startRow, endCol + 1, endRow + 1)
        }
    }
    
    /// Convert alignment to CSS
    private static func alignmentToCSS(_ alignment: CellAlignment) -> (justify: String, align: String) {
        let properties = alignment.cssProperties
        return (properties.justifyContent, properties.alignItems)
    }
    
    /// Render block using provided renderer
    private static func renderBlock(_ block: Block, with renderer: any SlideRenderer) -> String {
        renderer.render(block: block)
    }
    
    /// Fallback block rendering
    private static func renderBlockFallback(_ block: Block) -> String {
        switch block {
        case .paragraph(let inlines, _):
            var content = "<p>"
            for inline in inlines {
                content += renderInlineFallback(inline)
            }
            content += "</p>\n"
            return content
            
        case .heading(let level, let inlines, _):
            let tag = "h\(level)"
            var content = "<\(tag)>"
            for inline in inlines {
                content += renderInlineFallback(inline)
            }
            content += "</\(tag)>\n"
            return content
            
        default:
            return "<div><!-- Unsupported block type --></div>\n"
        }
    }
    
    /// Fallback inline rendering
    private static func renderInlineFallback(_ inline: Inline) -> String {
        switch inline {
        case .text(let text):
            return text
        case .strong(let inlines):
            return "<strong>" + inlines.map(renderInlineFallback).joined() + "</strong>"
        case .emphasis(let inlines):
            return "<em>" + inlines.map(renderInlineFallback).joined() + "</em>"
        case .codeSpan(let code, _):
            return "<code>\(code)</code>"
        default:
            return ""
        }
    }
    
    /// Generate CSS for grid layouts
    public static func generateCSS() -> String {
        return """
        .rhoemd-grid {
            box-sizing: border-box;
            position: relative;
        }
        
        .rhoemd-grid-cell {
            box-sizing: border-box;
            overflow: hidden;
            position: relative;
        }
        
        /* Nested grids */
        .rhoemd-grid-cell .rhoemd-grid {
            width: 100% !important;
            height: 100% !important;
        }
        
        /* Cell content styling */
        .rhoemd-grid-cell > * {
            margin: 0;
        }
        
        .rhoemd-grid-cell p:first-child {
            margin-top: 0;
        }
        
        .rhoemd-grid-cell p:last-child {
            margin-bottom: 0;
        }
        """
    }
}

// MARK: - Shape Renderer Extension

extension ShapeRenderer {
    
    /// Generate grid shape content
    public static func generateGridShape(
        for shape: ShapeContent,
        size: ShapeSize
    ) -> String? {
        guard let grid = shape.extractGridConfiguration() else {
            return nil
        }
        
        let htmlSize = CGSize(width: size.width, height: size.height)
        return GridShapeRenderer.renderToHTML(
            grid: grid,
            size: htmlSize
        )
    }
}

// MARK: - Recursive Grid Support

extension GridShapeRenderer {
    
    /// Check if content contains nested grids
    private static func containsNestedGrid(_ blocks: [Block]) -> Bool {
        for block in blocks {
            switch block {
            case .paragraph(let inlines, _):
                for inline in inlines {
                    if case .text(let text) = inline,
                       text.contains("!!! Grid") {
                        return true
                    }
                }
            default:
                continue
            }
        }
        return false
    }
    
    /// Process nested grids recursively
    public static func processNestedGrids(in content: [Block]) -> [Block] {
        // This would parse and render nested grid shapes
        // For now, return as-is
        return content
    }
}
