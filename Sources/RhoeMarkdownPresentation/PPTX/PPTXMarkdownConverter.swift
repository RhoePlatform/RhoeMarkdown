//
//  PPTXMarkdownConverter.swift
//  RhoeMarkdownKit
//
//  Converts markdown slides to PPTX shapes
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// Converts markdown presentation to PPTX
public struct PPTXMarkdownConverter {
    
    private let design: PPTXDesignConfiguration
    
    // Layout constants derived from design
    private var slideMargin: Double { design.spacing.margins.left }
    private var slideRightMargin: Double { design.spacing.margins.right }
    private var titleHeight: Double { 1.5 }
    private var titleY: Double { design.spacing.margins.top }
    private var contentY: Double { 2.0 }
    private var lineSpacing: Double { 0.05 }
    private var paragraphSpacing: Double { design.spacing.gap.medium }
    private var listItemSpacing: Double { 0.35 }
    
    // Calculated widths
    private var contentWidth: Double {
        let dims = design.actualDimensions
        return dims.width - slideMargin - slideRightMargin
    }
    
    public init(design: PPTXDesignConfiguration = PPTXDesignConfiguration()) {
        self.design = design
    }
    
    /// Convert a markdown presentation to PPTX
    public func convert(presentation: Presentation) -> PPTXPresentation {
        // Parse design from metadata
        var metadataDict: [String: Any] = [:]
        if let title = presentation.metadata.title { metadataDict["title"] = title }
        if let author = presentation.metadata.author { metadataDict["author"] = author }
        if let theme = presentation.metadata.theme { metadataDict["theme"] = theme }
        // Add custom fields
        for (key, value) in presentation.metadata.customFields {
            metadataDict[key] = value
        }
        
        let finalDesign = PPTXDesignParser.parse(from: metadataDict)
        let converter = PPTXMarkdownConverter(design: finalDesign)
        
        let slides = presentation.slides.map { converter.convertSlide($0) }
        
        return PPTXPresentation(
            slides: slides,
            title: presentation.title,
            author: presentation.author,
            design: finalDesign
        )
    }
    
    /// Convert a single slide
    private func convertSlide(_ slide: Slide) -> PPTXSlide {
        var shapes: [PPTXShape] = []
        var shapeId = 2 // Start at 2 (1 is reserved for group)
        var currentY = titleY
        
        // Parse slide-level design attributes
        let slideDesign = PPTXDesignParser.parseElementAttributes(slide.attributes)
        
        // Process each content element
        for contentElement in slide.content {
            guard case .markdown(let block) = contentElement else { continue }
            let converted = convertBlock(
                block,
                shapeId: &shapeId,
                currentY: &currentY,
                slideDesign: slideDesign
            )
            shapes.append(contentsOf: converted)
        }
        
        // Determine background
        var background: PPTXBackground? = design.defaultBackground
        if let bgColor = slideDesign.backgroundColor {
            background = .solid(color: bgColor)
        }
        
        // Extract speaker notes from slide attributes
        let speakerNotes = slide.attributes?.keyValues["notes"]

        // Extract transition from slide attributes
        let transition: PPTXTransitionType? = {
            guard let transStr = slide.attributes?.keyValues["transition"] else { return nil }
            return PPTXTransitionType(rawValue: transStr)
        }()

        return PPTXSlide(
            id: shapes.count + 1,
            shapes: shapes,
            background: background,
            speakerNotes: speakerNotes,
            transition: transition
        )
    }
    
