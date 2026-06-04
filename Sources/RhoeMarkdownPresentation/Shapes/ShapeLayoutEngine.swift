//
//  ShapeLayoutEngine.swift
//  RhoeMarkdownKit
//
//  Shape sizing and text layout algorithms
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// Shape layout engine for sizing and text positioning
public struct ShapeLayoutEngine: Sendable {
    
    // MARK: - Layout Configuration
    
    public struct LayoutConfig: Sendable, Equatable {
        /// Minimum shape size
        public let minSize: ShapeRenderer.ShapeSize
        
        /// Maximum shape size
        public let maxSize: ShapeRenderer.ShapeSize
        
        /// Padding inside shape for text
        public let textPadding: Double
        
        /// Font size range
        public let minFontSize: Double
        public let maxFontSize: Double
        
        /// Aspect ratio preference
        public let preferredAspectRatio: Double?
        
        public init(
            minSize: ShapeRenderer.ShapeSize = ShapeRenderer.ShapeSize(width: 100, height: 75),
            maxSize: ShapeRenderer.ShapeSize = ShapeRenderer.ShapeSize(width: 400, height: 300),
            textPadding: Double = 20,
            minFontSize: Double = 12,
            maxFontSize: Double = 48,
            preferredAspectRatio: Double? = nil
        ) {
            self.minSize = minSize
            self.maxSize = maxSize
            self.textPadding = textPadding
            self.minFontSize = minFontSize
            self.maxFontSize = maxFontSize
            self.preferredAspectRatio = preferredAspectRatio
        }
        
        public static let `default` = LayoutConfig()
        
        public static let presentation = LayoutConfig(
            minSize: ShapeRenderer.ShapeSize(width: 150, height: 100),
            maxSize: ShapeRenderer.ShapeSize(width: 600, height: 400),
            textPadding: 30,
            minFontSize: 16,
            maxFontSize: 72
        )
        
        public static let compact = LayoutConfig(
            minSize: ShapeRenderer.ShapeSize(width: 80, height: 60),
            maxSize: ShapeRenderer.ShapeSize(width: 200, height: 150),
            textPadding: 10,
            minFontSize: 10,
            maxFontSize: 24
        )
    }
    
    // MARK: - Text Measurement
    
    public struct TextMetrics: Sendable, Equatable {
        public let width: Double
        public let height: Double
        public let fontSize: Double
        public let lineCount: Int
        
        public init(width: Double, height: Double, fontSize: Double, lineCount: Int) {
            self.width = width
            self.height = height
            self.fontSize = fontSize
            self.lineCount = lineCount
        }
    }
    
