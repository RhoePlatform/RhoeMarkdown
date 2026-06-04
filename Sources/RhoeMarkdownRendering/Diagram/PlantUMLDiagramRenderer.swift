import Foundation
import RhoeMarkdownModel

#if !os(WASI)

/// Renders PlantUML diagrams to SVG using the `plantuml` command-line tool.
///
/// PlantUML is typically installed via Homebrew (`brew install plantuml`) or
/// as a Java JAR file. The renderer pipes source via stdin and captures SVG
/// from stdout using `plantuml -tsvg -pipe`.
public struct PlantUMLDiagramRenderer: DiagramRenderer, Sendable {
    public let supportedLanguages: Set<String> = ["plantuml"]

    private let additionalSearchPaths: [String]

    public init(additionalSearchPaths: [String] = []) {
        self.additionalSearchPaths = additionalSearchPaths
    }

    public func isAvailable() -> Bool {
        ToolDiscovery.findTool(named: "plantuml", additionalPaths: additionalSearchPaths) != nil
    }

    public func render(source: String) -> DiagramResult? {
        guard let toolPath = ToolDiscovery.findTool(named: "plantuml", additionalPaths: additionalSearchPaths) else {
            return nil
        }

        guard let inputData = source.data(using: .utf8) else { return nil }

        guard let result = ToolDiscovery.runProcess(
            executablePath: toolPath,
            arguments: ["-tsvg", "-pipe"],
            stdinData: inputData,
            timeout: 60
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
