//
//  PPTXDesignSystem.swift
//  RhoeMarkdownKit
//
//  NEXT-GENERATION PPTX Design System 🎨
//  Complete control over presentation aesthetics
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

// MARK: - Slide Size Configuration

/// Standard PowerPoint slide sizes
public enum PPTXSlideSize: String, CaseIterable, Sendable {
    case widescreen = "widescreen"      // 16:9 - 13.333" x 7.5"
    case standard = "standard"          // 4:3  - 10" x 7.5"
    case a4 = "a4"                     // A4   - 10.83" x 7.5"
    case letter = "letter"              // Letter - 10" x 7.5"
    case ledger = "ledger"              // 11" x 17"
    case b4iso = "b4iso"               // B4 ISO - 10.12" x 7.17"
    case b5iso = "b5iso"               // B5 ISO - 7.17" x 5.08"
    case onScreen16x9 = "onscreen16x9"  // 10" x 5.625"
    case onScreen16x10 = "onscreen16x10" // 10" x 6.25"
    case custom = "custom"              // User-defined
    
    /// Get dimensions in inches
    public var dimensions: (width: Double, height: Double) {
        switch self {
        case .widescreen:
            return (13.333, 7.5)
        case .standard:
            return (10.0, 7.5)
        case .a4:
            return (10.83, 7.5)
        case .letter:
            return (10.0, 7.5)
        case .ledger:
            return (11.0, 17.0)
        case .b4iso:
            return (10.12, 7.17)
        case .b5iso:
            return (7.17, 5.08)
        case .onScreen16x9:
            return (10.0, 5.625)
        case .onScreen16x10:
            return (10.0, 6.25)
        case .custom:
            return (10.0, 5.625) // Default to 16:9
        }
    }
    
    /// Get dimensions in EMUs
    public var emuDimensions: (width: Int, height: Int) {
        let dims = dimensions
        return (
            PPTXUnits.inchesToEmu(dims.width),
            PPTXUnits.inchesToEmu(dims.height)
        )
    }
}

// MARK: - Typography System

/// Font configuration for different text elements
public struct PPTXTypography: Sendable {
    public let fontFamily: String
    public let fontSize: Double  // in points
    public let fontWeight: FontWeight
    public let fontStyle: FontStyle
    public let color: String     // RGB hex
    public let letterSpacing: Double?  // in EMUs
    public let lineHeight: Double?     // multiplier
    
    public enum FontWeight: String, Sendable {
        case thin = "100"
        case light = "300"
        case regular = "400"
        case medium = "500"
        case semibold = "600"
        case bold = "700"
        case heavy = "900"
    }
    
    public enum FontStyle: String, Sendable {
        case normal = "normal"
        case italic = "italic"
    }
    
    public init(
        fontFamily: String = "Arial",
        fontSize: Double = 18.0,
        fontWeight: FontWeight = .regular,
        fontStyle: FontStyle = .normal,
        color: String = "000000",
        letterSpacing: Double? = nil,
        lineHeight: Double? = nil
    ) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.fontStyle = fontStyle
        self.color = color
        self.letterSpacing = letterSpacing
        self.lineHeight = lineHeight
    }
}

/// Typography roles in a presentation
public struct PPTXTypographySystem: Sendable {
    public let title: PPTXTypography
    public let subtitle: PPTXTypography
    public let heading1: PPTXTypography
    public let heading2: PPTXTypography
    public let heading3: PPTXTypography
    public let body: PPTXTypography
    public let caption: PPTXTypography
    public let code: PPTXTypography
    public let quote: PPTXTypography
    
