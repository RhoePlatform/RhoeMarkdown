//
//  ASTMerger.swift
//  RhoeMarkdownKit
//
//  Simplified AST merger for parallel parsing
//

import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownRendering

/// Merges AST chunks from parallel parsing
@available(macOS 13.0, iOS 16.0, *)
public actor ASTMerger {
    
    // MARK: - Main Merge Function
    
    public func merge(_ chunks: [ASTChunk]) async -> RhoeMarkdownKit.Document {
        // Phase 1: Merge blocks in order
        let mergedBlocks = await mergeBlocks(chunks)
        
        // Reference and footnote payloads remain on ASTChunk for a future rich merger.
        let metadata = await calculateMetadata(mergedBlocks)
        
        return RhoeMarkdownKit.Document(blocks: mergedBlocks, metadata: metadata)
    }
    
    // MARK: - Block Merging (Simplified)
    
    private func mergeBlocks(_ chunks: [ASTChunk]) async -> [Block] {
        var mergedBlocks: [Block] = []
        
        // Simple concatenation - advanced merging could be added later
        for chunk in chunks.sorted(by: { $0.id < $1.id }) {
            mergedBlocks.append(contentsOf: chunk.blocks)
        }
        
        return mergedBlocks
    }
    
    // MARK: - Reference Collection
    
    private func collectAllReferences(_ chunks: [ASTChunk]) -> [String: (url: String, title: String?)] {
        var allReferences: [String: (url: String, title: String?)] = [:]
        
        for chunk in chunks {
            allReferences.merge(chunk.references) { _, new in new }
        }
        
        return allReferences
    }
    
    private func collectAllFootnotes(_ chunks: [ASTChunk]) -> [String: [Block]] {
        var allFootnotes: [String: [Block]] = [:]
        
        for chunk in chunks {
            allFootnotes.merge(chunk.footnotes) { _, new in new }
        }
        
        return allFootnotes
    }
    
    // MARK: - Metadata Calculation
    
    private func calculateMetadata(_ blocks: [Block]) async -> RhoeMarkdownKit.DocumentMetadata {
        let wordCount = calculateWordCount(blocks)
        let readingTime = estimateReadingTime(wordCount)
        
        return RhoeMarkdownKit.DocumentMetadata(
            wordCount: wordCount,
            estimatedReadingTime: readingTime
        )
    }
    
    private func calculateWordCount(_ blocks: [Block]) -> Int {
        var count = 0
        
        for block in blocks {
            count += countWordsInBlock(block)
        }
        
        return count
    }
    
    private func countWordsInBlock(_ block: Block) -> Int {
        switch block {
        case .paragraph(let inlines, _):
            return countWordsInInlines(inlines)
        case .heading(_, let content, _):
            return countWordsInInlines(content)
        case .blockQuote(let blocks, _):
            return blocks.reduce(0) { $0 + countWordsInBlock($1) }
        case .list(_, let items, _):
            return items.reduce(0) { $0 + $1.content.reduce(0) { $0 + countWordsInBlock($1) } }
        case .codeBlock(_, let content, _):
            return content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        case .horizontalRule:
            return 0
        case .table(let headers, let rows, _, _):
            let headerWords = headers.reduce(0) { $0 + countWordsInInlines($1.content) }
            let rowWords = rows.reduce(0) { sum, row in
                sum + row.reduce(0) { $0 + countWordsInInlines($1.content) }
            }
            return headerWords + rowWords
        case .definitionList(let items, _):
            return items.reduce(0) { sum, item in
                let termWords = countWordsInInlines(item.term)
                let defWords = item.definitions.reduce(0) { $0 + $1.reduce(0) { $0 + countWordsInBlock($1) } }
                return sum + termWords + defWords
            }
        case .footnoteDefinition(_, let content):
            return content.reduce(0) { $0 + countWordsInBlock($1) }
        case .admonition(_, _, let content, _, _):
            return content.reduce(0) { $0 + countWordsInBlock($1) }
        case .html:
            return 0 // Don't count HTML words
        case .div(let content, _):
            return content.reduce(0) { $0 + countWordsInBlock($1) }
        case .lineBlock(let lines):
            return lines.reduce(0) { $0 + countWordsInInlines($1) }
        case .abbreviationDefinition:
            return 1
        case .visualBlock(_, let content, _):
            return content.reduce(0) { $0 + countWordsInBlock($1) }
        case .authorAnnotation:
            return 0
        case .transclusion:
            return 0
        case .schemaIsland:
            return 0
        case .componentDeclaration:
            return 0
        case .phase2Directive:
            return 0
        case .placeholder:
            return 0
        case .expression:
            return 0
        case .field:
            return 0
        case .form(_, let content, _):
            return content.reduce(0) { $0 + countWordsInBlock($1) }
        case .widget(_, let content, _):
            return content.reduce(0) { $0 + countWordsInBlock($1) }
        case .tab(_, let content, _):
            return content.reduce(0) { $0 + countWordsInBlock($1) }
        case .stage(_, let content, _):
            return content.reduce(0) { $0 + countWordsInBlock($1) }
        case .lane(let content, _):
            return content.reduce(0) { $0 + countWordsInBlock($1) }
        case .module(_, _, let content, _):
            return content.reduce(0) { $0 + countWordsInBlock($1) }
        case .contractDirective(_, let content, _):
            return content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        default:
            return 0
        }
    }

    private func countWordsInInlines(_ inlines: [Inline]) -> Int {
        var count = 0
        
        for inline in inlines {
            switch inline {
            case .text(let text):
                count += text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            case .emphasis(let content), .strong(let content), .strikethrough(let content),
                 .superscript(let content), .subscript(let content), .highlight(let content):
                count += countWordsInInlines(content)
            case .codeSpan(let text, _):
                count += text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            case .link(let text, _, _, _):
                count += countWordsInInlines(text)
            case .image(let alt, _, _, _):
                count += countWordsInInlines(alt)
            case .span(let content, _):
                count += countWordsInInlines(content)
            case .inlineFootnote(let content):
                count += countWordsInInlines(content)
            case .citation(let items, _):
                count += items.count // Count each citation key as one word
            case .crossReference:
                count += 1 // Count as one word
            case .rawInline(let content, _):
                count += content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            case .wikilink(let target, let display):
                count += display.map { countWordsInInlines($0) } ?? target.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            case .resolvedCitation(let text, _, _):
                count += text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            case .resolvedCrossReference(let text, _):
                count += text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            case .footnoteRef, .inlineMath, .mathDisplay, .html, .hardBreak, .softBreak:
                break // Don't count these as words
            case .transclusionInline:
                break
            case .annotationInline:
                break
            case .paramRef, .slotRef:
                break
            case .placeholderInline:
                break
            case .expressionInline:
                break
            case .inputFieldInline:
                break
            default:
                break
            }
        }

        return count
    }
    
    private func estimateReadingTime(_ wordCount: Int) -> TimeInterval {
        // Average reading speed: 250 words per minute
        return Double(wordCount) / 250.0 * 60.0
    }
}
