//
//  ShapeIntegration.swift
//  RhoeMarkdownKit
//
//  Integration of shapes with the slide rendering system
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// Shape integration for slide rendering
public struct ShapeIntegration {
    
    // MARK: - Shape Processing
    
    /// Process a shape content block into renderable format
    public static func processShape(
        _ shapeContent: ShapeContent,
        in cellBounds: CellBounds? = nil,
        presentationAttributes: RhoeMarkdownKit.Attributes? = nil
    ) -> RenderableShape {
        // Extract text content from blocks
        let text = extractText(from: shapeContent.content)
        
        // Apply styling from attributes
        let style = ShapeStyler.styleFromAttributes(shapeContent.attributes)
        
        // Calculate size based on content and cell bounds
        let size: ShapeRenderer.ShapeSize
        if let bounds = cellBounds {
            size = ShapeLayoutEngine.sizeForGridCell(
                shape: shapeContent.shape,
                cellWidth: bounds.width,
                cellHeight: bounds.height,
                padding: bounds.padding
            )
        } else {
            size = ShapeLayoutEngine.calculateSize(
                for: shapeContent.shape,
                content: text,
                config: .presentation
            )
        }
        
        // Generate SVG
        let svg = ShapeStyler.generateSVG(
            shape: shapeContent.shape,
            style: style,
            size: size,
            content: text.isEmpty ? nil : text,
            presentationAttributes: presentationAttributes
        )
        
        return RenderableShape(
            type: shapeContent.shape,
            size: size,
            style: style,
            content: text,
            svg: svg,
            position: cellBounds?.position
        )
    }
    
    /// Extract text from content blocks
    private static func extractText(from blocks: [Block]) -> String {
        var texts: [String] = []
        
        for block in blocks {
            switch block {
            case .paragraph(let inlines, _):
                texts.append(extractTextFromInlines(inlines))
                
            case .heading(_, let inlines, _):
                texts.append(extractTextFromInlines(inlines))
                
            case .list(_, let items, _):
                for item in items {
                    if let firstBlock = item.content.first,
                       case .paragraph(let inlines, _) = firstBlock {
                        texts.append("• " + extractTextFromInlines(inlines))
                    }
                }
                
            default:
                // Other block types not typically used in shapes
                break
            }
        }
        
        return texts.joined(separator: "\n")
    }
    
    /// Extract text from inline elements
    private static func extractTextFromInlines(_ inlines: [Inline]) -> String {
        return inlines.map { inline in
            switch inline {
            case .text(let str):
                return str
            case .emphasis(let inner), .strong(let inner):
                return extractTextFromInlines(inner)
            case .codeSpan(let str, _):
                return str
            case .softBreak, .hardBreak:
                return " "
            default:
                return ""
            }
        }.joined()
    }
    
    // MARK: - Batch Processing
    
    /// Process all shapes in a slide
    public static func processShapesInSlide(_ slide: Slide) -> [RenderableShape] {
        var shapes: [RenderableShape] = []
        
        for content in slide.content {
            switch content {
            case .grid(let gridElement):
                if case .shape(let shapeContent) = gridElement.content {
                    // Grid-cell geometry is resolved by downstream layout renderers in 0.1.0.
                    let shape = processShape(shapeContent)
                    shapes.append(shape)
                }
                
            case .slot(let slotElement):
                // Shapes in slots are not common but could be supported
                for block in slotElement.content {
                    if case .admonition(let type, _, let content, _, let attrs) = block,
                       let shapeType = ShapeType(from: type) {
                        let shapeContent = ShapeContent(
                            shape: shapeType,
                            attributes: attrs,
                            content: content
                        )
                        let shape = processShape(shapeContent)
                        shapes.append(shape)
                    }
                }
                
            case .markdown:
                // Regular markdown blocks don't contain shapes
                break
            }
        }

        return shapes
    }
    
    // MARK: - Shape Library
    
    /// Get all available shapes with sample renders
    public static func shapeLibrary() -> [ShapeLibrarySample] {
        let shapes: [ShapeType] =
            BasicShape.allCases.map { .basic($0) } +
            [.icon(iconSet: .lucide, name: "heart"), .emoji(name: "rocket")]

        return shapes.map { shape in
            let sample = sampleForShape(shape)
            let size = ShapeRenderer.ShapeSize.default
            let svg = ShapeStyler.generateSVG(
                shape: shape,
                style: sample.style,
                size: size,
                content: sample.text
            )
            
            return ShapeLibrarySample(
                type: shape,
                name: shapeDisplayName(shape),
                category: shapeCategory(shape),
                sampleSVG: svg,
                sampleText: sample.text,
                sampleStyle: sample.style
            )
        }
    }
    
