//
//  ShapeStyler.swift
//  RhoeMarkdownKit
//
//  Shape styling and attribute application
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// Shape styling system for applying visual attributes
public struct ShapeStyler: Sendable {
    
    // MARK: - Style Properties
    
    public struct ShapeStyle: Sendable, Equatable {
        public var fill: String?
        public var stroke: String?
        public var strokeWidth: Double?
        public var opacity: Double?
        public var shadow: ShadowStyle?
        public var gradient: GradientStyle?
        public var cornerRadius: Double?
        
        public init(
            fill: String? = nil,
            stroke: String? = nil,
            strokeWidth: Double? = nil,
            opacity: Double? = nil,
            shadow: ShadowStyle? = nil,
            gradient: GradientStyle? = nil,
            cornerRadius: Double? = nil
        ) {
            self.fill = fill
            self.stroke = stroke
            self.strokeWidth = strokeWidth
            self.opacity = opacity
            self.shadow = shadow
            self.gradient = gradient
            self.cornerRadius = cornerRadius
        }
        
        /// Default styles for different contexts
        public static let `default` = ShapeStyle(
            fill: "#E3F2FD",
            stroke: "#1976D2",
            strokeWidth: 2
        )
        
        public static let primary = ShapeStyle(
            fill: "#1976D2",
            stroke: "#0D47A1",
            strokeWidth: 2
        )
        
        public static let secondary = ShapeStyle(
            fill: "#F57C00",
            stroke: "#E65100",
            strokeWidth: 2
        )
        
        public static let success = ShapeStyle(
            fill: "#4CAF50",
            stroke: "#2E7D32",
            strokeWidth: 2
        )
        
        public static let warning = ShapeStyle(
            fill: "#FFC107",
            stroke: "#F57C00",
            strokeWidth: 2
        )
        
        public static let danger = ShapeStyle(
            fill: "#F44336",
            stroke: "#C62828",
            strokeWidth: 2
        )
    }
    
    public struct ShadowStyle: Sendable, Equatable {
        public let dx: Double
        public let dy: Double
        public let blur: Double
        public let color: String
        public let opacity: Double
        
        public init(
            dx: Double = 2,
            dy: Double = 2,
            blur: Double = 4,
            color: String = "#000000",
            opacity: Double = 0.3
        ) {
            self.dx = dx
            self.dy = dy
            self.blur = blur
            self.color = color
            self.opacity = opacity
        }
        
        public static let subtle = ShadowStyle()
        public static let elevated = ShadowStyle(dx: 0, dy: 4, blur: 8, opacity: 0.2)
        public static let dramatic = ShadowStyle(dx: 4, dy: 4, blur: 12, opacity: 0.4)
    }
    
    public struct GradientStyle: Sendable, Equatable {
        public enum GradientType: Sendable, Equatable {
            case linear(angle: Double)
            case radial(cx: Double = 0.5, cy: Double = 0.5)
        }
        
        public let type: GradientType
        public let stops: [(offset: Double, color: String)]
        
        public init(type: GradientType, stops: [(offset: Double, color: String)]) {
            self.type = type
            self.stops = stops
        }

        public static func == (lhs: GradientStyle, rhs: GradientStyle) -> Bool {
            lhs.type == rhs.type &&
            lhs.stops.count == rhs.stops.count &&
            zip(lhs.stops, rhs.stops).allSatisfy { left, right in
                left.offset == right.offset && left.color == right.color
            }
        }
        
        public static let blueGradient = GradientStyle(
            type: .linear(angle: 45),
            stops: [(0, "#2196F3"), (1, "#1976D2")]
        )
        
        public static let warmGradient = GradientStyle(
            type: .linear(angle: 135),
            stops: [(0, "#FF9800"), (1, "#F44336")]
        )
        
        public static let coolGradient = GradientStyle(
            type: .linear(angle: 45),
            stops: [(0, "#4CAF50"), (1, "#2196F3")]
        )
    }
    
    // MARK: - Style Creation
    
    /// Create style from attributes
    public static func styleFromAttributes(_ attributes: RhoeMarkdownKit.Attributes?) -> ShapeStyle {
        guard let attributes = attributes else { return .default }
        
        var style = ShapeStyle.default
        
        // Apply class-based styles first
        for className in attributes.classes {
            if let classStyle = predefinedStyle(for: className) {
                style = mergeStyles(base: style, override: classStyle)
            }
        }
        
        // Apply direct attributes
        if let fill = attributes.keyValues["fill"] {
            style.fill = fill
        }
        
        if let stroke = attributes.keyValues["stroke"] {
            style.stroke = stroke
        }
        
        if let strokeWidthStr = attributes.keyValues["stroke-width"],
           let strokeWidth = Double(strokeWidthStr) {
            style.strokeWidth = strokeWidth
        }
        
        if let opacityStr = attributes.keyValues["opacity"],
           let opacity = Double(opacityStr) {
            style.opacity = opacity
        }
        
        // Shadow from attributes
        if attributes.classes.contains("shadow") {
            style.shadow = .subtle
        } else if attributes.classes.contains("shadow-elevated") {
            style.shadow = .elevated
        } else if attributes.classes.contains("shadow-dramatic") {
            style.shadow = .dramatic
        }
        
        // Gradient from attributes
        if let gradientType = attributes.keyValues["gradient"] {
            style.gradient = gradientFromString(gradientType)
        }
        
        return style
    }
    