    /// Convert a markdown block to shapes
    private func convertBlock(
        _ block: Block,
        shapeId: inout Int,
        currentY: inout Double,
        slideDesign: ElementDesign
    ) -> [PPTXShape] {
        switch block {
        case .heading(let level, let content, let attrs):
            let blockDesign = PPTXDesignParser.parseElementAttributes(attrs)
            return [convertHeading(level: level, content: content, attrs: attrs, 
                                 shapeId: &shapeId, currentY: &currentY, 
                                 slideDesign: slideDesign, blockDesign: blockDesign)]
            
        case .paragraph(let inlines, let attrs):
            let blockDesign = PPTXDesignParser.parseElementAttributes(attrs)
            return [convertParagraph(inlines: inlines, attrs: attrs,
                                   shapeId: &shapeId, currentY: &currentY,
                                   slideDesign: slideDesign, blockDesign: blockDesign)]
            
        case .list(let type, let items, let attrs):
            let blockDesign = PPTXDesignParser.parseElementAttributes(attrs)
            return [convertList(type: type, items: items, attrs: attrs,
                              shapeId: &shapeId, currentY: &currentY,
                              slideDesign: slideDesign, blockDesign: blockDesign)]
            
        case .codeBlock(let language, let content, let attrs):
            let blockDesign = PPTXDesignParser.parseElementAttributes(attrs)
            return [convertCodeBlock(language: language, content: content, attrs: attrs,
                                   shapeId: &shapeId, currentY: &currentY,
                                   slideDesign: slideDesign, blockDesign: blockDesign)]
            
        case .blockQuote(let blocks, let attrs):
            let blockDesign = PPTXDesignParser.parseElementAttributes(attrs)
            return convertBlockQuote(blocks: blocks, attrs: attrs,
                                   shapeId: &shapeId, currentY: &currentY,
                                   slideDesign: slideDesign, blockDesign: blockDesign)
            
        case .table(let headers, let rows, _, let attrs):
            let blockDesign = PPTXDesignParser.parseElementAttributes(attrs)
            return convertTable(headers: headers, rows: rows, attrs: attrs,
                              shapeId: &shapeId, currentY: &currentY,
                              slideDesign: slideDesign, blockDesign: blockDesign)
            
        case .html(let html):
            // Check if this is a grid layout
            if html.contains("slide-grid") {
                return convertGridLayout(html: html, shapeId: &shapeId)
            }
            return []
            
        case .horizontalRule:
            return [convertHorizontalRule(shapeId: &shapeId, currentY: &currentY)]
            
        default:
            return []
        }
    }
    
    // MARK: - Heading Conversion
    
    private func convertHeading(
        level: Int,
        content: [Inline],
        attrs: RhoeMarkdownKit.Attributes?,
        shapeId: inout Int,
        currentY: inout Double,
        slideDesign: ElementDesign,
        blockDesign: ElementDesign
    ) -> PPTXShape {
        let typography: PPTXTypography
        let height: Double
        
        // Select typography based on level
        switch level {
        case 1:
            typography = design.typography.title
            height = titleHeight
        case 2:
            typography = design.typography.heading1
            height = 1.0
        case 3:
            typography = design.typography.heading2
            height = 0.9
        default:
            typography = design.typography.heading3
            height = 0.8
        }
        
        // Apply design overrides
        var finalFontSize = typography.fontSize
        var finalFontFamily = typography.fontFamily
        var finalColor = typography.color
        var finalAlignment: PPTXTextAlignment = level == 1 ? .center : .left
        
        // Apply slide-level overrides
        if let size = slideDesign.fontSize { finalFontSize = size }
        if let family = slideDesign.fontFamily { finalFontFamily = family }
        if let color = slideDesign.textColor { finalColor = color }
        if let align = slideDesign.alignment { finalAlignment = align }
        
        // Apply block-level overrides (highest priority)
        if let size = blockDesign.fontSize { finalFontSize = size }
        if let family = blockDesign.fontFamily { finalFontFamily = family }
        if let color = blockDesign.textColor { finalColor = color }
        if let align = blockDesign.alignment { finalAlignment = align }
        
        let y = level == 1 ? titleY : currentY
        
        let frame = PPTXFrame.fromInches(
            x: slideMargin,
            y: y,
            width: contentWidth,
            height: height
        )
        
        let textRuns = convertInlines(
            content, 
            defaultStyle: PPTXTextStyle(
                fontSize: finalFontSize,
                bold: typography.fontWeight == .bold || typography.fontWeight == .semibold,
                italic: typography.fontStyle == .italic,
                fontFamily: finalFontFamily,
                color: finalColor
            )
        )
        
        let paragraph = PPTXParagraph(
            runs: textRuns,
            alignment: finalAlignment
        )
        
        let shape = PPTXShape(
            id: shapeId,
            name: "Heading \(level)",
            type: .textBox(frame: frame),
            paragraphs: [paragraph]
        )
        
        shapeId += 1
        if level != 1 {
            currentY += height + paragraphSpacing
        }
        
        return shape
    }
    
