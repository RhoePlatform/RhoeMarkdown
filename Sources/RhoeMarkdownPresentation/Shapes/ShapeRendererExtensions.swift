//
//  ShapeRendererExtensions.swift
//  RhoeMarkdownKit
//
//  Additional shape path implementations for the extended shape set
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

extension ShapeRenderer {
    
    // MARK: - Communication & Flow Shapes
    
    static func speechBubblePath(size: ShapeSize) -> String {
        let bubbleHeight = size.height * 0.75
        let cornerRadius = min(size.width, bubbleHeight) * 0.1
        
        return """
        M \(cornerRadius),0
        L \(size.width - cornerRadius),0
        Q \(size.width),0 \(size.width),\(cornerRadius)
        L \(size.width),\(bubbleHeight - cornerRadius)
        Q \(size.width),\(bubbleHeight) \(size.width - cornerRadius),\(bubbleHeight)
        L \(size.width * 0.3),\(bubbleHeight)
        L \(size.width * 0.2),\(size.height)
        L \(size.width * 0.25),\(bubbleHeight)
        L \(cornerRadius),\(bubbleHeight)
        Q 0,\(bubbleHeight) 0,\(bubbleHeight - cornerRadius)
        L 0,\(cornerRadius)
        Q 0,0 \(cornerRadius),0
        Z
        """
    }
    
    static func thoughtBubblePath(size: ShapeSize) -> String {
        // Main cloud bubble
        let mainRadius = min(size.width, size.height) * 0.35
        let cx = size.width / 2
        let cy = size.height * 0.4
        
        // Three small circles leading to main bubble
        let circles = [
            (x: cx - mainRadius * 0.6, y: cy + mainRadius * 1.3, r: mainRadius * 0.15),
            (x: cx - mainRadius * 0.4, y: cy + mainRadius * 1.0, r: mainRadius * 0.2),
            (x: cx - mainRadius * 0.2, y: cy + mainRadius * 0.7, r: mainRadius * 0.25)
        ]
        
        var path = ""
        
        // Draw the small circles
        for circle in circles {
            path += "M \(circle.x - circle.r),\(circle.y) "
            path += "A \(circle.r),\(circle.r) 0 1,0 \(circle.x + circle.r),\(circle.y) "
            path += "A \(circle.r),\(circle.r) 0 1,0 \(circle.x - circle.r),\(circle.y) "
        }
        
        // Main thought bubble (cloud-like)
        path += cloudPath(size: ShapeSize(width: size.width, height: size.height * 0.7))
        
        return path
    }
    
    static func bannerPath(size: ShapeSize) -> String {
        let ribbonHeight = size.height * 0.7
        let notchDepth = size.width * 0.1
        
        return """
        M 0,0
        L \(size.width),0
        L \(size.width),\(ribbonHeight)
        L \(size.width - notchDepth),\(size.height)
        L \(size.width / 2),\(ribbonHeight + (size.height - ribbonHeight) * 0.5)
        L \(notchDepth),\(size.height)
        L 0,\(ribbonHeight)
        Z
        """
    }
    
    static func flagPath(size: ShapeSize) -> String {
        let poleWidth = size.width * 0.05
        let flagWidth = size.width * 0.9
        let waveAmplitude = size.height * 0.1
        
        return """
        M 0,0
        L \(poleWidth),0
        L \(poleWidth),\(size.height)
        L 0,\(size.height)
        Z
        M \(poleWidth),\(size.height * 0.1)
        L \(flagWidth),\(size.height * 0.15)
        Q \(flagWidth + waveAmplitude),\(size.height * 0.35) \(flagWidth),\(size.height * 0.55)
        L \(poleWidth),\(size.height * 0.6)
        Z
        """
    }
    
