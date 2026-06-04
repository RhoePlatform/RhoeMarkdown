import Foundation
import RhoeMarkdownModel

/// Manifest describing a registered extension.
public struct ExtensionManifest: Sendable, Equatable {
    /// Fully qualified extension name (e.g., `@finance.cashflow`)
    public let name: String
    /// Extension surface class
    public let surface: ExtensionSurface
    /// Trust class
    public let trustClass: ExtensionTrustClass
    /// Handler that produces output from an invocation payload
    public let handler: @Sendable (ExtensionPayload) -> ExtensionResult

    public init(
        name: String,
        surface: ExtensionSurface = .customBlock,
        trustClass: ExtensionTrustClass = .localSandboxed,
        handler: @escaping @Sendable (ExtensionPayload) -> ExtensionResult
    ) {
        self.name = name
        self.surface = surface
        self.trustClass = trustClass
        self.handler = handler
    }

    public static func == (lhs: ExtensionManifest, rhs: ExtensionManifest) -> Bool {
        lhs.name == rhs.name && lhs.surface == rhs.surface && lhs.trustClass == rhs.trustClass
    }
}

/// Extension surface classes
public enum ExtensionSurface: String, Sendable, Equatable {
    case customBlock
    case phase1Filter
    case phase2Helper
    case fullWriter
    case writerOverlay
}

/// Extension trust classes
public enum ExtensionTrustClass: String, Sendable, Equatable {
    case localSandboxed
    case serviceBacked
    case compilerBundled
    case trustedProjectLocal
}

/// Payload sent to an extension for invocation.
public struct ExtensionPayload: Sendable {
    /// Fully qualified extension name
    public let name: String
    /// Normalized parameters
    public let parameters: [String: String]
    /// Body content as plain text (from parsed body blocks)
    public let bodyText: String
    /// Source provenance
    public let sourceFile: String?
    public let sourceLine: Int?
}

/// Result returned by an extension.
public enum ExtensionResult: Sendable {
    /// Native RhoeMarkdown fragment — will be reparsed by the compiler
    case rhoeMarkdownFragment(String)
    /// SVG artifact
    case svgArtifact(String)
    /// PNG artifact
    case pngArtifact(Data)
    /// Extension failed or is not available
    case unresolved(message: String)
}

/// Registry of installed extensions.
public final class ExtensionRegistry: @unchecked Sendable {
    private var manifests: [String: ExtensionManifest] = [:]

    public init() {}

    /// Register an extension manifest.
    public func register(_ manifest: ExtensionManifest) {
        manifests[manifest.name.lowercased()] = manifest
    }

    /// Remove a registered extension.
    public func remove(name: String) {
        manifests.removeValue(forKey: name.lowercased())
    }

    /// Look up an extension by name.
    public func lookup(_ name: String) -> ExtensionManifest? {
        manifests[name.lowercased()]
    }

    /// List all registered extensions.
    public var allExtensions: [ExtensionManifest] {
        Array(manifests.values)
    }

    /// Whether the registry has any extensions registered.
    public var isEmpty: Bool { manifests.isEmpty }
}

/// Pipeline pass that resolves extension blocks.
///
/// Scans the AST for blocks with `@`-prefixed names (semantic extensions via
/// `.admonition(type: "@vendor.name")`, editor-native structural extensions via
/// `.extension_(vendor:name:...)`, and legacy visual-extension compatibility via
/// `.visualBlock(name: "@vendor.name")`), resolves them against the registry,
/// and replaces them with the extension's output.
public struct ExtensionResolutionPass: DocumentPass, Sendable {
    private let registry: ExtensionRegistry

    public init(registry: ExtensionRegistry = ExtensionRegistry()) {
        self.registry = registry
    }

    public func process(_ document: RhoeMarkdownKit.Document) -> RhoeMarkdownKit.Document {
        let resolvedBlocks = resolveBlocks(document.blocks)
        return RhoeMarkdownKit.Document(blocks: resolvedBlocks, metadata: document.metadata)
    }

    private func resolveBlocks(_ blocks: [Block]) -> [Block] {
        blocks.flatMap { block -> [Block] in
            // Check for semantic extension: .admonition(type: "@vendor.name")
            if case .admonition(let type, let title, let content, _, let attrs) = block,
               type.hasPrefix("@") {
                return resolveExtension(name: type, title: title, bodyBlocks: content, attributes: attrs)
            }

            if case .extension_(let vendor, let name, let content, let attrs) = block {
                return resolveExtension(name: "@\(vendor).\(name)", title: nil, bodyBlocks: content, attributes: attrs)
            }

            // Check for visual extension: .visualBlock(name: "@vendor.name")
            if case .visualBlock(let name, let content, let attrs) = block,
               name.hasPrefix("@") {
                return resolveExtension(name: name, title: nil, bodyBlocks: content, attributes: attrs)
            }

            // Recurse into container blocks
            return [recurse(block)]
        }
    }

