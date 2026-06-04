import Foundation
import RhoeMarkdownModel

#if !os(WASI)

/// Renders D2 diagrams to SVG using the `d2` command-line tool.
///
/// D2 is installed via `curl -fsSL https://d2lang.com/install.sh | sh -s --`
/// or Homebrew (`brew install d2`). The renderer pipes source via stdin
/// and captures SVG from stdout using `d2 - -`.
public struct D2DiagramRenderer: DiagramRenderer, Sendable {
    public let supportedLanguages: Set<String> = ["d2"]

    private let additionalSearchPaths: [String]

    public init(additionalSearchPaths: [String] = []) {
        self.additionalSearchPaths = additionalSearchPaths
    }

    public func isAvailable() -> Bool {
        ToolDiscovery.findTool(named: "d2", additionalPaths: additionalSearchPaths) != nil
    }

    public func render(source: String) -> DiagramResult? {
        guard let toolPath = ToolDiscovery.findTool(named: "d2", additionalPaths: additionalSearchPaths) else {
            return nil
        }

        guard let inputData = source.data(using: .utf8) else { return nil }

        guard let result = ToolDiscovery.runProcess(
            executablePath: toolPath,
            arguments: ["-", "-"],
            stdinData: inputData,
            timeout: 30
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