    static func tagPath(size: ShapeSize) -> String {
        let tagWidth = size.width * 0.8
        let holeRadius = min(size.width, size.height) * 0.05
        let cornerCut = size.height * 0.3
        
        return """
        M \(holeRadius * 2),0
        L \(tagWidth),0
        L \(size.width),\(cornerCut)
        L \(size.width),\(size.height)
        L \(holeRadius * 2),\(size.height)
        L \(holeRadius * 2),\(size.height - cornerCut)
        L 0,\(size.height / 2)
        L \(holeRadius * 2),\(cornerCut)
        Z
        M \(holeRadius * 3),\(size.height / 2)
        A \(holeRadius),\(holeRadius) 0 1,0 \(holeRadius * 5),\(size.height / 2)
        A \(holeRadius),\(holeRadius) 0 1,0 \(holeRadius * 3),\(size.height / 2)
        """
    }
    
    // MARK: - Advanced Polygons
    
    static func squarePath(size: ShapeSize) -> String {
        let side = min(size.width, size.height)
        let x = (size.width - side) / 2
        let y = (size.height - side) / 2
        
        return "M \(x),\(y) L \(x + side),\(y) L \(x + side),\(y + side) L \(x),\(y + side) Z"
    }
    
    static func parallelogramPath(size: ShapeSize) -> String {
        let skew = size.width * 0.2
        
        return """
        M \(skew),0
        L \(size.width),0
        L \(size.width - skew),\(size.height)
        L 0,\(size.height)
        Z
        """
    }
    
    static func trapezoidPath(size: ShapeSize) -> String {
        let topInset = size.width * 0.2
        
        return """
        M \(topInset),0
        L \(size.width - topInset),0
        L \(size.width),\(size.height)
        L 0,\(size.height)
        Z
        """
    }
    
    static func rhombusPath(size: ShapeSize) -> String {
        let cx = size.width / 2
        let cy = size.height / 2
        
        return """
        M \(cx),0
        L \(size.width),\(cy)
        L \(cx),\(size.height)
        L 0,\(cy)
        Z
        """
    }
    
    // MARK: - Business & Diagram Shapes
    
    static func cylinderPath(size: ShapeSize) -> String {
        let ellipseHeight = size.height * 0.15
        let rx = size.width / 2
        let ry = ellipseHeight / 2
        
        return """
        M 0,\(ry)
        L 0,\(size.height - ry)
        A \(rx),\(ry) 0 0,0 \(size.width),\(size.height - ry)
        L \(size.width),\(ry)
        A \(rx),\(ry) 0 0,1 0,\(ry)
        Z
        M 0,\(ry)
        A \(rx),\(ry) 0 0,0 \(size.width),\(ry)
        """
    }
    
    static func cubePath(size: ShapeSize) -> String {
        let depth = min(size.width, size.height) * 0.3
        let frontSize = min(size.width, size.height) * 0.7
        
        return """
        M 0,\(depth)
        L \(frontSize),\(depth)
        L \(frontSize),\(depth + frontSize)
        L 0,\(depth + frontSize)
        Z
        M 0,\(depth)
        L \(depth),0
        L \(frontSize + depth),0
        L \(frontSize),\(depth)
        M \(frontSize + depth),0
        L \(frontSize + depth),\(frontSize)
        L \(frontSize),\(depth + frontSize)
        M \(frontSize + depth),\(frontSize)
        L \(depth),\(frontSize + depth)
        L 0,\(depth + frontSize)
        """
    }
    
    static func pyramidPath(size: ShapeSize) -> String {
        let cx = size.width / 2
        let baseY = size.height * 0.8
        let baseWidth = size.width * 0.8
        let baseOffset = (size.width - baseWidth) / 2
        
        return """
        M \(cx),0
        L \(baseOffset + baseWidth),\(baseY)
        L \(baseOffset + baseWidth * 0.7),\(size.height)
        L \(baseOffset),\(size.height)
        L \(baseOffset),\(baseY)
        Z
        M \(cx),0
        L \(baseOffset),\(baseY)
        M \(cx),0
        L \(baseOffset + baseWidth * 0.7),\(size.height)
        """
    }
    
