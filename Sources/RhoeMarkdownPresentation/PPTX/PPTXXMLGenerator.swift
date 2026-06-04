//
//  PPTXXMLGenerator.swift
//  RhoeMarkdownKit
//
//  XML generation for PPTX files
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// Generates XML content for PPTX files
public struct PPTXXMLGenerator {
    
    // MARK: - Content Types
    
    static func generateContentTypes(slideCount: Int, hasImages: Bool) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
            <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
            <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
            <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
            <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
            <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
        """
        
        // Add slide content types
        for i in 1...slideCount {
            xml += """
            
            <Override PartName="/ppt/slides/slide\(i).xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
            """
        }
        
        // Add image types if needed
        if hasImages {
            xml += """
            
            <Default Extension="png" ContentType="image/png"/>
            <Default Extension="jpeg" ContentType="image/jpeg"/>
            <Default Extension="jpg" ContentType="image/jpeg"/>
            """
        }
        
        xml += "\n</Types>"
        return xml
    }
    
    // MARK: - Package Relationships
    
    static func generatePackageRels() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
            <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
            <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
        </Relationships>
        """
    }
    
    // MARK: - Core Properties
    
    static func generateCoreProperties(title: String?, author: String?) -> String {
        let now = ISO8601DateFormatter().string(from: Date())
        let escapedTitle = escapeXML(title ?? "Presentation")
        let escapedAuthor = escapeXML(author ?? "RhoeMarkdownKit")
        
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <dc:title>\(escapedTitle)</dc:title>
            <dc:creator>\(escapedAuthor)</dc:creator>
            <cp:lastModifiedBy>\(escapedAuthor)</cp:lastModifiedBy>
            <dcterms:created xsi:type="dcterms:W3CDTF">\(now)</dcterms:created>
            <dcterms:modified xsi:type="dcterms:W3CDTF">\(now)</dcterms:modified>
        </cp:coreProperties>
        """
    }
    
    // MARK: - App Properties
    
    static func generateAppProperties(slideCount: Int) -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
            <Application>RhoeMarkdownKit</Application>
            <PresentationFormat>On-screen Show (16:9)</PresentationFormat>
            <Slides>\(slideCount)</Slides>
            <ScaleCrop>false</ScaleCrop>
            <LinksUpToDate>false</LinksUpToDate>
            <SharedDoc>false</SharedDoc>
            <HyperlinksChanged>false</HyperlinksChanged>
            <AppVersion>1.0</AppVersion>
        </Properties>
        """
    }
    
    // MARK: - Presentation
    
    static func generatePresentation(slideCount: Int, width: Int, height: Int) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
            <p:sldMasterIdLst>
                <p:sldMasterId id="2147483648" r:id="rId1"/>
            </p:sldMasterIdLst>
            <p:sldIdLst>
        """
        
        // Add slide references
        for i in 1...slideCount {
            xml += """
            
                <p:sldId id="\(255 + i)" r:id="rId\(i + 1)"/>
            """
        }
        
        xml += """
        
            </p:sldIdLst>
            <p:sldSz cx="\(width)" cy="\(height)"/>
            <p:notesSz cx="\(height)" cy="\(width)"/>
        </p:presentation>
        """
        
        return xml
    }
    
    // MARK: - Presentation Relationships
    
    static func generatePresentationRels(slideCount: Int) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
        """
        
        // Add slide relationships
        for i in 1...slideCount {
            xml += """
            
            <Relationship Id="rId\(i + 1)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide\(i).xml"/>
            """
        }
        
        xml += """
        
            <Relationship Id="rId\(slideCount + 2)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>
        </Relationships>
        """
        
        return xml
    }
    
    // MARK: - Minimal Theme
    
    static func generateMinimalTheme() -> String {
        // This is a minimal theme that PowerPoint will accept
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Minimal">
            <a:themeElements>
                <a:clrScheme name="Minimal">
                    <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
                    <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
                    <a:dk2><a:srgbClr val="1F497D"/></a:dk2>
                    <a:lt2><a:srgbClr val="EEECE1"/></a:lt2>
                    <a:accent1><a:srgbClr val="4F81BD"/></a:accent1>
                    <a:accent2><a:srgbClr val="C0504D"/></a:accent2>
                    <a:accent3><a:srgbClr val="9BBB59"/></a:accent3>
                    <a:accent4><a:srgbClr val="8064A2"/></a:accent4>
                    <a:accent5><a:srgbClr val="4BACC6"/></a:accent5>
                    <a:accent6><a:srgbClr val="F79646"/></a:accent6>
                    <a:hlink><a:srgbClr val="0000FF"/></a:hlink>
                    <a:folHlink><a:srgbClr val="800080"/></a:folHlink>
                </a:clrScheme>
                <a:fontScheme name="Minimal">
                    <a:majorFont>
                        <a:latin typeface="Arial"/>
                        <a:ea typeface=""/>
                        <a:cs typeface=""/>
                    </a:majorFont>
                    <a:minorFont>
                        <a:latin typeface="Arial"/>
                        <a:ea typeface=""/>
                        <a:cs typeface=""/>
                    </a:minorFont>
                </a:fontScheme>
                <a:fmtScheme name="Minimal">
                    <a:fillStyleLst>
                        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
                        <a:gradFill rotWithShape="1">
                            <a:gsLst>
                                <a:gs pos="0"><a:schemeClr val="phClr"/></a:gs>
                                <a:gs pos="100000"><a:schemeClr val="phClr"/></a:gs>
                            </a:gsLst>
                            <a:lin ang="2700000" scaled="1"/>
                        </a:gradFill>
                        <a:noFill/>
                    </a:fillStyleLst>
                    <a:lnStyleLst>
                        <a:ln w="9525" cap="flat" cmpd="sng" algn="ctr">
                            <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
                            <a:prstDash val="solid"/>
                        </a:ln>
                        <a:ln w="25400" cap="flat" cmpd="sng" algn="ctr">
                            <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
                            <a:prstDash val="solid"/>
                        </a:ln>
                        <a:ln w="38100" cap="flat" cmpd="sng" algn="ctr">
                            <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
                            <a:prstDash val="solid"/>
                        </a:ln>
                    </a:lnStyleLst>
                    <a:effectStyleLst>
                        <a:effectStyle><a:effectLst/></a:effectStyle>
                        <a:effectStyle><a:effectLst/></a:effectStyle>
                        <a:effectStyle><a:effectLst/></a:effectStyle>
                    </a:effectStyleLst>
                    <a:bgFillStyleLst>
                        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
                        <a:gradFill rotWithShape="1">
                            <a:gsLst>
                                <a:gs pos="0"><a:schemeClr val="phClr"/></a:gs>
                                <a:gs pos="100000"><a:schemeClr val="phClr"/></a:gs>
                            </a:gsLst>
                            <a:lin ang="2700000" scaled="1"/>
                        </a:gradFill>
                        <a:noFill/>
                    </a:bgFillStyleLst>
                </a:fmtScheme>
            </a:themeElements>
            <a:objectDefaults/>
            <a:extraClrSchemeLst/>
        </a:theme>
        """
    }
    
    // MARK: - Utilities
    
    /// Escape special XML characters
    static func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}