    // MARK: - Paragraph Conversion
    
    private func convertParagraph(
        inlines: [Inline],
        attrs: RhoeMarkdownKit.Attributes?,
        shapeId: inout Int,
        currentY: inout Double,
        slideDesign: ElementDesign,
        blockDesign: ElementDesign
    ) -> PPTXShape {
        let typography = design.typography.body
        
        // Apply design overrides
        var finalFontSize = typography.fontSize
        var finalFontFamily = typography.fontFamily
        var finalColor = typography.color
        var finalAlignment: PPTXTextAlignment = .left
        
        // Apply slide-level overrides
        if let size = slideDesign.fontSize { finalFontSize = size }
        if let family = slideDesign.fontFamily { finalFontFamily = family }
        if let color = slideDesign.textColor { finalColor = color }
        if let align = slideDesign.alignment { finalAlignment = align }
        
        // Apply block-level overrides (highest priority)
        if let size = blockDesign.fontSize { finalFontSize = size }
        if let family = blockDesign.fontFamily { finalFontFamily = family }
        if let color = blockDesign.textColor { finalColor = color }
        if let align = blockDesign.alignment { finalAlignment = align }
        
        // Calculate approximate height based on text length
        let textLength = inlines.reduce(0) { count, inline in
            switch inline {
            case .text(let str):
                return count + str.count
            default:
                return count + 10  // Estimate for other types
            }
        }
        
        // Estimate lines needed (roughly 80 chars per line at body font size)
        let estimatedLines = max(1, (textLength + 79) / 80)
        let lineHeight = 0.3  // inches per line
        let height = Double(estimatedLines) * lineHeight
        
        let frame = PPTXFrame.fromInches(
            x: slideMargin,
            y: currentY,
            width: contentWidth,
            height: height
        )
        
        let textRuns = convertInlines(
            inlines,
            defaultStyle: PPTXTextStyle(
                fontSize: finalFontSize,
                fontFamily: finalFontFamily,
                color: finalColor
            )
        )
        let paragraph = PPTXParagraph(runs: textRuns, alignment: finalAlignment)
        
        let shape = PPTXShape(
            id: shapeId,
            name: "Paragraph \(shapeId)",
            type: .textBox(frame: frame),
            paragraphs: [paragraph]
        )
        
        shapeId += 1
        currentY += height + paragraphSpacing
        
        return shape
    }
    
    // MARK: - List Conversion
    
