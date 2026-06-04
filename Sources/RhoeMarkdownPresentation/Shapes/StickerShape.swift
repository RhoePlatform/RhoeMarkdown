//
//  StickerShape.swift
//  RhoeMarkdownKit
//
//  Sticker shape for semantic labels (McKinsey-style and more)
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// Sticker shape renderer
public struct StickerShapeRenderer {
    
    /// Sticker style variants
    public enum StickerStyle: String {
        case mckinsey = "mckinsey"        // Thin lines top/bottom, all caps
        case badge = "badge"               // Rounded corners, colored bg
        case ribbon = "ribbon"             // Ribbon ends
        case stamp = "stamp"               // Rotated, rough edges
        case label = "label"               // Simple label
        case pill = "pill"                 // Pill shape
        case flag = "flag"                 // Flag shape
        case corner = "corner"             // Corner ribbon
    }
    
    /// Render sticker to HTML
    public static func renderToHTML(
        content: [Block],
        attributes: SlideAttributes?,
        style: StickerStyle = .mckinsey
    ) -> String {
        // Extract text content
        let text = extractText(from: content)
        guard !text.isEmpty else {
            return "<div class=\"rhoemd-sticker-empty\">No content</div>"
        }
        
        // Determine style from attributes
        let stickerStyle = determineStyle(from: attributes) ?? style
        
        switch stickerStyle {
        case .mckinsey:
            return renderMcKinseySticker(text, attributes: attributes)
        case .badge:
            return renderBadgeSticker(text, attributes: attributes)
        case .ribbon:
            return renderRibbonSticker(text, attributes: attributes)
        case .stamp:
            return renderStampSticker(text, attributes: attributes)
        case .label:
            return renderLabelSticker(text, attributes: attributes)
        case .pill:
            return renderPillSticker(text, attributes: attributes)
        case .flag:
            return renderFlagSticker(text, attributes: attributes)
        case .corner:
            return renderCornerSticker(text, attributes: attributes)
        }
    }
    
