//
//  IconManager.swift
//  RhoeMarkdownKit
//
//  Icon management system for loading and rendering icon sets
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// Manages icon loading and SVG generation
public struct IconManager: Sendable {
    
    // MARK: - Icon Loading
    
    /// Get SVG content for an icon
    public static func getSVGContent(
        iconSet: IconSet?,
        iconName: String,
        size: ShapeSize,
        style: ShapeStyler.ShapeStyle,
        presentationAttributes: RhoeMarkdownKit.Attributes?
    ) -> String? {
        // Determine which icon set to use
        let actualIconSet = iconSet ?? getDefaultIconSet(from: presentationAttributes)
        
        // Get the icon SVG
        guard let iconSVG = loadIcon(iconSet: actualIconSet, name: iconName) else {
            return nil
        }
        
        // Apply styling and sizing
        return styleIcon(
            svg: iconSVG,
            size: size,
            style: style,
            iconSet: actualIconSet
        )
    }
    
    /// Load an icon's SVG content
    private static func loadIcon(iconSet: IconSet, name: String) -> String? {
        // For now, return sample icons. In production, this would load from bundled resources
        switch (iconSet, name) {
        case (.lucide, "heart"):
            return """
            <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" 
                  fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            """
            
        case (.lucide, "home"):
            return """
            <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" 
                  fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            <polyline points="9 22 9 12 15 12 15 22" 
                      fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            """
            
        case (.lucide, "user"):
            return """
            <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" 
                  fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            <circle cx="12" cy="7" r="4" 
                    fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            """
            
        case (.lucide, "settings"):
            return """
            <circle cx="12" cy="12" r="3" fill="none" stroke="currentColor" stroke-width="2"/>
            <path d="M12 1v6m0 6v6m-5.196-13.196l4.243 4.243m1.906 1.906l4.243 4.243M1 12h6m6 0h6m-13.196 5.196l4.243-4.243m1.906-1.906l4.243-4.243" 
                  fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            """
            
        case (.lucide, "arrow-right"):
            return """
            <line x1="5" y1="12" x2="19" y2="12" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            <polyline points="12 5 19 12 12 19" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            """
            
        case (.fluent, "heart"):
            return """
            <path d="M12.82 5.58L12 6.401l-.824-.82a4.5 4.5 0 0 0-6.351 6.354l.114.117 7.06 7.06 7.06-7.06a4.5 4.5 0 0 0-6.24-6.472z" 
                  fill="currentColor"/>
            """
            
        case (.fluent, "home"):
            return """
            <path d="M10.55 2.532a2.25 2.25 0 0 1 2.9 0l6.75 5.692c.507.428.8 1.057.8 1.72v7.558a1.498 1.498 0 0 1-1.5 1.498h-3a1.5 1.5 0 0 1-1.5-1.5V14a.5.5 0 0 0-.5-.5h-5a.5.5 0 0 0-.5.5v3.5a1.5 1.5 0 0 1-1.5 1.5h-3A1.5 1.5 0 0 1 3 17.502V9.944c0-.663.293-1.292.8-1.72l6.75-5.692z" 
                  fill="currentColor"/>
            """
            
        case (.fluent, "person"):
            return """
            <path d="M17.754 13.999a2.249 2.249 0 0 1 2.248 2.102l.005.15v.918a3.572 3.572 0 0 1-.068.779l-.011.054-.014.054c-.49 1.705-2.056 2.866-4.405 3.368a15.155 15.155 0 0 1-3.002.324L12 21.75c-1.109 0-2.167-.113-3.142-.317l-.365-.081c-2.276-.523-3.79-1.649-4.27-3.28l-.023-.085-.017-.067a2.06 2.06 0 0 1-.031-.17l-.01-.069-.012-.125L4.003 16.251a2.249 2.249 0 0 1 2.102-2.246l.149-.005h11.5zM12 2.004a5 5 0 1 1 0 10 5 5 0 0 1 0-10z" 
                  fill="currentColor"/>
            """
            
        // Heroicons Outline (24x24)
        case (.heroicons, "home"):
            return """
            <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25" 
                  fill="none" stroke="currentColor" stroke-width="1.5"/>
            """
            
        case (.heroicons, "heart"):
            return """
            <path stroke-linecap="round" stroke-linejoin="round" d="M21 8.5c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 4 3 6.015 3 8.5c0 .564.12 1.099.321 1.59l.003.006c.026.063.057.125.089.186.079.152.17.298.267.441.008.011.015.023.023.034.531.899 1.287 1.751 2.17 2.57a36.155 36.155 0 003.352 2.684c.536.398 1.092.806 1.672 1.224.314.227.638.455.971.685.213.148.429.296.649.445.11.074.222.149.336.223.055.037.112.074.169.111.274.183.56.354.836.507.025.013.048.029.073.042.012.007.025.012.037.019.014.007.028.015.042.022.005.003.011.005.016.008.006.003.011.006.017.009a.993.993 0 00.862 0c.006-.003.011-.006.017-.009.005-.003.011-.005.016-.008.014-.007.028-.015.042-.022.012-.007.025-.012.037-.019.025-.013.048-.029.073-.042.276-.153.562-.324.836-.507.057-.037.114-.074.169-.111.114-.074.226-.149.336-.223.22-.149.436-.297.649-.445.333-.23.657-.458.971-.685.58-.418 1.136-.826 1.672-1.224a36.155 36.155 0 003.352-2.684c.883-.819 1.639-1.671 2.17-2.57.008-.011.015-.023.023-.034.097-.143.188-.289.267-.441.032-.061.063-.123.089-.186l.003-.006c.201-.491.321-1.026.321-1.59z" 
                  fill="none" stroke="currentColor" stroke-width="1.5"/>
            """
            
        case (.heroicons, "user"):
            return """
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" 
                  fill="none" stroke="currentColor" stroke-width="1.5"/>
            """
            
        case (.heroicons, "cog"):
            return """
            <path stroke-linecap="round" stroke-linejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z" 
                  fill="none" stroke="currentColor" stroke-width="1.5"/>
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" 
                  fill="none" stroke="currentColor" stroke-width="1.5"/>
            """
            
        case (.heroicons, "arrow-left"):
            return """
            <path stroke-linecap="round" stroke-linejoin="round" d="M19 12H5m0 0l7 7m-7-7l7-7" 
                  fill="none" stroke="currentColor" stroke-width="1.5"/>
            """
            
        case (.heroicons, "arrow-right"):
            return """
            <path stroke-linecap="round" stroke-linejoin="round" d="M5 12h14m0 0l-7-7m7 7l-7 7" 
                  fill="none" stroke="currentColor" stroke-width="1.5"/>
            """
            
        case (.heroicons, "sparkles"):
            return """
            <path stroke-linecap="round" stroke-linejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456zM16.894 20.567L16.5 21.75l-.394-1.183a2.25 2.25 0 00-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 001.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 001.423 1.423l1.183.394-1.183.394a2.25 2.25 0 00-1.423 1.423z" 
                  fill="none" stroke="currentColor" stroke-width="1.5"/>
            """
            
        // Heroicons Solid (20x20) - different viewBox!
        case (.heroiconsSolid, "home"):
            return """
            <path fill-rule="evenodd" d="M9.293 2.293a1 1 0 011.414 0l7 7A1 1 0 0117 11h-1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-3a1 1 0 00-1-1H9a1 1 0 00-1 1v3a1 1 0 01-1 1H5a1 1 0 01-1-1v-6H3a1 1 0 01-.707-1.707l7-7z" 
                  clip-rule="evenodd" fill="currentColor"/>
            """
            
        case (.heroiconsSolid, "heart"):
            return """
            <path d="M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z" 
                  fill="currentColor"/>
            """
            
        case (.heroiconsSolid, "user"):
            return """
            <path fill-rule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" 
                  clip-rule="evenodd" fill="currentColor"/>
            """
            
        case (.heroiconsSolid, "cog"):
            return """
            <path fill-rule="evenodd" d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z" 
                  clip-rule="evenodd" fill="currentColor"/>
            """
            
        case (.heroiconsSolid, "sparkles"):
            return """
            <path fill-rule="evenodd" d="M9 4.5a.75.75 0 01.721.544l.813 2.846a3.75 3.75 0 002.576 2.576l2.846.813a.75.75 0 010 1.442l-2.846.813a3.75 3.75 0 00-2.576 2.576l-.813 2.846a.75.75 0 01-1.442 0l-.813-2.846a3.75 3.75 0 00-2.576-2.576l-2.846-.813a.75.75 0 010-1.442l2.846-.813A3.75 3.75 0 007.466 7.89l.813-2.846A.75.75 0 019 4.5zM18 1.5a.75.75 0 01.728.568l.258 1.036c.236.94.97 1.674 1.91 1.91l1.036.258a.75.75 0 010 1.456l-1.036.258c-.94.236-1.674.97-1.91 1.91l-.258 1.036a.75.75 0 01-1.456 0l-.258-1.036a2.625 2.625 0 00-1.91-1.91l-1.036-.258a.75.75 0 010-1.456l1.036-.258a2.625 2.625 0 001.91-1.91l.258-1.036A.75.75 0 0118 1.5zM16.5 15a.75.75 0 01.712.513l.394 1.183c.15.447.5.799.948.948l1.183.395a.75.75 0 010 1.422l-1.183.395c-.447.15-.799.5-.948.948l-.395 1.183a.75.75 0 01-1.422 0l-.395-1.183a1.5 1.5 0 00-.948-.948l-1.183-.395a.75.75 0 010-1.422l1.183-.395c.447-.15.799-.5.948-.948l.395-1.183A.75.75 0 0116.5 15z" 
                  clip-rule="evenodd" fill="currentColor"/>
            """
            
        default:
            // Return a generic icon placeholder
            return """
            <rect x="4" y="4" width="16" height="16" rx="2" 
                  fill="none" stroke="currentColor" stroke-width="2"/>
            <line x1="12" y1="8" x2="12" y2="16" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
            <circle cx="12" cy="12" r="1" fill="currentColor"/>
            """
        }
    }
    
