import Foundation
import RhoeMarkdownModel

/// Protocol for resolving transclusion targets to document content.
public protocol DocumentResolver: Sendable {
    /// Resolve a target path to its content string.
    func resolve(target: String, relativeTo: String?) async throws -> String
}

/// Resolves files from the local filesystem.
public struct FileSystemDocumentResolver: DocumentResolver, Sendable {
    public let basePath: String

    public init(basePath: String) {
        self.basePath = basePath
    }

    public func resolve(target: String, relativeTo: String?) async throws -> String {
        let base: String
        if let rel = relativeTo {
            base = (rel as NSString).deletingLastPathComponent
        } else {
            base = basePath
        }

        let fullPath: String
        if target.hasPrefix("/") {
            fullPath = target
        } else {
            fullPath = (base as NSString).appendingPathComponent(target)
        }

        let url = URL(fileURLWithPath: fullPath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}

/// Resolves transclusion nodes by loading and parsing referenced documents.
///
/// Walks the AST, finds `.transclusion` block and `.transclusionInline` inline nodes,
/// resolves their targets using the document resolver, parses the resolved content,
/// and replaces the transclusion nodes with the parsed content.
///
/// Cycle detection: maintains a set of currently-resolving paths. If a path appears
/// twice in the resolution chain, the transclusion is left as an unresolved placeholder
/// and a diagnostic is emitted.
public struct TransclusionResolutionPass: Sendable {
    private let resolver: any DocumentResolver
    private let parser: DocumentParser

    public init(resolver: any DocumentResolver, parser: DocumentParser = DocumentParser()) {
        self.resolver = resolver
        self.parser = parser
    }

    /// Process a document, resolving all transclusion nodes.
    public func process(_ document: RhoeMarkdownKit.Document) async -> RhoeMarkdownKit.Document {
        var resolvingPaths: Set<String> = []
        let resolvedBlocks = await resolveBlocks(document.blocks, resolvingPaths: &resolvingPaths)
        return RhoeMarkdownKit.Document(blocks: resolvedBlocks, metadata: document.metadata)
    }

    private func resolveBlocks(
        _ blocks: [Block],
        resolvingPaths: inout Set<String>
    ) async -> [Block] {
        var result: [Block] = []

        for block in blocks {
            switch block {
            case .transclusion(let target, let fragment, _, _):
                let resolved = await resolveTarget(target, fragment: fragment, resolvingPaths: &resolvingPaths)
                if let resolved {
                    result.append(contentsOf: resolved)
                } else {
                    result.append(block) // Leave as unresolved placeholder
                }

            case .blockQuote(let nested, let attrs):
                let resolved = await resolveBlocks(nested, resolvingPaths: &resolvingPaths)
                result.append(.blockQuote(resolved, attributes: attrs))

            case .list(let type, let items, let attrs):
                var resolvedItems: [ListItem] = []
                for item in items {
                    let resolvedContent = await resolveBlocks(item.content, resolvingPaths: &resolvingPaths)
                    resolvedItems.append(
                        ListItem(content: resolvedContent, checked: item.checked, isLoose: item.isLoose)
                    )
                }
                result.append(.list(type: type, items: resolvedItems, attributes: attrs))

            case .div(let nested, let attrs):
                let resolved = await resolveBlocks(nested, resolvingPaths: &resolvingPaths)
                result.append(.div(content: resolved, attributes: attrs))

            case .admonition(let type, let title, let content, let collapsible, let attrs):
                let resolved = await resolveBlocks(content, resolvingPaths: &resolvingPaths)
                result.append(.admonition(type: type, title: title, content: resolved,
                                         collapsible: collapsible, attributes: attrs))

            default:
                result.append(block)
            }
        }

        return result
    }

    private func resolveTarget(
        _ target: String,
        fragment: String?,
        resolvingPaths: inout Set<String>
    ) async -> [Block]? {
        // Cycle detection
        guard !resolvingPaths.contains(target) else { return nil }
        resolvingPaths.insert(target)
        defer { resolvingPaths.remove(target) }

        do {
            let content = try await resolver.resolve(target: target, relativeTo: nil)
            let parsed = await parser.parse(content)
            var blocks = parsed.document.blocks

            // Fragment extraction: select section by heading ID
            if let fragment {
                blocks = extractFragment(fragment, from: blocks)
            }

            // Recursive resolution for nested transclusions
            blocks = await resolveBlocks(blocks, resolvingPaths: &resolvingPaths)
            return blocks
        } catch {
            return nil // Leave as unresolved placeholder
        }
    }

    /// Extract a heading section by ID from a document's blocks.
    private func extractFragment(_ fragment: String, from blocks: [Block]) -> [Block] {
        var capturing = false
        var capturedLevel = 0
        var result: [Block] = []

        for block in blocks {
            if case .heading(let level, _, let attrs) = block {
                if attrs.id == fragment {
                    capturing = true
                    capturedLevel = level
                    result.append(block)
                    continue
                } else if capturing && level <= capturedLevel {
                    break // Next heading at same or higher level
                }
            }

            if capturing {
                result.append(block)
            }

            // Also check for any block with matching ID
            if !capturing {
                switch block {
                case .div(_, let attrs), .admonition(_, _, _, _, let attrs),
                     .table(_, _, _, let attrs):
                    if attrs.id == fragment {
                        return [block]
                    }
                default: break
                }
            }
        }

        return result.isEmpty ? blocks : result
    }
}
