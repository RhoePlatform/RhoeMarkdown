//
//  SlideContentSplitter.swift
//  RhoeMarkdownKit
//
//  Content splitting engine for Grid Overflow Mode 🚀
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

// MARK: - Content Splitter

/// Splits content across multiple pages based on available space
public struct SlideContentSplitter: Sendable {
    private let fontConfig: SlideFontConfiguration
    private let contentSizer: SlideContentSizer
    
    public init(fontConfig: SlideFontConfiguration) {
        self.fontConfig = fontConfig
        self.contentSizer = SlideContentSizer(fontConfig: fontConfig)
    }
    
    /// Result of content splitting
    public struct SplitResult: Sendable {
        public let pages: [[Block]]
        public let pageFontSizes: [Double]
        public let totalPages: Int
        
        public init(pages: [[Block]], pageFontSizes: [Double]) {
            self.pages = pages
            self.pageFontSizes = pageFontSizes
            self.totalPages = pages.count
        }
    }
    
    /// Split content based on overflow configuration
    public func splitContent(
        blocks: [Block],
        cellHeight: Double,
        overflowConfig: GridOverflowConfiguration,
        elementType: SlideFontConfiguration.ElementType
    ) -> SplitResult {
        // Get font range for element type
        let fontRange = fontConfig.range(for: elementType)
        
        // Try to fit everything at optimal size first
        let optimalSize = contentSizer.findOptimalFontSize(
            for: blocks,
            in: cellHeight,
            elementType: elementType
        )
        
        let totalHeight = contentSizer.measureHeight(blocks: blocks, fontSize: optimalSize)
        
        // If it fits, no splitting needed
        if totalHeight <= cellHeight || overflowConfig.mode == .none {
            return SplitResult(pages: [blocks], pageFontSizes: [optimalSize])
        }
        
        // Split based on overflow mode
        switch overflowConfig.mode {
        case .vertical:
            return splitVertically(
                blocks: blocks,
                cellHeight: cellHeight,
                fontRange: fontRange,
                elementType: elementType
            )
        case .horizontal:
            // Phase 2 implementation
            return SplitResult(pages: [blocks], pageFontSizes: [optimalSize])
        case .both:
            // Phase 3 implementation
            return SplitResult(pages: [blocks], pageFontSizes: [optimalSize])
        case .none:
            return SplitResult(pages: [blocks], pageFontSizes: [optimalSize])
        }
    }
    
    /// Split content vertically across pages
    private func splitVertically(
        blocks: [Block],
        cellHeight: Double,
        fontRange: FontSizeRange,
        elementType: SlideFontConfiguration.ElementType
    ) -> SplitResult {
        var pages: [[Block]] = []
        var pageFontSizes: [Double] = []
        var remainingBlocks = blocks
        
        while !remainingBlocks.isEmpty {
            // Find how many blocks fit on this page
            let (pageBlocks, fontSize) = fitBlocksInHeight(
                blocks: remainingBlocks,
                maxHeight: cellHeight,
                fontRange: fontRange,
                elementType: elementType
            )
            
            if pageBlocks.isEmpty {
                // Even one block doesn't fit - split the block itself
                if let firstBlock = remainingBlocks.first {
                    let (splitBlocks, splitSizes) = splitSingleBlock(
                        block: firstBlock,
                        cellHeight: cellHeight,
                        fontRange: fontRange
                    )
                    pages.append(contentsOf: splitBlocks)
                    pageFontSizes.append(contentsOf: splitSizes)
                    remainingBlocks.removeFirst()
                }
            } else {
                pages.append(pageBlocks)
                pageFontSizes.append(fontSize)
                remainingBlocks.removeFirst(pageBlocks.count)
            }
        }
        
        return SplitResult(pages: pages, pageFontSizes: pageFontSizes)
    }
    
