//
//  SlideContentSizer.swift
//  RhoeMarkdownKit
//
//  Content sizing and measurement for Grid Overflow Mode 🚀
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

// MARK: - Content Sizer

/// Handles content measurement and font sizing calculations
public struct SlideContentSizer: Sendable {
    private let fontConfig: SlideFontConfiguration
    private let baseLineHeight: Double = 1.5
    
    public init(fontConfig: SlideFontConfiguration = SlideFontConfiguration()) {
        self.fontConfig = fontConfig
    }
    
    /// Find optimal font size for content within available space
    public func findOptimalFontSize(
        for blocks: [Block],
        in availableHeight: Double,
        elementType: SlideFontConfiguration.ElementType = .unknown
    ) -> Double {
        let range = fontConfig.range(for: elementType)
        
        // First try max size
        let heightAtMax = measureHeight(blocks: blocks, fontSize: range.max)
        if heightAtMax <= availableHeight {
            return range.max
        }
        
        // Binary search for optimal size
        var low = range.min
        var high = range.max
        let epsilon = 0.5
        
        while high - low > epsilon {
            let mid = (low + high) / 2
            let heightAtMid = measureHeight(blocks: blocks, fontSize: mid)
            
            if heightAtMid <= availableHeight {
                low = mid
            } else {
                high = mid
            }
        }
        
        return low
    }
    
    /// Measure total height of blocks at given font size
    public func measureHeight(blocks: [Block], fontSize: Double) -> Double {
        var totalHeight = 0.0
        
        for block in blocks {
            totalHeight += measureBlockHeight(block, fontSize: fontSize)
        }
        
        return totalHeight
    }
    
    /// Measure height of a single block
    public func measureBlockHeight(_ block: Block, fontSize: Double) -> Double {
        switch block {
        case .paragraph(let inlines, _):
            // Estimate based on character count and line wrapping
            let text = extractText(from: inlines)
            let estimatedLines = ceil(Double(text.count) / 60.0) // ~60 chars per line
            return estimatedLines * fontSize * baseLineHeight
            
        case .heading(let level, _, _):
            let headingSize = fontConfig.range(for: .heading(level)).max
            let scale = fontSize / fontConfig.default.max
            return headingSize * scale * baseLineHeight * 1.5 // Extra spacing for headings
            
        case .list(_, let items, _):
            var height = 0.0
            for item in items {
                // Each item is approximately one line + sub-content
                height += fontSize * baseLineHeight
                for block in item.content {
                    height += measureBlockHeight(block, fontSize: fontSize * 0.9) // Slightly smaller for nested
                }
            }
            return height
            
        case .codeBlock(_, let content, _):
            let lines = content.components(separatedBy: .newlines).count
            let codeSize = fontConfig.range(for: .code).max
            let scale = fontSize / fontConfig.default.max
            return Double(lines) * codeSize * scale * baseLineHeight
            
        case .table(_, let rows, _, _):
            let tableSize = fontConfig.range(for: .table).max
            let scale = fontSize / fontConfig.default.max
            let rowCount = rows.count + 1 // +1 for header
            return Double(rowCount) * tableSize * scale * baseLineHeight * 1.2
            
        case .blockQuote(let blocks, _):
            var height = 0.0
            for block in blocks {
                height += measureBlockHeight(block, fontSize: fontSize * 0.95)
            }
            return height * 1.1 // Extra padding for blockquote
            
        case .horizontalRule:
            return fontSize * 2 // Simple spacing
            
        case .html:
            return fontSize * 3 // Rough estimate
            
        default:
            return fontSize * baseLineHeight
        }
    }
    
    /// Extract text content from inlines for measurement
    private func extractText(from inlines: [Inline]) -> String {
        var text = ""
        for inline in inlines {
            switch inline {
            case .text(let str):
                text += str
            case .codeSpan(let str, _):
                text += str
            case .emphasis(let nested), .strong(let nested):
                text += extractText(from: nested)
            case .link(let nested, _, _, _):
                text += extractText(from: nested)
            case .inlineMath(let expr, _):
                text += expr
            case .mathDisplay(let expr, _):
                text += expr
            default:
                text += " "
            }
        }
        return text
    }
}

