import Foundation
import RhoeMarkdownModel
import RhoeMarkdownKit

/// Compiles a single document to a target format within the project context.
public struct DocumentCompiler: Sendable {

    public init() {}

    /// Compile a single document to the specified format.
    public func compile(
        document: CollectionDocument,
        format: RhoeMarkdownKit.OutputFormat
    ) async throws -> CompiledDocument {
        let content = try String(contentsOf: document.url, encoding: .utf8)

        let parseStart = Date().timeIntervalSinceReferenceDate
        let parseResult = await RhoeMarkdownKit.parse(content)
        let parseTime = Date().timeIntervalSinceReferenceDate - parseStart

        let renderStart = Date().timeIntervalSinceReferenceDate
        let rendered = RhoeMarkdownKit.render(parseResult.document, format: format)
        let renderTime = Date().timeIntervalSinceReferenceDate - renderStart

        return CompiledDocument(
            source: document,
            data: rendered,
            format: format,
            parseTime: parseTime,
            renderTime: renderTime
        )
    }

    /// Compile a single document to multiple formats in parallel (parse once, render N times).
    public func compileMultiFormat(
        document: CollectionDocument,
        formats: [RhoeMarkdownKit.OutputFormat]
    ) async throws -> [RhoeMarkdownKit.OutputFormat: CompiledDocument] {
        let content = try String(contentsOf: document.url, encoding: .utf8)

        let parseStart = Date().timeIntervalSinceReferenceDate
        let parseResult = await RhoeMarkdownKit.parse(content)
        let parseTime = Date().timeIntervalSinceReferenceDate - parseStart

        // Render to all formats in parallel
        return await withTaskGroup(
            of: (RhoeMarkdownKit.OutputFormat, Data, TimeInterval).self,
            returning: [RhoeMarkdownKit.OutputFormat: CompiledDocument].self
        ) { group in
            for format in formats {
                group.addTask {
                    let renderStart = Date().timeIntervalSinceReferenceDate
                    let rendered = RhoeMarkdownKit.render(parseResult.document, format: format)
                    let renderTime = Date().timeIntervalSinceReferenceDate - renderStart
                    return (format, rendered, renderTime)
                }
            }
            var results: [RhoeMarkdownKit.OutputFormat: CompiledDocument] = [:]
            for await (format, data, renderTime) in group {
                results[format] = CompiledDocument(
                    source: document,
                    data: data,
                    format: format,
                    parseTime: parseTime / Double(formats.count), // Shared parse time
                    renderTime: renderTime
                )
            }
            return results
        }
    }
}

/// A compiled document with rendered output data.
public struct CompiledDocument: Sendable {
    public let source: CollectionDocument
    public let data: Data
    public let format: RhoeMarkdownKit.OutputFormat
    public let parseTime: TimeInterval
    public let renderTime: TimeInterval

    public init(
        source: CollectionDocument,
        data: Data,
        format: RhoeMarkdownKit.OutputFormat,
        parseTime: TimeInterval,
        renderTime: TimeInterval
    ) {
        self.source = source
        self.data = data
        self.format = format
        self.parseTime = parseTime
        self.renderTime = renderTime
    }
}
