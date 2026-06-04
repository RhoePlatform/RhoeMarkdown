import Foundation
import RhoeMarkdownModel

/// Orchestrates multi-document project builds across targets.
public struct ProjectBuilder: Sendable {

    private let compiler = DocumentCompiler()
    private let formatResolver = TargetFormatResolver()
    private let outputManager = OutputManager()

    public init() {}

    /// Build a single target.
    public func build(
        target targetName: String,
        graph: ProjectGraph,
        projectRoot: URL
    ) async throws -> BuildResult {
        guard let target = graph.configuration.targets[targetName] else {
            return BuildResult(
                targetName: targetName,
                targetType: .staticSite,
                documentsBuilt: 0,
                outputDirectory: projectRoot,
                diagnostics: [.error("Target '\(targetName)' not found in configuration.")],
                timing: BuildTiming(totalDuration: 0)
            )
        }

        guard target.enabled else {
            return BuildResult(
                targetName: targetName,
                targetType: target.type,
                documentsBuilt: 0,
                outputDirectory: projectRoot,
                diagnostics: [.info("Target '\(targetName)' is disabled. Skipping.")],
                timing: BuildTiming(totalDuration: 0)
            )
        }

        let buildStart = Date().timeIntervalSinceReferenceDate
        let documents = graph.documents(for: targetName)
        let format = formatResolver.resolve(target: target)

        let outputDir = projectRoot.appendingPathComponent(
            target.outputDir ?? graph.configuration.paths.output
        ).appendingPathComponent(targetName)

        try outputManager.ensureDirectory(outputDir)

        var totalParseTime: TimeInterval = 0
        var totalRenderTime: TimeInterval = 0
        var artifacts: [BuildArtifact] = []
        var diagnostics: [ProjectDiagnostic] = []

        // Compile documents in parallel using TaskGroup
        let compiledResults: [(index: Int, result: Result<CompiledDocument, any Error>)]
        compiledResults = await withTaskGroup(
            of: (Int, Result<CompiledDocument, any Error>).self,
            returning: [(Int, Result<CompiledDocument, any Error>)].self
        ) { group in
            for (index, document) in documents.enumerated() {
                group.addTask { [compiler, format] in
                    do {
                        let compiled = try await compiler.compile(document: document, format: format)
                        return (index, .success(compiled))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            var results: [(Int, Result<CompiledDocument, any Error>)] = []
            results.reserveCapacity(documents.count)
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 } // Preserve original document order
        }

        // Write results sequentially (filesystem I/O)
        let writeStart = Date().timeIntervalSinceReferenceDate

        for (index, result) in compiledResults {
            switch result {
            case .success(let compiled):
                totalParseTime += compiled.parseTime
                totalRenderTime += compiled.renderTime

                let outputFileName = documents[index].relativePath
                    .replacingOccurrences(of: ".md", with: ".\(format.fileExtension)")
                    .replacingOccurrences(of: ".markdown", with: ".\(format.fileExtension)")
                let outputPath = outputDir.appendingPathComponent(outputFileName)

                do {
                    try outputManager.write(data: compiled.data, to: outputPath)
                    artifacts.append(BuildArtifact(
                        sourcePath: documents[index].relativePath,
                        outputPath: outputFileName,
                        format: format.rawValue,
                        size: compiled.data.count
                    ))
                } catch {
                    diagnostics.append(.warning("Failed to write '\(documents[index].relativePath)': \(error.localizedDescription)"))
                }

            case .failure(let error):
                diagnostics.append(.warning("Failed to compile '\(documents[index].relativePath)': \(error.localizedDescription)"))
            }
        }

        let writeTime = Date().timeIntervalSinceReferenceDate - writeStart
        let totalTime = Date().timeIntervalSinceReferenceDate - buildStart

        return BuildResult(
            targetName: targetName,
            targetType: target.type,
            documentsBuilt: artifacts.count,
            outputDirectory: outputDir,
            diagnostics: diagnostics,
            timing: BuildTiming(
                totalDuration: totalTime,
                parseDuration: totalParseTime,
                renderDuration: totalRenderTime,
                writeDuration: max(0, writeTime)
            ),
            artifacts: artifacts
        )
    }

    /// Build all enabled targets in parallel.
    public func buildAll(
        graph: ProjectGraph,
        projectRoot: URL
    ) async throws -> [String: BuildResult] {
        let enabledTargets = graph.configuration.targets.filter(\.value.enabled)

        return await withTaskGroup(
            of: (String, BuildResult).self,
            returning: [String: BuildResult].self
        ) { group in
            for (name, _) in enabledTargets {
                group.addTask {
                    do {
                        let result = try await self.build(target: name, graph: graph, projectRoot: projectRoot)
                        return (name, result)
                    } catch {
                        return (name, BuildResult(
                            targetName: name,
                            targetType: .staticSite,
                            documentsBuilt: 0,
                            outputDirectory: projectRoot,
                            diagnostics: [.error("Build failed: \(error.localizedDescription)")],
                            timing: BuildTiming(totalDuration: 0)
                        ))
                    }
                }
            }
            var results: [String: BuildResult] = [:]
            for await (name, result) in group {
                results[name] = result
            }
            return results
        }
    }
}