    /// Find how many blocks fit in given height
    private func fitBlocksInHeight(
        blocks: [Block],
        maxHeight: Double,
        fontRange: FontSizeRange,
        elementType: SlideFontConfiguration.ElementType
    ) -> (blocks: [Block], fontSize: Double) {
        var fittingBlocks: [Block] = []
        var currentHeight = 0.0
        
        // Binary search for optimal font size
        var low = fontRange.min
        var high = fontRange.max
        var bestFit: (blocks: [Block], fontSize: Double) = ([], fontRange.min)
        
        while high - low > 0.5 {
            let mid = (low + high) / 2
            fittingBlocks = []
            currentHeight = 0.0
            
            for block in blocks {
                let blockHeight = contentSizer.measureBlockHeight(block, fontSize: mid)
                if currentHeight + blockHeight <= maxHeight {
                    fittingBlocks.append(block)
                    currentHeight += blockHeight
                } else {
                    break
                }
            }
            
            if fittingBlocks.isEmpty {
                high = mid
            } else {
                bestFit = (fittingBlocks, mid)
                if fittingBlocks.count == blocks.count {
                    low = mid
                } else {
                    break // Found optimal split
                }
            }
        }
        
        return bestFit
    }
    
    /// Split a single block across pages (for large blocks)
    private func splitSingleBlock(
        block: Block,
        cellHeight: Double,
        fontRange: FontSizeRange
    ) -> (blocks: [[Block]], fontSizes: [Double]) {
        switch block {
        case .list(let listType, let items, _):
            return splitList(items: items, listType: listType, cellHeight: cellHeight, fontRange: fontRange)
        case .paragraph(_, _):
            // For now, put entire paragraph on one page at minimum size
            return ([[block]], [fontRange.min])
        case .table(let headers, let rows, _, _):
            return splitTable(headers: headers, rows: rows, cellHeight: cellHeight, fontRange: fontRange)
        default:
            // Other blocks can't be split
            return ([[block]], [fontRange.min])
        }
    }
    
    /// Split a list across pages
    private func splitList(
        items: [ListItem],
        listType: ListType,
        cellHeight: Double,
        fontRange: FontSizeRange
    ) -> (blocks: [[Block]], fontSizes: [Double]) {
        var pages: [[Block]] = []
        var fontSizes: [Double] = []
        var currentItems: [ListItem] = []
        
        // Try to fit items at optimal size
        let optimalSize = contentSizer.findOptimalFontSize(
            for: [.list(type: listType, items: items, attributes: RhoeMarkdownKit.Attributes())],
            in: cellHeight,
            elementType: .list
        )
        
        var currentHeight = 0.0
        
        for item in items {
            let itemHeight = measureListItem(item, fontSize: optimalSize)
            
            if currentHeight + itemHeight > cellHeight && !currentItems.isEmpty {
                // Start new page
                pages.append([.list(type: listType, items: currentItems, attributes: RhoeMarkdownKit.Attributes())])
                fontSizes.append(optimalSize)
                currentItems = [item]
                currentHeight = itemHeight
            } else {
                currentItems.append(item)
                currentHeight += itemHeight
            }
        }
        
        if !currentItems.isEmpty {
            pages.append([.list(type: listType, items: currentItems, attributes: RhoeMarkdownKit.Attributes())])
            fontSizes.append(optimalSize)
        }
        
        return (pages, fontSizes)
    }
    
    /// Split a table across pages
    private func splitTable(
        headers: [TableCell],
        rows: [[TableCell]],
        cellHeight: Double,
        fontRange: FontSizeRange
    ) -> (blocks: [[Block]], fontSizes: [Double]) {
        // Phase 2: Implement table splitting
        // For now, keep table intact
        return ([[.table(headers: headers, rows: rows, attributes: RhoeMarkdownKit.Attributes())]], [fontRange.min])
    }
    
    /// Measure height of a list item
    private func measureListItem(_ item: ListItem, fontSize: Double) -> Double {
        var height = fontSize * 1.2 // Base line height
        
        // Add nested content
        for block in item.content {
            height += contentSizer.measureBlockHeight(block, fontSize: fontSize)
        }
        
        return height
    }
    
    /// Measure height of inline content
    private func measureInlineHeight(_ inline: Inline, fontSize: Double) -> Double {
        // Simplified height calculation
        switch inline {
        case .text(let str):
            let lines = str.split(separator: "\n").count
            return Double(lines) * fontSize * 1.2
        case .hardBreak:
            return fontSize * 1.2
        default:
            return 0 // Inline elements don't add height
        }
    }
}
