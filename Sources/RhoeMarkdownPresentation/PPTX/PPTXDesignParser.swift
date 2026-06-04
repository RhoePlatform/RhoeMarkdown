//
//  PPTXDesignParser.swift
//  RhoeMarkdownKit
//
//  Parse design configuration from YAML frontmatter
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// Parser for PPTX design configuration from frontmatter
public struct PPTXDesignParser {
    
    /// Parse design configuration from frontmatter
    public static func parse(from frontmatter: [String: Any]?) -> PPTXDesignConfiguration {
        guard let frontmatter = frontmatter else {
            return PPTXDesignConfiguration()
        }
        
        // Check for preset first
        if let presetName = frontmatter["design_preset"] as? String,
           let preset = PPTXDesignPreset(rawValue: presetName) {
            let config = preset.configuration
            
            // Allow overrides on top of preset
            return parseOverrides(on: config, from: frontmatter)
        }
        
        // Otherwise parse from scratch
        let slideSize = parseSlideSize(from: frontmatter)
        let customSize = parseCustomSize(from: frontmatter)
        let typography = parseTypography(from: frontmatter)
        let colorScheme = parseColorScheme(from: frontmatter)
        let spacing = parseSpacing(from: frontmatter)
        let background = parseBackground(from: frontmatter["slide_background"])
        
        return PPTXDesignConfiguration(
            slideSize: slideSize,
            customSize: customSize,
            typography: typography,
            colorScheme: colorScheme,
            spacing: spacing,
            defaultBackground: background
        )
    }
    
    /// Apply overrides to existing configuration
    private static func parseOverrides(on config: PPTXDesignConfiguration, from frontmatter: [String: Any]) -> PPTXDesignConfiguration {
        var newConfig = config
        
        // Override slide size if specified
        if let _ = frontmatter["slide_size"] {
            let slideSize = parseSlideSize(from: frontmatter)
            let customSize = parseCustomSize(from: frontmatter)
            newConfig = PPTXDesignConfiguration(
                slideSize: slideSize,
                customSize: customSize,
                typography: config.typography,
                colorScheme: config.colorScheme,
                spacing: config.spacing,
                defaultBackground: config.defaultBackground
            )
        }
        
        // Override background if specified
        if let bgData = frontmatter["slide_background"] {
            let background = parseBackground(from: bgData)
            newConfig = PPTXDesignConfiguration(
                slideSize: newConfig.slideSize,
                customSize: newConfig.customSize,
                typography: newConfig.typography,
                colorScheme: newConfig.colorScheme,
                spacing: newConfig.spacing,
                defaultBackground: background
            )
        }
        
        return newConfig
    }
    
    // MARK: - Slide Size Parsing
    
    private static func parseSlideSize(from frontmatter: [String: Any]) -> PPTXSlideSize {
        guard let sizeStr = frontmatter["slide_size"] as? String else {
            return .widescreen
        }
        
        // Try standard sizes
        if let standardSize = PPTXSlideSize(rawValue: sizeStr.lowercased()) {
            return standardSize
        }
        
        // Check for custom format like "10x7.5" or "10in x 7.5in"
        if sizeStr.contains("x") || sizeStr.contains("×") {
            return .custom
        }
        
        return .widescreen
    }
    
    private static func parseCustomSize(from frontmatter: [String: Any]) -> (width: Double, height: Double)? {
        if let sizeStr = frontmatter["slide_size"] as? String {
            // Parse formats like "10x7.5", "10in x 7.5in", "25.4cm × 19.05cm"
            let cleaned = sizeStr
                .replacingOccurrences(of: "in", with: "")
                .replacingOccurrences(of: "inches", with: "")
                .replacingOccurrences(of: " ", with: "")
            
            let separators = ["x", "×", "X"]
            for separator in separators {
                if cleaned.contains(separator) {
                    let parts = cleaned.split(separator: Character(separator))
                    if parts.count == 2,
                       let width = parseLength(String(parts[0])),
                       let height = parseLength(String(parts[1])) {
                        return (width, height)
                    }
                }
            }
        }
        
        // Alternative format with separate width/height
        if let width = parseLength(from: frontmatter["slide_width"]),
           let height = parseLength(from: frontmatter["slide_height"]) {
            return (width, height)
        }
        
        return nil
    }
    
