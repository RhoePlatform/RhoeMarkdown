import Foundation

/// Assembles the final site output: writes compiled documents, copies assets,
/// and writes navigation JSON sidecar.
public struct SiteAssembler: Sendable {

    private let outputManager = OutputManager()
    private let navigationSerializer = NavigationSerializer()

    public init() {}

    /// Assemble the output for a target.
    public func assemble(
        targetName: String,
        compiledDocuments: [CompiledDocument],
        navigation: NavigationTree,
        projectRoot: URL,
        outputDir: URL,
        paths: PathConfiguration
    ) throws {
        // 1. Ensure output directory exists
        try outputManager.ensureDirectory(outputDir)

        // 2. Write compiled documents
        for compiled in compiledDocuments {
            let outputFileName = compiled.source.relativePath
                .replacingOccurrences(of: ".md", with: ".\(compiled.format.fileExtension)")
                .replacingOccurrences(of: ".markdown", with: ".\(compiled.format.fileExtension)")
            let outputPath = outputDir.appendingPathComponent(outputFileName)
            try outputManager.write(data: compiled.data, to: outputPath)
        }

        // 3. Copy static assets
        let assetsSource = projectRoot.appendingPathComponent(paths.assets)
        let assetsDestination = outputDir.appendingPathComponent("assets")
        try outputManager.copyAssets(from: assetsSource, to: assetsDestination)

        // 4. Write navigation JSON sidecar
        let navData = navigationSerializer.serialize(navigation)
        let navPath = outputDir.appendingPathComponent("navigation.json")
        try outputManager.write(data: navData, to: navPath)
    }
}
