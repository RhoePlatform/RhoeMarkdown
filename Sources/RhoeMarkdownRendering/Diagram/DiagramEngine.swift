import Foundation
import RhoeMarkdownModel

#if !os(WASI)

/// Coordinates diagram rendering across all registered engines.
///
/// The engine dispatches rendering requests to the appropriate
/// `DiagramRenderer` based on the code block language, caches results
/// to avoid redundant external tool invocations, and provides
/// fallback behavior when tools aren't installed.
public struct DiagramEngine: Sendable {
    private let renderers: [any DiagramRenderer]
    private let cache: DiagramCache
    private let configuration: RhoeMarkdownKit.DiagramConfiguration

    public init(configuration: RhoeMarkdownKit.DiagramConfiguration = .default) {
        self.configuration = configuration
        self.cache = DiagramCache()
        self.renderers = [
            MermaidDiagramRenderer(additionalSearchPaths: configuration.additionalSearchPaths),
            GraphvizDiagramRenderer(additionalSearchPaths: configuration.additionalSearchPaths),
            PlantUMLDiagramRenderer(additionalSearchPaths: configuration.additionalSearchPaths),
            D2DiagramRenderer(additionalSearchPaths: configuration.additionalSearchPaths),
        ]
    }

    /// Check if a code block language is a recognized diagram language.
    public func isDiagramLanguage(_ language: String) -> Bool {
        diagramLanguages.contains(language.lowercased())
    }

    /// Find the renderer that handles a given language.
    public func renderer(for language: String) -> (any DiagramRenderer)? {
        let lang = language.lowercased()
        return renderers.first { $0.supportedLanguages.contains(lang) }
    }

    /// Check if the tool for a given language is available.
    public func isToolAvailable(for language: String) -> Bool {
        renderer(for: language)?.isAvailable() ?? false
    }

    /// Render a diagram, using cache when available.
    ///
    /// Returns `nil` when:
    /// - The language is not recognized as a diagram language
    /// - The external tool is not installed
    /// - The tool execution fails (syntax error, timeout, etc.)
    public func render(language: String, source: String) -> DiagramResult? {
        let lang = language.lowercased()

        // Skip Mermaid if client-side rendering is preferred
        if lang == "mermaid" && configuration.mermaidClientSide {
            return nil
        }

        // Check cache
        if let cached = cache.lookup(language: lang, source: source) {
            return cached
        }

        // Find and invoke renderer
        guard let renderer = renderer(for: lang),
              renderer.isAvailable() else {
            return nil
        }

        // For Graphviz, pass the specific engine name
        let result: DiagramResult?
        if let graphviz = renderer as? GraphvizDiagramRenderer {
            result = graphviz.render(source: source, engine: lang)
        } else {
            result = renderer.render(source: source)
        }

        // Cache successful results
        if let result = result {
            cache.store(language: lang, source: source, result: result)
        }

        return result
    }
}

#endif