    private static func sampleForShape(_ shape: ShapeType) -> (text: String, style: ShapeStyler.ShapeStyle) {
        switch shape {
        case .basic(.circle):
            return ("Core", .primary)
        case .basic(.rect):
            return ("Basic", .default)
        case .basic(.roundedRect):
            return ("Modern", .secondary)
        case .basic(.arrow), .basic(.arrowUp), .basic(.arrowDown), .basic(.arrowLeft), .basic(.arrowRight):
            return ("Next", .success)
        case .basic(.star), .basic(.star6):
            return ("★", .warning)
        case .basic(.heart):
            return ("♥", ShapeStyler.ShapeStyle(fill: "#E91E63", stroke: "#C2185B", strokeWidth: 2))
        case .basic(.shield):
            return ("Secure", ShapeStyler.ShapeStyle(fill: "#4CAF50", stroke: "#2E7D32", strokeWidth: 2))
        case .basic(.cloud):
            return ("Cloud", ShapeStyler.ShapeStyle(fill: "#E3F2FD", stroke: "#64B5F6", strokeWidth: 2))
        case .icon:
            return ("Icon", .default)
        case .emoji:
            return ("Emoji", .default)
        default:
            return (shape.rawValue, .default)
        }
    }
    
    private static func shapeDisplayName(_ shape: ShapeType) -> String {
        switch shape {
        case .basic(.roundedRect): return "Rounded Rectangle"
        case .basic(.arrowUp): return "Arrow Up"
        case .basic(.arrowDown): return "Arrow Down"
        case .basic(.arrowLeft): return "Arrow Left"
        case .basic(.arrowRight): return "Arrow Right"
        case .basic(.star6): return "6-Point Star"
        default: return shape.rawValue
        }
    }
    
    private static func shapeCategory(_ shape: ShapeType) -> ShapeCategory {
        switch shape {
        case .basic(.circle), .basic(.rect), .basic(.roundedRect), .basic(.ellipse), .basic(.capsule):
            return .geometric
        case .basic(.triangle), .basic(.diamond), .basic(.pentagon), .basic(.hexagon), .basic(.octagon):
            return .polygons
        case .basic(.arrow), .basic(.arrowUp), .basic(.arrowDown), .basic(.arrowLeft), .basic(.arrowRight):
            return .arrows
        case .basic(.chevron), .basic(.plus), .basic(.cross), .basic(.star), .basic(.star6):
            return .symbols
        case .basic(.cloud), .basic(.heart), .basic(.shield), .basic(.burst), .basic(.callout):
            return .special
        case .basic(.chart), .basic(.mermaid), .basic(.liquid), .icon, .emoji:
            return .content
        default:
            return .special
        }
    }
}

// MARK: - Supporting Types

/// Renderable shape with all computed properties
public struct RenderableShape: Sendable, Equatable {
    public let type: ShapeType
    public let size: ShapeRenderer.ShapeSize
    public let style: ShapeStyler.ShapeStyle
    public let content: String
    public let svg: String
    public let position: CGPoint?
    
    public init(
        type: ShapeType,
        size: ShapeRenderer.ShapeSize,
        style: ShapeStyler.ShapeStyle,
        content: String,
        svg: String,
        position: CGPoint? = nil
    ) {
        self.type = type
        self.size = size
        self.style = style
        self.content = content
        self.svg = svg
        self.position = position
    }
}

/// Cell bounds for shape layout
public struct CellBounds: Sendable, Equatable {
    public let width: Double
    public let height: Double
    public let padding: Double
    public let position: CGPoint
    
    public init(
        width: Double,
        height: Double,
        padding: Double = 10,
        position: CGPoint = CGPoint(x: 0, y: 0)
    ) {
        self.width = width
        self.height = height
        self.padding = padding
        self.position = position
    }
}

/// Shape library sample
public struct ShapeLibrarySample: Sendable, Equatable {
    public let type: ShapeType
    public let name: String
    public let category: ShapeCategory
    public let sampleSVG: String
    public let sampleText: String
    public let sampleStyle: ShapeStyler.ShapeStyle
}

/// Shape categories for organization
public enum ShapeCategory: String, Sendable, Equatable, CaseIterable {
    case geometric = "Geometric"
    case polygons = "Polygons"
    case arrows = "Arrows"
    case symbols = "Symbols"
    case special = "Special"
    case content = "Content"
}