    private static func parseLength(_ str: String) -> Double? {
        let cleaned = str.trimmingCharacters(in: .whitespaces)
        
        // Handle cm
        if cleaned.hasSuffix("cm") {
            let numStr = cleaned.dropLast(2)
            if let num = Double(numStr) {
                return num / 2.54  // Convert to inches
            }
        }
        
        // Handle mm
        if cleaned.hasSuffix("mm") {
            let numStr = cleaned.dropLast(2)
            if let num = Double(numStr) {
                return num / 25.4  // Convert to inches
            }
        }
        
        // Default to inches
        return Double(cleaned)
    }
    
    private static func parseLength(from value: Any?) -> Double? {
        if let str = value as? String {
            return parseLength(str)
        } else if let num = value as? Double {
            return num
        } else if let num = value as? Int {
            return Double(num)
        }
        return nil
    }
    
    // MARK: - Typography Parsing
    
    private static func parseTypography(from frontmatter: [String: Any]) -> PPTXTypographySystem {
        guard let typography = frontmatter["typography"] as? [String: Any] else {
            return .default
        }
        
        // Parse global font settings
        let globalFont = typography["font_family"] as? String
        let globalColor = typography["text_color"] as? String
        
        // Parse individual typography roles
        let title = parseTypographyRole("title", from: typography, defaults: (globalFont, 44.0, globalColor))
        let subtitle = parseTypographyRole("subtitle", from: typography, defaults: (globalFont, 28.0, globalColor))
        let heading1 = parseTypographyRole("heading1", from: typography, defaults: (globalFont, 36.0, globalColor))
        let heading2 = parseTypographyRole("heading2", from: typography, defaults: (globalFont, 28.0, globalColor))
        let heading3 = parseTypographyRole("heading3", from: typography, defaults: (globalFont, 24.0, globalColor))
        let body = parseTypographyRole("body", from: typography, defaults: (globalFont, 18.0, globalColor))
        let caption = parseTypographyRole("caption", from: typography, defaults: (globalFont, 14.0, globalColor))
        let code = parseTypographyRole("code", from: typography, defaults: ("Courier New", 14.0, globalColor))
        let quote = parseTypographyRole("quote", from: typography, defaults: (globalFont, 18.0, globalColor))
        
        return PPTXTypographySystem(
            title: title,
            subtitle: subtitle,
            heading1: heading1,
            heading2: heading2,
            heading3: heading3,
            body: body,
            caption: caption,
            code: code,
            quote: quote
        )
    }
    
    private static func parseTypographyRole(
        _ role: String,
        from typography: [String: Any],
        defaults: (font: String?, size: Double, color: String?)
    ) -> PPTXTypography {
        guard let roleData = typography[role] as? [String: Any] else {
            return PPTXTypography(
                fontFamily: defaults.font ?? "Arial",
                fontSize: defaults.size,
                color: defaults.color ?? "000000"
            )
        }
        
        let fontFamily = (roleData["font"] as? String) ?? defaults.font ?? "Arial"
        let fontSize = parseDouble(roleData["size"]) ?? defaults.size
        let fontWeight = parseFontWeight(roleData["weight"])
        let fontStyle = parseFontStyle(roleData["style"])
        let color = (roleData["color"] as? String)?.replacingOccurrences(of: "#", with: "") ?? defaults.color ?? "000000"
        let letterSpacing = parseDouble(roleData["letter_spacing"])
        let lineHeight = parseDouble(roleData["line_height"])
        
        return PPTXTypography(
            fontFamily: fontFamily,
            fontSize: fontSize,
            fontWeight: fontWeight,
            fontStyle: fontStyle,
            color: color,
            letterSpacing: letterSpacing,
            lineHeight: lineHeight
        )
    }
    
    private static func parseFontWeight(_ value: Any?) -> PPTXTypography.FontWeight {
        guard let weightStr = value as? String else { return .regular }
        
        switch weightStr.lowercased() {
        case "thin", "100": return .thin
        case "light", "300": return .light
        case "regular", "normal", "400": return .regular
        case "medium", "500": return .medium
        case "semibold", "600": return .semibold
        case "bold", "700": return .bold
        case "heavy", "black", "900": return .heavy
        default: return .regular
        }
    }
    
