import Foundation
import RhoeMarkdownModel

#if !os(WASI)

/// Generates PDF documents by piping through LaTeX or Typst writers
/// and compiling with external tools (`pdflatex`/`xelatex` or `typst`).
///
/// The writer delegates to the existing `LaTeXWriter` or `TypstWriter` for
/// intermediate markup generation, then shells out to the appropriate
/// compiler to produce PDF bytes. Returns empty `Data` if the required
/// compilation tool is not installed.
public struct PDFWriter: DocumentWriter, Sendable {
    public typealias Output = Data

    private let configuration: RhoeMarkdownKit.PDFConfiguration
    private let resourceBaseURL: URL?

    public init(
        configuration: RhoeMarkdownKit.PDFConfiguration = .default,
        resourceBaseURL: URL? = nil
    ) {
        self.configuration = configuration
        self.resourceBaseURL = resourceBaseURL
    }

    public func write(_ document: RhoeMarkdownKit.Document) -> Data {
        switch configuration.pipeline {
        case .latex:
            return compileLaTeX(document)
        case .typst:
            return compileTypst(document)
        case .webkit:
            // WebKit requires async + MainActor — use writeAsync() instead.
            // Synchronous fallback: try Typst, then LaTeX.
            let typstData = compileTypst(document)
            if !typstData.isEmpty { return typstData }
            return compileLaTeX(document)
        }
    }

    /// Async PDF generation — required for WebKit pipeline.
    @MainActor
    public func writeAsync(_ document: RhoeMarkdownKit.Document) async -> Data {
        #if canImport(WebKit) && (os(macOS) || os(iOS) || os(visionOS))
        if configuration.pipeline == .webkit {
            do {
                return try await compileWebKit(document)
            } catch {
                // Fall back to Typst/LaTeX
                let typstData = compileTypst(document)
                if !typstData.isEmpty { return typstData }
                return compileLaTeX(document)
            }
        }
        #endif

        return write(document)
    }

    /// Check if the required tool for the configured pipeline is available.
    public func isAvailable() -> Bool {
        switch configuration.pipeline {
        case .latex:
            return ToolDiscovery.findTool(named: "pdflatex") != nil
                || ToolDiscovery.findTool(named: "xelatex") != nil
        case .typst:
            return ToolDiscovery.findTool(named: "typst") != nil
        case .webkit:
            #if canImport(WebKit) && (os(macOS) || os(iOS) || os(visionOS))
            return true
            #else
            return false
            #endif
        }
    }

    // MARK: - WebKit Pipeline

    #if canImport(WebKit) && (os(macOS) || os(iOS) || os(visionOS))
    @MainActor
    private func compileWebKit(_ document: RhoeMarkdownKit.Document) async throws -> Data {
        // Render to full HTML with embedded CSS
        var htmlRenderer = RhoeHTMLRenderer(configuration: .init(
            prettyPrint: true,
            includeDefaultCSS: true,
            wrapInDocument: true
        ))
        let html = htmlRenderer.render(document)

        // Determine page settings from configuration
        let pageSize = PDFPageSize(name: configuration.paperSize) ?? .a4
        let orientation: PDFPageOrientation = configuration.orientation == "landscape" ? .landscape : .portrait
        let printCSS = RhoePrintCSS.documentCSS(pageSize: pageSize, orientation: orientation)

        // Inject print CSS before closing </style> or wrap at top
        let fullHTML: String
        if let range = html.range(of: "</style>") {
            var modified = html
            modified.insert(contentsOf: "\n\(printCSS)\n", at: range.lowerBound)
            fullHTML = modified
        } else {
            fullHTML = "<style>\(printCSS)</style>\n\(html)"
        }

        // Render via WebKit
        let renderer = WebKitPDFRenderer()
        return try await renderer.renderPDF(
            html: fullHTML,
            pageSize: pageSize,
            orientation: orientation,
            margins: .default,
            baseURL: resourceBaseURL
        )
    }
    #endif

    // MARK: - LaTeX Pipeline

    private func compileLaTeX(_ document: RhoeMarkdownKit.Document) -> Data {
        let latexConfig = RhoeMarkdownKit.LaTeXConfiguration(
            documentClass: "article",
            classOptions: [configuration.fontSize, configuration.paperSize == "letter" ? "letterpaper" : "a4paper"],
            generatePreamble: true,
            astNearEmission: false // Use flat LaTeX for pdflatex compatibility
        )
        let latex = LaTeXWriter(configuration: latexConfig).write(document)

        // Find compiler
        guard let compiler = ToolDiscovery.findTool(named: "pdflatex")
                          ?? ToolDiscovery.findTool(named: "xelatex") else {
            return Data()
        }

        // Create temp directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-latex-\(UUID().uuidString)")
        let texFile = tempDir.appendingPathComponent("document.tex")
        let pdfFile = tempDir.appendingPathComponent("document.pdf")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try latex.write(to: texFile, atomically: true, encoding: .utf8)
        } catch {
            return Data()
        }

        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Run pdflatex (twice for TOC/references)
        let runs = configuration.enableTableOfContents ? 2 : 1
        for _ in 0..<runs {
            guard let result = ToolDiscovery.runProcess(
                executablePath: compiler,
                arguments: ["-interaction=nonstopmode", "-output-directory=\(tempDir.path)", texFile.path],
                timeout: 60
            ), result.exitCode == 0 else {
                return Data()
            }
        }

        return (try? Data(contentsOf: pdfFile)) ?? Data()
    }

    // MARK: - Typst Pipeline

    private func compileTypst(_ document: RhoeMarkdownKit.Document) -> Data {
        let typstConfig = RhoeMarkdownKit.TypstConfiguration(
            paperSize: configuration.paperSize,
            fontSize: configuration.fontSize,
            generatePreamble: true
        )
        let typst = TypstWriter(configuration: typstConfig).write(document)

        guard let compiler = ToolDiscovery.findTool(named: "typst") else {
            return Data()
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-typst-\(UUID().uuidString)")
        let typFile = tempDir.appendingPathComponent("document.typ")
        let pdfFile = tempDir.appendingPathComponent("document.pdf")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try typst.write(to: typFile, atomically: true, encoding: .utf8)
        } catch {
            return Data()
        }

        defer { try? FileManager.default.removeItem(at: tempDir) }

        guard let result = ToolDiscovery.runProcess(
            executablePath: compiler,
            arguments: ["compile", typFile.path, pdfFile.path],
            timeout: 60
        ), result.exitCode == 0 else {
            return Data()
        }

        return (try? Data(contentsOf: pdfFile)) ?? Data()
    }
}

#endif