    /// Estimate text metrics for content
    public static func measureText(
        _ content: String,
        maxWidth: Double,
        fontSize: Double
    ) -> TextMetrics {
        // Simplified text measurement
        // In real implementation, would use Core Text or similar
        let avgCharWidth = fontSize * 0.6
        let lineHeight = fontSize * 1.4
        
        let words = content.split(separator: " ")
        var lines: [String] = []
        var currentLine = ""
        var currentWidth: Double = 0
        
        for word in words {
            let wordWidth = Double(word.count) * avgCharWidth
            
            if currentWidth + wordWidth > maxWidth && !currentLine.isEmpty {
                lines.append(currentLine)
                currentLine = String(word)
                currentWidth = wordWidth
            } else {
                if !currentLine.isEmpty {
                    currentLine += " "
                    currentWidth += avgCharWidth
                }
                currentLine += String(word)
                currentWidth += wordWidth
            }
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        let totalHeight = Double(lines.count) * lineHeight
        let maxLineWidth = lines.map { Double($0.count) * avgCharWidth }.max() ?? 0
        
        return TextMetrics(
            width: maxLineWidth,
            height: totalHeight,
            fontSize: fontSize,
            lineCount: lines.count
        )
    }
    
    // MARK: - Size Calculation
    
    /// Calculate optimal shape size for content
    public static func calculateSize(
        for shape: ShapeType,
        content: String,
        config: LayoutConfig = .default
    ) -> ShapeRenderer.ShapeSize {
        // Start with preferred aspect ratio if specified
        let targetAspectRatio = config.preferredAspectRatio ?? aspectRatioForShape(shape)
        
        // Binary search for optimal font size
        var low = config.minFontSize
        var high = config.maxFontSize
        var bestSize = config.minSize
        var bestFontSize = config.minFontSize
        
        while high - low > 0.5 {
            let fontSize = (low + high) / 2
            
            // Try different widths
            for widthFactor in stride(from: 0.5, through: 2.0, by: 0.25) {
                let testWidth = config.minSize.width * widthFactor
                
                if testWidth > config.maxSize.width {
                    continue
                }
                
                let testHeight = testWidth / targetAspectRatio
                
                if testHeight > config.maxSize.height || testHeight < config.minSize.height {
                    continue
                }
                
                let shapeSize = ShapeRenderer.ShapeSize(width: testWidth, height: testHeight)
                let textBounds = ShapeRenderer.textBounds(for: shape, size: shapeSize)
                let availableWidth = textBounds.width - config.textPadding * 2
                
                let metrics = measureText(content, maxWidth: availableWidth, fontSize: fontSize)
                
                // Check if text fits
                if metrics.height <= textBounds.height - config.textPadding * 2 {
                    bestSize = shapeSize
                    bestFontSize = fontSize
                    low = fontSize + 0.5
                    break
                }
            }
            
            if bestFontSize == fontSize {
                high = fontSize - 0.5
            }
        }
        
        // Ensure minimum size
        return ShapeRenderer.ShapeSize(
            width: max(bestSize.width, config.minSize.width),
            height: max(bestSize.height, config.minSize.height)
        )
    }
    
    /// Get preferred aspect ratio for shape type
    private static func aspectRatioForShape(_ shape: ShapeType) -> Double {
        switch shape {
        case .basic(.circle), .basic(.burst):
            return 1.0 // Square aspect ratio
            
        case .basic(.rect), .basic(.roundedRect):
            return 1.5 // Wider than tall
            
        case .basic(.ellipse), .basic(.capsule):
            return 1.8 // Even wider
            
        case .basic(.arrow), .basic(.arrowLeft), .basic(.arrowRight):
            return 2.0 // Horizontal arrows
            
        case .basic(.arrowUp), .basic(.arrowDown):
            return 0.75 // Vertical arrows
            
        case .basic(.triangle):
            return 1.2 // Slightly wider
            
        case .basic(.diamond):
            return 1.0 // Square
            
        case .basic(.pentagon), .basic(.hexagon), .basic(.octagon):
            return 1.0 // Regular polygons
            
        case .basic(.chevron):
            return 2.5 // Very wide
            
        case .basic(.plus), .basic(.cross):
            return 1.0 // Square
            
        case .basic(.star), .basic(.star6):
            return 1.0 // Square
            
        case .basic(.cloud):
            return 1.3 // Slightly wider
            
        case .basic(.heart):
            return 0.9 // Slightly taller
            
        case .basic(.shield):
            return 0.8 // Taller than wide
            
        case .basic(.callout):
            return 1.5 // Like a speech bubble
            
        case .basic(.chart), .basic(.mermaid), .basic(.liquid):
            return 1.6 // Content containers
        case .icon, .emoji:
            return 1.0
        default:
            return 1.0
        }
    }
    
    // MARK: - Text Layout
    
    public struct TextLayout: Sendable, Equatable {
        public let lines: [TextLine]
        public let fontSize: Double
        public let bounds: CGRect
        
        public struct TextLine: Sendable, Equatable {
            public let text: String
            public let x: Double
            public let y: Double
            public let width: Double
            public let height: Double
        }
    }
    
    /// Calculate text layout within shape
    public static func layoutText(
        _ content: String,
        in shape: ShapeType,
        size: ShapeRenderer.ShapeSize,
        config: LayoutConfig = .default
    ) -> TextLayout {
        let textBounds = ShapeRenderer.textBounds(for: shape, size: size)
        let availableWidth = textBounds.width - config.textPadding * 2
        let availableHeight = textBounds.height - config.textPadding * 2
        
        // Find best font size
        var fontSize = config.maxFontSize
        var metrics: TextMetrics
        
        repeat {
            metrics = measureText(content, maxWidth: availableWidth, fontSize: fontSize)
            if metrics.height <= availableHeight {
                break
            }
            fontSize -= 1
        } while fontSize > config.minFontSize
        
        // Layout lines
        let lineHeight = fontSize * 1.4
        let totalHeight = metrics.height
        let startY = textBounds.y + config.textPadding + (availableHeight - totalHeight) / 2
        
        // Re-flow text at chosen font size
        let avgCharWidth = fontSize * 0.6
        let words = content.split(separator: " ")
        var lines: [TextLayout.TextLine] = []
        var currentLine = ""
        var currentWidth: Double = 0
        var y = startY
        
        for word in words {
            let wordWidth = Double(word.count) * avgCharWidth
            
            if currentWidth + wordWidth > availableWidth && !currentLine.isEmpty {
                // Finish current line
                let x = textBounds.x + config.textPadding + (availableWidth - currentWidth) / 2
                lines.append(TextLayout.TextLine(
                    text: currentLine,
                    x: x,
                    y: y,
                    width: currentWidth,
                    height: lineHeight
                ))
                
                currentLine = String(word)
                currentWidth = wordWidth
                y += lineHeight
            } else {
                if !currentLine.isEmpty {
                    currentLine += " "
                    currentWidth += avgCharWidth
                }
                currentLine += String(word)
                currentWidth += wordWidth
            }
        }
        
        // Add last line
        if !currentLine.isEmpty {
            let x = textBounds.x + config.textPadding + (availableWidth - currentWidth) / 2
            lines.append(TextLayout.TextLine(
                text: currentLine,
                x: x,
                y: y,
                width: currentWidth,
                height: lineHeight
            ))
        }
        
        return TextLayout(
            lines: lines,
            fontSize: fontSize,
            bounds: textBounds
        )
    }
    
    // MARK: - Grid Cell Shape Fitting
    
    /// Calculate shape size to fit in grid cell
    public static func sizeForGridCell(
        shape: ShapeType,
        cellWidth: Double,
        cellHeight: Double,
        padding: Double = 10
    ) -> ShapeRenderer.ShapeSize {
        let availableWidth = cellWidth - padding * 2
        let availableHeight = cellHeight - padding * 2
        
        let shapeAspectRatio = aspectRatioForShape(shape)
        let cellAspectRatio = availableWidth / availableHeight
        
        let finalWidth: Double
        let finalHeight: Double
        
        if shapeAspectRatio > cellAspectRatio {
            // Shape is wider - fit to width
            finalWidth = availableWidth
            finalHeight = finalWidth / shapeAspectRatio
        } else {
            // Shape is taller - fit to height
            finalHeight = availableHeight
            finalWidth = finalHeight * shapeAspectRatio
        }
        
        return ShapeRenderer.ShapeSize(
            width: finalWidth,
            height: finalHeight
        )
    }
}