    static func funnelPath(size: ShapeSize) -> String {
        let topWidth = size.width
        let bottomWidth = size.width * 0.3
        let neckHeight = size.height * 0.3
        
        return """
        M 0,0
        L \(topWidth),0
        L \((topWidth + bottomWidth) / 2),\(size.height - neckHeight)
        L \((topWidth + bottomWidth) / 2),\(size.height)
        L \((topWidth - bottomWidth) / 2),\(size.height)
        L \((topWidth - bottomWidth) / 2),\(size.height - neckHeight)
        Z
        """
    }
    
    static func processPath(size: ShapeSize) -> String {
        let sideWidth = size.width * 0.15
        
        return """
        M 0,0
        L \(sideWidth),0
        L \(sideWidth),\(size.height)
        L 0,\(size.height)
        Z
        M \(sideWidth),0
        L \(size.width - sideWidth),0
        L \(size.width - sideWidth),\(size.height)
        L \(sideWidth),\(size.height)
        M \(size.width - sideWidth),0
        L \(size.width),0
        L \(size.width),\(size.height)
        L \(size.width - sideWidth),\(size.height)
        """
    }
    
    static func documentPath(size: ShapeSize) -> String {
        let foldSize = min(size.width, size.height) * 0.2
        
        return """
        M 0,0
        L \(size.width - foldSize),0
        L \(size.width),\(foldSize)
        L \(size.width),\(size.height)
        L 0,\(size.height)
        Z
        M \(size.width - foldSize),0
        L \(size.width - foldSize),\(foldSize)
        L \(size.width),\(foldSize)
        """
    }
    
    static func folderPath(size: ShapeSize) -> String {
        let tabWidth = size.width * 0.3
        let tabHeight = size.height * 0.15
        
        return """
        M 0,\(tabHeight)
        L 0,\(size.height)
        L \(size.width),\(size.height)
        L \(size.width),\(tabHeight)
        L \(tabWidth),\(tabHeight)
        L \(tabWidth),0
        L 0,0
        Z
        """
    }
    
    // MARK: - Modern UI Shapes
    
    static func pillPath(size: ShapeSize) -> String {
        let radius = size.height / 2
        
        return """
        M \(radius),0
        L \(size.width - radius),0
        A \(radius),\(radius) 0 0,1 \(size.width - radius),\(size.height)
        L \(radius),\(size.height)
        A \(radius),\(radius) 0 0,1 \(radius),0
        Z
        """
    }
    
    static func badgePath(size: ShapeSize) -> String {
        let cornerRadius = min(size.width, size.height) * 0.3
        let notchSize = size.height * 0.15
        
        return """
        M \(cornerRadius),0
        L \(size.width - cornerRadius),0
        Q \(size.width),0 \(size.width),\(cornerRadius)
        L \(size.width),\(size.height - cornerRadius)
        Q \(size.width),\(size.height) \(size.width - cornerRadius),\(size.height)
        L \(size.width / 2 + notchSize),\(size.height)
        L \(size.width / 2),\(size.height - notchSize)
        L \(size.width / 2 - notchSize),\(size.height)
        L \(cornerRadius),\(size.height)
        Q 0,\(size.height) 0,\(size.height - cornerRadius)
        L 0,\(cornerRadius)
        Q 0,0 \(cornerRadius),0
        Z
        """
    }
    
