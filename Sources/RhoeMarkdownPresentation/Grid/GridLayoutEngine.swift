//
//  GridLayoutEngine.swift
//  RhoeMarkdownKit
//
//  Revolutionary Excel-style grid layout system for markdown
//

import Foundation
import RhoeLoggingKit
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering
// import RhoePerformanceKit // Temporarily disabled

/// Revolutionary grid layout engine with Excel-style positioning
public actor GridLayoutEngine {
    
    private let logger = RhoeLogger.shared
    private let logCategory = LogCategory(name: "GridLayout", subsystem: "RhoeMarkdownKit")

    public init() {}
    
    // MARK: - Grid Types
    
    /// Grid cell reference (Excel-style)
    public struct CellReference: Sendable, Hashable, Codable {
        public let row: Int
        public let column: Int
        
        public init(row: Int, column: Int) {
            self.row = row
            self.column = column
        }
        
        /// Parse from Excel-style notation (e.g., "A1", "B2", "AA10")
        public init?(notation: String) {
            guard !notation.isEmpty else { return nil }
            
            var columnPart = ""
            var rowPart = ""
            var foundDigit = false
            
            for char in notation {
                if char.isLetter && !foundDigit {
                    columnPart.append(char.uppercased())
                } else if char.isNumber {
                    foundDigit = true
                    rowPart.append(char)
                } else {
                    return nil
                }
            }
            
            guard !columnPart.isEmpty, !rowPart.isEmpty,
                  let rowNum = Int(rowPart) else { return nil }
            
            // Convert column letters to number (A=1, B=2, ..., Z=26, AA=27, etc.)
            var columnNum = 0
            for char in columnPart {
                guard let value = char.asciiValue,
                      value >= 65 && value <= 90 else { return nil }
                columnNum = columnNum * 26 + Int(value - 64)
            }
            
            self.row = rowNum
            self.column = columnNum
        }
        
        /// Convert to Excel-style notation
        public var notation: String {
            var columnStr = ""
            var col = column
            
            while col > 0 {
                let remainder = (col - 1) % 26
                columnStr = String(Character(UnicodeScalar(65 + remainder)!)) + columnStr
                col = (col - 1) / 26
            }
            
            return "\(columnStr)\(row)"
        }
    }
    
    /// Grid range specification
    public struct GridRange: Sendable, Codable {
        public let start: CellReference
        public let end: CellReference
        
        public init(start: CellReference, end: CellReference) {
            self.start = start
            self.end = end
        }
        
        /// Parse from notation like "A1:B3" or "[1,1:2,3]"
        public init?(notation: String) {
            if notation.hasPrefix("[") && notation.hasSuffix("]") {
                // Parse bracket notation [row,col:row,col]
                let inner = String(notation.dropFirst().dropLast())
                let parts = inner.split(separator: ":")
                
                if parts.count == 2 {
                    let startParts = parts[0].split(separator: ",")
                    let endParts = parts[1].split(separator: ",")
                    
                    if startParts.count == 2, endParts.count == 2,
                       let startRow = Int(startParts[0].trimmingCharacters(in: .whitespaces)),
                       let startCol = Int(startParts[1].trimmingCharacters(in: .whitespaces)),
                       let endRow = Int(endParts[0].trimmingCharacters(in: .whitespaces)),
                       let endCol = Int(endParts[1].trimmingCharacters(in: .whitespaces)) {
                        self.start = CellReference(row: startRow, column: startCol)
                        self.end = CellReference(row: endRow, column: endCol)
                        return
                    }
                }
            } else if notation.contains(":") {
                // Parse Excel notation A1:B3
                let parts = notation.split(separator: ":")
                if parts.count == 2,
                   let start = CellReference(notation: String(parts[0])),
                   let end = CellReference(notation: String(parts[1])) {
                    self.start = start
                    self.end = end
                    return
                }
            }
            
            return nil
        }
        
        /// Check if a cell is within this range
        public func contains(_ cell: CellReference) -> Bool {
            return cell.row >= start.row && cell.row <= end.row &&
                   cell.column >= start.column && cell.column <= end.column
        }
        
        /// Calculate the number of cells in this range
        public var cellCount: Int {
            let rows = end.row - start.row + 1
            let cols = end.column - start.column + 1
            return rows * cols
        }
    }
    
    /// Grid cell with content and styling
    public struct GridCell: Sendable, Codable {
        public let reference: CellReference
        public let content: String
        public let span: GridSpan?
        public let alignment: GridAlignment
        public let style: GridCellStyle?
        public let formula: String?
        
        public init(
            reference: CellReference,
            content: String,
            span: GridSpan? = nil,
            alignment: GridAlignment = .left,
            style: GridCellStyle? = nil,
            formula: String? = nil
        ) {
            self.reference = reference
            self.content = content
            self.span = span
            self.alignment = alignment
            self.style = style
            self.formula = formula
        }
    }
    
    /// Cell spanning specification
    public struct GridSpan: Sendable, Codable {
        public let rowSpan: Int
        public let colSpan: Int
        
        public init(rowSpan: Int = 1, colSpan: Int = 1) {
            self.rowSpan = max(1, rowSpan)
            self.colSpan = max(1, colSpan)
        }
    }
    
    /// Cell alignment
    public enum GridAlignment: String, Sendable, Codable {
        case left = "left"
        case center = "center"
        case right = "right"
        case justify = "justify"
        case top = "top"
        case middle = "middle"
        case bottom = "bottom"
    }
    
    /// Cell styling options
    public struct GridCellStyle: Sendable, Codable {
        public let backgroundColor: String?
        public let textColor: String?
        public let borderStyle: BorderStyle?
        public let fontSize: String?
        public let fontWeight: String?
        
        public enum BorderStyle: String, Sendable, Codable {
            case none = "none"
            case solid = "solid"
            case dashed = "dashed"
            case dotted = "dotted"
            case double = "double"
        }
        
        public init(
            backgroundColor: String? = nil,
            textColor: String? = nil,
            borderStyle: BorderStyle? = nil,
            fontSize: String? = nil,
            fontWeight: String? = nil
        ) {
            self.backgroundColor = backgroundColor
            self.textColor = textColor
            self.borderStyle = borderStyle
            self.fontSize = fontSize
            self.fontWeight = fontWeight
        }
    }
    
    /// Complete grid layout
    public struct GridLayout: Sendable, Codable {
        public let cells: [GridCell]
        public let rows: Int
        public let columns: Int
        public let metadata: GridMetadata
        
        public init(cells: [GridCell], rows: Int, columns: Int, metadata: GridMetadata = GridMetadata()) {
            self.cells = cells
            self.rows = rows
            self.columns = columns
            self.metadata = metadata
        }
    }
    
    /// Grid metadata
    public struct GridMetadata: Sendable, Codable {
        public let title: String?
        public let caption: String?
        public let responsive: Bool
        public let striped: Bool
        public let bordered: Bool
        public let hoverable: Bool
        
        public init(
            title: String? = nil,
            caption: String? = nil,
            responsive: Bool = true,
            striped: Bool = false,
            bordered: Bool = true,
            hoverable: Bool = false
        ) {
            self.title = title
            self.caption = caption
            self.responsive = responsive
            self.striped = striped
            self.bordered = bordered
            self.hoverable = hoverable
        }
    }
    
    // MARK: - Grid Parsing
    
    /// Parse grid layout from markdown table syntax
    public func parseGrid(_ markdown: String) async throws -> GridLayout {
        logger.info("Parsing grid layout from markdown", category: logCategory)
        
        let startTime = Date().timeIntervalSinceReferenceDate
        
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var cells: [GridCell] = []
        var maxRow = 0
        var maxCol = 0
        
        // Track merged cells to avoid duplicates
        var mergedCells = Set<CellReference>()
        
        for (lineIndex, line) in lines.enumerated() {
            guard line.hasPrefix("|") else { continue }
            
            let parts = line.split(separator: "|")
                .dropFirst() // Remove empty first element
                .dropLast()   // Remove empty last element if line ends with |
                .map { $0.trimmingCharacters(in: .whitespaces) }
            
            for (colIndex, part) in parts.enumerated() {
                let row = lineIndex + 1
                let col = colIndex + 1
                let cellRef = CellReference(row: row, column: col)
                
                // Skip if this cell is part of a merged range
                if mergedCells.contains(cellRef) {
                    continue
                }
                
                // Parse cell content and attributes
                if let cell = parseCell(part, at: cellRef) {
                    cells.append(cell)
                    
                    // Track merged cells if this cell spans multiple positions
                    if let span = cell.span {
                        for r in row..<(row + span.rowSpan) {
                            for c in col..<(col + span.colSpan) {
                                if r != row || c != col {
                                    mergedCells.insert(CellReference(row: r, column: c))
                                }
                            }
                        }
                        
                        maxRow = max(maxRow, row + span.rowSpan - 1)
                        maxCol = max(maxCol, col + span.colSpan - 1)
                    } else {
                        maxRow = max(maxRow, row)
                        maxCol = max(maxCol, col)
                    }
                }
            }
        }
        
        let parseTime = Date().timeIntervalSinceReferenceDate - startTime
        
        logger.info(
            "Grid parsed: \(cells.count) cells, \(maxRow)x\(maxCol) grid in \(parseTime * 1000)ms",
            category: logCategory
        )
        
        // Record performance metrics
        PerformanceMonitor.shared.recordMetric(
            name: "grid_parse",
            value: parseTime,
            unit: .seconds,
            metadata: [
                "cells": "\(cells.count)",
                "rows": "\(maxRow)",
                "columns": "\(maxCol)"
            ]
        )
        
        return GridLayout(
            cells: cells,
            rows: maxRow,
            columns: maxCol,
            metadata: extractGridMetadata(from: markdown)
        )
    }
    
    /// Parse individual cell with bracket notation support
    private func parseCell(_ content: String, at reference: CellReference) -> GridCell? {
        guard !content.isEmpty else { return nil }
        
        // Check for bracket notation [row,col] or [row,col:row2,col2]
        if content.hasPrefix("[") {
            let bracketEnd = content.firstIndex(of: "]") ?? content.endIndex
            let bracketContent = String(content[content.index(after: content.startIndex)..<bracketEnd])
            let cellContent = String(content[content.index(after: bracketEnd)...])
                .trimmingCharacters(in: .whitespaces)
            
            // Parse position or range
            if bracketContent.contains(":") {
                // This is a range specification for merged cells
                if let range = GridRange(notation: "[\(bracketContent)]") {
                    let rowSpan = range.end.row - range.start.row + 1
                    let colSpan = range.end.column - range.start.column + 1
                    
                    return GridCell(
                        reference: CellReference(row: range.start.row, column: range.start.column),
                        content: cellContent,
                        span: GridSpan(rowSpan: rowSpan, colSpan: colSpan),
                        alignment: detectAlignment(cellContent),
                        style: extractStyle(from: cellContent)
                    )
                }
            } else {
                // Single cell position
                let parts = bracketContent.split(separator: ",")
                if parts.count == 2,
                   let row = Int(parts[0].trimmingCharacters(in: .whitespaces)),
                   let col = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                    
                    return GridCell(
                        reference: CellReference(row: row, column: col),
                        content: cellContent,
                        alignment: detectAlignment(cellContent),
                        style: extractStyle(from: cellContent)
                    )
                }
            }
        }
        
        // Standard cell without positioning
        return GridCell(
            reference: reference,
            content: content,
            alignment: detectAlignment(content),
            style: extractStyle(from: content),
            formula: detectFormula(content)
        )
    }
    
    /// Detect cell alignment from content
    private func detectAlignment(_ content: String) -> GridAlignment {
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        
        // Check for explicit alignment markers
        if trimmed.hasPrefix(":") && trimmed.hasSuffix(":") {
            return .center
        } else if trimmed.hasPrefix(":") {
            return .left
        } else if trimmed.hasSuffix(":") {
            return .right
        }
        
        // Default alignment based on content type
        if trimmed.hasPrefix("$") || trimmed.contains(".") && Double(trimmed) != nil {
            return .right // Numbers and currency align right
        }
        
        return .left
    }
    
    /// Extract style attributes from content
    private func extractStyle(from content: String) -> GridCellStyle? {
        // Look for style attributes in {style} format
        guard let styleStart = content.firstIndex(of: "{"),
              let styleEnd = content.firstIndex(of: "}"),
              styleStart < styleEnd else { return nil }
        
        let styleStr = String(content[content.index(after: styleStart)..<styleEnd])
        var style = GridCellStyle()
        
        let attributes = styleStr.split(separator: " ")
        for attr in attributes {
            let parts = attr.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0])
                let value = String(parts[1]).replacingOccurrences(of: "\"", with: "")
                
                switch key {
                case "bg", "background":
                    style = GridCellStyle(
                        backgroundColor: value,
                        textColor: style.textColor,
                        borderStyle: style.borderStyle,
                        fontSize: style.fontSize,
                        fontWeight: style.fontWeight
                    )
                case "color", "text":
                    style = GridCellStyle(
                        backgroundColor: style.backgroundColor,
                        textColor: value,
                        borderStyle: style.borderStyle,
                        fontSize: style.fontSize,
                        fontWeight: style.fontWeight
                    )
                case "border":
                    let borderStyle = GridCellStyle.BorderStyle(rawValue: value) ?? .solid
                    style = GridCellStyle(
                        backgroundColor: style.backgroundColor,
                        textColor: style.textColor,
                        borderStyle: borderStyle,
                        fontSize: style.fontSize,
                        fontWeight: style.fontWeight
                    )
                case "size", "font-size":
                    style = GridCellStyle(
                        backgroundColor: style.backgroundColor,
                        textColor: style.textColor,
                        borderStyle: style.borderStyle,
                        fontSize: value,
                        fontWeight: style.fontWeight
                    )
                case "weight", "font-weight":
                    style = GridCellStyle(
                        backgroundColor: style.backgroundColor,
                        textColor: style.textColor,
                        borderStyle: style.borderStyle,
                        fontSize: style.fontSize,
                        fontWeight: value
                    )
                default:
                    break
                }
            }
        }
        
        return style
    }
    
    /// Detect Excel-style formulas
    private func detectFormula(_ content: String) -> String? {
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        
        // Excel-style formulas start with =
        if trimmed.hasPrefix("=") {
            return String(trimmed.dropFirst())
        }
        
        return nil
    }
    
    /// Extract grid metadata from markdown
    private func extractGridMetadata(from markdown: String) -> GridMetadata {
        var title: String?
        var caption: String?
        var responsive = true
        var striped = false
        var bordered = true
        var hoverable = false
        
        // Look for metadata in HTML comments <!-- grid: ... -->
        if let metaStart = markdown.range(of: "<!-- grid:"),
           let metaEnd = markdown.range(of: "-->", range: metaStart.upperBound..<markdown.endIndex) {
            let metaContent = String(markdown[metaStart.upperBound..<metaEnd.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            
            let attributes = metaContent.split(separator: " ")
            for attr in attributes {
                let parts = attr.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0])
                    let value = String(parts[1]).replacingOccurrences(of: "\"", with: "")
                    
                    switch key {
                    case "title":
                        title = value
                    case "caption":
                        caption = value
                    case "responsive":
                        responsive = value == "true"
                    case "striped":
                        striped = value == "true"
                    case "bordered":
                        bordered = value == "true"
                    case "hoverable":
                        hoverable = value == "true"
                    default:
                        break
                    }
                }
            }
        }
        
        return GridMetadata(
            title: title,
            caption: caption,
            responsive: responsive,
            striped: striped,
            bordered: bordered,
            hoverable: hoverable
        )
    }
    
    // MARK: - Grid Rendering
    
    /// Render grid to HTML
    public func renderHTML(_ grid: GridLayout) -> String {
        var html = "<div class=\"rhoe-grid\">\n"
        
        if let title = grid.metadata.title {
            html += "  <h3 class=\"grid-title\">\(escapeHTML(title))</h3>\n"
        }
        
        html += "  <table"
        
        var classes: [String] = ["grid-table"]
        if grid.metadata.responsive { classes.append("responsive") }
        if grid.metadata.striped { classes.append("striped") }
        if grid.metadata.bordered { classes.append("bordered") }
        if grid.metadata.hoverable { classes.append("hoverable") }
        
        if !classes.isEmpty {
            html += " class=\"\(classes.joined(separator: " "))\""
        }
        
        html += ">\n"
        
        // Create grid matrix
        var matrix: [[GridCell?]] = Array(repeating: Array(repeating: nil, count: grid.columns), count: grid.rows)
        
        // Fill matrix with cells
        for cell in grid.cells {
            let row = cell.reference.row - 1
            let col = cell.reference.column - 1
            
            if row < grid.rows && col < grid.columns {
                matrix[row][col] = cell
            }
        }
        
        // Render rows
        for rowIndex in 0..<grid.rows {
            html += "    <tr>\n"
            
            var colIndex = 0
            while colIndex < grid.columns {
                if let cell = matrix[rowIndex][colIndex] {
                    html += renderCell(cell)
                    
                    // Skip columns covered by span
                    if let span = cell.span {
                        colIndex += span.colSpan
                    } else {
                        colIndex += 1
                    }
                } else {
                    // Check if this cell is covered by a span from above
                    var isCovered = false
                    for prevRow in 0..<rowIndex {
                        if let prevCell = matrix[prevRow][colIndex],
                           let span = prevCell.span,
                           prevRow + span.rowSpan > rowIndex {
                            isCovered = true
                            break
                        }
                    }
                    
                    if !isCovered {
                        html += "      <td></td>\n"
                    }
                    colIndex += 1
                }
            }
            
            html += "    </tr>\n"
        }
        
        html += "  </table>\n"
        
        if let caption = grid.metadata.caption {
            html += "  <p class=\"grid-caption\">\(escapeHTML(caption))</p>\n"
        }
        
        html += "</div>"
        
        return html
    }
    
    /// Render individual cell to HTML
    private func renderCell(_ cell: GridCell) -> String {
        var html = "      <td"
        
        // Add span attributes
        if let span = cell.span {
            if span.rowSpan > 1 {
                html += " rowspan=\"\(span.rowSpan)\""
            }
            if span.colSpan > 1 {
                html += " colspan=\"\(span.colSpan)\""
            }
        }
        
        // Add style attributes
        var styles: [String] = []
        
        if cell.alignment != .left {
            styles.append("text-align: \(cell.alignment.rawValue)")
        }
        
        if let style = cell.style {
            if let bg = style.backgroundColor {
                styles.append("background-color: \(bg)")
            }
            if let color = style.textColor {
                styles.append("color: \(color)")
            }
            if let border = style.borderStyle {
                styles.append("border-style: \(border.rawValue)")
            }
            if let size = style.fontSize {
                styles.append("font-size: \(size)")
            }
            if let weight = style.fontWeight {
                styles.append("font-weight: \(weight)")
            }
        }
        
        if !styles.isEmpty {
            html += " style=\"\(styles.joined(separator: "; "))\""
        }
        
        // Add data attributes for formulas
        if let formula = cell.formula {
            html += " data-formula=\"\(escapeHTML(formula))\""
        }
        
        html += ">"
        
        // Add content
        html += escapeHTML(cell.content)
        
        html += "</td>\n"
        
        return html
    }
    
    /// Escape HTML special characters
    private func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    // MARK: - Grid Formulas
    
    /// Evaluate formulas in grid (simplified implementation)
    public func evaluateFormulas(_ grid: GridLayout) async -> GridLayout {
        logger.info("Evaluating grid formulas", category: logCategory)
        
        var updatedCells = grid.cells
        
        for (index, cell) in grid.cells.enumerated() {
            if let formula = cell.formula {
                let result = await evaluateFormula(formula, in: grid)
                updatedCells[index] = GridCell(
                    reference: cell.reference,
                    content: result,
                    span: cell.span,
                    alignment: cell.alignment,
                    style: cell.style,
                    formula: cell.formula
                )
            }
        }
        
        return GridLayout(
            cells: updatedCells,
            rows: grid.rows,
            columns: grid.columns,
            metadata: grid.metadata
        )
    }
    
    /// Evaluate a single formula
    private func evaluateFormula(_ formula: String, in grid: GridLayout) async -> String {
        // Simplified formula evaluation
        // In a real implementation, this would support Excel-style functions
        
        if formula.uppercased().hasPrefix("SUM(") {
            // Extract range
            let rangeStr = String(formula.dropFirst(4).dropLast())
            if let range = GridRange(notation: rangeStr) {
                var sum = 0.0
                for cell in grid.cells {
                    if range.contains(cell.reference),
                       let value = Double(cell.content) {
                        sum += value
                    }
                }
                return String(format: "%.2f", sum)
            }
        } else if formula.uppercased().hasPrefix("AVG(") {
            // Extract range
            let rangeStr = String(formula.dropFirst(4).dropLast())
            if let range = GridRange(notation: rangeStr) {
                var sum = 0.0
                var count = 0
                for cell in grid.cells {
                    if range.contains(cell.reference),
                       let value = Double(cell.content) {
                        sum += value
                        count += 1
                    }
                }
                if count > 0 {
                    return String(format: "%.2f", sum / Double(count))
                }
            }
        }
        
        // Return formula as-is if not evaluated
        return "=\(formula)"
    }
}

// MARK: - Grid Export

extension GridLayoutEngine {
    
    /// Export grid to CSV format
    public func exportCSV(_ grid: GridLayout) -> String {
        var csv = ""
        
        // Create grid matrix
        var matrix: [[String]] = Array(repeating: Array(repeating: "", count: grid.columns), count: grid.rows)
        
        // Fill matrix with cell contents
        for cell in grid.cells {
            let row = cell.reference.row - 1
            let col = cell.reference.column - 1
            
            if row < grid.rows && col < grid.columns {
                let content = cell.content.contains(",") || cell.content.contains("\"") 
                    ? "\"\(cell.content.replacingOccurrences(of: "\"", with: "\"\""))\"" 
                    : cell.content
                matrix[row][col] = content
            }
        }
        
        // Build CSV
        for row in matrix {
            csv += row.joined(separator: ",") + "\n"
        }
        
        return csv
    }
    
    /// Export grid to JSON format
    public func exportJSON(_ grid: GridLayout) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(grid)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
