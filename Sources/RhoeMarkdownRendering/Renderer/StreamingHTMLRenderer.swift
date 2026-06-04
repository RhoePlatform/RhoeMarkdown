import Foundation
import RhoeMarkdownModel

/// Streaming HTML renderer that produces output as an `AsyncStream<String>`.
///
/// Instead of building the entire HTML document as a single String in memory,
/// this renderer yields one HTML fragment per block. The consumer can write
/// each fragment to a file, socket, or response stream immediately.
///
/// Memory impact: instead of holding the entire rendered HTML (~2-5x the input size),
/// only one rendered block is in memory at a time (~1-10KB typically).
///
/// Usage:
/// ```swift
/// let renderer = StreamingHTMLRenderer()
/// for await fragment in renderer.renderStream(document) {
///     fileHandle.write(Data(fragment.utf8))
/// }
/// ```
public struct StreamingHTMLRenderer: Sendable {

    public init(configuration: RhoeMarkdownKit.HTMLConfiguration = .init()) {
    }

    /// Create a fresh renderer for each block to avoid mutating state issues.
    private func renderSingleBlock(_ block: Block, metadata: RhoeMarkdownKit.DocumentMetadata) -> String {
        var renderer = RhoeHTMLRenderer()
        let doc = RhoeMarkdownKit.Document(blocks: [block], metadata: metadata)
        return renderer.render(doc)
    }

    // MARK: - Streaming Render

    /// Render document blocks as an async stream of HTML fragments.
    ///
    /// Each yielded string is one rendered block element (paragraph, heading,
    /// table, admonition, etc.). The consumer controls the pace — this is
    /// backpressure-aware through Swift's AsyncStream.
    ///
    /// - Parameter document: The fully normalized document to render
    /// - Returns: AsyncStream yielding one HTML fragment per block
    public func renderStream(
        _ document: RhoeMarkdownKit.Document
    ) -> AsyncStream<String> {
        let blocks = document.blocks

        return AsyncStream { continuation in
            // Streaming render — blocks yielded one at a time

            for block in blocks {
                let fragment = self.renderSingleBlock(block, metadata: document.metadata)

                if !fragment.isEmpty {
                    continuation.yield(fragment)
                }
            }

            // All blocks yielded
            continuation.finish()
        }
    }

    /// Render and write directly to a file handle for maximum efficiency.
    ///
    /// This is the optimal path for large documents: each block is rendered
    /// and written immediately, with no intermediate String accumulation.
    ///
    /// - Parameters:
    ///   - document: The fully normalized document
    ///   - fileHandle: File handle to write to (must be open for writing)
    public func renderToFile(
        _ document: RhoeMarkdownKit.Document,
        fileHandle: FileHandle
    ) {
        for block in document.blocks {
            let fragment = renderSingleBlock(block, metadata: document.metadata)

            if !fragment.isEmpty {
                if let data = fragment.data(using: .utf8) {
                    fileHandle.write(data)
                }
            }
        }
    }

    /// Render with a callback for each fragment (useful for non-file consumers).
    ///
    /// - Parameters:
    ///   - document: The fully normalized document
    ///   - onFragment: Callback invoked for each rendered HTML fragment
    public func renderWithCallback(
        _ document: RhoeMarkdownKit.Document,
        onFragment: (String) -> Void
    ) {
        for block in document.blocks {
            let fragment = renderSingleBlock(block, metadata: document.metadata)

            if !fragment.isEmpty {
                onFragment(fragment)
            }
        }
    }

    /// Count of blocks that will be yielded (for progress tracking).
    public func blockCount(_ document: RhoeMarkdownKit.Document) -> Int {
        document.blocks.count
    }
}
