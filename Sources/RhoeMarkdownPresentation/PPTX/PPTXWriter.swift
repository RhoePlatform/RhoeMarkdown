//
//  PPTXWriter.swift
//  RhoeMarkdownKit
//
//  Writes PPTX files from markdown presentations
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering
#if canImport(Compression)
import Compression
#endif

/// Writes PPTX presentations to disk
public struct PPTXWriter {
    
    /// Write a markdown presentation as PPTX
    public static func write(
        presentation: Presentation,
        to url: URL
    ) throws {
        // Convert markdown to PPTX structure
        let converter = PPTXMarkdownConverter()
        let pptx = converter.convert(presentation: presentation)
        
        // Create temporary directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        
        defer {
            // Clean up temp directory
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Create PPTX structure
        try createPPTXStructure(pptx: pptx, in: tempDir)
        
        // Zip the directory
        try createZipArchive(from: tempDir, to: url)
    }
    
    // MARK: - Directory Structure
    
    private static func createPPTXStructure(
        pptx: PPTXPresentation,
        in directory: URL
    ) throws {
        // Create directories
        let dirs = [
            "_rels",
            "docProps",
            "ppt",
            "ppt/_rels",
            "ppt/slides",
            "ppt/slides/_rels",
            "ppt/slideLayouts",
            "ppt/slideLayouts/_rels",
            "ppt/slideMasters",
            "ppt/slideMasters/_rels",
            "ppt/theme",
            "ppt/media"
        ]
        
        for dir in dirs {
            try FileManager.default.createDirectory(
                at: directory.appendingPathComponent(dir),
                withIntermediateDirectories: true
            )
        }
        
        // Write files
        try writeContentTypes(pptx: pptx, to: directory)
        try writePackageRels(to: directory)
        try writeProperties(pptx: pptx, to: directory)
        try writePresentation(pptx: pptx, to: directory)
        try writeTheme(to: directory)
        try writeMasters(to: directory)
        try writeSlides(pptx: pptx, to: directory)
    }
    
    // MARK: - File Writers
    
    private static func writeContentTypes(pptx: PPTXPresentation, to dir: URL) throws {
        let content = PPTXXMLGenerator.generateContentTypes(
            slideCount: pptx.slides.count,
            hasImages: false  // 0.1.0 writes shape/text slides; media parts are deferred.
        )
        let url = dir.appendingPathComponent("[Content_Types].xml")
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private static func writePackageRels(to dir: URL) throws {
        let content = PPTXXMLGenerator.generatePackageRels()
        let url = dir.appendingPathComponent("_rels/.rels")
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private static func writeProperties(pptx: PPTXPresentation, to dir: URL) throws {
        // Core properties
        let core = PPTXXMLGenerator.generateCoreProperties(
            title: pptx.title,
            author: pptx.author
        )
        try core.write(
            to: dir.appendingPathComponent("docProps/core.xml"),
            atomically: true,
            encoding: .utf8
        )
        
        // App properties
        let app = PPTXXMLGenerator.generateAppProperties(
            slideCount: pptx.slides.count
        )
        try app.write(
            to: dir.appendingPathComponent("docProps/app.xml"),
            atomically: true,
            encoding: .utf8
        )
    }
    
    private static func writePresentation(pptx: PPTXPresentation, to dir: URL) throws {
        // Presentation.xml
        let pres = PPTXXMLGenerator.generatePresentation(
            slideCount: pptx.slides.count,
            width: pptx.slideWidth,
            height: pptx.slideHeight
        )
        try pres.write(
            to: dir.appendingPathComponent("ppt/presentation.xml"),
            atomically: true,
            encoding: .utf8
        )
        
        // Presentation rels
        let rels = PPTXXMLGenerator.generatePresentationRels(
            slideCount: pptx.slides.count
        )
        try rels.write(
            to: dir.appendingPathComponent("ppt/_rels/presentation.xml.rels"),
            atomically: true,
            encoding: .utf8
        )
    }
    
    private static func writeTheme(to dir: URL) throws {
        let theme = PPTXXMLGenerator.generateMinimalTheme()
        try theme.write(
            to: dir.appendingPathComponent("ppt/theme/theme1.xml"),
            atomically: true,
            encoding: .utf8
        )
    }
    
    private static func writeMasters(to dir: URL) throws {
        // Slide master
        let master = PPTXMasterGenerator.generateSlideMaster()
        try master.write(
            to: dir.appendingPathComponent("ppt/slideMasters/slideMaster1.xml"),
            atomically: true,
            encoding: .utf8
        )
        
        // Master rels
        let masterRels = PPTXMasterGenerator.generateSlideMasterRels()
        try masterRels.write(
            to: dir.appendingPathComponent("ppt/slideMasters/_rels/slideMaster1.xml.rels"),
            atomically: true,
            encoding: .utf8
        )
        
        // Slide layout
        let layout = PPTXMasterGenerator.generateSlideLayout()
        try layout.write(
            to: dir.appendingPathComponent("ppt/slideLayouts/slideLayout1.xml"),
            atomically: true,
            encoding: .utf8
        )
        
        // Layout rels
        let layoutRels = PPTXMasterGenerator.generateSlideLayoutRels()
        try layoutRels.write(
            to: dir.appendingPathComponent("ppt/slideLayouts/_rels/slideLayout1.xml.rels"),
            atomically: true,
            encoding: .utf8
        )
    }
    
    private static func writeSlides(pptx: PPTXPresentation, to dir: URL) throws {
        for (index, slide) in pptx.slides.enumerated() {
            let slideNum = index + 1
            
            // Slide XML
            let slideXML = PPTXSlideGenerator.generateSlide(slide)
            try slideXML.write(
                to: dir.appendingPathComponent("ppt/slides/slide\(slideNum).xml"),
                atomically: true,
                encoding: .utf8
            )
            
            // Slide rels (even if empty, PowerPoint expects this)
            let slideRels = PPTXSlideGenerator.generateSlideRels(
                slideId: slideNum,
                imageRels: []  // 0.1.0 does not emit slide media relationships.
            )
            try slideRels.write(
                to: dir.appendingPathComponent("ppt/slides/_rels/slide\(slideNum).xml.rels"),
                atomically: true,
                encoding: .utf8
            )
        }
    }
    
    // MARK: - Zip Creation
    
    private static func createZipArchive(from sourceDir: URL, to destination: URL) throws {
        // Create a temp zip file first
        let tempZip = sourceDir.appendingPathComponent("temp.zip")
        
        // Use the `zip` command
        let process = Process()
        process.currentDirectoryURL = sourceDir
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q", "temp.zip", "."]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw PPTXError.zipCreationFailed
        }
        
        // Move the temp zip to final destination
        try FileManager.default.moveItem(at: tempZip, to: destination)
    }
}

// MARK: - Errors

public enum PPTXError: LocalizedError {
    case zipCreationFailed
    case invalidPresentation
    
    public var errorDescription: String? {
        switch self {
        case .zipCreationFailed:
            return "Failed to create PPTX zip archive"
        case .invalidPresentation:
            return "Invalid presentation structure"
        }
    }
}