// MARK: - Content Splitter

/// Handles splitting content for overflow pages
public struct SlideContentSplitterOld: Sendable {
    private let sizer: SlideContentSizer
    private let overflowRules = OverflowRules.self
    
    public init(fontConfig: SlideFontConfiguration = SlideFontConfiguration()) {
        self.sizer = SlideContentSizer(fontConfig: fontConfig)
    }
    
    /// Split content across multiple pages
    public func splitContent(
        blocks: [Block],
        cellHeight: Double,
        overflowConfig: GridOverflowConfiguration,
        elementType: SlideFontConfiguration.ElementType = .unknown
    ) -> ContentSplitResult {
        guard overflowConfig.mode != .none else {
            // No overflow - return as single page
            let fontSize = sizer.findOptimalFontSize(
                for: blocks,
                in: cellHeight,
                elementType: elementType
            )
            return ContentSplitResult(
                pages: [blocks],
                pageFontSizes: [fontSize]
            )
        }
        
        // Find split points
        let splitPoints = findSplitPoints(
            blocks: blocks,
            cellHeight: cellHeight,
            minItemsPerPage: overflowConfig.minItemsPerPage
        )
        
        // Create pages from split points
        var pages: [[Block]] = []
        var pageFontSizes: [Double] = []
        var startIdx = 0
        
        for endIdx in splitPoints {
            let pageBlocks = Array(blocks[startIdx..<endIdx])
            pages.append(pageBlocks)
            
            // Calculate optimal font size for this page
            let fontSize = sizer.findOptimalFontSize(
                for: pageBlocks,
                in: cellHeight,
                elementType: elementType
            )
            pageFontSizes.append(fontSize)
            
            startIdx = endIdx
        }
        
        // Don't forget the last page
        if startIdx < blocks.count {
            let pageBlocks = Array(blocks[startIdx...])
            pages.append(pageBlocks)
            
            let fontSize = sizer.findOptimalFontSize(
                for: pageBlocks,
                in: cellHeight,
                elementType: elementType
            )
            pageFontSizes.append(fontSize)
        }
        
        return ContentSplitResult(
            pages: pages,
            pageFontSizes: pageFontSizes
        )
    }
    
    /// Find optimal split points for content
    private func findSplitPoints(
        blocks: [Block],
        cellHeight: Double,
        minItemsPerPage: Int
    ) -> [Int] {
        var splitPoints: [Int] = []
        var currentHeight = 0.0
        var currentStart = 0
        var itemsInCurrentPage = 0
        
        // Use a reasonable font size for estimation
        let estimationFontSize = 12.0
        
        for (index, block) in blocks.enumerated() {
            let blockHeight = sizer.measureBlockHeight(block, fontSize: estimationFontSize)
            
            // Check if adding this block would exceed height
            if currentHeight + blockHeight > cellHeight && itemsInCurrentPage >= minItemsPerPage {
                // Check if we're leaving too few items
                let remainingItems = blocks.count - index
                if remainingItems < minItemsPerPage && remainingItems < itemsInCurrentPage / 2 {
                    // Adjust split point backwards
                    let adjustedSplit = max(currentStart + minItemsPerPage, index - minItemsPerPage)
                    splitPoints.append(adjustedSplit)
                    currentStart = adjustedSplit
                } else {
                    splitPoints.append(index)
                    currentStart = index
                }
                
                currentHeight = 0
                itemsInCurrentPage = 0
            }
            
            currentHeight += blockHeight
            itemsInCurrentPage += countItems(in: block)
        }
        
        return splitPoints
    }
    
    /// Count logical items in a block (for minimum rules)
    private func countItems(in block: Block) -> Int {
        switch block {
        case .list(_, let items, _):
            return items.count
        case .table(_, let rows, _, _):
            return rows.count
        case .codeBlock(_, let content, _):
            return content.components(separatedBy: .newlines).count
        default:
            return 1
        }
    }
}