    private func resolveExtension(
        name: String,
        title: String?,
        bodyBlocks: [Block],
        attributes: RhoeMarkdownKit.Attributes
    ) -> [Block] {
        let bodyText = bodyBlocks.map { blockToPlainText($0) }.joined(separator: "\n")

        guard let manifest = registry.lookup(name) else {
            // Unresolved — preserve as a div with diagnostic class
            var kv = attributes.keyValues
            kv["data-extension"] = name
            kv["data-extension-status"] = "unresolved"
            let unresolvedAttrs = RhoeMarkdownKit.Attributes(
                id: attributes.id,
                classes: attributes.classes + ["rhoe-extension-unresolved"],
                keyValues: kv
            )
            return [.div(
                content: [.paragraph([.text("[Unresolved extension: \(name)]")])],
                attributes: unresolvedAttrs
            )]
        }

        // Build invocation payload
        let payload = ExtensionPayload(
            name: name,
            parameters: attributes.keyValues,
            bodyText: bodyText,
            sourceFile: nil,
            sourceLine: nil
        )

        // Execute extension
        let result = manifest.handler(payload)

        switch result {
        case .rhoeMarkdownFragment(let fragment):
            // Safe fragment reparsing: parse the returned markdown with restricted rules
            return safeParseFragment(fragment, sourceExtension: name)

        case .svgArtifact(let svg):
            // Wrap SVG in an HTML block
            return [.html(svg)]

        case .pngArtifact:
            // PNG artifacts need file-based handling (deferred)
            return [.paragraph([.text("[PNG artifact from \(name)]")])]

        case .unresolved(let message):
            return [.paragraph([.text("[Extension error: \(name) — \(message)]")])]
        }
    }

    /// Parse a returned Markdown fragment with safety restrictions.
    ///
    /// Returned fragments MUST NOT contain:
    /// - Liquid syntax ({{ }}, {% %})
    /// - Phase 2 directives ({@ @})
    /// - YAML frontmatter
    /// - Nested extension invocations
    /// - Computable blocks
    private func safeParseFragment(_ fragment: String, sourceExtension: String) -> [Block] {
        // For now, produce a simple paragraph with the fragment text.
        // Full implementation would use a restricted parser configuration.
        let lines = fragment.components(separatedBy: "\n").filter { !$0.isEmpty }
        if lines.isEmpty { return [] }

        return lines.map { line in
            .paragraph([.text(line)])
        }
    }

    private func recurse(_ block: Block) -> Block {
        switch block {
        case .blockQuote(let nested, let attrs):
            return .blockQuote(resolveBlocks(nested), attributes: attrs)
        case .list(let type, let items, let attrs):
            let resolved = items.map { item in
                ListItem(
                    content: resolveBlocks(item.content),
                    checked: item.checked,
                    isLoose: item.isLoose
                )
            }
            return .list(type: type, items: resolved, attributes: attrs)
        case .div(let nested, let attrs):
            return .div(content: resolveBlocks(nested), attributes: attrs)
        case .admonition(let type, let title, let content, let collapsible, let attrs):
            return .admonition(type: type, title: title,
                             content: resolveBlocks(content),
                             collapsible: collapsible, attributes: attrs)
        case .widget(let title, let content, let attrs):
            return .widget(title: title, content: resolveBlocks(content), attributes: attrs)
        case .tab(let title, let content, let attrs):
            return .tab(title: title, content: resolveBlocks(content), attributes: attrs)
        case .stage(let kind, let content, let attrs):
            return .stage(kind: kind, content: resolveBlocks(content), attributes: attrs)
        case .lane(let content, let attrs):
            return .lane(content: resolveBlocks(content), attributes: attrs)
        case .module(let family, let name, let content, let attrs):
            return .module(family: family, name: name, content: resolveBlocks(content), attributes: attrs)
        case .extension_(let vendor, let name, let content, let attrs):
            return .extension_(vendor: vendor, name: name, content: resolveBlocks(content), attributes: attrs)
        default:
            return block
        }
    }

    private func blockToPlainText(_ block: Block) -> String {
        switch block {
        case .paragraph(let inlines, _):
            return inlines.map { inlineToText($0) }.joined()
        case .heading(_, let content, _):
            return content.map { inlineToText($0) }.joined()
        case .codeBlock(_, let content, _):
            return content
        default:
            return ""
        }
    }

    private func inlineToText(_ inline: Inline) -> String {
        switch inline {
        case .text(let t): return t
        case .emphasis(let c), .strong(let c), .strikethrough(let c),
             .superscript(let c), .subscript(let c), .highlight(let c):
            return c.map { inlineToText($0) }.joined()
        case .codeSpan(let t, _): return t
        case .link(let text, _, _, _): return text.map { inlineToText($0) }.joined()
        default: return ""
        }
    }
}
