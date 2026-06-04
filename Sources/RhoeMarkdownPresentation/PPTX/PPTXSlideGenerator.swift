//
//  PPTXSlideGenerator.swift
//  RhoeMarkdownKit
//
//  Generates individual slide XML with shapes
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// Generates slide XML content
public struct PPTXSlideGenerator {
    
    /// Generate XML for a single slide
    static func generateSlide(_ slide: PPTXSlide) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
            <p:cSld>
        """
        
        // Add background if specified
        if let background = slide.background {
            xml += generateBackground(background)
        }
        
        xml += """
        
                <p:spTree>
                    <p:nvGrpSpPr>
                        <p:cNvPr id="1" name=""/>
                        <p:cNvGrpSpPr/>
                        <p:nvPr/>
                    </p:nvGrpSpPr>
                    <p:grpSpPr>
                        <a:xfrm>
                            <a:off x="0" y="0"/>
                            <a:ext cx="0" cy="0"/>
                            <a:chOff x="0" y="0"/>
                            <a:chExt cx="0" cy="0"/>
                        </a:xfrm>
                    </p:grpSpPr>
        """
        
        // Add shapes
        for shape in slide.shapes {
            xml += "\n" + generateShape(shape)
        }
        
        xml += """

                </p:spTree>
            </p:cSld>
            <p:clrMapOvr>
                <a:masterClrMapping/>
            </p:clrMapOvr>
        """

        // Add transition if specified
        if let transition = slide.transition, transition != .none {
            xml += "\n    <p:transition spd=\"med\">\(transition.xmlElement)</p:transition>"
        }

        // Add speaker notes if present
        if let notes = slide.speakerNotes, !notes.isEmpty {
            let escapedNotes = notes
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            xml += """

            <p:notes>
                <p:cSld>
                    <p:spTree>
                        <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
                        <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
                        <p:sp>
                            <p:nvSpPr><p:cNvPr id="2" name="Notes"/><p:cNvSpPr/><p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr>
                            <p:spPr/>
                            <p:txBody>
                                <a:bodyPr/>
                                <a:lstStyle/>
                                <a:p><a:r><a:t>\(escapedNotes)</a:t></a:r></a:p>
                            </p:txBody>
                        </p:sp>
                    </p:spTree>
                </p:cSld>
            </p:notes>
            """
        }

        xml += "\n</p:sld>"

        return xml
    }
    
    /// Generate slide relationship file
    static func generateSlideRels(slideId: Int, imageRels: [(id: String, filename: String)]) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
        """
        
        // Add image relationships
        for rel in imageRels {
            xml += """
            
            <Relationship Id="\(rel.id)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/\(rel.filename)"/>
            """
        }
        