    /// Apply styling to an icon SVG
    private static func styleIcon(
        svg: String,
        size: ShapeSize,
        style: ShapeStyler.ShapeStyle,
        iconSet: IconSet
    ) -> String {
        let viewBox = iconSet.viewBox
        let strokeWidth = iconSet.defaultStrokeWidth
        
        // Build the full SVG
        var result = """
        <svg width="\(size.width)" height="\(size.height)" viewBox="\(viewBox)" xmlns="http://www.w3.org/2000/svg">
        """
        
        // Apply fill and stroke colors
        var styledSVG = svg
        if let fill = style.fill {
            styledSVG = styledSVG.replacingOccurrences(of: "currentColor", with: fill)
        }
        if let stroke = style.stroke {
            styledSVG = styledSVG.replacingOccurrences(of: "stroke=\"currentColor\"", with: "stroke=\"\(stroke)\"")
        }
        if let customStrokeWidth = style.strokeWidth {
            styledSVG = styledSVG.replacingOccurrences(of: "stroke-width=\"\(strokeWidth)\"", with: "stroke-width=\"\(customStrokeWidth)\"")
        }
        
        // Apply gradient if specified
        if let gradient = style.gradient {
            let gradientId = "icon-gradient-\(UUID().uuidString)"
            result += ShapeStyler.generateGradientDef(gradient, id: gradientId) ?? ""
            styledSVG = styledSVG.replacingOccurrences(of: "fill=\"currentColor\"", with: "fill=\"url(#\(gradientId))\"")
        }
        
        // Apply shadow if specified
        if let shadow = style.shadow {
            let shadowId = "icon-shadow-\(UUID().uuidString)"
            result += ShapeStyler.generateShadowFilter(shadow, id: shadowId)
            result += "<g filter=\"url(#\(shadowId))\">"
        }
        
        result += styledSVG
        
        if style.shadow != nil {
            result += "</g>"
        }
        
        result += "</svg>"
        
        return result
    }
    
