//
//  MeshGradientParser.swift
//  RhoeMarkdownKit
//
//  Parser for mesh gradient notation
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// Parser for mesh gradient markdown notation
public struct MeshGradientParser {
    
    /// Parse mesh gradient from markdown content
    /// Supports formats:
    /// - !!! MeshGradient C6
    /// - !!! MeshGradient.C6
    public static func parse(from content: [Block]) -> MeshGradient? {
        var meshSize = MeshSize.medium
        var points: [MeshPoint] = []
        
        for (index, block) in content.enumerated() {
            // First block might contain size specification
            if index == 0 {
                if let size = extractSize(from: block) {
                    meshSize = size
                    continue
                }
            }
            
            // Parse point definitions
            if let blockPoints = extractPoints(from: block) {
                points.append(contentsOf: blockPoints)
            }
        }
        
        // Return nil if no points defined
        guard !points.isEmpty else { return nil }
        
        return MeshGradient(
            size: meshSize,
            points: points,
            smoothing: 0.5
        )
    }
    
    /// Extract size from block
    private static func extractSize(from block: Block) -> MeshSize? {
        switch block {
        case .paragraph(let inlines, _):
            for inline in inlines {
                if case .text(let text) = inline {
                    // Check if it's a size notation like "C6"
                    let trimmed = text.trimmingCharacters(in: .whitespaces)
                    if let size = MeshSize(from: trimmed) {
                        return size
                    }
                }
            }
        default:
            break
        }
        return nil
    }
    
    /// Extract points from block
    private static func extractPoints(from block: Block) -> [MeshPoint]? {
        var points: [MeshPoint] = []
        
        switch block {
        case .paragraph(let inlines, _):
            // Parse inline point definitions
            var currentPosition: String? = nil
            var attributes: [String: String] = [:]
            
            for inline in inlines {
                switch inline {
                case .text(let text):
                    let trimmed = text.trimmingCharacters(in: .whitespaces)
                    
                    // Check for shorthand notation: A1.purple600
                    if let point = MeshPoint(shorthand: trimmed) {
                        points.append(point)
                    }
                    // Check for position: A1
                    else if let (_, _) = GridCell.parseReference(trimmed) {
                        currentPosition = trimmed
                    }
                    
                case .codeSpan(let code, _):
                    // Could be attribute: color="Material.purple600"
                    if let (key, value) = parseAttribute(code) {
                        attributes[key] = value
                    }
                    
                default:
                    break
                }
            }
            
            // Create point from position and attributes
            if let pos = currentPosition,
               let (col, row) = GridCell.parseReference(pos),
               let color = attributes["color"] {
                let position = GridPosition(column: col, row: row)
                let intensity = Double(attributes["intensity"] ?? "1.0") ?? 1.0
                points.append(MeshPoint(
                    position: position,
                    color: color,
                    intensity: intensity
                ))
            }
            
        case .codeBlock(_, let code, _):
            // Parse multi-line definitions
            let lines = code.split(separator: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                // Skip empty lines
                if trimmed.isEmpty { continue }
                
                // Try shorthand first
                if let point = MeshPoint(shorthand: trimmed) {
                    points.append(point)
                    continue
                }
                
                // Try structured format: A1 { color="..." }
                if let point = parseStructuredPoint(trimmed) {
                    points.append(point)
                }
            }
            
        case .list(_, let items, _):
            // Parse list items as points
            for item in items {
                if let itemPoints = extractPoints(from: item.content.first ?? .paragraph([])) {
                    points.append(contentsOf: itemPoints)
                }
            }
            
        default:
            break
        }
        
        return points.isEmpty ? nil : points
    }
    
    /// Parse attribute from string
    private static func parseAttribute(_ text: String) -> (String, String)? {
        let pattern = /(\w+)="([^"]+)"/
        if let match = try? pattern.firstMatch(in: text) {
            return (String(match.1), String(match.2))
        }
        return nil
    }
    
    /// Parse structured point format: A1 { color="Material.purple600" intensity="0.8" }
    private static func parseStructuredPoint(_ text: String) -> MeshPoint? {
        let parts = text.split(separator: "{", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        
        let positionStr = parts[0].trimmingCharacters(in: .whitespaces)
        guard let (col, row) = GridCell.parseReference(positionStr) else { return nil }
        
        let attributesStr = parts[1].trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "}")))
        var attributes: [String: String] = [:]
        
        // Parse attributes
        let attrPattern = /(\w+)="([^"]+)"/
        let matches = attributesStr.matches(of: attrPattern)
        for match in matches {
            attributes[String(match.1)] = String(match.2)
        }
        
        guard let color = attributes["color"] else { return nil }
        let intensity = Double(attributes["intensity"] ?? "1.0") ?? 1.0
        
        return MeshPoint(
            position: GridPosition(column: col, row: row),
            color: color,
            intensity: intensity
        )
    }
}

// MARK: - Convenience Extensions

extension MeshGradient {
    
    /// Create a simple two-color diagonal gradient
    public static func diagonal(
        from topLeftColor: String,
        to bottomRightColor: String,
        size: MeshSize = .small
    ) -> MeshGradient {
        let (cols, rows) = size.dimensions
        
        return MeshGradient(
            size: size,
            points: [
                MeshPoint(
                    position: GridPosition(column: 1, row: 1),
                    color: topLeftColor
                ),
                MeshPoint(
                    position: GridPosition(column: cols, row: rows),
                    color: bottomRightColor
                )
            ]
        )
    }
    
    /// Create a radial gradient from center
    public static func radial(
        center centerColor: String,
        edge edgeColor: String,
        size: MeshSize = .small
    ) -> MeshGradient {
        let (cols, rows) = size.dimensions
        let centerCol = (cols + 1) / 2
        let centerRow = (rows + 1) / 2
        
        var points: [MeshPoint] = []
        
        // Center point
        points.append(MeshPoint(
            position: GridPosition(column: centerCol, row: centerRow),
            color: centerColor
        ))
        
        // Corner points
        for (col, row) in [(1, 1), (cols, 1), (1, rows), (cols, rows)] {
            points.append(MeshPoint(
                position: GridPosition(column: col, row: row),
                color: edgeColor,
                intensity: 0.7
            ))
        }
        
        return MeshGradient(size: size, points: points)
    }
}