    private func convertList(
        type: ListType,
        items: [ListItem],
        attrs: RhoeMarkdownKit.Attributes?,
        shapeId: inout Int,
        currentY: inout Double,
        slideDesign: ElementDesign,
        blockDesign: ElementDesign
    ) -> PPTXShape {
        let typography = design.typography.body
        
        // Apply design overrides  
        var finalFontSize = typography.fontSize
        var finalFontFamily = typography.fontFamily
        var finalColor = typography.color
        
        if let size = slideDesign.fontSize { finalFontSize = size }
        if let family = slideDesign.fontFamily { finalFontFamily = family }
        if let color = slideDesign.textColor { finalColor = color }
        
        if let size = blockDesign.fontSize { finalFontSize = size }
        if let family = blockDesign.fontFamily { finalFontFamily = family }
        if let color = blockDesign.textColor { finalColor = color }
        
        let frame = PPTXFrame.fromInches(
            x: slideMargin,
            y: currentY,
            width: contentWidth,
            height: Double(items.count) * listItemSpacing + 0.2
        )
        
        var paragraphs: [PPTXParagraph] = []
        
        for (index, item) in items.enumerated() {
            // Convert first block of item (usually paragraph)
            if let firstBlock = item.content.first,
               case .paragraph(let inlines, _) = firstBlock {
                let defaultStyle = PPTXTextStyle(
                    fontSize: finalFontSize,
                    fontFamily: finalFontFamily,
                    color: finalColor
                )
                let runs = convertInlines(inlines, defaultStyle: defaultStyle)
                
                // Create proper PPTX paragraph based on list type
                switch type {
                case .ordered(let start, _):
                    // For ordered lists, we'll prepend the number as text
                    // since PPTX auto-numbering is complex
                    var orderedRuns = [PPTXTextRun(
                        text: "\(start + index). ",
                        style: defaultStyle
                    )]
                    orderedRuns.append(contentsOf: runs)
                    paragraphs.append(PPTXParagraph(runs: orderedRuns))
                    
                case .unordered:
                    // For unordered lists, prepend bullet for proper formatting
                    var bulletRuns = [PPTXTextRun(
                        text: "• ",
                        style: defaultStyle
                    )]
                    bulletRuns.append(contentsOf: runs)
                    paragraphs.append(PPTXParagraph(runs: bulletRuns))
                    
                case .task:
                    // For task lists, add checkbox as text
                    var taskRuns = [PPTXTextRun(
                        text: item.checked == true ? "☑ " : "☐ ",
                        style: defaultStyle
                    )]
                    taskRuns.append(contentsOf: runs)
                    paragraphs.append(PPTXParagraph(runs: taskRuns))
                }
            }
        }
        
        let shape = PPTXShape(
            id: shapeId,
            name: "List \(shapeId)",
            type: .textBox(frame: frame),
            paragraphs: paragraphs
        )
        
        shapeId += 1
        currentY += Double(items.count) * listItemSpacing + paragraphSpacing
        
        return shape
    }
    
    // MARK: - Code Block Conversion
    
    private func convertCodeBlock(
        language: String?,
        content: String,
        attrs: RhoeMarkdownKit.Attributes?,
        shapeId: inout Int,
        currentY: inout Double,
        slideDesign: ElementDesign,
        blockDesign: ElementDesign
    ) -> PPTXShape {
        let typography = design.typography.code
        
        // Apply design overrides
        var finalFontSize = typography.fontSize
        var finalFontFamily = typography.fontFamily
        var finalColor = typography.color
        
        if let size = slideDesign.fontSize { finalFontSize = size }
        if let family = slideDesign.fontFamily { finalFontFamily = family }
        if let color = slideDesign.textColor { finalColor = color }
        
        if let size = blockDesign.fontSize { finalFontSize = size }
        if let family = blockDesign.fontFamily { finalFontFamily = family }
        if let color = blockDesign.textColor { finalColor = color }
        
        // Background rectangle
        let bgFrame = PPTXFrame.fromInches(
            x: slideMargin,
            y: currentY,
            width: contentWidth,
            height: Double(content.split(separator: "\n").count) * 0.25 + 0.2
        )
        
        // Code text with padding
        let textFrame = PPTXFrame.fromInches(
            x: slideMargin + design.spacing.padding.small,
            y: currentY + design.spacing.padding.small,
            width: contentWidth - (2 * design.spacing.padding.small),
            height: Double(bgFrame.height) / Double(PPTXUnits.emuPerInch) - (2 * design.spacing.padding.small)
        )
        
        let run = PPTXTextRun(
            text: content,
            style: PPTXTextStyle(
                fontSize: finalFontSize,
                fontFamily: finalFontFamily,
                color: finalColor
            )
        )
        
        let shape = PPTXShape(
            id: shapeId,
            name: "Code \(shapeId)",
            type: .textBox(frame: textFrame),
            paragraphs: [PPTXParagraph(runs: [run])]
        )
        
        shapeId += 1
        currentY += Double(content.split(separator: "\n").count) * 0.25 + 0.4
        
        return shape
    }
    
    // MARK: - Block Quote Conversion
    
