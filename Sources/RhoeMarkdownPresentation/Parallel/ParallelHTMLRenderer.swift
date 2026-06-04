//
//  ParallelHTMLRenderer.swift
//  RhoeMarkdownKit
//
//  Revolutionary parallel HTML rendering engine for Apple Silicon
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// Revolutionary parallel HTML renderer that leverages multi-core power
@available(macOS 13.0, iOS 16.0, *)
public actor ParallelHTMLRenderer {
    
    // MARK: - Configuration
    
    public struct Configuration: Sendable {
        public let maxCores: Int
        public let minChunkSize: Int
        public let targetChunkSize: Int
        public let enableFragmentOptimization: Bool
        public let enableStreamingOutput: Bool
        
        public init(
            maxCores: Int = ProcessInfo.processInfo.activeProcessorCount,
            minChunkSize: Int = 5,        // Minimum 5 blocks per chunk
            targetChunkSize: Int = 20,     // Target 20 blocks per chunk
            enableFragmentOptimization: Bool = true,
            enableStreamingOutput: Bool = true
        ) {
            self.maxCores = maxCores
            self.minChunkSize = minChunkSize
            self.targetChunkSize = targetChunkSize
            self.enableFragmentOptimization = enableFragmentOptimization
            self.enableStreamingOutput = enableStreamingOutput
        }
        
        public static let `default` = Configuration()
    }
    
    private let configuration: Configuration
    private let htmlConfiguration: RhoeMarkdownKit.HTMLConfiguration
    
    public init(
        configuration: Configuration = .default,
        htmlConfiguration: RhoeMarkdownKit.HTMLConfiguration = .default
    ) {
        self.configuration = configuration
        self.htmlConfiguration = htmlConfiguration
    }
    
    // MARK: - Main Render Function
    
    public func render(_ document: RhoeMarkdownKit.Document) async -> RenderResult {
        let startTime = Date().timeIntervalSinceReferenceDate
        
        // Step 1: Split AST into renderable chunks
        let chunks = await splitIntoRenderChunks(document.blocks)
        
        // Step 2: Render chunks in parallel
        let htmlFragments = await renderChunksInParallel(chunks)
        
        // Step 3: Merge HTML fragments
        let finalHTML = await mergeHTMLFragments(htmlFragments, document: document)
        
        let renderTime = Date().timeIntervalSinceReferenceDate - startTime
        
        return RenderResult(
            html: finalHTML,
            renderTime: renderTime,
            chunksProcessed: chunks.count,
            coresUsed: min(configuration.maxCores, chunks.count)
        )
    }
    
    public func renderWithMetrics(_ document: RhoeMarkdownKit.Document) async -> (String, ParallelRenderMetrics) {
        let totalStart = Date().timeIntervalSinceReferenceDate
        
        // Phase 1: Chunking
        let chunkStart = Date().timeIntervalSinceReferenceDate
        let chunks = await splitIntoRenderChunks(document.blocks)
        let chunkTime = Date().timeIntervalSinceReferenceDate - chunkStart
        
        // Phase 2: Parallel rendering
        let renderStart = Date().timeIntervalSinceReferenceDate
        let htmlFragments = await renderChunksInParallel(chunks)
        let renderTime = Date().timeIntervalSinceReferenceDate - renderStart
        
        // Phase 3: Merging
        let mergeStart = Date().timeIntervalSinceReferenceDate
        let finalHTML = await mergeHTMLFragments(htmlFragments, document: document)
        let mergeTime = Date().timeIntervalSinceReferenceDate - mergeStart
        
        let totalTime = Date().timeIntervalSinceReferenceDate - totalStart
        
        // Calculate speedup estimate
        let estimatedSequentialTime = Double(document.blocks.count) / 100.0 // Rough estimate
        let speedup = estimatedSequentialTime / totalTime
        
        let metrics = ParallelRenderMetrics(
            totalTime: totalTime,
            chunkingTime: chunkTime,
            renderingTime: renderTime,
            mergingTime: mergeTime,
            coresUsed: min(configuration.maxCores, chunks.count),
            chunksProcessed: chunks.count,
            speedup: speedup
        )
        
        return (finalHTML, metrics)
    }
    
    // MARK: - AST Chunking
    
    private func splitIntoRenderChunks(_ blocks: [Block]) async -> [RenderChunk] {
        let totalBlocks = blocks.count
        let coreCount = min(configuration.maxCores, ProcessInfo.processInfo.activeProcessorCount)
        let targetChunkSize = max(configuration.targetChunkSize, totalBlocks / coreCount)
        
        var chunks: [RenderChunk] = []
        var currentIndex = 0
        var chunkId = 0
        
        while currentIndex < blocks.count {
            let chunkEnd = min(currentIndex + targetChunkSize, blocks.count)
            let chunkBlocks = Array(blocks[currentIndex..<chunkEnd])
            
            let chunk = RenderChunk(
                id: chunkId,
                blocks: chunkBlocks,
                startIndex: currentIndex,
                endIndex: chunkEnd
            )
            
            chunks.append(chunk)
            currentIndex = chunkEnd
            chunkId += 1
        }
        
        return chunks
    }
    
    // MARK: - Parallel Rendering
    
    private func renderChunksInParallel(_ chunks: [RenderChunk]) async -> [HTMLFragment] {
        return await withTaskGroup(of: HTMLFragment.self, returning: [HTMLFragment].self) { group in
            var results: [HTMLFragment] = []
            
            for chunk in chunks {
                group.addTask { [htmlConfiguration] in
                    let renderer = RhoeHTMLRenderer(configuration: htmlConfiguration)
                    var html = ""
                    
                    for block in chunk.blocks {
                        html += renderer.renderBlock(block)
                        if htmlConfiguration.prettyPrint {
                            html += "\n"
                        }
                    }
                    
                    return HTMLFragment(
                        id: chunk.id,
                        html: html,
                        startIndex: chunk.startIndex,
                        endIndex: chunk.endIndex
                    )
                }
            }
            
            for await result in group {
                results.append(result)
            }
            
            // Sort by chunk ID to maintain order
            return results.sorted { $0.id < $1.id }
        }
    }
    
    // MARK: - HTML Fragment Merging
    
    private func mergeHTMLFragments(
        _ fragments: [HTMLFragment],
        document: RhoeMarkdownKit.Document
    ) async -> String {
        var finalHTML = ""
        
        // Add document header if pretty printing
        if htmlConfiguration.prettyPrint {
            finalHTML += "<!DOCTYPE html>\n"
            finalHTML += "<html>\n"
            finalHTML += "<head>\n"
            finalHTML += "<meta charset=\"utf-8\">\n"
            finalHTML += "<title>Rendered by RhoeMarkdownKit Parallel Engine</title>\n"
            finalHTML += "</head>\n"
            finalHTML += "<body>\n"
        }
        
        // Merge fragments in order
        for fragment in fragments.sorted(by: { $0.id < $1.id }) {
            finalHTML += fragment.html
        }
        
        // Add document footer if pretty printing
        if htmlConfiguration.prettyPrint {
            finalHTML += "</body>\n"
            finalHTML += "</html>\n"
        }
        
        return finalHTML
    }
    
    // MARK: - Streaming Support
    
    public func renderStream(_ document: RhoeMarkdownKit.Document) -> AsyncStream<String> {
        return AsyncStream { continuation in
            Task {
                let chunks = await splitIntoRenderChunks(document.blocks)
                
                // Send header
                if htmlConfiguration.prettyPrint {
                    continuation.yield("<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n</head>\n<body>\n")
                }
                
                // Process chunks and stream results
                for chunk in chunks {
                    let renderer = RhoeHTMLRenderer(configuration: htmlConfiguration)
                    var html = ""
                    
                    for block in chunk.blocks {
                        html += renderer.renderBlock(block)
                        if htmlConfiguration.prettyPrint {
                            html += "\n"
                        }
                    }
                    
                    continuation.yield(html)
                }
                
                // Send footer
                if htmlConfiguration.prettyPrint {
                    continuation.yield("</body>\n</html>\n")
                }
                
                continuation.finish()
            }
        }
    }
}