    /// Get default icon set from presentation attributes
    private static func getDefaultIconSet(from attributes: RhoeMarkdownKit.Attributes?) -> IconSet {
        if let iconSetString = attributes?.keyValues["icons"],
           let iconSet = IconSet(rawValue: iconSetString) {
            return iconSet
        }
        return .lucide // Default to Lucide
    }
}

// MARK: - Icon Set Properties

extension IconSet {
    /// The viewBox for this icon set
    public var viewBox: String {
        switch self {
        case .lucide: return "0 0 24 24"
        case .fluent: return "0 0 24 24"
        case .feather: return "0 0 24 24"
        case .heroicons: return "0 0 24 24"
        case .heroiconsSolid: return "0 0 20 20"  // Solid icons are 20x20
        }
    }
    
    /// Default stroke width for this icon set
    public var defaultStrokeWidth: Double {
        switch self {
        case .lucide: return 2
        case .fluent: return 1.5
        case .feather: return 2
        case .heroicons: return 1.5
        case .heroiconsSolid: return 0  // Solid icons don't use strokes
        }
    }
    
    /// Whether this icon set uses filled icons by default
    public var isFilledByDefault: Bool {
        switch self {
        case .lucide: return false
        case .fluent: return true
        case .feather: return false
        case .heroicons: return false
        case .heroiconsSolid: return true
        }
    }
}