    /// Get predefined style for class name
    private static func predefinedStyle(for className: String) -> ShapeStyle? {
        switch className {
        case "primary": return .primary
        case "secondary": return .secondary
        case "success": return .success
        case "warning": return .warning
        case "danger", "error": return .danger
        case "accent": return ShapeStyle(
            fill: "#9C27B0",
            stroke: "#6A1B9A",
            strokeWidth: 2
        )
        case "info": return ShapeStyle(
            fill: "#00BCD4",
            stroke: "#0097A7",
            strokeWidth: 2
        )
        case "dark": return ShapeStyle(
            fill: "#424242",
            stroke: "#212121",
            strokeWidth: 2
        )
        case "light": return ShapeStyle(
            fill: "#FAFAFA",
            stroke: "#E0E0E0",
            strokeWidth: 2
        )
        default: return nil
        }
    }
    
    /// Merge two styles
    private static func mergeStyles(base: ShapeStyle, override: ShapeStyle) -> ShapeStyle {
        return ShapeStyle(
            fill: override.fill ?? base.fill,
            stroke: override.stroke ?? base.stroke,
            strokeWidth: override.strokeWidth ?? base.strokeWidth,
            opacity: override.opacity ?? base.opacity,
            shadow: override.shadow ?? base.shadow,
            gradient: override.gradient ?? base.gradient,
            cornerRadius: override.cornerRadius ?? base.cornerRadius
        )
    }
    
    /// Parse gradient from string
    private static func gradientFromString(_ str: String) -> GradientStyle? {
        switch str {
        case "blue": return .blueGradient
        case "warm": return .warmGradient
        case "cool": return .coolGradient
        default:
            // Parse custom gradient syntax: "linear(45deg, #000 0%, #fff 100%)"
            if str.hasPrefix("linear(") {
                // Custom gradient parsing is intentionally deferred from 0.1.0.
                return nil
            }
            return nil
        }
    }
    
    // MARK: - SVG Generation
    
    /// Generate SVG element with shape and styling
    public static func generateSVG(
        shape: ShapeType,
        style: ShapeStyle,
        size: ShapeRenderer.ShapeSize,
        content: String? = nil,
        presentationAttributes: RhoeMarkdownKit.Attributes? = nil
    ) -> String {
        // Handle icon and emoji shapes differently
        switch shape {
        case .icon(let iconSet, let name):
            if let iconSVG = IconManager.getSVGContent(
                iconSet: iconSet,
                iconName: name,
                size: size,
                style: style,
                presentationAttributes: presentationAttributes
            ) {
                return iconSVG
            } else {
                // Fallback to a placeholder
                return generatePlaceholderIcon(name: name, size: size, style: style)
            }
            
        case .emoji(let name):
            if let emojiSVG = EmojiManager.getSVGContent(
                emojiName: name,
                size: size,
                style: style,
                presentationAttributes: presentationAttributes
            ) {
                return emojiSVG
            } else {
                // Fallback to a placeholder
                return generatePlaceholderEmoji(name: name, size: size, style: style)
            }
            
        case .basic:
            break // Continue with normal shape rendering
        }
        
        let path = ShapeRenderer.generatePath(for: shape, size: size)
        let textBounds = ShapeRenderer.textBounds(for: shape, size: size)
        
        var svg = """
        <svg width="\(size.width)" height="\(size.height)" xmlns="http://www.w3.org/2000/svg">
        """
        
        // Add definitions for gradients and shadows
        if let gradient = style.gradient, let gradientDef = generateGradientDef(gradient) {
            svg += "\n<defs>\n\(gradientDef)\n</defs>"
        }
        
        // Add shadow filter if needed
        if let shadow = style.shadow {
            svg += generateShadowFilter(shadow)
        }
        
        // Shape path with styling
        svg += "\n<path d=\"\(path)\""
        
        // Apply fill
        if style.gradient != nil {
            svg += " fill=\"url(#gradient-\(shape.rawValue))\""
        } else if let fill = style.fill {
            svg += " fill=\"\(fill)\""
        }
        
        // Apply stroke
        if let stroke = style.stroke {
            svg += " stroke=\"\(stroke)\""
        }
        
        if let strokeWidth = style.strokeWidth {
            svg += " stroke-width=\"\(strokeWidth)\""
        }
        
        if let opacity = style.opacity {
            svg += " opacity=\"\(opacity)\""
        }
        
        if style.shadow != nil {
            svg += " filter=\"url(#shadow-\(shape.rawValue))\""
        }
        
        svg += "/>"
        
        // Add text content if provided
        if let content = content {
            svg += generateTextElement(
                content: content,
                bounds: textBounds,
                style: style
            )
        }
        
        svg += "\n</svg>"
        
        return svg
    }
    