    static func tooltipPath(size: ShapeSize) -> String {
        let bubbleHeight = size.height * 0.8
        let cornerRadius = min(size.width, bubbleHeight) * 0.1
        let pointerWidth = size.width * 0.2
        let pointerX = size.width * 0.4
        
        return """
        M \(cornerRadius),0
        L \(size.width - cornerRadius),0
        Q \(size.width),0 \(size.width),\(cornerRadius)
        L \(size.width),\(bubbleHeight - cornerRadius)
        Q \(size.width),\(bubbleHeight) \(size.width - cornerRadius),\(bubbleHeight)
        L \(pointerX + pointerWidth),\(bubbleHeight)
        L \(pointerX + pointerWidth/2),\(size.height)
        L \(pointerX),\(bubbleHeight)
        L \(cornerRadius),\(bubbleHeight)
        Q 0,\(bubbleHeight) 0,\(bubbleHeight - cornerRadius)
        L 0,\(cornerRadius)
        Q 0,0 \(cornerRadius),0
        Z
        """
    }
    
    static func tabPath(size: ShapeSize) -> String {
        let cornerRadius = min(size.width, size.height) * 0.15
        
        return """
        M 0,\(size.height)
        L 0,\(cornerRadius)
        Q 0,0 \(cornerRadius),0
        L \(size.width - cornerRadius),0
        Q \(size.width),0 \(size.width),\(cornerRadius)
        L \(size.width),\(size.height)
        Z
        """
    }
    
    static func cardPath(size: ShapeSize) -> String {
        let cornerRadius = min(size.width, size.height) * 0.05
        
        return roundedRectPath(size: size, cornerRadius: cornerRadius)
    }
    
    // MARK: - Nature & Organic Shapes
    
    static func flowerPath(size: ShapeSize) -> String {
        let cx = size.width / 2
        let cy = size.height / 2
        let petalRadius = min(size.width, size.height) * 0.2
        let centerRadius = petalRadius * 0.6
        
        var path = ""
        
        // Draw 6 petals
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3
            let px = cx + cos(angle) * petalRadius * 1.5
            let py = cy + sin(angle) * petalRadius * 1.5
            
            path += "M \(cx),\(cy) "
            path += "Q \(px - petalRadius * 0.5),\(py - petalRadius * 0.5) \(px),\(py) "
            path += "A \(petalRadius),\(petalRadius) 0 0,1 \(px + petalRadius),\(py) "
            path += "Q \(px + petalRadius * 0.5),\(py + petalRadius * 0.5) \(cx),\(cy) "
        }
        
        // Center circle
        path += "M \(cx - centerRadius),\(cy) "
        path += "A \(centerRadius),\(centerRadius) 0 1,0 \(cx + centerRadius),\(cy) "
        path += "A \(centerRadius),\(centerRadius) 0 1,0 \(cx - centerRadius),\(cy) "
        
