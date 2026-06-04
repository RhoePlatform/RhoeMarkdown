import Foundation
import RhoeMarkdownModel

/// The result of rendering a diagram from source code.
public struct DiagramResult: Sendable, Equatable {
    /// Rendered SVG content
    public let svg: String
    /// Any warnings produced by the external tool (stderr output)
    public let warnings: [String]

    public init(svg: String, warnings: [String] = []) {
        self.svg = svg
        self.warnings = warnings
    }
}

/// Protocol for external diagram rendering tools.
///
/// Each implementation wraps a specific CLI tool (e.g., `dot` for Graphviz,
/// `mmdc` for Mermaid) and provides tool discovery, availability checking,
/// and source-to-SVG rendering.
public protocol DiagramRenderer: Sendable {
    /// The code block language identifiers this renderer handles.
    /// e.g., `["mermaid"]` or `["dot", "graphviz"]`
    var supportedLanguages: Set<String> { get }

    /// Check whether the external tool is available on this system.
    func isAvailable() -> Bool

    /// Render diagram source code to SVG.
    /// Returns `nil` if rendering fails (tool not found, syntax error, etc.).
    func render(source: String) -> DiagramResult?
}

/// Set of all recognized diagram language identifiers.
public let diagramLanguages: Set<String> = [
    "mermaid",
    "dot", "graphviz", "neato", "circo", "fdp", "twopi", "sfdp",
    "plantuml",
    "d2"
]
