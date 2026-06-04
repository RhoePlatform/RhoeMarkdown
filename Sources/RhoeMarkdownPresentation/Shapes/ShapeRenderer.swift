//
//  ShapeRenderer.swift
//  RhoeMarkdownKit
//
//  SVG path generation for all shape types
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// Shape renderer that generates SVG paths for all shape types
public struct ShapeRenderer: Sendable {
    
    // MARK: - Shape Dimensions
    
    public struct ShapeSize: Sendable, Equatable {
        public let width: Double
        public let height: Double
        
        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }
        
        public static let `default` = ShapeSize(width: 200, height: 150)
        public static let square = ShapeSize(width: 150, height: 150)
        public static let wide = ShapeSize(width: 300, height: 150)
        public static let tall = ShapeSize(width: 150, height: 200)
    }
    
    // MARK: - Public API
    
    /// Generate SVG path for a shape
    public static func generatePath(
        for shape: ShapeType,
        size: ShapeSize = .default
    ) -> String {
        switch shape {
        case .basic(let basicShape):
            return generateBasicPath(for: basicShape, size: size)
        case .icon, .emoji:
            // Icons and emojis don't use paths, they use full SVG content
            return ""
        }
    }
    
    private static func generateBasicPath(
        for shape: BasicShape,
        size: ShapeSize
    ) -> String {
        switch shape {
        // Geometric shapes
        case .circle:
            return circlePath(size: size)
        case .rect:
            return rectPath(size: size)
        case .roundedRect:
            return roundedRectPath(size: size)
        case .ellipse:
            return ellipsePath(size: size)
        case .capsule:
            return capsulePath(size: size)
            
        // Polygons
        case .triangle:
            return trianglePath(size: size)
        case .diamond:
            return diamondPath(size: size)
        case .pentagon:
            return pentagonPath(size: size)
        case .hexagon:
            return hexagonPath(size: size)
        case .octagon:
            return octagonPath(size: size)
            
        // Arrows
        case .arrow:
            return arrowPath(size: size, direction: .right)
        case .arrowUp:
            return arrowPath(size: size, direction: .up)
        case .arrowDown:
            return arrowPath(size: size, direction: .down)
        case .arrowLeft:
            return arrowPath(size: size, direction: .left)
        case .arrowRight:
            return arrowPath(size: size, direction: .right)
            
        // Symbols
        case .chevron:
            return chevronPath(size: size)
        case .plus:
            return plusPath(size: size)
        case .cross:
            return crossPath(size: size)
        case .star:
            return starPath(size: size, points: 5)
        case .star6:
            return starPath(size: size, points: 6)
            
        // Special shapes
        case .cloud:
            return cloudPath(size: size)
        case .heart:
            return heartPath(size: size)
        case .shield:
            return shieldPath(size: size)
        case .burst:
            return burstPath(size: size)
        case .callout:
            return calloutPath(size: size)
            
        // Communication & Flow
        case .speechBubble:
            return speechBubblePath(size: size)
        case .thoughtBubble:
            return thoughtBubblePath(size: size)
        case .banner:
            return bannerPath(size: size)
        case .flag:
            return flagPath(size: size)
        case .tag:
            return tagPath(size: size)
            
        // Advanced Polygons
        case .square:
            return squarePath(size: size)
        case .parallelogram:
            return parallelogramPath(size: size)
        case .trapezoid:
            return trapezoidPath(size: size)
        case .rhombus:
            return rhombusPath(size: size)
        case .star4:
            return starPath(size: size, points: 4)
        case .star8:
            return starPath(size: size, points: 8)
        case .star12:
            return starPath(size: size, points: 12)
            
        // Business & Diagrams
        case .cylinder:
            return cylinderPath(size: size)
        case .cube:
            return cubePath(size: size)
        case .pyramid:
            return pyramidPath(size: size)
        case .funnel:
            return funnelPath(size: size)
        case .process:
            return processPath(size: size)
        case .decision:
            return diamondPath(size: size) // Reuse diamond for decision
        case .document:
            return documentPath(size: size)
        case .folder:
            return folderPath(size: size)
            
        // Modern UI
        case .pill:
            return pillPath(size: size)
        case .badge:
            return badgePath(size: size)
        case .tooltip:
            return tooltipPath(size: size)
        case .tab:
            return tabPath(size: size)
        case .card:
            return cardPath(size: size)
            
        // Nature & Organic
        case .flower:
            return flowerPath(size: size)
        case .leaf:
            return leafPath(size: size)
        case .drop:
            return dropPath(size: size)
            
        // Additional Special
        case .gear:
            return gearPath(size: size)
        case .lightning:
            return lightningPath(size: size)
        case .moon:
            return moonPath(size: size)
        case .sun:
            return sunPath(size: size)
            
        // Content shapes (placeholder rectangles)
        case .chart, .mermaid, .liquid:
            return rectPath(size: size)
            
        // Gradient shapes
        case .meshGradient:
            return "" // Mesh gradients are rendered differently
            
        // Layout shapes
        case .grid:
            return "" // Grids are rendered as HTML, not SVG paths
            
        // Semantic shapes
        case .math:
            return "" // Math is rendered as MathML/LaTeX, not SVG
        case .sticker:
            return "" // Stickers are rendered as styled HTML, not SVG
        case .countryMap:
            return rectPath(size: size)
        }
    }
    
    /// Get the text bounding box for a shape
    public static func textBounds(
        for shape: ShapeType,
        size: ShapeSize
    ) -> CGRect {
        switch shape {
        case .basic(let basicShape):
            return textBoundsForBasic(basicShape, size: size)
        case .icon, .emoji:
            // Icons and emojis use the full size for text bounds
            return CGRect(x: 0, y: 0, width: size.width, height: size.height)
        }
    }
    
    private static func textBoundsForBasic(
        _ shape: BasicShape,
        size: ShapeSize
    ) -> CGRect {
        // Calculate safe text area inside shape
        let inset: Double
        
        switch shape {
        case .circle, .ellipse:
            // Inscribed rectangle in ellipse
            inset = min(size.width, size.height) * 0.3
        case .triangle:
            // Lower 2/3 of triangle
            return CGRect(
                x: size.width * 0.2,
                y: size.height * 0.4,
                width: size.width * 0.6,
                height: size.height * 0.4
            )
        case .diamond:
            // Center square
            inset = min(size.width, size.height) * 0.35
        case .star, .star6:
            // Inner circle
            inset = min(size.width, size.height) * 0.4
        case .cloud:
            // Center area
            inset = min(size.width, size.height) * 0.3
        case .heart:
            // Lower portion
            return CGRect(
                x: size.width * 0.2,
                y: size.height * 0.3,
                width: size.width * 0.6,
                height: size.height * 0.5
            )
        case .callout:
            // Main body excluding tail
            return CGRect(
                x: 10,
                y: 10,
                width: size.width - 20,
                height: size.height - 40
            )
        default:
            // Default inset for rectangles and others
            inset = 15
        }
        
        return CGRect(
            x: inset,
            y: inset,
            width: size.width - (inset * 2),
            height: size.height - (inset * 2)
        )
    }
    
    // MARK: - Geometric Shapes
    
    private static func circlePath(size: ShapeSize) -> String {
        let radius = min(size.width, size.height) / 2
        let cx = size.width / 2
        let cy = size.height / 2
        return "M \(cx - radius),\(cy) A \(radius),\(radius) 0 1,0 \(cx + radius),\(cy) A \(radius),\(radius) 0 1,0 \(cx - radius),\(cy) Z"
    }
    
    private static func rectPath(size: ShapeSize) -> String {
        return "M 0,0 L \(size.width),0 L \(size.width),\(size.height) L 0,\(size.height) Z"
    }
    
    private static func roundedRectPath(size: ShapeSize, radius: Double = 10) -> String {
        let r = min(radius, min(size.width, size.height) / 2)
        return """
        M \(r),0 
        L \(size.width - r),0 
        Q \(size.width),0 \(size.width),\(r)
        L \(size.width),\(size.height - r)
        Q \(size.width),\(size.height) \(size.width - r),\(size.height)
        L \(r),\(size.height)
        Q 0,\(size.height) 0,\(size.height - r)
        L 0,\(r)
        Q 0,0 \(r),0
        Z
        """
    }
    
    private static func ellipsePath(size: ShapeSize) -> String {
        let rx = size.width / 2
        let ry = size.height / 2
        return "M 0,\(ry) A \(rx),\(ry) 0 1,0 \(size.width),\(ry) A \(rx),\(ry) 0 1,0 0,\(ry) Z"
    }
    
    private static func capsulePath(size: ShapeSize) -> String {
        let radius = size.height / 2
        if size.width <= size.height {
            // Vertical capsule (circle)
            return circlePath(size: size)
        }
        return """
        M \(radius),0
        L \(size.width - radius),0
        A \(radius),\(radius) 0 0,1 \(size.width - radius),\(size.height)
        L \(radius),\(size.height)
        A \(radius),\(radius) 0 0,1 \(radius),0
        Z
        """
    }
    
    // MARK: - Polygons
    
    private static func trianglePath(size: ShapeSize) -> String {
        return "M \(size.width / 2),0 L \(size.width),\(size.height) L 0,\(size.height) Z"
    }
    
    private static func diamondPath(size: ShapeSize) -> String {
        let cx = size.width / 2
        let cy = size.height / 2
        return "M \(cx),0 L \(size.width),\(cy) L \(cx),\(size.height) L 0,\(cy) Z"
    }
    
    private static func pentagonPath(size: ShapeSize) -> String {
        let cx = size.width / 2
        let cy = size.height / 2
        let r = min(cx, cy)
        
        var points: [CGPoint] = []
        for i in 0..<5 {
            let angle = (Double(i) * 2 * .pi / 5) - (.pi / 2)
            let x = cx + r * cos(angle)
            let y = cy + r * sin(angle)
            points.append(CGPoint(x: x, y: y))
        }
        
        return pathFromPoints(points)
    }
    
    private static func hexagonPath(size: ShapeSize) -> String {
        let cx = size.width / 2
        let cy = size.height / 2
        let r = min(cx, cy)
        
        var points: [CGPoint] = []
        for i in 0..<6 {
            let angle = (Double(i) * 2 * .pi / 6) - (.pi / 2)
            let x = cx + r * cos(angle)
            let y = cy + r * sin(angle)
            points.append(CGPoint(x: x, y: y))
        }
        
        return pathFromPoints(points)
    }
    
    private static func octagonPath(size: ShapeSize) -> String {
        let cx = size.width / 2
        let cy = size.height / 2
        let r = min(cx, cy)
        
        var points: [CGPoint] = []
        for i in 0..<8 {
            let angle = (Double(i) * 2 * .pi / 8) - (.pi / 8)
            let x = cx + r * cos(angle)
            let y = cy + r * sin(angle)
            points.append(CGPoint(x: x, y: y))
        }
        
        return pathFromPoints(points)
    }
    
    // MARK: - Arrows
    
    private enum ArrowDirection {
        case up, down, left, right
    }
    
    private static func arrowPath(size: ShapeSize, direction: ArrowDirection) -> String {
        switch direction {
        case .right:
            let arrowWidth = size.width * 0.4
            let shaftHeight = size.height * 0.6
            let shaftY = (size.height - shaftHeight) / 2
            
            return """
            M 0,\(shaftY)
            L \(size.width - arrowWidth),\(shaftY)
            L \(size.width - arrowWidth),0
            L \(size.width),\(size.height / 2)
            L \(size.width - arrowWidth),\(size.height)
            L \(size.width - arrowWidth),\(shaftY + shaftHeight)
            L 0,\(shaftY + shaftHeight)
            Z
            """
            
        case .left:
            let arrowWidth = size.width * 0.4
            let shaftHeight = size.height * 0.6
            let shaftY = (size.height - shaftHeight) / 2
            
            return """
            M \(arrowWidth),0
            L \(arrowWidth),\(shaftY)
            L \(size.width),\(shaftY)
            L \(size.width),\(shaftY + shaftHeight)
            L \(arrowWidth),\(shaftY + shaftHeight)
            L \(arrowWidth),\(size.height)
            L 0,\(size.height / 2)
            Z
            """
            
        case .up:
            let arrowHeight = size.height * 0.4
            let shaftWidth = size.width * 0.6
            let shaftX = (size.width - shaftWidth) / 2
            
            return """
            M \(size.width / 2),0
            L \(size.width),\(arrowHeight)
            L \(shaftX + shaftWidth),\(arrowHeight)
            L \(shaftX + shaftWidth),\(size.height)
            L \(shaftX),\(size.height)
            L \(shaftX),\(arrowHeight)
            L 0,\(arrowHeight)
            Z
            """
            
        case .down:
            let arrowHeight = size.height * 0.4
            let shaftWidth = size.width * 0.6
            let shaftX = (size.width - shaftWidth) / 2
            
            return """
            M \(shaftX),0
            L \(shaftX + shaftWidth),0
            L \(shaftX + shaftWidth),\(size.height - arrowHeight)
            L \(size.width),\(size.height - arrowHeight)
            L \(size.width / 2),\(size.height)
            L 0,\(size.height - arrowHeight)
            L \(shaftX),\(size.height - arrowHeight)
            Z
            """
        }
    }
    
    // MARK: - Symbols
    
    private static func chevronPath(size: ShapeSize) -> String {
        let thickness = min(size.width, size.height) * 0.3
        return """
        M 0,0
        L \(size.width - thickness),0
        L \(size.width),\(size.height / 2)
        L \(size.width - thickness),\(size.height)
        L 0,\(size.height)
        L \(thickness),\(size.height / 2)
        Z
        """
    }
    
    private static func plusPath(size: ShapeSize) -> String {
        let cx = size.width / 2
        let cy = size.height / 2
        let thickness = min(size.width, size.height) * 0.2
        let length = min(size.width, size.height) * 0.8
        
        return """
        M \(cx - thickness/2),\(cy - length/2)
        L \(cx + thickness/2),\(cy - length/2)
        L \(cx + thickness/2),\(cy - thickness/2)
        L \(cx + length/2),\(cy - thickness/2)
        L \(cx + length/2),\(cy + thickness/2)
        L \(cx + thickness/2),\(cy + thickness/2)
        L \(cx + thickness/2),\(cy + length/2)
        L \(cx - thickness/2),\(cy + length/2)
        L \(cx - thickness/2),\(cy + thickness/2)
        L \(cx - length/2),\(cy + thickness/2)
        L \(cx - length/2),\(cy - thickness/2)
        L \(cx - thickness/2),\(cy - thickness/2)
        Z
        """
    }
    
    private static func crossPath(size: ShapeSize) -> String {
        let cx = size.width / 2
        let cy = size.height / 2
        let thickness = min(size.width, size.height) * 0.15
        let length = min(size.width, size.height) * 0.7
        
        // Create an X shape
        let halfThick = thickness / 2
        let halfLength = length / 2
        
        return """
        M \(cx - halfLength + halfThick),\(cy - halfLength)
        L \(cx),\(cy - halfThick)
        L \(cx + halfLength - halfThick),\(cy - halfLength)
        L \(cx + halfLength),\(cy - halfLength + halfThick)
        L \(cx + halfThick),\(cy)
        L \(cx + halfLength),\(cy + halfLength - halfThick)
        L \(cx + halfLength - halfThick),\(cy + halfLength)
        L \(cx),\(cy + halfThick)
        L \(cx - halfLength + halfThick),\(cy + halfLength)
        L \(cx - halfLength),\(cy + halfLength - halfThick)
        L \(cx - halfThick),\(cy)
        L \(cx - halfLength),\(cy - halfLength + halfThick)
        Z
        """
    }
    
    private static func starPath(size: ShapeSize, points: Int) -> String {
        let cx = size.width / 2
        let cy = size.height / 2
        let outerRadius = min(cx, cy) * 0.9
        let innerRadius = outerRadius * 0.4
        
        var pathPoints: [CGPoint] = []
        let angleStep = 2 * .pi / Double(points * 2)
        
        for i in 0..<(points * 2) {
            let angle = Double(i) * angleStep - (.pi / 2)
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let x = cx + radius * cos(angle)
            let y = cy + radius * sin(angle)
            pathPoints.append(CGPoint(x: x, y: y))
        }
        
        return pathFromPoints(pathPoints)
    }
    
    // MARK: - Special Shapes
    
    static func cloudPath(size: ShapeSize) -> String {
        // Simplified cloud shape with multiple circles
        let unit = min(size.width, size.height) / 4
        
        return """
        M \(unit * 1.5),\(unit * 3)
        A \(unit * 0.8),\(unit * 0.8) 0 1,1 \(unit * 0.8),\(unit * 2)
        A \(unit * 0.9),\(unit * 0.9) 0 1,1 \(unit * 1.2),\(unit * 1)
        A \(unit * 1),\(unit * 1) 0 1,1 \(unit * 2.8),\(unit * 1)
        A \(unit * 0.9),\(unit * 0.9) 0 1,1 \(unit * 3.2),\(unit * 2)
        A \(unit * 0.8),\(unit * 0.8) 0 1,1 \(unit * 2.5),\(unit * 3)
        Z
        """
    }
    
    private static func heartPath(size: ShapeSize) -> String {
        let w = size.width
        let h = size.height
        
        return """
        M \(w * 0.5),\(h * 0.9)
        C \(w * 0.2),\(h * 0.7) 0,\(h * 0.4) 0,\(h * 0.25)
        A \(w * 0.25),\(h * 0.25) 0 0,1 \(w * 0.5),\(h * 0.25)
        A \(w * 0.25),\(h * 0.25) 0 0,1 \(w),\(h * 0.25)
        C \(w),\(h * 0.4) \(w * 0.8),\(h * 0.7) \(w * 0.5),\(h * 0.9)
        Z
        """
    }
    
    private static func shieldPath(size: ShapeSize) -> String {
        let w = size.width
        let h = size.height
        
        return """
        M \(w * 0.5),0
        L \(w),\(h * 0.3)
        L \(w),\(h * 0.5)
        C \(w),\(h * 0.8) \(w * 0.8),\(h * 0.95) \(w * 0.5),\(h)
        C \(w * 0.2),\(h * 0.95) 0,\(h * 0.8) 0,\(h * 0.5)
        L 0,\(h * 0.3)
        Z
        """
    }
    
    private static func burstPath(size: ShapeSize) -> String {
        let cx = size.width / 2
        let cy = size.height / 2
        let outerRadius = min(cx, cy) * 0.9
        let innerRadius = outerRadius * 0.6
        let points = 12
        
        var pathPoints: [CGPoint] = []
        let angleStep = 2 * .pi / Double(points)
        
        for i in 0..<points {
            let angle = Double(i) * angleStep - (.pi / 2)
            
            // Outer point
            let outerX = cx + outerRadius * cos(angle)
            let outerY = cy + outerRadius * sin(angle)
            pathPoints.append(CGPoint(x: outerX, y: outerY))
            
            // Inner point (between outer points)
            let innerAngle = angle + angleStep / 2
            let innerX = cx + innerRadius * cos(innerAngle)
            let innerY = cy + innerRadius * sin(innerAngle)
            pathPoints.append(CGPoint(x: innerX, y: innerY))
        }
        
        return pathFromPoints(pathPoints)
    }
    
    private static func calloutPath(size: ShapeSize) -> String {
        let radius: Double = 10
        let tailSize: Double = 20
        let tailOffset = size.width * 0.2
        
        return """
        M \(radius),0
        L \(size.width - radius),0
        Q \(size.width),0 \(size.width),\(radius)
        L \(size.width),\(size.height - tailSize - radius)
        Q \(size.width),\(size.height - tailSize) \(size.width - radius),\(size.height - tailSize)
        L \(tailOffset + tailSize),\(size.height - tailSize)
        L \(tailOffset),\(size.height)
        L \(tailOffset + tailSize/2),\(size.height - tailSize)
        L \(radius),\(size.height - tailSize)
        Q 0,\(size.height - tailSize) 0,\(size.height - tailSize - radius)
        L 0,\(radius)
        Q 0,0 \(radius),0
        Z
        """
    }
    
    // MARK: - Utilities
    
    private static func pathFromPoints(_ points: [CGPoint]) -> String {
        guard !points.isEmpty else { return "" }
        
        var path = "M \(points[0].x),\(points[0].y)"
        for i in 1..<points.count {
            path += " L \(points[i].x),\(points[i].y)"
        }
        path += " Z"
        
        return path
    }
}

// MARK: - Geometry Bridge

public struct CGPoint: Sendable, Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct CGRect: Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
    
    public var minX: Double { x }
    public var minY: Double { y }
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }
}

// Math extensions
private func cos(_ angle: Double) -> Double {
    Foundation.cos(angle)
}

private func sin(_ angle: Double) -> Double {
    Foundation.sin(angle)
}
