import Foundation
import RhoeMarkdownKit
import RhoeProjectKitCore

/// Handles project-level CLI commands: build, validate, targets.
public enum ProjectCommands {

    /// Execute a project build.
    public static func executeBuild(
        projectRoot: URL,
        configURL: URL,
        target: String?,
        allTargets: Bool,
        profile: String?,
        clean: Bool,
        verbose: Bool
    ) async throws {
        let config = try ProjectConfigurationLoader().load(from: configURL)
        let diagnostics = ProjectConfigurationValidator().validate(config)

        // Report validation errors
        let errors = diagnostics.filter { $0.severity == .error }
        if !errors.isEmpty {
            for error in errors {
                writeStandardError("error: \(error.message)\n")
            }
            writeStandardError("Build aborted due to configuration errors.\n")
            return
        }

        if verbose {
            for diag in diagnostics {
                writeStandardError("\(diag.severity): \(diag.message)\n")
            }
        }

        // Build the project graph
        let graph = try ProjectGraphBuilder().build(
            configuration: config,
            projectRoot: projectRoot
        )

        if verbose {
            writeStandardError("Project: \(config.project.name)\n")
            writeStandardError("Collections: \(graph.collections.count)\n")
            writeStandardError("Documents: \(graph.allDocuments.count)\n")
        }

        let builder = ProjectBuilder()

        if clean {
            let outputDir = projectRoot.appendingPathComponent(config.paths.output)
            try OutputManager().clean(outputDir)
            if verbose { writeStandardError("Cleaned output directory.\n") }
        }

        if allTargets {
            let results = try await builder.buildAll(graph: graph, projectRoot: projectRoot)
            for (_, result) in results.sorted(by: { $0.key < $1.key }) {
                printBuildResult(result, verbose: verbose)
            }
        } else if let target {
            let result = try await builder.build(target: target, graph: graph, projectRoot: projectRoot)
            printBuildResult(result, verbose: verbose)
        } else {
            // Build first enabled target (default)
            if let (name, _) = config.targets.first(where: { $0.value.enabled }) {
                let result = try await builder.build(target: name, graph: graph, projectRoot: projectRoot)
                printBuildResult(result, verbose: verbose)
            } else {
                writeStandardError("No enabled targets found.\n")
            }
        }
    }

    /// Validate the project configuration.
    public static func executeValidate(
        configURL: URL,
        verbose: Bool
    ) throws {
        let config = try ProjectConfigurationLoader().load(from: configURL)
        let diagnostics = ProjectConfigurationValidator().validate(config)

        if diagnostics.isEmpty {
            print("✅ Configuration is valid.")
        } else {
            for diag in diagnostics {
                let icon = diag.severity == .error ? "❌" : diag.severity == .warning ? "⚠️" : "ℹ️"
                print("\(icon) \(diag.message)")
            }
            let errorCount = diagnostics.filter { $0.severity == .error }.count
            if errorCount > 0 {
                print("\n\(errorCount) error(s) found.")
            } else {
                print("\n✅ No errors. \(diagnostics.count) info/warning(s).")
            }
        }
    }

    /// List all defined targets.
    public static func executeTargets(
        configURL: URL
    ) throws {
        let config = try ProjectConfigurationLoader().load(from: configURL)

        if config.targets.isEmpty {
            print("No targets defined.")
            return
        }

        print("Targets:")
        for (name, target) in config.targets.sorted(by: { $0.key < $1.key }) {
            let status = target.enabled ? "✅" : "⏸️"
            let collections = target.collections.isEmpty ? "all" : target.collections.joined(separator: ", ")
            print("  \(status) \(name) (\(target.type.rawValue)) → collections: \(collections)")
        }
    }

    // MARK: - Helpers

    private static func printBuildResult(_ result: BuildResult, verbose: Bool) {
        let duration = String(format: "%.2f", result.timing.totalDuration * 1000)
        print("Built \(result.targetName) (\(result.targetType.rawValue)): \(result.documentsBuilt) documents in \(duration)ms")

        if verbose {
            for artifact in result.artifacts {
                print("  → \(artifact.outputPath) (\(artifact.size) bytes)")
            }
        }

        for diag in result.diagnostics {
            let icon = diag.severity == .error ? "❌" : diag.severity == .warning ? "⚠️" : "ℹ️"
            writeStandardError("  \(icon) \(diag.message)\n")
        }
    }

    private static func writeStandardError(_ message: String) {
        FileHandle.standardError.write(Data(message.utf8))
    }
}