    private func convertBlockQuote(
        blocks: [Block],
        attrs: RhoeMarkdownKit.Attributes?,
        shapeId: inout Int,
        currentY: inout Double,
        slideDesign: ElementDesign,
        blockDesign: ElementDesign
    ) -> [PPTXShape] {
        var shapes: [PPTXShape] = []
        
        // Quote bar
        let barFrame = PPTXFrame.fromInches(
            x: slideMargin,
            y: currentY,
            width: 0.05,
            height: 0.5  // Will adjust based on content
        )
        
        let bar = PPTXShape(
            id: shapeId,
            name: "Quote Bar \(shapeId)",
            type: .rectangle(frame: barFrame, fillColor: "CCCCCC"),
            paragraphs: []
        )
        shapes.append(bar)
        shapeId += 1
        
        // Quote content (indented)
        for block in blocks {
            var quoteY = currentY
            let quoteShapes = convertBlock(block, shapeId: &shapeId, currentY: &quoteY, slideDesign: slideDesign)
            
            // Shift shapes to the right
            for shape in quoteShapes {
                // This is simplified - in real implementation we'd modify the frame
                shapes.append(shape)
            }
            currentY = quoteY
        }
        
        return shapes
    }
    
    // MARK: - Table Conversion
    
    private func convertTable(
        headers: [TableCell],
        rows: [[TableCell]],
        attrs: RhoeMarkdownKit.Attributes?,
        shapeId: inout Int,
        currentY: inout Double,
        slideDesign: ElementDesign,
        blockDesign: ElementDesign
    ) -> [PPTXShape] {
        let numColumns = headers.count
        let numRows = rows.count + 1  // +1 for header row
        
        // Calculate table dimensions
        let tableWidth = contentWidth
        let cellHeight = 0.5  // inches per row
        let tableHeight = Double(numRows) * cellHeight
        
        let frame = PPTXFrame.fromInches(
            x: slideMargin,
            y: currentY,
            width: tableWidth,
            height: tableHeight
        )
        
        // Create table cells
        var tableCells: [[PPTXTableCell]] = []
        
        // Header row
        var headerCells: [PPTXTableCell] = []
        for header in headers {
            let headerStyle = PPTXTextStyle(
                fontSize: design.typography.body.fontSize,
                bold: true,
                fontFamily: design.typography.body.fontFamily,
                color: design.typography.body.color
            )
            let runs = convertInlines(header.content, defaultStyle: headerStyle)
            let paragraph = PPTXParagraph(runs: runs, alignment: .center)
            headerCells.append(PPTXTableCell(
                paragraphs: [paragraph],
                fillColor: design.colorScheme.surface  // Use surface color for headers
            ))
        }
        tableCells.append(headerCells)
        
        // Data rows
        for row in rows {
            var rowCells: [PPTXTableCell] = []
            for cell in row {
                let runs = convertInlines(cell.content, defaultStyle: PPTXTextStyle(
                    fontSize: design.typography.body.fontSize,
                    fontFamily: design.typography.body.fontFamily,
                    color: design.typography.body.color
                ))
                let paragraph = PPTXParagraph(runs: runs)
                rowCells.append(PPTXTableCell(paragraphs: [paragraph]))
            }
            tableCells.append(rowCells)
        }
        
        let shape = PPTXShape(
            id: shapeId,
            name: "Table \(shapeId)",
            type: .table(frame: frame, rows: numRows, columns: numColumns),
            tableCells: tableCells
        )
        
        shapeId += 1
        currentY += tableHeight + paragraphSpacing
        
        return [shape]
    }
    
    // MARK: - Grid Layout Conversion
    
    private func convertGridLayout(
        html: String,
        shapeId: inout Int
    ) -> [PPTXShape] {
        // Parse grid dimensions from HTML
        // This is a simplified version - real implementation would parse the HTML properly
        
        var shapes: [PPTXShape] = []
        
        // For now, create a simple 3x3 grid
        let cellWidth = 3.0
        let cellHeight = 1.5
        let cellMargin = 0.1
        
        for row in 0..<3 {
            for col in 0..<3 {
                let frame = PPTXFrame.fromInches(
                    x: slideMargin + Double(col) * (cellWidth + cellMargin),
                    y: contentY + Double(row) * (cellHeight + cellMargin),
                    width: cellWidth,
                    height: cellHeight
                )
                
                // Border
                let border = PPTXShape(
                    id: shapeId,
                    name: "Grid Cell \(row),\(col)",
                    type: .rectangle(frame: frame, fillColor: nil),
                    paragraphs: []
                )
                shapes.append(border)
                shapeId += 1
            }
        }
        
        return shapes
    }
    
