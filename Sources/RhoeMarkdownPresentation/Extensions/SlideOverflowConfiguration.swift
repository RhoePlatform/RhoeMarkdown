//
//  SlideOverflowConfiguration.swift
//  RhoeMarkdownKit
//
//  Overflow mode configuration for Grid cells 🚀
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

// MARK: - Overflow Configuration

/// Overflow mode for grid cells
public enum OverflowMode: String, Sendable, Equatable, Codable {
    case none = "none"
    case vertical = "vertical"
    case horizontal = "horizontal"
    case both = "both"
}

/// Overflow configuration for a grid
public struct GridOverflowConfiguration: Sendable, Equatable {
    public let mode: OverflowMode
    public let alignment: CellAlignment
    public let minItemsPerPage: Int
    public let showEllipsis: Bool
    
    public init(
        mode: OverflowMode = .none,
        alignment: CellAlignment = .topLeft,
        minItemsPerPage: Int = 3,
        showEllipsis: Bool = true
    ) {
        self.mode = mode
        self.alignment = alignment
        self.minItemsPerPage = minItemsPerPage
        self.showEllipsis = showEllipsis
    }
    
    /// Parse from grid attributes
    public static func parse(from attributes: RhoeMarkdownKit.Attributes?) -> GridOverflowConfiguration {
        guard let attrs = attributes else {
            return GridOverflowConfiguration()
        }
        
        var mode: OverflowMode = .none
        var alignment: CellAlignment = .topLeft
        
        for className in attrs.classes {
            // Parse overflow mode
            if className == "overflow-vertical" {
                mode = .vertical
            } else if className == "overflow-horizontal" {
                mode = .horizontal
            } else if className == "overflow-both" {
                mode = .both
            }
            
            // Parse alignment
            if let align = CellAlignment(rawValue: className.replacingOccurrences(of: "align-", with: "")) {
                alignment = align
            }
        }
        
        return GridOverflowConfiguration(
            mode: mode,
            alignment: alignment
        )
    }
}

// MARK: - Content Measurement

/// Represents measurable content for overflow calculations
public protocol MeasurableContent {
    /// Calculate height at given font size
    func height(at fontSize: Double) -> Double
    
    /// Calculate width at given font size
    func width(at fontSize: Double) -> Double
    
    /// Can this content be split?
    var isSplittable: Bool { get }
    
    /// Minimum units that should stay together
    var atomicUnitCount: Int { get }
}

/// Content metrics for overflow calculations
public struct ContentMetrics: Sendable {
    public let estimatedHeight: Double
    public let estimatedWidth: Double
    public let splittablePoints: [Int]
    public let minimumChunkSize: Int
    
    public init(
        estimatedHeight: Double,
        estimatedWidth: Double,
        splittablePoints: [Int] = [],
        minimumChunkSize: Int = 1
    ) {
        self.estimatedHeight = estimatedHeight
        self.estimatedWidth = estimatedWidth
        self.splittablePoints = splittablePoints
        self.minimumChunkSize = minimumChunkSize
    }
}

// MARK: - Overflow Rules

/// Rules for different content types
public struct OverflowRules {
    // Minimum items to keep on a page
    public static let minListItems = 3
    public static let minParagraphs = 2
    public static let minTableRows = 5
    public static let minCodeLines = 10
    
    // Prefer to keep together if less than
    public static let keepTogetherThreshold = 5
    
    /// Check if content should trigger overflow
    public static func shouldOverflow(
        itemCount: Int,
        itemType: ContentType,
        availableSpace: Double,
        requiredSpace: Double
    ) -> Bool {
        // If content fits, no overflow needed
        if requiredSpace <= availableSpace {
            return false
        }
        
        // Check minimum rules
        let minItems: Int
        switch itemType {
        case .list: minItems = minListItems
        case .paragraph: minItems = minParagraphs
        case .table: minItems = minTableRows
        case .code: minItems = minCodeLines
        default: minItems = 1
        }
        
        // Only overflow if we have more than minimum items
        return itemCount > minItems
    }
    
    public enum ContentType {
        case list
        case paragraph
        case table
        case code
        case mixed
    }
}

// MARK: - Split Result

/// Result of content splitting for overflow
public struct ContentSplitResult: Sendable {
    public let pages: [[Block]]
    public let pageFontSizes: [Double]
    public let totalPages: Int
    
    public init(pages: [[Block]], pageFontSizes: [Double]) {
        self.pages = pages
        self.pageFontSizes = pageFontSizes
        self.totalPages = pages.count
    }
}

// MARK: - Ellipsis Configuration

/// Configuration for ellipsis indicators
public struct EllipsisConfiguration: Sendable {
    public let text: String
    public let style: EllipsisStyle
    
    public init(
        text: String = "⋯",
        style: EllipsisStyle = .subtle
    ) {
        self.text = text
        self.style = style
    }
    
    public enum EllipsisStyle: String, Sendable {
        case subtle = "ellipsis-subtle"
        case prominent = "ellipsis-prominent"
        case count = "ellipsis-count" // Shows "... (47 more items)"
    }
    
    /// Generate ellipsis HTML
    public func html(remainingCount: Int? = nil) -> String {
        switch style {
        case .subtle:
            return "<span class=\"\(style.rawValue)\">\(text)</span>"
        case .prominent:
            return "<div class=\"\(style.rawValue)\">\(text)</div>"
        case .count:
            if let count = remainingCount {
                return "<div class=\"\(style.rawValue)\">\(text) \(count) more items</div>"
            } else {
                return "<div class=\"\(style.rawValue)\">\(text) continued</div>"
            }
        }
    }
}