    private static func parseFontStyle(_ value: Any?) -> PPTXTypography.FontStyle {
        guard let styleStr = value as? String else { return .normal }
        return styleStr.lowercased() == "italic" ? .italic : .normal
    }
    
    // MARK: - Color Scheme Parsing
    
    private static func parseColorScheme(from frontmatter: [String: Any]) -> PPTXColorScheme {
        guard let colors = frontmatter["colors"] as? [String: Any] else {
            return .default
        }
        
        return PPTXColorScheme(
            primary: parseColor(colors["primary"]) ?? PPTXColorScheme.default.primary,
            secondary: parseColor(colors["secondary"]) ?? PPTXColorScheme.default.secondary,
            accent: parseColor(colors["accent"]) ?? PPTXColorScheme.default.accent,
            background: parseColor(colors["background"]) ?? PPTXColorScheme.default.background,
            surface: parseColor(colors["surface"]) ?? PPTXColorScheme.default.surface,
            text: parseColor(colors["text"]) ?? PPTXColorScheme.default.text,
            textSecondary: parseColor(colors["text_secondary"]) ?? PPTXColorScheme.default.textSecondary,
            error: parseColor(colors["error"]) ?? PPTXColorScheme.default.error,
            warning: parseColor(colors["warning"]) ?? PPTXColorScheme.default.warning,
            success: parseColor(colors["success"]) ?? PPTXColorScheme.default.success
        )
    }
    
    private static func parseColor(_ value: Any?) -> String? {
        guard let colorStr = value as? String else { return nil }
        return colorStr.replacingOccurrences(of: "#", with: "").uppercased()
    }
    
    // MARK: - Spacing Parsing
    
    private static func parseSpacing(from frontmatter: [String: Any]) -> PPTXSpacing {
        guard let spacing = frontmatter["spacing"] as? [String: Any] else {
            return .default
        }
        
        let unit = parseDouble(spacing["unit"]) ?? 0.25
        
        let margins = parseMargins(spacing["margins"])
        let padding = parsePadding(spacing["padding"])
        let gap = parseGap(spacing["gap"])
        
        return PPTXSpacing(
            unit: unit,
            margins: margins,
            padding: padding,
            gap: gap
        )
    }
    
    private static func parseMargins(_ value: Any?) -> PPTXSpacing.Margins {
        if let dict = value as? [String: Any] {
            return PPTXSpacing.Margins(
                top: parseDouble(dict["top"]) ?? 0.5,
                right: parseDouble(dict["right"]) ?? 0.5,
                bottom: parseDouble(dict["bottom"]) ?? 0.5,
                left: parseDouble(dict["left"]) ?? 0.5
            )
        } else if let num = parseDouble(value) {
            // Single value applies to all sides
            return PPTXSpacing.Margins(top: num, right: num, bottom: num, left: num)
        }
        
        return PPTXSpacing.default.margins
    }
    
    private static func parsePadding(_ value: Any?) -> PPTXSpacing.Padding {
        if let dict = value as? [String: Any] {
            return PPTXSpacing.Padding(
                small: parseDouble(dict["small"]) ?? 0.25,
                medium: parseDouble(dict["medium"]) ?? 0.5,
                large: parseDouble(dict["large"]) ?? 1.0
            )
        }
        return PPTXSpacing.default.padding
    }
    
    private static func parseGap(_ value: Any?) -> PPTXSpacing.Gap {
        if let dict = value as? [String: Any] {
            return PPTXSpacing.Gap(
                small: parseDouble(dict["small"]) ?? 0.1,
                medium: parseDouble(dict["medium"]) ?? 0.25,
                large: parseDouble(dict["large"]) ?? 0.5
            )
        }
        return PPTXSpacing.default.gap
    }
    
    // MARK: - Background Parsing
    
