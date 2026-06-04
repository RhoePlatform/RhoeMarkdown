import Foundation
import RhoeMarkdownModel

#if !os(WASI)

/// Renders Mermaid diagrams to SVG using the `mmdc` (mermaid-cli) tool.
///
/// Mermaid-cli is typically installed via npm: `npm install -g @mermaid-js/mermaid-cli`.
/// The renderer writes source to a temp file, invokes `mmdc`, and reads the SVG output.
public struct MermaidDiagramRenderer: DiagramRenderer, Sendable {
    public let supportedLanguages: Set<String> = ["mermaid"]

    private let additionalSearchPaths: [String]

    public init(additionalSearchPaths: [String] = []) {
        self.additionalSearchPaths = additionalSearchPaths
    }

    public func isAvailable() -> Bool {
        ToolDiscovery.findTool(named: "mmdc", additionalPaths: additionalSearchPaths) != nil
    }

    public func render(source: String) -> DiagramResult? {
        guard let toolPath = ToolDiscovery.findTool(named: "mmdc", additionalPaths: additionalSearchPaths) else {
            return nil
        }

        // mmdc requires file-based I/O
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mermaid-\(UUID().uuidString)")
        let inputFile = tempDir.appendingPathComponent("input.mmd")
        let outputFile = tempDir.appendingPathComponent("output.svg")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try source.write(to: inputFile, atomically: true, encoding: .utf8)
        } catch {
            return nil
        }

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        guard let result = ToolDiscovery.runProcess(
            executablePath: toolPath,
            arguments: ["-i", inputFile.path, "-o", outputFile.path, "-e", "svg"],
            timeout: 60
        ) else {
            return nil
        }

        guard result.exitCode == 0 else { return nil }

        guard let svg = try? String(contentsOf: outputFile, encoding: .utf8),
              !svg.isEmpty else {
            return nil
        }

        let warnings = result.stderr.isEmpty ? [] : result.stderr.components(separatedBy: "\n").filter { !$0.isEmpty }
        return DiagramResult(svg: svg, warnings: warnings)
    }
}

#endif
