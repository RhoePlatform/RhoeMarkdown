import Foundation
import RhoeMarkdownModel
import RhoeMarkdownPresentation
import RhoeMarkdownRendering

#if canImport(PDFKit)
import PDFKit
#endif

#if os(macOS)
import WebKit
#endif

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public extension RhoeMarkdownKit {
    enum RenderBackend: String, Sendable, Equatable {
        case presentationHTMLPDF = "presentation_html_pdf"
        case typst
        case latex
    }

    enum RenderSelection: Sendable, Equatable {
        case deck
        case slide(index: Int)

        public var selectedSlideIndex: Int? {
            switch self {
            case .deck:
                return nil
            case .slide(let index):
                return index
            }
        }
    }

    struct RenderPageMetadata: Sendable, Equatable {
        public let pageIndex: Int
        public let label: String?
        public let pointWidth: Double
        public let pointHeight: Double

        public init(pageIndex: Int, label: String?, pointWidth: Double, pointHeight: Double) {
            self.pageIndex = pageIndex
            self.label = label
            self.pointWidth = pointWidth
            self.pointHeight = pointHeight
        }
    }

    struct RenderPipelineCapability: Sendable, Equatable {
        public let pipeline: PDFConfiguration.PDFPipeline
        public let toolPath: String?

        public init(pipeline: PDFConfiguration.PDFPipeline, toolPath: String?) {
            self.pipeline = pipeline
            self.toolPath = toolPath
        }

        public var isAvailable: Bool { toolPath != nil }
    }

    struct RenderCapabilities: Sendable, Equatable {
        public let preferredPipeline: PDFConfiguration.PDFPipeline
        public let pipelines: [RenderPipelineCapability]

        public init(
            preferredPipeline: PDFConfiguration.PDFPipeline,
            pipelines: [RenderPipelineCapability]
        ) {
            self.preferredPipeline = preferredPipeline
            self.pipelines = pipelines
        }

        public var canRenderPDF: Bool {
            pipelines.contains(where: \.isAvailable)
        }
    }

    struct PDFRenderResult: Sendable {
        public let pdfData: Data
        public let selection: RenderSelection
        public let sourcePageCount: Int
        public let outputPageCount: Int
        public let selectedPage: RenderPageMetadata?
        public let pages: [RenderPageMetadata]
        public let diagnostics: [Diagnostic]
        public let backend: RenderBackend
        public let toolPath: String?

        public init(
            pdfData: Data,
            selection: RenderSelection,
            sourcePageCount: Int,
            outputPageCount: Int,
            selectedPage: RenderPageMetadata?,
            pages: [RenderPageMetadata],
            diagnostics: [Diagnostic],
            backend: RenderBackend,
            toolPath: String?
        ) {
            self.pdfData = pdfData
            self.selection = selection
            self.sourcePageCount = sourcePageCount
            self.outputPageCount = outputPageCount
            self.selectedPage = selectedPage
            self.pages = pages
            self.diagnostics = diagnostics
            self.backend = backend
            self.toolPath = toolPath
        }
    }

    struct PNGRasterizationConfiguration: Sendable, Equatable {
        public let targetWidth: Int

        public init(targetWidth: Int = 1600) {
            self.targetWidth = max(1, targetWidth)
        }

        public static let `default` = PNGRasterizationConfiguration()
    }

    struct RenderedPNGPage: Sendable, Equatable {
        public let metadata: RenderPageMetadata
        public let pngData: Data

        public init(metadata: RenderPageMetadata, pngData: Data) {
            self.metadata = metadata
            self.pngData = pngData
        }
    }

    struct PNGRenderResult: Sendable {
        public let selection: RenderSelection
        public let sourcePageCount: Int
        public let pages: [RenderedPNGPage]
        public let diagnostics: [Diagnostic]
        public let backend: RenderBackend
        public let toolPath: String?

        public init(
            selection: RenderSelection,
            sourcePageCount: Int,
            pages: [RenderedPNGPage],
            diagnostics: [Diagnostic],
            backend: RenderBackend,
            toolPath: String?
        ) {
            self.selection = selection
            self.sourcePageCount = sourcePageCount
            self.pages = pages
            self.diagnostics = diagnostics
            self.backend = backend
            self.toolPath = toolPath
        }
    }

    enum RenderError: Error, LocalizedError, Equatable {
        case toolUnavailable(pipeline: PDFConfiguration.PDFPipeline)
        case compilationFailed(pipeline: PDFConfiguration.PDFPipeline)
        case invalidSelectedSlideIndex(index: Int, availableSlides: Int)
        case nonPresentationSelection
        case unreadableRenderedPDF
        case selectedPageUnavailable(index: Int)
        case rasterizationUnavailable

        public var errorDescription: String? {
            switch self {
            case .toolUnavailable(let pipeline):
                return "No PDF compiler tool is available for the \(pipeline.rawValue) pipeline."
            case .compilationFailed(let pipeline):
                return "The \(pipeline.rawValue) PDF compilation failed."
            case .invalidSelectedSlideIndex(let index, let availableSlides):
                return "Selected slide index \(index) is out of range for \(availableSlides) slide(s)."
            case .nonPresentationSelection:
                return "Slide selection requires a presentation with at least one slide."
            case .unreadableRenderedPDF:
                return "The rendered PDF could not be decoded for page inspection."
            case .selectedPageUnavailable(let index):
                return "The rendered PDF did not contain page \(index)."
            case .rasterizationUnavailable:
                return "PNG rasterization is unavailable on this platform."
            }
        }
    }

    static func renderingCapabilities(
        configuration: PDFConfiguration = .default
    ) -> RenderCapabilities {
        RenderCapabilities(
            preferredPipeline: configuration.pipeline,
            pipelines: PDFConfiguration.PDFPipeline.allCases.map { pipeline in
                RenderPipelineCapability(
                    pipeline: pipeline,
                    toolPath: toolPath(for: pipeline)
                )
            }
        )
    }

    static func renderPDF(
        _ document: Document,
        selection: RenderSelection,
        resourceBaseURL: URL? = nil,
        configuration: PDFConfiguration = .default
    ) async throws -> PDFRenderResult {
        try await renderPDF(
            toRhoeMarkdown(document),
            selection: selection,
            resourceBaseURL: resourceBaseURL,
            configuration: configuration
        )
    }

    static func renderPDF(
        _ markdown: String,
        selection: RenderSelection,
        resourceBaseURL: URL? = nil,
        configuration: PDFConfiguration = .default
    ) async throws -> PDFRenderResult {
        let parseResult = await parse(markdown)
        let presentation = try await PresentationParser().parse(markdown)

        if !presentation.presentation.slides.isEmpty {
            #if os(macOS)
            return try await renderPresentationPDF(
                presentation: presentation.presentation,
                selection: selection,
                diagnostics: parseResult.diagnostics,
                resourceBaseURL: resourceBaseURL
            )
            #else
            if case .slide = selection {
                throw RenderError.rasterizationUnavailable
            }
            #endif
        }

        if case .slide = selection {
            throw RenderError.nonPresentationSelection
        }

        let rendered = try await renderGenericPDF(
            parseResult.document,
            selection: selection,
            diagnostics: parseResult.diagnostics,
            resourceBaseURL: resourceBaseURL,
            configuration: configuration
        )
        return rendered
    }

    static func renderPNG(
        _ document: Document,
        selection: RenderSelection,
        resourceBaseURL: URL? = nil,
        configuration: PDFConfiguration = .default,
        rasterization: PNGRasterizationConfiguration = .default
    ) async throws -> PNGRenderResult {
        let pdf = try await renderPDF(document, selection: selection, resourceBaseURL: resourceBaseURL, configuration: configuration)
        return try rasterize(pdf, rasterization: rasterization)
    }

    static func renderPNG(
        _ markdown: String,
        selection: RenderSelection,
        resourceBaseURL: URL? = nil,
        configuration: PDFConfiguration = .default,
        rasterization: PNGRasterizationConfiguration = .default
    ) async throws -> PNGRenderResult {
        let pdf = try await renderPDF(markdown, selection: selection, resourceBaseURL: resourceBaseURL, configuration: configuration)
        return try rasterize(pdf, rasterization: rasterization)
    }
}

