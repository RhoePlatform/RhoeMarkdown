//
//  ChunkSplitter.swift
//  RhoeMarkdownKit
//
//  Smart markdown chunk splitting for parallel parsing
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// A chunk of markdown with context information
public struct MarkdownChunk: Sendable {
    public let id: Int
    public let content: Substring
    public let range: Range<String.Index>
    public let context: ChunkContext
    public let boundary: ChunkBoundary
}

/// Context information for a chunk
public struct ChunkContext: Sendable {
    public let listStack: [(type: ListType, depth: Int)]
    public let blockQuoteDepth: Int
    public let isInsideCodeBlock: Bool
    public let codeBlockInfo: CodeBlockInfo?
    public let isInsideTable: Bool
    public let precedingReferences: [String: (url: String, title: String?)]
    public let openStructures: Set<OpenStructure>
    
    public init(
        listStack: [(type: ListType, depth: Int)] = [],
        blockQuoteDepth: Int = 0,
        isInsideCodeBlock: Bool = false,
        codeBlockInfo: CodeBlockInfo? = nil,
        isInsideTable: Bool = false,
        precedingReferences: [String: (url: String, title: String?)] = [:],
        openStructures: Set<OpenStructure> = []
    ) {
        self.listStack = listStack
        self.blockQuoteDepth = blockQuoteDepth
        self.isInsideCodeBlock = isInsideCodeBlock
        self.codeBlockInfo = codeBlockInfo
        self.isInsideTable = isInsideTable
        self.precedingReferences = precedingReferences
        self.openStructures = openStructures
    }
}

/// Information about an open code block
public struct CodeBlockInfo: Sendable, Equatable {
    public let delimiter: String  // ``` or ~~~
    public let count: Int        // Number of delimiter chars
    public let language: String?
}

/// Open structures that affect parsing
public enum OpenStructure: Sendable, Hashable {
    case htmlBlock(tag: String)
    case mathBlock
    case rawBlock(format: String)
}

/// Boundary information for merging
public struct ChunkBoundary: Sendable {
    public let startsClean: Bool
    public let endsClean: Bool
    public let mergeableWithNext: Bool
    public let mergeableWithPrevious: Bool
    public let pendingContent: String? // Content that needs to be prepended to next chunk
}