        xml += "\n</Relationships>"
        return xml
    }
    
    // MARK: - Shape Generation
    
    private static func generateShape(_ shape: PPTXShape) -> String {
        switch shape.type {
        case .textBox(let frame):
            return generateTextBox(shape: shape, frame: frame)
        case .image(let frame, _, _):
            return generateImage(shape: shape, frame: frame)
        case .rectangle(let frame, let fillColor):
            return generateRectangle(shape: shape, frame: frame, fillColor: fillColor)
        case .line(let x1, let y1, let x2, let y2, let strokeColor, let strokeWidth):
            return generateLine(shape: shape, x1: x1, y1: y1, x2: x2, y2: y2, 
                              strokeColor: strokeColor, strokeWidth: strokeWidth)
        case .table(let frame, let rows, let columns):
            return generateTable(shape: shape, frame: frame, rows: rows, columns: columns)
        }
    }
    
    // MARK: - Text Box
    
    private static func generateTextBox(shape: PPTXShape, frame: PPTXFrame) -> String {
        var xml = """
                    <p:sp>
                        <p:nvSpPr>
                            <p:cNvPr id="\(shape.id)" name="\(shape.name)"/>
                            <p:cNvSpPr txBox="1"/>
                            <p:nvPr/>
                        </p:nvSpPr>
                        <p:spPr>
                            <a:xfrm>
                                <a:off x="\(frame.x)" y="\(frame.y)"/>
                                <a:ext cx="\(frame.width)" cy="\(frame.height)"/>
                            </a:xfrm>
                            <a:prstGeom prst="rect">
                                <a:avLst/>
                            </a:prstGeom>
                            <a:noFill/>
                        </p:spPr>
                        <p:txBody>
                            <a:bodyPr wrap="square" lIns="91440" tIns="45720" rIns="91440" bIns="45720">
                                <a:spAutoFit/>
                            </a:bodyPr>
                            <a:lstStyle/>
        """
        
        // Add paragraphs
        for paragraph in shape.paragraphs {
            xml += "\n" + generateParagraph(paragraph)
        }
        
        xml += """
        
                        </p:txBody>
                    </p:sp>
        """
        
        return xml
    }
    
    // MARK: - Paragraph Generation
    
    private static func generateParagraph(_ paragraph: PPTXParagraph) -> String {
        var xml = """
                            <a:p>
                                <a:pPr algn="\(paragraph.alignment.xmlValue)"
        """
        
        if let spaceBefore = paragraph.spaceBefore {
            xml += " spcBef=\"\(spaceBefore)\""
        }
        if let spaceAfter = paragraph.spaceAfter {
            xml += " spcAft=\"\(spaceAfter)\""
        }
        
        // Check if this is a bulleted paragraph
        let isBullet = paragraph.runs.first?.text.hasPrefix("• ") ?? false
        
        xml += ">"
        
        // Add bullet if needed
        if isBullet {
            xml += """
            
                                    <a:buChar char="•"/>
            """
        }
        
        if let lineSpacing = paragraph.lineSpacing {
            xml += """
            
                                    <a:lnSpc>
                                        <a:spcPct val="\(lineSpacing)000"/>
                                    </a:lnSpc>
            """
        }
        
        xml += """
        
                                </a:pPr>
        """
        
        // Add text runs
        for (index, run) in paragraph.runs.enumerated() {
            // Skip bullet character in text if this is the first run of a bulleted paragraph
            if isBullet && index == 0 {
                var modifiedRun = run
                let text = run.text
                if text.hasPrefix("• ") {
                    modifiedRun = PPTXTextRun(
                        text: String(text.dropFirst(2)),
                        style: run.style
                    )
                }
                xml += "\n" + generateTextRun(modifiedRun)
            } else {
                xml += "\n" + generateTextRun(run)
            }
        }
        
        xml += """
        
                            </a:p>
        """
        
        return xml
    }
    
    // MARK: - Text Run Generation
    
    private static func generateTextRun(_ run: PPTXTextRun) -> String {
        var xml = """
                                <a:r>
                                    <a:rPr lang="en-US"
        """
        
        if let fontSize = run.style.fontSize {
            xml += " sz=\"\(fontSize)\""
        }
        if run.style.bold {
            xml += " b=\"1\""
        }
        if run.style.italic {
            xml += " i=\"1\""
        }
        if run.style.underline {
            xml += " u=\"sng\""
        }
        
        xml += ">"
        
        // Add font
        xml += """
        
                                        <a:latin typeface="\(run.style.fontFamily)"/>
        """
        
        // Add color
        xml += """
        
                                        <a:solidFill>
                                            <a:srgbClr val="\(run.style.color)"/>
                                        </a:solidFill>
                                    </a:rPr>
                                    <a:t>\(PPTXXMLGenerator.escapeXML(run.text))</a:t>
                                </a:r>
        """
        
        return xml
    }
    
    // MARK: - Image Shape
    
    private static func generateImage(shape: PPTXShape, frame: PPTXFrame) -> String {
        // Image relationships are handled separately
        return """
                    <p:pic>
                        <p:nvPicPr>
                            <p:cNvPr id="\(shape.id)" name="\(shape.name)"/>
                            <p:cNvPicPr>
                                <a:picLocks noChangeAspect="1"/>
                            </p:cNvPicPr>
                            <p:nvPr/>
                        </p:nvPicPr>
                        <p:blipFill>
                            <a:blip r:embed="rId\(shape.id)"/>
                            <a:stretch>
                                <a:fillRect/>
                            </a:stretch>
                        </p:blipFill>
                        <p:spPr>
                            <a:xfrm>
                                <a:off x="\(frame.x)" y="\(frame.y)"/>
                                <a:ext cx="\(frame.width)" cy="\(frame.height)"/>
                            </a:xfrm>
                            <a:prstGeom prst="rect">
                                <a:avLst/>
                            </a:prstGeom>
                        </p:spPr>
                    </p:pic>
        """
    }
    
    // MARK: - Rectangle Shape
    
    private static func generateRectangle(shape: PPTXShape, frame: PPTXFrame, fillColor: String?) -> String {
        var xml = """
                    <p:sp>
                        <p:nvSpPr>
                            <p:cNvPr id="\(shape.id)" name="\(shape.name)"/>
                            <p:cNvSpPr/>
                            <p:nvPr/>
                        </p:nvSpPr>
                        <p:spPr>
                            <a:xfrm>
                                <a:off x="\(frame.x)" y="\(frame.y)"/>
                                <a:ext cx="\(frame.width)" cy="\(frame.height)"/>
                            </a:xfrm>
                            <a:prstGeom prst="rect">
                                <a:avLst/>
                            </a:prstGeom>
        """
        
        if let color = fillColor {
            xml += """
            
                            <a:solidFill>
                                <a:srgbClr val="\(color)"/>
                            </a:solidFill>
            """
        } else {
            xml += """
            
                            <a:noFill/>
            """
        }
        
        xml += """
        
                        </p:spPr>
                    </p:sp>
        """
        
        return xml
    }
    
    // MARK: - Line Shape
    
    private static func generateLine(shape: PPTXShape, x1: Int, y1: Int, x2: Int, y2: Int,
                                   strokeColor: String, strokeWidth: Int) -> String {
        let minX = min(x1, x2)
        let minY = min(y1, y2)
        let width = abs(x2 - x1)
        let height = abs(y2 - y1)
        
        // Determine if line needs to be flipped
        let flipH = x2 < x1
        let flipV = y2 < y1
        
        var xml = """
                    <p:cxnSp>
                        <p:nvCxnSpPr>
                            <p:cNvPr id="\(shape.id)" name="\(shape.name)"/>
                            <p:cNvCxnSpPr/>
                            <p:nvPr/>
                        </p:nvCxnSpPr>
                        <p:spPr>
                            <a:xfrm
        """
        
        if flipH {
            xml += " flipH=\"1\""
        }
        if flipV {
            xml += " flipV=\"1\""
        }
        
        xml += """
        >
                                <a:off x="\(minX)" y="\(minY)"/>
                                <a:ext cx="\(width)" cy="\(height)"/>
                            </a:xfrm>
                            <a:prstGeom prst="line">
                                <a:avLst/>
                            </a:prstGeom>
                            <a:ln w="\(strokeWidth)">
                                <a:solidFill>
                                    <a:srgbClr val="\(strokeColor)"/>
                                </a:solidFill>
                            </a:ln>
                        </p:spPr>
                    </p:cxnSp>
        """
        
        return xml
    }
    
    // MARK: - Background Generation
    
    private static func generateBackground(_ background: PPTXBackground) -> String {
        switch background {
        case .solid(let color):
            return """
                    <p:bg>
                        <p:bgPr>
                            <a:solidFill>
                                <a:srgbClr val="\(color)"/>
                            </a:solidFill>
                        </p:bgPr>
                    </p:bg>
            """
        case .gradient(let colors, let angle):
            // Simplified gradient - just use first and last colors
            let startColor = colors.first ?? "FFFFFF"
            let endColor = colors.last ?? "000000"
            let angleInDegrees = Int(angle * 60000) // Convert to 60000ths of a degree
            
            return """
                    <p:bg>
                        <p:bgPr>
                            <a:gradFill rotWithShape="1">
                                <a:gsLst>
                                    <a:gs pos="0">
                                        <a:srgbClr val="\(startColor)"/>
                                    </a:gs>
                                    <a:gs pos="100000">
                                        <a:srgbClr val="\(endColor)"/>
                                    </a:gs>
                                </a:gsLst>
                                <a:lin ang="\(angleInDegrees)" scaled="0"/>
                            </a:gradFill>
                        </p:bgPr>
                    </p:bg>
            """
        case .image(_, _):
            // Image backgrounds would require more complex handling
            // For now, return empty string
            return ""
        case .pattern(_, let color):
            // Patterns require theme definitions - using solid color fallback
            return """
                    <p:bg>
                        <p:bgPr>
                            <a:solidFill>
                                <a:srgbClr val="\(color)"/>
                            </a:solidFill>
                        </p:bgPr>
                    </p:bg>
            """
        }
    }
    
    // MARK: - Table Generation
    
    private static func generateTable(shape: PPTXShape, frame: PPTXFrame, rows: Int, columns: Int) -> String {
        let cellWidth = frame.width / columns
        let cellHeight = frame.height / rows
        
        var xml = """
                    <p:graphicFrame>
                        <p:nvGraphicFramePr>
                            <p:cNvPr id="\(shape.id)" name="\(shape.name)"/>
                            <p:cNvGraphicFramePr>
                                <a:graphicFrameLocks noGrp="1"/>
                            </p:cNvGraphicFramePr>
                            <p:nvPr/>
                        </p:nvGraphicFramePr>
                        <p:xfrm>
                            <a:off x="\(frame.x)" y="\(frame.y)"/>
                            <a:ext cx="\(frame.width)" cy="\(frame.height)"/>
                        </p:xfrm>
                        <a:graphic>
                            <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table">
                                <a:tbl>
                                    <a:tblPr>
                                        <a:tableStyleId>{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}</a:tableStyleId>
                                    </a:tblPr>
                                    <a:tblGrid>
        """
        
        // Table grid columns
        for _ in 0..<columns {
            xml += """
            
                                        <a:gridCol w="\(cellWidth)"/>
            """
        }
        
        xml += """
        
                                    </a:tblGrid>
        """
        
        // Table rows
        for rowIndex in 0..<rows {
            xml += """
            
                                    <a:tr h="\(cellHeight)">
            """
            
            // Table cells
            for colIndex in 0..<columns {
                let cell = shape.tableCells[safe: rowIndex]?[safe: colIndex]
                
                xml += """
                
                                        <a:tc>
                """
                
                // Cell text
                if let cell = cell {
                    xml += """
                    
                                            <a:txBody>
                                                <a:bodyPr/>
                                                <a:lstStyle/>
                    """
                    
                    for paragraph in cell.paragraphs {
                        xml += "\n" + generateParagraph(paragraph)
                    }
                    
                    xml += """
                    
                                            </a:txBody>
                    """
                }
                
                // Cell properties
                xml += """
                
                                            <a:tcPr>
                """
                
                if let fillColor = cell?.fillColor {
                    xml += """
                    
                                                <a:solidFill>
                                                    <a:srgbClr val="\(fillColor)"/>
                                                </a:solidFill>
                    """
                }
                
                xml += """
                
                                            </a:tcPr>
                                        </a:tc>
                """
            }
            
            xml += """
            
                                    </a:tr>
            """
        }
        
        xml += """
        
                                </a:tbl>
                            </a:graphicData>
                        </a:graphic>
                    </p:graphicFrame>
        """
        
        return xml
    }
}

// Safe subscript extension
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