private extension RhoeMarkdownKit {
    static func renderGenericPDF(
        _ document: Document,
        selection: RenderSelection,
        diagnostics: [Diagnostic],
        resourceBaseURL: URL?,
        configuration: PDFConfiguration
    ) async throws -> PDFRenderResult {
        let writer = PDFWriter(configuration: configuration, resourceBaseURL: resourceBaseURL)
        guard writer.isAvailable() else {
            throw RenderError.toolUnavailable(pipeline: configuration.pipeline)
        }

        let pdfData: Data
        if configuration.pipeline == .webkit {
            pdfData = await writer.writeAsync(document)
        } else {
            pdfData = writer.write(document)
        }
        guard !pdfData.isEmpty else {
            throw RenderError.compilationFailed(pipeline: configuration.pipeline)
        }

        let backend: RenderBackend
        switch configuration.pipeline {
        case .typst:
            backend = .typst
        case .latex:
            backend = .latex
        case .webkit:
            backend = .presentationHTMLPDF
        }

        return try makePDFRenderResult(
            pdfData: pdfData,
            selection: selection,
            diagnostics: diagnostics,
            backend: backend,
            toolPath: toolPath(for: configuration.pipeline)
        )
    }

    static func makePDFRenderResult(
        pdfData: Data,
        selection: RenderSelection,
        diagnostics: [Diagnostic],
        backend: RenderBackend,
        toolPath: String?
    ) throws -> PDFRenderResult {
        #if canImport(PDFKit)
        guard let pdfDocument = PDFDocument(data: pdfData) else {
            throw RenderError.unreadableRenderedPDF
        }

        let sourcePages = metadata(for: pdfDocument)
        let selectedIndices = try selectedPageIndices(
            for: selection,
            sourcePageCount: sourcePages.count
        )

        let outputData: Data
        let outputPages: [RenderPageMetadata]
        let selectedPage = selectedIndices.first.flatMap { sourcePages[$0] }

        if selectedIndices.count == sourcePages.count {
            outputData = pdfData
            outputPages = sourcePages
        } else {
            let subset = PDFDocument()
            for (position, index) in selectedIndices.enumerated() {
                guard let page = pdfDocument.page(at: index) else {
                    throw RenderError.selectedPageUnavailable(index: index)
                }
                subset.insert(page, at: position)
            }
            guard let subsetData = subset.dataRepresentation() else {
                throw RenderError.unreadableRenderedPDF
            }
            outputData = subsetData
            outputPages = metadata(for: subset)
        }

        return PDFRenderResult(
            pdfData: outputData,
            selection: selection,
            sourcePageCount: sourcePages.count,
            outputPageCount: outputPages.count,
            selectedPage: selectedPage,
            pages: outputPages,
            diagnostics: diagnostics,
            backend: backend,
            toolPath: toolPath
        )
        #else
        throw RenderError.rasterizationUnavailable
        #endif
    }

