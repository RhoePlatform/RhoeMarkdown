//
//  PPTXStructure.swift
//  RhoeMarkdownKit
//
//  FRONTIER-LEVEL PPTX EXPORTER 🚀
//  Treating slides as blank canvases with absolute positioning
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

// MARK: - PPTX Document Structure

/// Core PPTX package structure
public struct PPTXPackage {
    // Required files and folders for minimal PPTX
    static let requiredStructure = [
        "[Content_Types].xml",
        "_rels/.rels",
        "ppt/presentation.xml",
        "ppt/_rels/presentation.xml.rels",
        "ppt/slides/",
        "ppt/slides/_rels/",
        "ppt/slideLayouts/",
        "ppt/slideLayouts/_rels/",
        "ppt/slideMasters/",
        "ppt/slideMasters/_rels/",
        "ppt/theme/",
        "ppt/media/",  // For images
        "docProps/app.xml",
        "docProps/core.xml"
    ]
}

// MARK: - Coordinate System

/// PPTX uses EMUs (English Metric Units)
/// 1 inch = 914400 EMUs
/// 1 cm = 360000 EMUs  
/// 1 pt = 12700 EMUs
public enum PPTXUnits {
    static let emuPerInch: Int = 914400
    static let emuPerCm: Int = 360000
    static let emuPerPoint: Int = 12700
    
    /// Standard slide dimensions (16:9)
    static let slideWidth: Int = 9144000   // 10 inches
    static let slideHeight: Int = 5143500  // 5.625 inches
    
    /// Convert points to EMUs
    static func pointsToEmu(_ points: Double) -> Int {
        return Int(points * Double(emuPerPoint))
    }
    
    /// Convert inches to EMUs
    static func inchesToEmu(_ inches: Double) -> Int {
        return Int(inches * Double(emuPerInch))
    }
}

// MARK: - Shape Positioning

/// Absolute position and size for PPTX shapes
public struct PPTXFrame {
    let x: Int      // EMUs from left
    let y: Int      // EMUs from top
    let width: Int  // EMUs
    let height: Int // EMUs
    
    /// Create frame from inches
    static func fromInches(x: Double, y: Double, width: Double, height: Double) -> PPTXFrame {
        return PPTXFrame(
            x: PPTXUnits.inchesToEmu(x),
            y: PPTXUnits.inchesToEmu(y),
            width: PPTXUnits.inchesToEmu(width),
            height: PPTXUnits.inchesToEmu(height)
        )
    }
    
    /// Create frame from points
    static func fromPoints(x: Double, y: Double, width: Double, height: Double) -> PPTXFrame {
        return PPTXFrame(
            x: PPTXUnits.pointsToEmu(x),
            y: PPTXUnits.pointsToEmu(y),
            width: PPTXUnits.pointsToEmu(width),
            height: PPTXUnits.pointsToEmu(height)
        )
    }
}

// MARK: - Text Styling

/// Text run properties for PPTX
public struct PPTXTextStyle {
    var fontSize: Int?      // In 100ths of a point (e.g., 1200 = 12pt)
    var bold: Bool
    var italic: Bool
    var underline: Bool
    var fontFamily: String
    var color: String      // RGB hex color
    
    init(
        fontSize: Double? = nil,
        bold: Bool = false,
        italic: Bool = false,
        underline: Bool = false,
        fontFamily: String = "Arial",
        color: String = "000000"
    ) {
        self.fontSize = fontSize.map { Int($0 * 100) }
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.fontFamily = fontFamily
        self.color = color
    }
}

// MARK: - Shape Types

/// Types of shapes we'll support
public enum PPTXShapeType {
    case textBox(frame: PPTXFrame)
    case image(frame: PPTXFrame, imageData: Data, contentType: String)
    case rectangle(frame: PPTXFrame, fillColor: String?)
    case line(x1: Int, y1: Int, x2: Int, y2: Int, strokeColor: String, strokeWidth: Int)
    case table(frame: PPTXFrame, rows: Int, columns: Int)
}

// MARK: - Content Elements

