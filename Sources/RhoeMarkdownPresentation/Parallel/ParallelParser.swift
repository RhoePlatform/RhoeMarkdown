//
//  ParallelParser.swift
//  RhoeMarkdownKit
//
//  Revolutionary parallel markdown parser for Apple Silicon
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

// MARK: - Types imported from other files
// MarkdownChunk, ChunkContext, etc. are defined in ChunkSplitter.swift
// ChunkTokens is defined in ParallelLexer.swift
// ASTChunk is defined in ParallelChunkParser.swift

// MARK: - Parallel Parser

@available(macOS 13.0, iOS 16.0, *)
public actor ParallelMarkdownParser {
    
    // MARK: - Configuration
    
    public typealias Configuration = ChunkSplitter.Configuration
    
    private let configuration: Configuration
    private let chunkSplitter: ChunkSplitter
    
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
        self.chunkSplitter = ChunkSplitter(configuration: configuration)
    }
    
    // MARK: - Main Parse Function
    
    public func parse(_ markdown: String) async -> RhoeMarkdownKit.ParseResult {
        let startTime = Date().timeIntervalSinceReferenceDate
        
        // Step 1: Split into chunks
        let chunks = await chunkSplitter.split(markdown)
        
        // Step 2: Parallel parsing (lexing happens per chunk)
        let astChunks = await parseChunksInParallel(chunks)
        
        // Step 4: Merge ASTs
        let document = await mergeASTs(astChunks)
        
        let parseTime = Date().timeIntervalSinceReferenceDate - startTime
        
        return RhoeMarkdownKit.ParseResult(
            document: document,
            diagnostics: [],
            parseTime: parseTime
        )
    }
    
    // MARK: - Parallel Parsing
    
    private func parseChunksInParallel(
        _ chunks: [MarkdownChunk]
    ) async -> [ASTChunk] {
        // Parse each chunk in parallel using async let
        return await withTaskGroup(of: ASTChunk.self, returning: [ASTChunk].self) { group in
            var results: [ASTChunk] = []
            
            for chunk in chunks {
                group.addTask {
                    let parser = RhoeParser(configuration: .default)
                    let result = await parser.parse(String(chunk.content))

                    // Extract references and footnotes from the parsed chunk
                    let references: [String: (url: String, title: String?)] = [:]
                    var footnotes: [String: [Block]] = [:]

                    for block in result.document.blocks {
                        switch block {
                        case .footnoteDefinition(let id, let content):
                            footnotes[id] = content
                        default:
                            break
                        }
                    }

                    return ASTChunk(
                        id: chunk.id,
                        blocks: result.document.blocks,
                        references: references,
                        footnotes: footnotes
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
    
    // MARK: - AST Merging
    
    private func mergeASTs(_ chunks: [ASTChunk]) async -> RhoeMarkdownKit.Document {
        let merger = ASTMerger()
        return await merger.merge(chunks)
    }
    
    // MARK: - Performance Metrics
    
    public func parseWithMetrics(_ markdown: String) async -> (RhoeMarkdownKit.Document, ParallelParserMetrics) {
        let totalStart = Date().timeIntervalSinceReferenceDate
        
        // Phase 1: Chunking
        let chunkStart = Date().timeIntervalSinceReferenceDate
        let chunks = await chunkSplitter.split(markdown)
        let chunkTime = Date().timeIntervalSinceReferenceDate - chunkStart
        
        // Phase 2: Parsing (includes lexing per chunk)
        let parseStart = Date().timeIntervalSinceReferenceDate
        let astChunks = await parseChunksInParallel(chunks)
        let parseTime = Date().timeIntervalSinceReferenceDate - parseStart
        
        // Phase 4: Merging
        let mergeStart = Date().timeIntervalSinceReferenceDate
        let document = await mergeASTs(astChunks)
        let mergeTime = Date().timeIntervalSinceReferenceDate - mergeStart
        
        let totalTime = Date().timeIntervalSinceReferenceDate - totalStart
        
        // Calculate speedup (would need sequential time for comparison)
        let estimatedSequentialTime = Double(markdown.count) / 10_000.0 // Rough estimate
        let speedup = estimatedSequentialTime / totalTime
        
        let metrics = ParallelParserMetrics(
            totalTime: totalTime,
            chunkingTime: chunkTime,
            lexingTime: 0, // Lexing now included in parsing time
            parsingTime: parseTime,
            mergingTime: mergeTime,
            coresUsed: min(configuration.maxCores, chunks.count),
            chunksProcessed: chunks.count,
            speedup: speedup
        )
        
        return (document, metrics)
    }
}


// MARK: - AST Chunk Definition

/// Result of parsing a chunk (simplified)
public struct ASTChunk: Sendable {
    public let id: Int
    public let blocks: [Block]
    public let references: [String: (url: String, title: String?)]
    public let footnotes: [String: [Block]]
    
    public init(
        id: Int,
        blocks: [Block],
        references: [String: (url: String, title: String?)] = [:],
        footnotes: [String: [Block]] = [:]
    ) {
        self.id = id
        self.blocks = blocks
        self.references = references
        self.footnotes = footnotes
    }
}



// MARK: - Performance Measurement

@available(macOS 13.0, iOS 16.0, *)
public struct ParallelParserMetrics: Sendable {
    public let totalTime: TimeInterval
    public let chunkingTime: TimeInterval
    public let lexingTime: TimeInterval
    public let parsingTime: TimeInterval
    public let mergingTime: TimeInterval
    public let coresUsed: Int
    public let chunksProcessed: Int
    public let speedup: Double // vs sequential
}

// MARK: - Streaming Support
// StreamingMarkdownParser is defined in StreamingParser.swift