    static func rasterize(
        _ result: PDFRenderResult,
        rasterization: PNGRasterizationConfiguration
    ) throws -> PNGRenderResult {
        #if canImport(PDFKit)
        guard let pdfDocument = PDFDocument(data: result.pdfData) else {
            throw RenderError.unreadableRenderedPDF
        }

        var pages: [RenderedPNGPage] = []
        pages.reserveCapacity(result.pages.count)

        for (index, metadata) in result.pages.enumerated() {
            guard let page = pdfDocument.page(at: index) else {
                throw RenderError.selectedPageUnavailable(index: index)
            }
            let pngData = try pngData(
                for: page,
                metadata: metadata,
                targetWidth: rasterization.targetWidth
            )
            pages.append(RenderedPNGPage(metadata: metadata, pngData: pngData))
        }

        return PNGRenderResult(
            selection: result.selection,
            sourcePageCount: result.sourcePageCount,
            pages: pages,
            diagnostics: result.diagnostics,
            backend: result.backend,
            toolPath: result.toolPath
        )
        #else
        throw RenderError.rasterizationUnavailable
        #endif
    }

    static func toolPath(for pipeline: PDFConfiguration.PDFPipeline) -> String? {
        switch pipeline {
        case .typst:
            return ToolDiscovery.findTool(named: "typst")
        case .latex:
            return ToolDiscovery.findTool(named: "pdflatex")
                ?? ToolDiscovery.findTool(named: "xelatex")
        case .webkit:
            return nil
        }
    }