// MARK: - Supporting Types

/// Chunk of blocks for parallel rendering
public struct RenderChunk: Sendable {
    public let id: Int
    public let blocks: [Block]
    public let startIndex: Int
    public let endIndex: Int
}

/// HTML fragment from parallel rendering
public struct HTMLFragment: Sendable {
    public let id: Int
    public let html: String
    public let startIndex: Int
    public let endIndex: Int
}

/// Result of parallel HTML rendering
public struct RenderResult: Sendable {
    public let html: String
    public let renderTime: TimeInterval
    public let chunksProcessed: Int
    public let coresUsed: Int
}

/// Performance metrics for parallel HTML rendering
@available(macOS 13.0, iOS 16.0, *)
public struct ParallelRenderMetrics: Sendable {
    public let totalTime: TimeInterval
    public let chunkingTime: TimeInterval
    public let renderingTime: TimeInterval
    public let mergingTime: TimeInterval
    public let coresUsed: Int
    public let chunksProcessed: Int
    public let speedup: Double // vs estimated sequential
    
    public init(
        totalTime: TimeInterval,
        chunkingTime: TimeInterval,  
        renderingTime: TimeInterval,
        mergingTime: TimeInterval,
        coresUsed: Int,
        chunksProcessed: Int,
        speedup: Double
    ) {
        self.totalTime = totalTime
        self.chunkingTime = chunkingTime
        self.renderingTime = renderingTime
        self.mergingTime = mergingTime
        self.coresUsed = coresUsed
        self.chunksProcessed = chunksProcessed
        self.speedup = speedup
    }
}