    /// Extract text from blocks
    private static func extractText(from blocks: [Block]) -> String {
        var textParts: [String] = []
        
        for block in blocks {
            switch block {
            case .paragraph(let inlines, _):
                for inline in inlines {
                    if case .text(let text) = inline {
                        textParts.append(text)
                    }
                }
            default:
                break
            }
        }
        
        return textParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Determine style from attributes
    private static func determineStyle(from attributes: SlideAttributes?) -> StickerStyle? {
        guard let attrs = attributes else { return nil }
        
        // Check for style attribute
        if let rawStyle = attrs.style,
           let style = StickerStyle(rawValue: rawStyle) {
            return style
        }
        
        // Check for class-based styles
        for className in attrs.classes {
            if let style = StickerStyle(rawValue: className) {
                return style
            }
        }
        
        return nil
    }
    
    /// Render McKinsey-style sticker
    private static func renderMcKinseySticker(_ text: String, attributes: SlideAttributes?) -> String {
        let upperText = text.uppercased()
        var styles = [
            "display: inline-block",
            "padding: 0.5em 1em",
            "font-family: -apple-system, 'Helvetica Neue', Arial, sans-serif",
            "font-size: 0.875em",
            "font-weight: 500",
            "letter-spacing: 0.1em",
            "text-transform: uppercase",
            "border-top: 1px solid black",
            "border-bottom: 1px solid black",
            "position: relative"
        ]
        
        // Apply custom attributes
        if let attrs = attributes {
            let resolved = attrs.resolvedStyles()
            if let color = resolved["color"] {
                styles.append("color: \(color)")
                styles[7] = "border-top: 1px solid \(color)"
                styles[8] = "border-bottom: 1px solid \(color)"
            }
            if let bg = resolved["background-color"] {
                styles.append("background-color: \(bg)")
            }
        }
        
        let styleStr = styles.joined(separator: "; ")
        return "<span class=\"rhoemd-sticker-mckinsey\" style=\"\(styleStr)\">\(upperText)</span>"
    }
    
    /// Render badge-style sticker
    private static func renderBadgeSticker(_ text: String, attributes: SlideAttributes?) -> String {
        var styles = [
            "display: inline-block",
            "padding: 0.25em 0.75em",
            "font-size: 0.875em",
            "font-weight: 600",
            "border-radius: 9999px",
            "background-color: #3b82f6",
            "color: white"
        ]
        
        // Apply custom attributes
        applyAttributes(&styles, from: attributes)
        
        let styleStr = styles.joined(separator: "; ")
        return "<span class=\"rhoemd-sticker-badge\" style=\"\(styleStr)\">\(text)</span>"
    }
    
    /// Render ribbon-style sticker
    private static func renderRibbonSticker(_ text: String, attributes: SlideAttributes?) -> String {
        var containerStyles = [
            "display: inline-block",
            "position: relative",
            "padding: 0.5em 2em",
            "background-color: #dc2626",
            "color: white",
            "font-weight: bold"
        ]
        
        applyAttributes(&containerStyles, from: attributes)
        
        return """
        <span class="rhoemd-sticker-ribbon" style="\(containerStyles.joined(separator: "; "))">
            <span class="ribbon-content">\(text)</span>
            <span class="ribbon-tail-left"></span>
            <span class="ribbon-tail-right"></span>
        </span>
        """
    }
    
    /// Render stamp-style sticker
    private static func renderStampSticker(_ text: String, attributes: SlideAttributes?) -> String {
        let upperText = text.uppercased()
        var styles = [
            "display: inline-block",
            "padding: 0.5em 1em",
            "border: 3px solid #ef4444",
            "color: #ef4444",
            "font-weight: bold",
            "font-family: 'Courier New', monospace",
            "transform: rotate(-5deg)",
            "text-transform: uppercase"
        ]
        
        applyAttributes(&styles, from: attributes)
        
        let styleStr = styles.joined(separator: "; ")
        return "<span class=\"rhoemd-sticker-stamp\" style=\"\(styleStr)\">\(upperText)</span>"
    }
    
    /// Render simple label sticker
    private static func renderLabelSticker(_ text: String, attributes: SlideAttributes?) -> String {
        var styles = [
            "display: inline-block",
            "padding: 0.25em 0.5em",
            "background-color: #f3f4f6",
            "color: #374151",
            "font-size: 0.875em",
            "border-radius: 0.25em"
        ]
        
        applyAttributes(&styles, from: attributes)
        
        let styleStr = styles.joined(separator: "; ")
        return "<span class=\"rhoemd-sticker-label\" style=\"\(styleStr)\">\(text)</span>"
    }
    
    /// Render pill-style sticker
    private static func renderPillSticker(_ text: String, attributes: SlideAttributes?) -> String {
        var styles = [
            "display: inline-block",
            "padding: 0.375em 1em",
            "background-color: #8b5cf6",
            "color: white",
            "font-weight: 500",
            "border-radius: 9999px",
            "font-size: 0.875em"
        ]
        
        applyAttributes(&styles, from: attributes)
        
        let styleStr = styles.joined(separator: "; ")
        return "<span class=\"rhoemd-sticker-pill\" style=\"\(styleStr)\">\(text)</span>"
    }
    
    /// Render flag-style sticker
    private static func renderFlagSticker(_ text: String, attributes: SlideAttributes?) -> String {
        var styles = [
            "display: inline-block",
            "padding: 0.5em 1.5em 0.5em 1em",
            "background-color: #059669",
            "color: white",
            "font-weight: 600",
            "position: relative",
            "margin-right: 1em"
        ]
        
        applyAttributes(&styles, from: attributes)
        
        return """
        <span class="rhoemd-sticker-flag" style="\(styles.joined(separator: "; "))">
            \(text)
            <span class="flag-tail"></span>
        </span>
        """
    }
    
    /// Render corner ribbon sticker
    private static func renderCornerSticker(_ text: String, attributes: SlideAttributes?) -> String {
        var styles = [
            "position: absolute",
            "top: 2em",
            "right: -2em",
            "padding: 0.5em 3em",
            "background-color: #dc2626",
            "color: white",
            "font-weight: bold",
            "transform: rotate(45deg)",
            "text-align: center",
            "box-shadow: 0 2px 4px rgba(0,0,0,0.1)"
        ]
        
        applyAttributes(&styles, from: attributes)
        
        let styleStr = styles.joined(separator: "; ")
        return "<span class=\"rhoemd-sticker-corner\" style=\"\(styleStr)\">\(text)</span>"
    }
    
    /// Apply attributes to styles array
    private static func applyAttributes(_ styles: inout [String], from attributes: SlideAttributes?) {
        guard let attrs = attributes else { return }
        
        let resolved = attrs.resolvedStyles()
        
        // Update colors
        if let color = resolved["color"] {
            if let colorIndex = styles.firstIndex(where: { $0.starts(with: "color:") }) {
                styles[colorIndex] = "color: \(color)"
            } else {
                styles.append("color: \(color)")
            }
        }
        
        if let bg = resolved["background-color"] {
            if let bgIndex = styles.firstIndex(where: { $0.starts(with: "background-color:") }) {
                styles[bgIndex] = "background-color: \(bg)"
            } else {
                styles.append("background-color: \(bg)")
            }
        }
        
        // Apply other styles
        for (key, value) in resolved {
            if !["color", "background-color", "@import"].contains(key) {
                styles.append("\(key): \(value)")
            }
        }
    }
    
    /// Generate CSS for sticker styles
    public static func generateCSS() -> String {
        return """
        /* McKinsey style */
        .rhoemd-sticker-mckinsey {
            white-space: nowrap;
        }
        
        /* Ribbon style */
        .rhoemd-sticker-ribbon {
            margin: 0 1em;
        }
        
        .rhoemd-sticker-ribbon .ribbon-tail-left,
        .rhoemd-sticker-ribbon .ribbon-tail-right {
            position: absolute;
            top: 0;
            width: 0;
            height: 0;
            border-style: solid;
            border-color: transparent;
        }
        
        .rhoemd-sticker-ribbon .ribbon-tail-left {
            left: -1em;
            border-width: 1.5em 1em 1.5em 0;
            border-right-color: inherit;
        }
        
        .rhoemd-sticker-ribbon .ribbon-tail-right {
            right: -1em;
            border-width: 1.5em 0 1.5em 1em;
            border-left-color: inherit;
        }
        
        /* Flag style */
        .rhoemd-sticker-flag .flag-tail {
            position: absolute;
            right: -1em;
            top: 0;
            width: 0;
            height: 0;
            border-style: solid;
            border-width: 1.5em 0 1.5em 1em;
            border-color: transparent transparent transparent;
            border-left-color: inherit;
        }
        
        /* Stamp style */
        .rhoemd-sticker-stamp {
            display: inline-block !important;
        }
        
        /* All stickers */
        [class^="rhoemd-sticker-"] {
            line-height: 1.5;
            user-select: none;
        }
        """
    }
}

// MARK: - Shape Extension

extension ShapeContent {
    /// Check if this is a sticker shape
    public var isStickerShape: Bool {
        if case .basic(.sticker) = shape {
            return true
        }
        return false
    }
}