    /// Default typography system
    public static let `default` = PPTXTypographySystem(
        title: PPTXTypography(
            fontFamily: "Arial",
            fontSize: 44.0,
            fontWeight: .bold,
            color: "000000"
        ),
        subtitle: PPTXTypography(
            fontFamily: "Arial",
            fontSize: 28.0,
            fontWeight: .regular,
            color: "666666"
        ),
        heading1: PPTXTypography(
            fontFamily: "Arial",
            fontSize: 36.0,
            fontWeight: .semibold,
            color: "000000"
        ),
        heading2: PPTXTypography(
            fontFamily: "Arial",
            fontSize: 28.0,
            fontWeight: .semibold,
            color: "000000"
        ),
        heading3: PPTXTypography(
            fontFamily: "Arial",
            fontSize: 24.0,
            fontWeight: .medium,
            color: "333333"
        ),
        body: PPTXTypography(
            fontFamily: "Arial",
            fontSize: 18.0,
            fontWeight: .regular,
            color: "333333",
            lineHeight: 1.5
        ),
        caption: PPTXTypography(
            fontFamily: "Arial",
            fontSize: 14.0,
            fontWeight: .regular,
            color: "666666"
        ),
        code: PPTXTypography(
            fontFamily: "Courier New",
            fontSize: 14.0,
            fontWeight: .regular,
            color: "444444"
        ),
        quote: PPTXTypography(
            fontFamily: "Georgia",
            fontSize: 18.0,
            fontWeight: .regular,
            fontStyle: .italic,
            color: "555555"
        )
    )
}

// MARK: - Background Configuration

/// Slide background options
public enum PPTXBackground: Sendable {
    case solid(color: String)
    case gradient(colors: [String], angle: Double)
    case image(path: String, opacity: Double)
    case pattern(type: PatternType, color: String)
    
    public enum PatternType: String, Sendable {
        case dots = "dots"
        case lines = "lines"
        case grid = "grid"
        case waves = "waves"
    }
}

// MARK: - Color Scheme

/// Color palette for the presentation
public struct PPTXColorScheme: Sendable {
    public let primary: String
    public let secondary: String
    public let accent: String
    public let background: String
    public let surface: String
    public let text: String
    public let textSecondary: String
    public let error: String
    public let warning: String
    public let success: String
    
    /// Default color scheme
    public static let `default` = PPTXColorScheme(
        primary: "1976D2",      // Blue
        secondary: "424242",    // Dark gray
        accent: "FF5722",       // Deep orange
        background: "FFFFFF",   // White
        surface: "F5F5F5",      // Light gray
        text: "212121",         // Almost black
        textSecondary: "757575", // Gray
        error: "D32F2F",        // Red
        warning: "F57C00",      // Orange
        success: "388E3C"       // Green
    )
}

// MARK: - Spacing System

/// Spacing configuration for layouts
public struct PPTXSpacing: Sendable {
    public let unit: Double  // Base unit in inches
    public let margins: Margins
    public let padding: Padding
    public let gap: Gap
    
    public struct Margins: Sendable {
        public let top: Double
        public let right: Double
        public let bottom: Double
        public let left: Double
    }
    
    public struct Padding: Sendable {
        public let small: Double
        public let medium: Double
        public let large: Double
    }
    
    public struct Gap: Sendable {
        public let small: Double
        public let medium: Double
        public let large: Double
    }
    
    /// Default spacing system
    public static let `default` = PPTXSpacing(
        unit: 0.25,  // 1/4 inch
        margins: Margins(
            top: 0.5,
            right: 0.5,
            bottom: 0.5,
            left: 0.5
        ),
        padding: Padding(
            small: 0.25,
            medium: 0.5,
            large: 1.0
        ),
        gap: Gap(
            small: 0.1,
            medium: 0.25,
            large: 0.5
        )
    )
}

// MARK: - Complete Design Configuration

/// Complete design system for a presentation
public struct PPTXDesignConfiguration: Sendable {
    public let slideSize: PPTXSlideSize
    public let customSize: (width: Double, height: Double)?
    public let typography: PPTXTypographySystem
    public let colorScheme: PPTXColorScheme
    public let spacing: PPTXSpacing
    public let defaultBackground: PPTXBackground?
    
    public init(
        slideSize: PPTXSlideSize = .widescreen,
        customSize: (width: Double, height: Double)? = nil,
        typography: PPTXTypographySystem = .default,
        colorScheme: PPTXColorScheme = .default,
        spacing: PPTXSpacing = .default,
        defaultBackground: PPTXBackground? = nil
    ) {
        self.slideSize = slideSize
        self.customSize = customSize
        self.typography = typography
        self.colorScheme = colorScheme
        self.spacing = spacing
        self.defaultBackground = defaultBackground
    }
    