    #if os(macOS)
    @MainActor
    static func renderPresentationPDF(
        presentation: Presentation,
        selection: RenderSelection,
        diagnostics: [Diagnostic],
        resourceBaseURL: URL?
    ) async throws -> PDFRenderResult {
        let selectedSlides = try selectedPresentationSlides(
            for: selection,
            from: presentation.slides
        )
        let pdfDocument = PDFDocument()
        var outputPages: [RenderPageMetadata] = []
        outputPages.reserveCapacity(selectedSlides.count)

        for (outputIndex, selectedSlide) in selectedSlides.enumerated() {
            let slidePresentation = Presentation(
                frontmatter: presentation.frontmatter,
                slides: [selectedSlide.slide],
                metadata: presentation.metadata
            )
            let renderer = ShapeHTMLRenderer(
                presentation: slidePresentation,
                options: .init(
                    slideWidth: 1600,
                    slideHeight: 900,
                    includeNavigation: false,
                    includeStyles: true
                )
            )
            let slidePDF = try await renderHTMLToPDF(
                renderer.render(),
                size: CGSize(width: 1600, height: 900),
                baseURL: resourceBaseURL
            )
            guard let slideDocument = PDFDocument(data: slidePDF),
                  let page = slideDocument.page(at: 0) else {
                throw RenderError.unreadableRenderedPDF
            }
            pdfDocument.insert(page, at: outputIndex)
            let bounds = page.bounds(for: .mediaBox)
            outputPages.append(
                RenderPageMetadata(
                    pageIndex: selectedSlide.sourceIndex,
                    label: page.label,
                    pointWidth: bounds.width,
                    pointHeight: bounds.height
                )
            )
        }

        guard let combinedData = pdfDocument.dataRepresentation() else {
            throw RenderError.unreadableRenderedPDF
        }

        return PDFRenderResult(
            pdfData: combinedData,
            selection: selection,
            sourcePageCount: presentation.slides.count,
            outputPageCount: outputPages.count,
            selectedPage: outputPages.first,
            pages: outputPages,
            diagnostics: diagnostics,
            backend: .presentationHTMLPDF,
            toolPath: nil
        )
    }

    static func selectedPresentationSlides(
        for selection: RenderSelection,
        from slides: [Slide]
    ) throws -> [(sourceIndex: Int, slide: Slide)] {
        switch selection {
        case .deck:
            return Array(slides.enumerated()).map { ($0.offset, $0.element) }
        case .slide(let index):
            guard slides.indices.contains(index) else {
                throw RenderError.invalidSelectedSlideIndex(index: index, availableSlides: slides.count)
            }
            return [(index, slides[index])]
        }
    }