/// A text run within a paragraph
public struct PPTXTextRun {
    let text: String
    let style: PPTXTextStyle
}

/// A paragraph in PPTX
public struct PPTXParagraph {
    let runs: [PPTXTextRun]
    let alignment: PPTXTextAlignment
    let spaceBefore: Int?  // EMUs
    let spaceAfter: Int?   // EMUs
    let lineSpacing: Int?  // Percentage (e.g., 120 = 1.2x)
    
    init(
        runs: [PPTXTextRun],
        alignment: PPTXTextAlignment = .left,
        spaceBefore: Int? = nil,
        spaceAfter: Int? = nil,
        lineSpacing: Int? = nil
    ) {
        self.runs = runs
        self.alignment = alignment
        self.spaceBefore = spaceBefore
        self.spaceAfter = spaceAfter
        self.lineSpacing = lineSpacing
    }
}

/// Text alignment options
public enum PPTXTextAlignment {
    case left
    case center
    case right
    case justify
    
    var xmlValue: String {
        switch self {
        case .left: return "l"
        case .center: return "ctr"
        case .right: return "r"
        case .justify: return "just"
        }
    }
}

// MARK: - Slide Content

/// A table cell
public struct PPTXTableCell {
    let paragraphs: [PPTXParagraph]
    let fillColor: String?
    let borderColor: String?
    
    init(
        paragraphs: [PPTXParagraph],
        fillColor: String? = nil,
        borderColor: String? = "000000"
    ) {
        self.paragraphs = paragraphs
        self.fillColor = fillColor
        self.borderColor = borderColor
    }
}

/// A shape on a slide
public struct PPTXShape {
    let id: Int
    let name: String
    let type: PPTXShapeType
    let paragraphs: [PPTXParagraph]
    let tableCells: [[PPTXTableCell]]  // For table type only
    
    init(
        id: Int,
        name: String,
        type: PPTXShapeType,
        paragraphs: [PPTXParagraph] = [],
        tableCells: [[PPTXTableCell]] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.paragraphs = paragraphs
        self.tableCells = tableCells
    }
}

/// Slide transition types
public enum PPTXTransitionType: String {
    case fade
    case push
    case wipe
    case split
    case dissolve
    case cover
    case uncover
    case none

    var xmlElement: String {
        switch self {
        case .fade: return "<p:fade/>"
        case .push: return "<p:push dir=\"l\"/>"
        case .wipe: return "<p:wipe dir=\"d\"/>"
        case .split: return "<p:split orient=\"horz\"/>"
        case .dissolve: return "<p:dissolve/>"
        case .cover: return "<p:cover dir=\"l\"/>"
        case .uncover: return "<p:uncover dir=\"l\"/>"
        case .none: return ""
        }
    }
}

/// A single slide
public struct PPTXSlide {
    let id: Int
    let shapes: [PPTXShape]
    let background: PPTXBackground?
    let speakerNotes: String?
    let transition: PPTXTransitionType?

    init(
        id: Int,
        shapes: [PPTXShape],
        background: PPTXBackground? = nil,
        speakerNotes: String? = nil,
        transition: PPTXTransitionType? = nil
    ) {
        self.id = id
        self.shapes = shapes
        self.background = background
        self.speakerNotes = speakerNotes
        self.transition = transition
    }
}

// MARK: - Document Model

/// The complete PPTX presentation
public struct PPTXPresentation {
    let slides: [PPTXSlide]
    let slideWidth: Int
    let slideHeight: Int
    let title: String?
    let author: String?
    let design: PPTXDesignConfiguration
    
    init(
        slides: [PPTXSlide],
        slideWidth: Int = PPTXUnits.slideWidth,
        slideHeight: Int = PPTXUnits.slideHeight,
        title: String? = nil,
        author: String? = nil,
        design: PPTXDesignConfiguration = PPTXDesignConfiguration()
    ) {
        self.slides = slides
        // Use design dimensions if available
        let dims = design.actualEmuDimensions
        self.slideWidth = dims.width
        self.slideHeight = dims.height
        self.title = title
        self.author = author
        self.design = design
    }
}