    // MARK: - Horizontal Rule
    
    private func convertHorizontalRule(
        shapeId: inout Int,
        currentY: inout Double
    ) -> PPTXShape {
        let shape = PPTXShape(
            id: shapeId,
            name: "Line \(shapeId)",
            type: .line(
                x1: PPTXUnits.inchesToEmu(slideMargin),
                y1: PPTXUnits.inchesToEmu(currentY + 0.1),
                x2: PPTXUnits.inchesToEmu(10.0 - slideMargin),
                y2: PPTXUnits.inchesToEmu(currentY + 0.1),
                strokeColor: "CCCCCC",
                strokeWidth: PPTXUnits.pointsToEmu(1)
            ),
            paragraphs: []
        )
        
        shapeId += 1
        currentY += 0.3
        
        return shape
    }
    
    // MARK: - Inline Conversion
    
    private func convertInlines(
        _ inlines: [Inline],
        defaultStyle: PPTXTextStyle
    ) -> [PPTXTextRun] {
        var runs: [PPTXTextRun] = []
        
        for inline in inlines {
            switch inline {
            case .text(let str):
                runs.append(PPTXTextRun(text: str, style: defaultStyle))
                
            case .strong(let content):
                var boldStyle = defaultStyle
                boldStyle.bold = true
                let nestedRuns = convertInlines(content, defaultStyle: boldStyle)
                runs.append(contentsOf: nestedRuns)
                
            case .emphasis(let content):
                var italicStyle = defaultStyle
                italicStyle.italic = true
                let nestedRuns = convertInlines(content, defaultStyle: italicStyle)
                runs.append(contentsOf: nestedRuns)
                
            case .codeSpan(let str, _):
                var codeStyle = defaultStyle
                let baseFontSize = Double(codeStyle.fontSize ?? 1800) / 100.0  // Convert from 100ths
                codeStyle.fontSize = Int((baseFontSize * 0.9) * 100)  // Scale and convert back
                codeStyle.fontFamily = design.typography.code.fontFamily
                codeStyle.color = design.typography.code.color
                runs.append(PPTXTextRun(text: str, style: codeStyle))
                
            case .link(let text, _, _, _):
                var linkStyle = defaultStyle
                linkStyle.underline = true
                linkStyle.color = design.colorScheme.primary
                let linkRuns = convertInlines(text, defaultStyle: linkStyle)
                runs.append(contentsOf: linkRuns)

            case .strikethrough(let content):
                let nestedRuns = convertInlines(content, defaultStyle: defaultStyle)
                runs.append(contentsOf: nestedRuns)

            case .highlight(let content):
                let nestedRuns = convertInlines(content, defaultStyle: defaultStyle)
                runs.append(contentsOf: nestedRuns)

            case .superscript(let content):
                let nestedRuns = convertInlines(content, defaultStyle: defaultStyle)
                runs.append(contentsOf: nestedRuns)

            case .subscript(let content):
                let nestedRuns = convertInlines(content, defaultStyle: defaultStyle)
                runs.append(contentsOf: nestedRuns)

            case .span(let content, _):
                let nestedRuns = convertInlines(content, defaultStyle: defaultStyle)
                runs.append(contentsOf: nestedRuns)

            case .softBreak:
                runs.append(PPTXTextRun(text: " ", style: defaultStyle))

            case .hardBreak:
                runs.append(PPTXTextRun(text: "\n", style: defaultStyle))

            case .image(let alt, let url, _, _):
                let altText = alt.isEmpty ? url : convertInlines(alt, defaultStyle: defaultStyle).map(\.text).joined()
                runs.append(PPTXTextRun(text: "[Image: \(altText)]", style: defaultStyle))

            default:
                break
            }
        }
        
        return runs
    }
}