    @MainActor
    static func renderHTMLToPDF(_ html: String, size: CGSize, baseURL: URL? = nil) async throws -> Data {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(origin: .zero, size: size), configuration: configuration)
        let delegate = RenderNavigationDelegate()
        webView.navigationDelegate = delegate
        webView.setValue(false, forKey: "drawsBackground")
        webView.loadHTMLString(html, baseURL: baseURL)
        try await delegate.waitUntilFinished()
        try await waitForSnapshotReadiness(in: webView)
        return webView.dataWithPDF(inside: webView.bounds)
    }

    @MainActor
    static func waitForSnapshotReadiness(in webView: WKWebView) async throws {
        for _ in 0..<20 {
            let isReady = try await evaluateJavaScriptBoolean(
                """
                document.readyState === "complete" && (!document.fonts || document.fonts.status === "loaded")
                """,
                in: webView
            )
            if isReady {
                return
            }
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    @MainActor
    static func evaluateJavaScriptBoolean(
        _ script: String,
        in webView: WKWebView
    ) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { value, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let boolValue = value as? Bool {
                    continuation.resume(returning: boolValue)
                    return
                }

                if let numberValue = value as? NSNumber {
                    continuation.resume(returning: numberValue.boolValue)
                    return
                }

                continuation.resume(returning: false)
            }
        }
    }
    #endif

    #if canImport(PDFKit)
    static func metadata(for document: PDFDocument) -> [RenderPageMetadata] {
        (0..<document.pageCount).compactMap { index in
            guard let page = document.page(at: index) else { return nil }
            let bounds = page.bounds(for: .mediaBox)
            return RenderPageMetadata(
                pageIndex: index,
                label: page.label,
                pointWidth: bounds.width,
                pointHeight: bounds.height
            )
        }
    }

    static func selectedPageIndices(
        for selection: RenderSelection,
        sourcePageCount: Int
    ) throws -> [Int] {
        switch selection {
        case .deck:
            return Array(0..<sourcePageCount)
        case .slide(let index):
            guard (0..<sourcePageCount).contains(index) else {
                throw RenderError.invalidSelectedSlideIndex(
                    index: index,
                    availableSlides: sourcePageCount
                )
            }
            return [index]
        }
    }

    static func pngData(
        for page: PDFPage,
        metadata: RenderPageMetadata,
        targetWidth: Int
    ) throws -> Data {
        #if os(macOS)
        let aspectRatio = metadata.pointWidth / max(1, metadata.pointHeight)
        let size = NSSize(
            width: CGFloat(targetWidth),
            height: CGFloat(max(1, Int((Double(targetWidth) / max(0.1, aspectRatio)).rounded())))
        )
        let image = NSImage(size: size)
        image.lockFocus()
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            throw RenderError.rasterizationUnavailable
        }
        NSColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        context.saveGState()
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(
            x: size.width / max(1, CGFloat(metadata.pointWidth)),
            y: -size.height / max(1, CGFloat(metadata.pointHeight))
        )
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
        image.unlockFocus()
        guard let data = image.pngData else {
            throw RenderError.rasterizationUnavailable
        }
        return data
        #elseif canImport(UIKit)
        let aspectRatio = metadata.pointWidth / max(1, metadata.pointHeight)
        let size = CGSize(
            width: CGFloat(targetWidth),
            height: CGFloat(max(1, Int((Double(targetWidth) / max(0.1, aspectRatio)).rounded())))
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { rendererContext in
            UIColor.white.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: size))
            let context = rendererContext.cgContext
            context.saveGState()
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(
                x: size.width / max(1, CGFloat(metadata.pointWidth)),
                y: -size.height / max(1, CGFloat(metadata.pointHeight))
            )
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()
        }
        guard let data = image.pngData() else {
            throw RenderError.rasterizationUnavailable
        }
        return data
        #else
        throw RenderError.rasterizationUnavailable
        #endif
    }
    #endif
}

#if os(macOS)
@MainActor
private final class RenderNavigationDelegate: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, any Error>?
    private var completedResult: Result<Void, any Error>?

    func waitUntilFinished() async throws {
        if let completedResult {
            try completedResult.get()
            return
        }

        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        complete(with: .success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        complete(with: .failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        complete(with: .failure(error))
    }

    private func complete(with result: Result<Void, any Error>) {
        if let continuation {
            continuation.resume(with: result)
            self.continuation = nil
        } else {
            completedResult = result
        }
    }
}
#endif

#if os(macOS)
private extension NSImage {
    var pngData: Data? {
        var proposedRect = CGRect(origin: .zero, size: size)
        guard let cgImage = cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return nil
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }
}
#endif