    private static func generateGradientDef(_ gradient: GradientStyle) -> String? {
        var def = ""
        
        switch gradient.type {
        case .linear(let angle):
            let rad = angle * .pi / 180
            let x1 = 50 + 50 * cos(rad + .pi)
            let y1 = 50 + 50 * sin(rad + .pi)
            let x2 = 50 + 50 * cos(rad)
            let y2 = 50 + 50 * sin(rad)
            
            def = """
            <linearGradient id="gradient" x1="\(x1)%" y1="\(y1)%" x2="\(x2)%" y2="\(y2)%">
            """
            
        case .radial(let cx, let cy):
            def = """
            <radialGradient id="gradient" cx="\(cx * 100)%" cy="\(cy * 100)%">
            """
        }
        
        for stop in gradient.stops {
            def += "\n  <stop offset=\"\(stop.offset * 100)%\" stop-color=\"\(stop.color)\"/>"
        }
        
        switch gradient.type {
        case .linear:
            def += "\n</linearGradient>"
        case .radial:
            def += "\n</radialGradient>"
        }
        
        return def
    }
    
    private static func generateShadowFilter(_ shadow: ShadowStyle) -> String {
        return """
        <filter id="shadow">
          <feGaussianBlur in="SourceAlpha" stdDeviation="\(shadow.blur/2)"/>
          <feOffset dx="\(shadow.dx)" dy="\(shadow.dy)" result="offsetblur"/>
          <feFlood flood-color="\(shadow.color)" flood-opacity="\(shadow.opacity)"/>
          <feComposite in2="offsetblur" operator="in"/>
          <feMerge>
            <feMergeNode/>
            <feMergeNode in="SourceGraphic"/>
          </feMerge>
        </filter>
        """
    }
    
    private static func generateTextElement(
        content: String,
        bounds: CGRect,
        style: ShapeStyle
    ) -> String {
        let fontSize = min(bounds.height / 3, 24)
        let textColor = textColorForBackground(style.fill ?? "#FFFFFF")
        
        return """
        <text x="\(bounds.midX)" y="\(bounds.midY)"
              text-anchor="middle" dominant-baseline="middle"
              font-family="system-ui, -apple-system, sans-serif"
              font-size="\(fontSize)px"
              fill="\(textColor)">
          \(escapeXML(content))
        </text>
        """
    }
    
    /// Determine text color based on background
    private static func textColorForBackground(_ background: String) -> String {
        // Simple heuristic - could be improved with proper color parsing
        let darkBackgrounds = ["#000", "#212121", "#424242", "#1976D2", "#0D47A1", "#C62828"]
        
        for dark in darkBackgrounds {
            if background.lowercased().hasPrefix(dark.lowercased()) {
                return "#FFFFFF"
            }
        }
        
        return "#000000"
    }
    
    private static func escapeXML(_ str: String) -> String {
        return str
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    /// Generate a placeholder icon when the requested icon is not found
    private static func generatePlaceholderIcon(
        name: String,
        size: ShapeRenderer.ShapeSize,
        style: ShapeStyle
    ) -> String {
        let fill = style.fill ?? "#CCCCCC"
        let stroke = style.stroke ?? "#999999"
        let strokeWidth = style.strokeWidth ?? 2
        
        return """
        <svg width="\(size.width)" height="\(size.height)" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <rect x="2" y="2" width="20" height="20" rx="3" 
                  fill="\(fill)" stroke="\(stroke)" stroke-width="\(strokeWidth)" opacity="0.3"/>
            <text x="12" y="12" text-anchor="middle" dominant-baseline="middle" 
                  font-family="system-ui" font-size="10" fill="\(stroke)">?</text>
            <text x="12" y="20" text-anchor="middle" 
                  font-family="system-ui" font-size="6" fill="\(stroke)">\(String(name.prefix(8)))</text>
        </svg>
        """
    }
    
    /// Generate a placeholder emoji when the requested emoji is not found
    private static func generatePlaceholderEmoji(
        name: String,
        size: ShapeRenderer.ShapeSize,
        style: ShapeStyle
    ) -> String {
        let fill = style.fill ?? "#EEEEEE"
        let fontSize = min(size.width, size.height) * 0.6
        
        return """
        <svg width="\(size.width)" height="\(size.height)" viewBox="0 0 \(size.width) \(size.height)" xmlns="http://www.w3.org/2000/svg">
            <rect width="\(size.width)" height="\(size.height)" fill="\(fill)" rx="\(style.cornerRadius ?? 8)" opacity="0.5"/>
            <text x="\(size.width/2)" y="\(size.height/2)" 
                  text-anchor="middle" dominant-baseline="central"
                  font-family="-apple-system, 'Segoe UI Emoji', sans-serif" 
                  font-size="\(fontSize)">❓</text>
            <text x="\(size.width/2)" y="\(size.height * 0.85)" 
                  text-anchor="middle" 
                  font-family="system-ui" font-size="\(fontSize * 0.2)" fill="#666">\(String(name.prefix(10)))</text>
        </svg>
        """
    }
}

// Math extensions (if not available globally)
private func cos(_ angle: Double) -> Double {
    Foundation.cos(angle)
}

private func sin(_ angle: Double) -> Double {
    Foundation.sin(angle)
}