    /// Get actual slide dimensions
    public var actualDimensions: (width: Double, height: Double) {
        if slideSize == .custom, let custom = customSize {
            return custom
        }
        return slideSize.dimensions
    }
    
    /// Get actual slide dimensions in EMUs
    public var actualEmuDimensions: (width: Int, height: Int) {
        let dims = actualDimensions
        return (
            PPTXUnits.inchesToEmu(dims.width),
            PPTXUnits.inchesToEmu(dims.height)
        )
    }
}

// MARK: - Design Presets

/// Pre-configured design themes
public enum PPTXDesignPreset: String, CaseIterable, Sendable {
    case minimal = "minimal"
    case corporate = "corporate"
    case creative = "creative"
    case academic = "academic"
    case dark = "dark"
    
    public var configuration: PPTXDesignConfiguration {
        switch self {
        case .minimal:
            return PPTXDesignConfiguration(
                slideSize: .widescreen,
                typography: .default,
                colorScheme: .default,
                spacing: .default
            )
            
        case .corporate:
            return PPTXDesignConfiguration(
                slideSize: .standard,
                typography: PPTXTypographySystem(
                    title: PPTXTypography(fontFamily: "Helvetica", fontSize: 48.0, fontWeight: .bold),
                    subtitle: PPTXTypography(fontFamily: "Helvetica", fontSize: 32.0),
                    heading1: PPTXTypography(fontFamily: "Helvetica", fontSize: 36.0, fontWeight: .semibold),
                    heading2: PPTXTypography(fontFamily: "Helvetica", fontSize: 28.0, fontWeight: .medium),
                    heading3: PPTXTypography(fontFamily: "Helvetica", fontSize: 24.0),
                    body: PPTXTypography(fontFamily: "Helvetica", fontSize: 18.0),
                    caption: PPTXTypography(fontFamily: "Helvetica", fontSize: 14.0),
                    code: PPTXTypography(fontFamily: "Monaco", fontSize: 14.0),
                    quote: PPTXTypography(fontFamily: "Helvetica", fontSize: 20.0, fontStyle: .italic)
                ),
                colorScheme: PPTXColorScheme(
                    primary: "003366",
                    secondary: "666666",
                    accent: "0099CC",
                    background: "FFFFFF",
                    surface: "F0F0F0",
                    text: "333333",
                    textSecondary: "666666",
                    error: "CC0000",
                    warning: "FF9900",
                    success: "009900"
                ),
                spacing: .default
            )
            
        case .creative:
            return PPTXDesignConfiguration(
                slideSize: .widescreen,
                typography: PPTXTypographySystem(
                    title: PPTXTypography(fontFamily: "Impact", fontSize: 56.0, fontWeight: .bold, color: "FF6B6B"),
                    subtitle: PPTXTypography(fontFamily: "Arial", fontSize: 32.0, color: "4ECDC4"),
                    heading1: PPTXTypography(fontFamily: "Impact", fontSize: 42.0, fontWeight: .bold),
                    heading2: PPTXTypography(fontFamily: "Arial Black", fontSize: 32.0),
                    heading3: PPTXTypography(fontFamily: "Arial", fontSize: 26.0, fontWeight: .semibold),
                    body: PPTXTypography(fontFamily: "Arial", fontSize: 20.0),
                    caption: PPTXTypography(fontFamily: "Arial", fontSize: 16.0),
                    code: PPTXTypography(fontFamily: "Consolas", fontSize: 16.0),
                    quote: PPTXTypography(fontFamily: "Georgia", fontSize: 22.0, fontStyle: .italic)
                ),
                colorScheme: PPTXColorScheme(
                    primary: "FF6B6B",
                    secondary: "4ECDC4",
                    accent: "45B7D1",
                    background: "F7F7F7",
                    surface: "FFFFFF",
                    text: "2C3E50",
                    textSecondary: "7F8C8D",
                    error: "E74C3C",
                    warning: "F39C12",
                    success: "27AE60"
                ),
                spacing: PPTXSpacing(
                    unit: 0.3,
                    margins: PPTXSpacing.Margins(top: 0.75, right: 0.75, bottom: 0.75, left: 0.75),
                    padding: PPTXSpacing.Padding(small: 0.3, medium: 0.6, large: 1.2),
                    gap: PPTXSpacing.Gap(small: 0.15, medium: 0.3, large: 0.6)
                ),
                defaultBackground: .gradient(colors: ["FFE5E5", "E5F5FF"], angle: 45)
            )
            
        case .academic:
            return PPTXDesignConfiguration(
                slideSize: .a4,
                typography: PPTXTypographySystem(
                    title: PPTXTypography(fontFamily: "Times New Roman", fontSize: 42.0, fontWeight: .bold),
                    subtitle: PPTXTypography(fontFamily: "Times New Roman", fontSize: 28.0),
                    heading1: PPTXTypography(fontFamily: "Times New Roman", fontSize: 36.0, fontWeight: .bold),
                    heading2: PPTXTypography(fontFamily: "Times New Roman", fontSize: 28.0, fontWeight: .semibold),
                    heading3: PPTXTypography(fontFamily: "Times New Roman", fontSize: 24.0),
                    body: PPTXTypography(fontFamily: "Times New Roman", fontSize: 18.0, lineHeight: 1.6),
                    caption: PPTXTypography(fontFamily: "Times New Roman", fontSize: 14.0, fontStyle: .italic),
                    code: PPTXTypography(fontFamily: "Courier", fontSize: 14.0),
                    quote: PPTXTypography(fontFamily: "Times New Roman", fontSize: 18.0, fontStyle: .italic)
                ),
                colorScheme: PPTXColorScheme(
                    primary: "1A237E",
                    secondary: "424242",
                    accent: "C62828",
                    background: "FAFAFA",
                    surface: "FFFFFF",
                    text: "212121",
                    textSecondary: "616161",
                    error: "B71C1C",
                    warning: "E65100",
                    success: "1B5E20"
                ),
                spacing: .default
            )
            
        case .dark:
            return PPTXDesignConfiguration(
                slideSize: .widescreen,
                typography: PPTXTypographySystem(
                    title: PPTXTypography(fontFamily: "SF Pro Display", fontSize: 48.0, fontWeight: .bold, color: "FFFFFF"),
                    subtitle: PPTXTypography(fontFamily: "SF Pro Display", fontSize: 32.0, color: "CCCCCC"),
                    heading1: PPTXTypography(fontFamily: "SF Pro Display", fontSize: 40.0, fontWeight: .semibold, color: "FFFFFF"),
                    heading2: PPTXTypography(fontFamily: "SF Pro Display", fontSize: 32.0, fontWeight: .medium, color: "EEEEEE"),
                    heading3: PPTXTypography(fontFamily: "SF Pro Display", fontSize: 26.0, color: "DDDDDD"),
                    body: PPTXTypography(fontFamily: "SF Pro Text", fontSize: 18.0, color: "CCCCCC"),
                    caption: PPTXTypography(fontFamily: "SF Pro Text", fontSize: 14.0, color: "999999"),
                    code: PPTXTypography(fontFamily: "SF Mono", fontSize: 14.0, color: "90CAF9"),
                    quote: PPTXTypography(fontFamily: "SF Pro Text", fontSize: 20.0, fontStyle: .italic, color: "BBBBBB")
                ),
                colorScheme: PPTXColorScheme(
                    primary: "2196F3",
                    secondary: "FFC107",
                    accent: "FF5722",
                    background: "121212",
                    surface: "1E1E1E",
                    text: "FFFFFF",
                    textSecondary: "B0B0B0",
                    error: "CF6679",
                    warning: "FFB74D",
                    success: "81C784"
                ),
                spacing: .default,
                defaultBackground: .solid(color: "121212")
            )
        }
    }
}