        return path
    }
    
    static func leafPath(size: ShapeSize) -> String {
        let cx = size.width / 2
        let stemHeight = size.height * 0.1
        
        return """
        M \(cx),\(size.height)
        L \(cx),\(size.height - stemHeight)
        Q 0,\(size.height * 0.7) 0,\(size.height * 0.3)
        Q 0,0 \(cx),0
        Q \(size.width),0 \(size.width),\(size.height * 0.3)
        Q \(size.width),\(size.height * 0.7) \(cx),\(size.height - stemHeight)
        M \(cx),\(size.height * 0.2)
        L \(cx),\(size.height * 0.8)
        """
    }
    
    static func dropPath(size: ShapeSize) -> String {
        let cx = size.width / 2
        let topRadius = size.width * 0.4
        let bottomPoint = size.height * 0.9
        
        return """
        M \(cx),\(bottomPoint)
        Q 0,\(size.height * 0.5) 0,\(topRadius)
        A \(topRadius),\(topRadius) 0 1,1 \(size.width),\(topRadius)
        Q \(size.width),\(size.height * 0.5) \(cx),\(bottomPoint)
        Z
        """
    }
    
    // MARK: - Additional Special Shapes
    
    static func gearPath(size: ShapeSize) -> String {
        let cx = size.width / 2
        let cy = size.height / 2
        let outerRadius = min(size.width, size.height) / 2
        let innerRadius = outerRadius * 0.6
        let teethCount = 8
        
        var path = ""
        
        for i in 0..<teethCount {
            let angle1 = Double(i) * 2 * .pi / Double(teethCount)
            let angle2 = Double(i + 1) * 2 * .pi / Double(teethCount)
            let midAngle = (angle1 + angle2) / 2
            
            // Inner circle arc
            let x1 = cx + cos(angle1) * innerRadius
            let y1 = cy + sin(angle1) * innerRadius
            
            // Tooth
            let tx1 = cx + cos(angle1 + 0.1) * outerRadius
            let ty1 = cy + sin(angle1 + 0.1) * outerRadius
            let tx2 = cx + cos(midAngle - 0.1) * outerRadius
            let ty2 = cy + sin(midAngle - 0.1) * outerRadius
            
            if i == 0 {
                path += "M \(x1),\(y1) "
            }
            
            path += "L \(tx1),\(ty1) "
            path += "L \(tx2),\(ty2) "
            
            let x2 = cx + cos(angle2) * innerRadius
            let y2 = cy + sin(angle2) * innerRadius
            path += "L \(x2),\(y2) "
        }
        
        path += "Z"
        
        // Center hole
        let holeRadius = innerRadius * 0.4
        path += "M \(cx - holeRadius),\(cy) "
        path += "A \(holeRadius),\(holeRadius) 0 1,0 \(cx + holeRadius),\(cy) "
        path += "A \(holeRadius),\(holeRadius) 0 1,0 \(cx - holeRadius),\(cy) "
        
        return path
    }
    
    static func lightningPath(size: ShapeSize) -> String {
        return """
        M \(size.width * 0.6),0
        L \(size.width * 0.2),\(size.height * 0.4)
        L \(size.width * 0.4),\(size.height * 0.4)
        L \(size.width * 0.3),\(size.height)
        L \(size.width * 0.7),\(size.height * 0.5)
        L \(size.width * 0.5),\(size.height * 0.5)
        Z
        """
    }
    
    static func moonPath(size: ShapeSize) -> String {
        let radius = min(size.width, size.height) / 2
        let cx = size.width / 2
        let cy = size.height / 2
        let innerRadius = radius * 0.7
        let offset = radius * 0.3
        
        return """
        M \(cx - radius),\(cy)
        A \(radius),\(radius) 0 1,0 \(cx + radius),\(cy)
        A \(radius),\(radius) 0 1,0 \(cx - radius),\(cy)
        M \(cx - radius + offset),\(cy)
        A \(innerRadius),\(innerRadius) 0 1,1 \(cx - radius + offset),\(cy)
        Z
        """
    }
    
    static func sunPath(size: ShapeSize) -> String {
        let cx = size.width / 2
        let cy = size.height / 2
        let centerRadius = min(size.width, size.height) * 0.3
        let rayLength = min(size.width, size.height) * 0.15
        let rayCount = 12
        
        var path = ""
        
        // Sun rays
        for i in 0..<rayCount {
            let angle = Double(i) * 2 * .pi / Double(rayCount)
            let innerRadius = centerRadius + rayLength * 0.2
            let outerRadius = centerRadius + rayLength
            
            let x1 = cx + cos(angle) * innerRadius
            let y1 = cy + sin(angle) * innerRadius
            let x2 = cx + cos(angle) * outerRadius
            let y2 = cy + sin(angle) * outerRadius
            
            path += "M \(x1),\(y1) L \(x2),\(y2) "
        }
        
        // Center circle
        path += "M \(cx - centerRadius),\(cy) "
        path += "A \(centerRadius),\(centerRadius) 0 1,0 \(cx + centerRadius),\(cy) "
        path += "A \(centerRadius),\(centerRadius) 0 1,0 \(cx - centerRadius),\(cy) "
        
        return path
    }
}

// Helper function for rounded rectangles with custom radius
private func roundedRectPath(size: ShapeSize, cornerRadius: Double) -> String {
    let r = cornerRadius
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