    private static func parseBackground(from value: Any?) -> PPTXBackground? {
        if let color = value as? String {
            return .solid(color: parseColor(color) ?? "FFFFFF")
        }
        
        guard let dict = value as? [String: Any] else { return nil }
        
        if let type = dict["type"] as? String {
            switch type.lowercased() {
            case "solid":
                if let color = parseColor(dict["color"]) {
                    return .solid(color: color)
                }
                
            case "gradient":
                if let colors = dict["colors"] as? [String] {
                    let parsedColors = colors.compactMap { parseColor($0) }
                    let angle = parseDouble(dict["angle"]) ?? 0
                    return .gradient(colors: parsedColors, angle: angle)
                }
                
            case "image":
                if let path = dict["path"] as? String {
                    let opacity = parseDouble(dict["opacity"]) ?? 1.0
                    return .image(path: path, opacity: opacity)
                }
                
            case "pattern":
                if let patternType = dict["pattern"] as? String,
                   let pattern = PPTXBackground.PatternType(rawValue: patternType),
                   let color = parseColor(dict["color"]) {
                    return .pattern(type: pattern, color: color)
                }
                
            default:
                break
            }
        }
        
        return nil
    }
    
    // MARK: - Utilities
    
    private static func parseDouble(_ value: Any?) -> Double? {
        if let num = value as? Double {
            return num
        } else if let num = value as? Int {
            return Double(num)
        } else if let str = value as? String {
            return Double(str)
        }
        return nil
    }
}

// MARK: - Attribute Parsing

extension PPTXDesignParser {
    
    /// Parse design attributes from attribute strings like {.bg-primary .text-white}
    public static func parseElementAttributes(_ attrs: RhoeMarkdownKit.Attributes?) -> ElementDesign {
        guard let attrs = attrs else {
            return ElementDesign()
        }
        
        var design = ElementDesign()
        
        // Parse classes
        for className in attrs.classes {
            // Background colors
            if className.hasPrefix("bg-") {
                design.backgroundColor = String(className.dropFirst(3))
            }
            // Text colors
            else if className.hasPrefix("text-") {
                design.textColor = String(className.dropFirst(5))
            }
            // Font sizes
            else if className.hasPrefix("text-") && className.hasSuffix("xl") {
                design.fontSize = parseSizeClass(className)
            }
            // Font weights
            else if let weight = parseFontWeightClass(className) {
                design.fontWeight = weight
            }
            // Alignment
            else if let align = parseAlignmentClass(className) {
                design.alignment = align
            }
        }
        
        // Parse key-value attributes
        for (key, value) in attrs.keyValues {
            switch key {
            case "font":
                design.fontFamily = value
            case "size":
                design.fontSize = parseDouble(value)
            case "color":
                design.textColor = parseColor(value)
            case "bg", "background":
                design.backgroundColor = parseColor(value)
            case "align":
                design.alignment = parseAlignment(value)
            default:
                break
            }
        }
        
        return design
    }
    
    private static func parseSizeClass(_ className: String) -> Double? {
        switch className {
        case "text-xs": return 12.0
        case "text-sm": return 14.0
        case "text-base": return 16.0
        case "text-lg": return 20.0
        case "text-xl": return 24.0
        case "text-2xl": return 30.0
        case "text-3xl": return 36.0
        case "text-4xl": return 48.0
        case "text-5xl": return 60.0
        default: return nil
        }
    }
    
    private static func parseFontWeightClass(_ className: String) -> PPTXTypography.FontWeight? {
        switch className {
        case "font-thin": return .thin
        case "font-light": return .light
        case "font-normal": return .regular
        case "font-medium": return .medium
        case "font-semibold": return .semibold
        case "font-bold": return .bold
        case "font-heavy", "font-black": return .heavy
        default: return nil
        }
    }
    
    private static func parseAlignmentClass(_ className: String) -> PPTXTextAlignment? {
        switch className {
        case "text-left": return .left
        case "text-center": return .center
        case "text-right": return .right
        case "text-justify": return .justify
        default: return nil
        }
    }
    
    private static func parseAlignment(_ value: String) -> PPTXTextAlignment? {
        switch value.lowercased() {
        case "left": return .left
        case "center": return .center
        case "right": return .right
        case "justify": return .justify
        default: return nil
        }
    }
}

/// Element-level design overrides
public struct ElementDesign {
    public var fontFamily: String?
    public var fontSize: Double?
    public var fontWeight: PPTXTypography.FontWeight?
    public var textColor: String?
    public var backgroundColor: String?
    public var alignment: PPTXTextAlignment?
}