/// Smart chunk splitter that respects markdown structure
@available(macOS 13.0, iOS 16.0, *)
public actor ChunkSplitter {
    
    // MARK: - Configuration
    
    public struct Configuration: Sendable {
        public let maxCores: Int
        public let minChunkSize: Int
        public let targetChunkSize: Int
        public let maxChunkSize: Int
        public let enableAdaptiveChunking: Bool
        public let respectStructures: Bool
        
        public static let `default` = Configuration(
            maxCores: ProcessInfo.processInfo.activeProcessorCount,
            minChunkSize: 10_000,      // 10KB minimum
            targetChunkSize: 100_000,   // 100KB target
            maxChunkSize: 500_000,      // 500KB maximum
            enableAdaptiveChunking: true,
            respectStructures: true
        )
    }
    
    private let configuration: Configuration
    
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Main Split Function
    
    public func split(_ markdown: String) async -> [MarkdownChunk] {
        let totalSize = markdown.count
        
        // For small documents, don't split
        if totalSize <= configuration.minChunkSize * 2 {
            return [MarkdownChunk(
                id: 0,
                content: Substring(markdown),
                range: markdown.startIndex..<markdown.endIndex,
                context: ChunkContext(),
                boundary: ChunkBoundary(
                    startsClean: true,
                    endsClean: true,
                    mergeableWithNext: false,
                    mergeableWithPrevious: false,
                    pendingContent: nil
                )
            )]
        }
        
        // Calculate optimal chunk count
        let coreCount = min(configuration.maxCores, ProcessInfo.processInfo.activeProcessorCount)
        let idealChunkCount = min(coreCount, totalSize / configuration.targetChunkSize + 1)
        let targetSize = totalSize / idealChunkCount
        
        // Split into chunks
        var chunks: [MarkdownChunk] = []
        var currentIndex = markdown.startIndex
        var chunkId = 0
        var context = ChunkContext()
        
        while currentIndex < markdown.endIndex {
            let (chunk, nextContext) = await findNextChunk(
                in: markdown,
                from: currentIndex,
                targetSize: targetSize,
                chunkId: chunkId,
                context: context
            )
            
            chunks.append(chunk)
            currentIndex = chunk.range.upperBound
            context = nextContext
            chunkId += 1
        }
        
        return chunks
    }
    
    // MARK: - Chunk Finding
    
    private func findNextChunk(
        in markdown: String,
        from start: String.Index,
        targetSize: Int,
        chunkId: Int,
        context: ChunkContext
    ) async -> (MarkdownChunk, ChunkContext) {
        
        // Calculate target end
        let targetEnd = markdown.index(
            start,
            offsetBy: targetSize,
            limitedBy: markdown.endIndex
        ) ?? markdown.endIndex
        
        // If we're at the end, take everything
        if targetEnd == markdown.endIndex {
            let chunk = MarkdownChunk(
                id: chunkId,
                content: markdown[start..<targetEnd],
                range: start..<targetEnd,
                context: context,
                boundary: ChunkBoundary(
                    startsClean: start == markdown.startIndex || context.openStructures.isEmpty,
                    endsClean: true,
                    mergeableWithNext: false,
                    mergeableWithPrevious: !context.openStructures.isEmpty,
                    pendingContent: nil
                )
            )
            return (chunk, context)
        }
        
        // Find the best split point
        let (bestSplit, boundary) = findBestSplitPoint(
            in: markdown,
            from: start,
            targetEnd: targetEnd,
            context: context
        )
        
        // Update context for next chunk
        let newContext = updateContext(
            from: start,
            to: bestSplit,
            in: markdown,
            currentContext: context
        )
        
        let chunk = MarkdownChunk(
            id: chunkId,
            content: markdown[start..<bestSplit],
            range: start..<bestSplit,
            context: context,
            boundary: boundary
        )
        
        return (chunk, newContext)
    }
    
    // MARK: - Split Point Finding
    
    private func findBestSplitPoint(
        in markdown: String,
        from start: String.Index,
        targetEnd: String.Index,
        context: ChunkContext
    ) -> (String.Index, ChunkBoundary) {
        
        // If in critical structure, extend to find safe point
        if context.isInsideCodeBlock || context.isInsideTable {
            if let safePoint = findStructureEnd(
                in: markdown,
                from: targetEnd,
                context: context
            ) {
                return (safePoint, ChunkBoundary(
                    startsClean: false,
                    endsClean: true,
                    mergeableWithNext: false,
                    mergeableWithPrevious: true,
                    pendingContent: nil
                ))
            }
        }
        
        // Score potential split points
        var bestSplit = targetEnd
        var bestScore = 0
        var bestBoundary = ChunkBoundary(
            startsClean: true,
            endsClean: false,
            mergeableWithNext: true,
            mergeableWithPrevious: false,
            pendingContent: nil
        )
        
        // Search window: ±20% of target
        let searchStart = markdown.index(
            targetEnd,
            offsetBy: -targetEnd.utf16Offset(in: markdown) / 5,
            limitedBy: start
        ) ?? start
        
        let searchEnd = markdown.index(
            targetEnd,
            offsetBy: targetEnd.utf16Offset(in: markdown) / 5,
            limitedBy: markdown.endIndex
        ) ?? markdown.endIndex
        
        var current = searchEnd
        while current > searchStart {
            let (score, boundary) = scoreSplitPoint(
                at: current,
                in: markdown,
                context: context
            )
            
            if score > bestScore {
                bestScore = score
                bestSplit = current
                bestBoundary = boundary
                
                // Perfect split found
                if score >= 100 {
                    break
                }
            }
            
            // Move backwards
            if current > markdown.startIndex {
                current = markdown.index(before: current)
            } else {
                break
            }
        }
        
        return (bestSplit, bestBoundary)
    }
    
    // MARK: - Split Point Scoring
    
    private func scoreSplitPoint(
        at index: String.Index,
        in markdown: String,
        context: ChunkContext
    ) -> (Int, ChunkBoundary) {
        
        // Check for double newline (paragraph boundary)
        if isDoubleNewline(at: index, in: markdown) {
            return (100, ChunkBoundary(
                startsClean: true,
                endsClean: true,
                mergeableWithNext: false,
                mergeableWithPrevious: false,
                pendingContent: nil
            ))
        }
        
        // Check for single newline after block marker
        if isBlockBoundary(at: index, in: markdown) {
            return (90, ChunkBoundary(
                startsClean: true,
                endsClean: true,
                mergeableWithNext: false,
                mergeableWithPrevious: false,
                pendingContent: nil
            ))
        }
        
        // Never split inside code block
        if context.isInsideCodeBlock {
            return (0, ChunkBoundary(
                startsClean: false,
                endsClean: false,
                mergeableWithNext: true,
                mergeableWithPrevious: true,
                pendingContent: nil
            ))
        }
        
        // Avoid splitting inside table
        if context.isInsideTable {
            return (10, ChunkBoundary(
                startsClean: false,
                endsClean: false,
                mergeableWithNext: true,
                mergeableWithPrevious: true,
                pendingContent: nil
            ))
        }
        
        // Single newline
        if isSingleNewline(at: index, in: markdown) {
            // Good if not in list
            if context.listStack.isEmpty {
                return (70, ChunkBoundary(
                    startsClean: true,
                    endsClean: true,
                    mergeableWithNext: false,
                    mergeableWithPrevious: false,
                    pendingContent: nil
                ))
            } else {
                // OK in list but not ideal
                return (40, ChunkBoundary(
                    startsClean: false,
                    endsClean: true,
                    mergeableWithNext: true,
                    mergeableWithPrevious: false,
                    pendingContent: nil
                ))
            }
        }
        
        // After sentence
        if isEndOfSentence(at: index, in: markdown) {
            return (50, ChunkBoundary(
                startsClean: false,
                endsClean: false,
                mergeableWithNext: true,
                mergeableWithPrevious: true,
                pendingContent: nil
            ))
        }
        
        // Default: not great
        return (20, ChunkBoundary(
            startsClean: false,
            endsClean: false,
            mergeableWithNext: true,
            mergeableWithPrevious: true,
            pendingContent: nil
        ))
    }
    
    // MARK: - Boundary Detection Helpers
    
    private func isDoubleNewline(at index: String.Index, in markdown: String) -> Bool {
        guard index >= markdown.index(markdown.startIndex, offsetBy: 2),
              index < markdown.endIndex else { return false }
        
        let before1 = markdown.index(before: index)
        let before2 = markdown.index(before: before1)
        
        return markdown[before2] == "\n" && markdown[before1] == "\n"
    }
    
    private func isSingleNewline(at index: String.Index, in markdown: String) -> Bool {
        guard index > markdown.startIndex,
              index < markdown.endIndex else { return false }
        
        let before = markdown.index(before: index)
        return markdown[before] == "\n"
    }
    
    private func isBlockBoundary(at index: String.Index, in markdown: String) -> Bool {
        guard isSingleNewline(at: index, in: markdown),
              index < markdown.endIndex else { return false }
        
        // Check if next line starts with block marker
        let lineStart = index
        
        // Skip whitespace
        var current = lineStart
        while current < markdown.endIndex && markdown[current].isWhitespace && markdown[current] != "\n" {
            current = markdown.index(after: current)
        }
        
        guard current < markdown.endIndex else { return false }
        
        // Check for block markers
        let markers = ["#", ">", "-", "*", "+", "1", "|", "```", "~~~", "---", "***", "___"]
        
        for marker in markers {
            if markdown[current...].hasPrefix(marker) {
                return true
            }
        }
        
        return false
    }
    
    private func isEndOfSentence(at index: String.Index, in markdown: String) -> Bool {
        guard index > markdown.startIndex else { return false }
        
        let before = markdown.index(before: index)
        return ".!?".contains(markdown[before])
    }
    
    private func findStructureEnd(
        in markdown: String,
        from start: String.Index,
        context: ChunkContext
    ) -> String.Index? {
        
        if context.isInsideCodeBlock, let info = context.codeBlockInfo {
            // Find matching code block delimiter
            var current = start
            while current < markdown.endIndex {
                if markdown[current] == "\n" {
                    let lineStart = markdown.index(after: current)
                    if lineStart < markdown.endIndex {
                        let delimiter = String(repeating: info.delimiter.first!, count: info.count)
                        if markdown[lineStart...].hasPrefix(delimiter) {
                            // Found end, return position after delimiter line
                            if let lineEnd = markdown[lineStart...].firstIndex(of: "\n") {
                                return markdown.index(after: lineEnd)
                            } else {
                                return markdown.endIndex
                            }
                        }
                    }
                }
                current = markdown.index(after: current)
            }
        }
        
        if context.isInsideTable {
            // Find end of table (empty line or non-table line)
            var current = start
            var lastTableLine = start
            
            while current < markdown.endIndex {
                if markdown[current] == "\n" {
                    let lineStart = markdown.index(after: current)
                    if lineStart < markdown.endIndex {
                        // Check if next line is still table
                        if !isTableLine(at: lineStart, in: markdown) {
                            return current
                        }
                        lastTableLine = current
                    }
                }
                current = markdown.index(after: current)
            }
            return lastTableLine
        }
        
        return nil
    }
    
    private func isTableLine(at index: String.Index, in markdown: String) -> Bool {
        // Simple check: line contains |
        if let lineEnd = markdown[index...].firstIndex(of: "\n") {
            return markdown[index..<lineEnd].contains("|")
        }
        return markdown[index...].contains("|")
    }
    
    // MARK: - Context Tracking
    
    private func updateContext(
        from start: String.Index,
        to end: String.Index,
        in markdown: String,
        currentContext: ChunkContext
    ) -> ChunkContext {
        var newContext = currentContext
        
        // Scan chunk for context changes
        let chunk = markdown[start..<end]
        
        // Update code block status
        if let codeBlockChange = detectCodeBlockChange(in: String(chunk), context: currentContext) {
            newContext = ChunkContext(
                listStack: newContext.listStack,
                blockQuoteDepth: newContext.blockQuoteDepth,
                isInsideCodeBlock: codeBlockChange.isInside,
                codeBlockInfo: codeBlockChange.info,
                isInsideTable: newContext.isInsideTable,
                precedingReferences: newContext.precedingReferences,
                openStructures: newContext.openStructures
            )
        }
        
        // Update table status
        let tableStatus = detectTableStatus(in: String(chunk), context: currentContext)
        newContext = ChunkContext(
            listStack: newContext.listStack,
            blockQuoteDepth: newContext.blockQuoteDepth,
            isInsideCodeBlock: newContext.isInsideCodeBlock,
            codeBlockInfo: newContext.codeBlockInfo,
            isInsideTable: tableStatus,
            precedingReferences: newContext.precedingReferences,
            openStructures: newContext.openStructures
        )
        
        // Collect references
        let refs = collectReferences(in: String(chunk))
        var allRefs = newContext.precedingReferences
        allRefs.merge(refs) { _, new in new }
        
        newContext = ChunkContext(
            listStack: newContext.listStack,
            blockQuoteDepth: newContext.blockQuoteDepth,
            isInsideCodeBlock: newContext.isInsideCodeBlock,
            codeBlockInfo: newContext.codeBlockInfo,
            isInsideTable: newContext.isInsideTable,
            precedingReferences: allRefs,
            openStructures: newContext.openStructures
        )
        
        return newContext
    }
    
    private func detectCodeBlockChange(
        in chunk: String,
        context: ChunkContext
    ) -> (isInside: Bool, info: CodeBlockInfo?)? {
        
        // Count fence markers
        let lines = chunk.split(separator: "\n", omittingEmptySubsequences: false)
        
        for line in lines {
            // Check for code fence
            if let fence = detectCodeFence(String(line)) {
                if context.isInsideCodeBlock {
                    // Check if this closes current block
                    if let currentInfo = context.codeBlockInfo,
                       fence.delimiter == currentInfo.delimiter.first!,
                       fence.count >= currentInfo.count {
                        return (false, nil)
                    }
                } else {
                    // Opens new block
                    return (true, CodeBlockInfo(
                        delimiter: String(fence.delimiter),
                        count: fence.count,
                        language: fence.language
                    ))
                }
            }
        }
        
        return nil
    }
    
    private func detectCodeFence(_ line: String) -> (delimiter: Character, count: Int, language: String?)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        if trimmed.hasPrefix("```") {
            let count = trimmed.prefix(while: { $0 == "`" }).count
            let language = trimmed.dropFirst(count).trimmingCharacters(in: .whitespaces)
            return ("`", count, language.isEmpty ? nil : language)
        } else if trimmed.hasPrefix("~~~") {
            let count = trimmed.prefix(while: { $0 == "~" }).count
            let language = trimmed.dropFirst(count).trimmingCharacters(in: .whitespaces)
            return ("~", count, language.isEmpty ? nil : language)
        }
        
        return nil
    }
    
    private func detectTableStatus(in chunk: String, context: ChunkContext) -> Bool {
        let lines = chunk.split(separator: "\n")
        var hasTableDelimiter = false
        
        for line in lines {
            if isTableDelimiterRow(String(line)) {
                hasTableDelimiter = true
                break
            }
        }
        
        // If we found delimiter, we're in a table
        if hasTableDelimiter {
            return true
        }
        
        // If already in table, check if we're still in it
        if context.isInsideTable {
            // Check last few lines
            let lastLines = lines.suffix(3)
            return lastLines.contains { $0.contains("|") }
        }
        
        return false
    }
    
    private func isTableDelimiterRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Must contain | and -
        guard trimmed.contains("|") && trimmed.contains("-") else { return false }
        
        // Check if it's mostly |, -, :, and whitespace
        let allowedChars = CharacterSet(charactersIn: "|:-").union(.whitespaces)
        return trimmed.unicodeScalars.allSatisfy { allowedChars.contains($0) }
    }
    
    private func collectReferences(in chunk: String) -> [String: (url: String, title: String?)] {
        var references: [String: (url: String, title: String?)] = [:]
        
        // Simple reference pattern: [id]: url "title"
        let lines = chunk.split(separator: "\n")
        for line in lines {
            if let ref = parseReferenceLine(String(line)) {
                references[ref.id] = (ref.url, ref.title)
            }
        }
        
        return references
    }
    
    private func parseReferenceLine(_ line: String) -> (id: String, url: String, title: String?)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Must start with [
        guard trimmed.hasPrefix("[") else { return nil }
        
        // Find ]:
        guard let endBracket = trimmed.firstIndex(of: "]") else { return nil }
        let colon = trimmed.index(after: endBracket)
        guard colon < trimmed.endIndex,
              trimmed[colon] == ":" else { return nil }
        
        let id = String(trimmed[trimmed.index(after: trimmed.startIndex)..<endBracket])
        let afterColon = trimmed.index(after: colon)
        
        // Parse URL and optional title
        let remainder = trimmed[afterColon...].trimmingCharacters(in: .whitespaces)
        
        // Simple parsing - real implementation would be more robust
        if let firstSpace = remainder.firstIndex(of: " ") {
            let url = String(remainder[..<firstSpace])
            let titlePart = remainder[firstSpace...].trimmingCharacters(in: .whitespaces)
            
            if titlePart.hasPrefix("\"") && titlePart.hasSuffix("\"") {
                let title = String(titlePart.dropFirst().dropLast())
                return (id, url, title)
            }
            
            return (id, url, nil)
        } else {
            return (id, String(remainder), nil)
        }
    }
}