// MARK: - Shadow Filter Generation

extension ShapeStyler {
    /// Generate SVG filter for shadow
    public static func generateShadowFilter(_ shadow: ShadowStyle, id: String) -> String {
        return """
        <defs>
            <filter id="\(id)" x="-50%" y="-50%" width="200%" height="200%">
                <feGaussianBlur in="SourceAlpha" stdDeviation="\(shadow.blur / 2)"/>
                <feOffset dx="\(shadow.dx)" dy="\(shadow.dy)" result="offsetblur"/>
                <feFlood flood-color="#000000" flood-opacity="\(shadow.opacity)"/>
                <feComposite in2="offsetblur" operator="in"/>
                <feMerge>
                    <feMergeNode/>
                    <feMergeNode in="SourceGraphic"/>
                </feMerge>
            </filter>
        </defs>
        """
    }
    
    /// Generate gradient definition
    public static func generateGradientDef(_ gradient: GradientStyle, id: String) -> String? {
        var def = ""
        
        switch gradient.type {
        case .linear(let angle):
            let radians = angle * .pi / 180
            let x2 = 50 + 50 * cos(radians)
            let y2 = 50 + 50 * sin(radians)
            
            def += """
            <defs>
                <linearGradient id="\(id)" x1="50%" y1="50%" x2="\(x2)%" y2="\(y2)%">
            """
            
        case .radial(let cx, let cy):
            def += """
            <defs>
                <radialGradient id="\(id)" cx="\(cx * 100)%" cy="\(cy * 100)%">
            """
        }
        
        for (offset, color) in gradient.stops {
            def += """
                    <stop offset="\(offset * 100)%" stop-color="\(color)"/>
            """
        }
        
        def += gradient.type.isLinear ? "</linearGradient></defs>" : "</radialGradient></defs>"
        
        return def
    }
}

extension ShapeStyler.GradientStyle.GradientType {
    var isLinear: Bool {
        if case .linear = self { return true }
        return false
    }
}