import Foundation
import RhoeMarkdownModel

#if !os(WASI)

/// Renders Graphviz DOT diagrams to SVG using the `dot` command-line tool.
///
/// Supports multiple Graphviz layout engines: `dot`, `neato`, `fdp`, `circo`,
/// `twopi`, `sfdp`. The language identifier determines which layout engine is used
/// (e.g., a code block with language "neato" will use the `neato` engine).
/// The generic "graphviz" identifier defaults to `dot`.
public struct GraphvizDiagramRenderer: DiagramRenderer, Sendable {
    public let supportedLanguages: Set<String> = [
        "dot", "graphviz", "neato", "circo", "fdp", "twopi", "sfdp"
    ]

    private let additionalSearchPaths: [String]

    public init(additionalSearchPaths: [String] = []) {
        self.additionalSearchPaths = additionalSearchPaths
    }

    public func isAvailable() -> Bool {
        ToolDiscovery.findTool(named: "dot", additionalPaths: additionalSearchPaths) != nil
    }

    public func render(source: String) -> DiagramResult? {
        render(source: source, engine: "dot")
    }

    /// Render using a specific Graphviz layout engine.
    public func render(source: String, engine: String) -> DiagramResult? {
        let engineName = engine == "graphviz" ? "dot" : engine
        guard let toolPath = ToolDiscovery.findTool(named: engineName, additionalPaths: additionalSearchPaths) else {
            return nil
        }

        guard let inputData = source.data(using: .utf8) else { return nil }

        guard let result = ToolDiscovery.runProcess(
            executablePath: toolPath,
            arguments: ["-Tsvg"],
            stdinData: inputData
        ) else {
            return nil
        }

        guard result.exitCode == 0,
              let svg = String(data: result.stdout, encoding: .utf8),
              !svg.isEmpty else {
            return nil
        }

        let warnings = result.stderr.isEmpty ? [] : result.stderr.components(separatedBy: "\n").filter { !$0.isEmpty }
        return DiagramResult(svg: svg, warnings: warnings)
    }
}

#endif
