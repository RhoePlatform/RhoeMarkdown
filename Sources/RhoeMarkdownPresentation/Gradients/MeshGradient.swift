//
//  MeshGradient.swift
//  RhoeMarkdownKit
//
//  SwiftUI-style mesh gradients with chessboard notation
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

// MARK: - Mesh Gradient Types

/// A mesh gradient defined by control points
public struct MeshGradient: Sendable, Equatable {
    public let size: MeshSize
    public let points: [MeshPoint]
    public let smoothing: Double
    
    public init(size: MeshSize, points: [MeshPoint], smoothing: Double = 0.5) {
        self.size = size
        self.points = points
        self.smoothing = smoothing
    }
}

/// Size of the mesh grid
public enum MeshSize: Sendable, Equatable {
    case small  // 3x3 (A1-C3)
    case medium // 6x6 (A1-F6)
    case large  // 9x9 (A1-I9)
    case custom(columns: Int, rows: Int)
    
    /// Parse from string (e.g., "C6" means 3x6 grid)
    public init?(from string: String) {
        guard let (col, row) = GridCell.parseReference(string) else {
            return nil
        }
        
        // Common sizes
        if col == 3 && row == 3 {
            self = .small
        } else if col == 6 && row == 6 {
            self = .medium
        } else if col == 9 && row == 9 {
            self = .large
        } else {
            self = .custom(columns: col, rows: row)
        }
    }
    
    /// Get the actual dimensions
    public var dimensions: (columns: Int, rows: Int) {
        switch self {
        case .small: return (3, 3)
        case .medium: return (6, 6)
        case .large: return (9, 9)
        case .custom(let cols, let rows): return (cols, rows)
        }
    }
    
    /// Get string representation
    public var notation: String {
        let (cols, rows) = dimensions
        let colLetter = GridCell.columnLetter(cols)
        return "\(colLetter)\(rows)"
    }
}

/// A control point in the mesh
public struct MeshPoint: Sendable, Equatable {
    public let position: GridPosition
    public let color: String
    public let intensity: Double
    
    public init(position: GridPosition, color: String, intensity: Double = 1.0) {
        self.position = position
        self.color = color
        self.intensity = intensity
    }
    
    /// Parse from shorthand notation like "A1.purple600"
    public init?(shorthand: String) {
        let parts = shorthand.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        
        let positionStr = String(parts[0])
        guard let (col, row) = GridCell.parseReference(positionStr) else { return nil }
        
        self.position = GridPosition(column: col, row: row)
        
        // Parse color
        if parts.count == 2 {
            // Simple color: A1.purple600
            self.color = String(parts[1])
        } else if parts.count == 3 {
            // Palette color: A1.Material.purple600
            self.color = "\(parts[1]).\(parts[2])"
        } else {
            return nil
        }
        
        self.intensity = 1.0
    }
}

/// Position in the grid
public struct GridPosition: Sendable, Equatable {
    public let column: Int
    public let row: Int
    
    /// Get normalized coordinates (0.0 to 1.0)
    public func normalized(in size: MeshSize) -> (x: Double, y: Double) {
        let (cols, rows) = size.dimensions
        let x = Double(column - 1) / Double(cols - 1)
        let y = Double(row - 1) / Double(rows - 1)
        return (x, y)
    }
    
    /// Get notation (e.g., "A1")
    public var notation: String {
        return "\(GridCell.columnLetter(column))\(row)"
    }
}

// MARK: - Mesh Content Extension

extension ShapeContent {
    public var isMeshGradient: Bool {
        guard case .basic(.meshGradient) = shape else {
            return false
        }
        return true
    }

    public func extractMeshConfiguration() -> (size: MeshSize, points: [MeshPoint])? {
        guard case .basic(.meshGradient) = shape else {
            return nil
        }

        var meshSize = MeshSize.medium

        if let firstBlock = content.first,
           case .paragraph(let inlines, _) = firstBlock,
           let firstInline = inlines.first,
           case .text(let text) = firstInline,
           let size = MeshSize(from: text) {
            meshSize = size
        }

        var points: [MeshPoint] = []

        for block in content {
            switch block {
            case .paragraph(let inlines, _):
                for inline in inlines {
                    guard case .text(let text) = inline else { continue }

                    if let point = MeshPoint(shorthand: text) {
                        points.append(point)
                    } else if let (col, row) = GridCell.parseReference(text) {
                        points.append(
                            MeshPoint(
                                position: GridPosition(column: col, row: row),
                                color: "MaterialColor.grey500",
                                intensity: 1.0
                            )
                        )
                    }
                }

            case .codeBlock(_, let code, _):
                let lines = code.split(separator: "\n")
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if let point = MeshPoint(shorthand: trimmed) {
                        points.append(point)
                    }
                }

            default:
                break
            }
        }

        return (meshSize, points)
    }
}

// MARK: - Grid Cell Utilities

struct GridCell {
    /// Parse a cell reference like "A1" into (column, row)
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
    
    /// Convert column number to letter(s)
    static func columnLetter(_ col: Int) -> String {
        var column = col
        var result = ""
        
        while column > 0 {
            column -= 1
            let remainder = column % 26
            result = String(Character(UnicodeScalar(65 + remainder)!)) + result
            column = column / 26
        }
        
        return result
    }
}
