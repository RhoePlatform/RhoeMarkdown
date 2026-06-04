//
//  MeshGradientRenderer.swift
//  RhoeMarkdownKit
//
//  Renders mesh gradients to SVG
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// Renders mesh gradients
public struct MeshGradientRenderer {
    
    /// Render a mesh gradient to SVG
    public static func renderToSVG(
        mesh: MeshGradient,
        size: CGSize,
        id: String = "meshGradient"
    ) -> String {
        var svg = ""
        
        // Create defs section with the gradient
        svg += "<defs>\n"
        svg += generateMeshFilter(mesh: mesh, size: size, id: id)
        svg += "</defs>\n"
        
        // Create rectangle with the gradient
        svg += """
        <rect x="0" y="0" width="\(size.width)" height="\(size.height)" 
              fill="url(#\(id))" />
        """
        
        return svg
    }
    
    /// Generate mesh filter definition
    private static func generateMeshFilter(
        mesh: MeshGradient,
        size: CGSize,
        id: String
    ) -> String {
        // For SVG, we'll use a combination of radial gradients to simulate mesh
        // This is a simplified approach - true mesh gradients require more complex SVG filters
        
        var gradients = ""
        let (cols, rows) = mesh.size.dimensions
        
        // Create a pattern that combines multiple gradients
        gradients += """
        <pattern id="\(id)" x="0" y="0" width="100%" height="100%" 
                 patternUnits="userSpaceOnUse">
        """
        
        // Background color (average of all points or first point)
        let bgColor = mesh.points.first.map { resolveColor($0.color) } ?? "#ffffff"
        gradients += """
          <rect x="0" y="0" width="\(size.width)" height="\(size.height)" 
                fill="\(bgColor)" opacity="0.3" />
        """
        
        // Create radial gradients for each control point
        for (index, point) in mesh.points.enumerated() {
            let (x, y) = point.position.normalized(in: mesh.size)
            let cx = x * size.width
            let cy = y * size.height
            
            // Calculate radius based on grid density
            let baseRadius = min(size.width, size.height) / Double(max(cols, rows))
            let radius = baseRadius * (1.5 + mesh.smoothing)
            
            let color = resolveColor(point.color)
            
            gradients += """
              <radialGradient id="\(id)_point\(index)">
                <stop offset="0%" stop-color="\(color)" stop-opacity="\(point.intensity)" />
                <stop offset="100%" stop-color="\(color)" stop-opacity="0" />
              </radialGradient>
              <circle cx="\(cx)" cy="\(cy)" r="\(radius)" 
                      fill="url(#\(id)_point\(index))" 
                      style="mix-blend-mode: screen;" />
            """
        }
        
        gradients += "</pattern>\n"
        
        return gradients
    }
    
    /// Generate CSS gradient (for simpler rendering)
    public static func generateCSSGradient(mesh: MeshGradient) -> String {
        // Create a conic gradient that approximates the mesh
        // This is a fallback for simpler rendering contexts
        
        guard !mesh.points.isEmpty else {
            return "linear-gradient(to bottom, #ffffff, #f0f0f0)"
        }
        
        // For simple cases, create a radial gradient
        if mesh.points.count == 1 {
            let point = mesh.points[0]
            let (x, y) = point.position.normalized(in: mesh.size)
            let color = resolveColor(point.color)
            return "radial-gradient(circle at \(x * 100)% \(y * 100)%, \(color), transparent)"
        }
        
        // For multiple points, create a complex gradient
        var gradients: [String] = []
        
        for point in mesh.points {
            let (x, y) = point.position.normalized(in: mesh.size)
            let color = resolveColor(point.color)
            let gradient = "radial-gradient(circle at \(x * 100)% \(y * 100)%, \(color) 0%, transparent 50%)"
            gradients.append(gradient)
        }
        
        // Combine gradients
        return gradients.joined(separator: ", ")
    }
    
    /// Resolve color value using design system
    private static func resolveColor(_ color: String) -> String {
        if color.hasPrefix("#") {
            return color
        }

        switch color.lowercased() {
        case "black":
            return "#000000"
        case "white":
            return "#ffffff"
        case "red":
            return "#ef4444"
        case "blue":
            return "#3b82f6"
        case "green":
            return "#22c55e"
        case "yellow":
            return "#eab308"
        case "purple":
            return "#8b5cf6"
        case "orange":
            return "#f97316"
        case "pink":
            return "#ec4899"
        case "gray", "grey":
            return "#6b7280"
        default:
            return color
        }
    }
}

// MARK: - Shape Renderer Extension

extension ShapeRenderer {
    
    /// Generate mesh gradient content
    public static func generateMeshGradient(
        for shape: ShapeContent,
        size: ShapeSize
    ) -> String? {
        guard let (meshSize, points) = shape.extractMeshConfiguration() else {
            return nil
        }
        
        let mesh = MeshGradient(
            size: meshSize,
            points: points,
            smoothing: 0.5
        )
        
        let svgSize = CGSize(width: size.width, height: size.height)
        return MeshGradientRenderer.renderToSVG(
            mesh: mesh,
            size: svgSize,
            id: "mesh_\(UUID().uuidString.prefix(8))"
        )
    }
}

// MARK: - Attribute Extensions

extension SlideAttributes {
    
    /// Apply mesh gradient as background
    public mutating func applyMeshGradient(_ mesh: MeshGradient) {
        let cssGradient = MeshGradientRenderer.generateCSSGradient(mesh: mesh)
        var updatedKeyValues = keyValues
        updatedKeyValues["background"] = cssGradient
        self = SlideAttributes(id: id, classes: classes, keyValues: updatedKeyValues)
    }
}

// MARK: - Core Graphics Types (for cross-platform compatibility)

#if !canImport(CoreGraphics)
public struct CGSize {
    public let width: Double
    public let height: Double
    
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}
#endif
