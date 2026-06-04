import Foundation

/// Result of a project build operation.
public struct BuildResult: Sendable {
    public let targetName: String
    public let targetType: TargetType
    public let documentsBuilt: Int
    public let outputDirectory: URL
    public let diagnostics: [ProjectDiagnostic]
    public let timing: BuildTiming
    public let artifacts: [BuildArtifact]

    public init(
        targetName: String,
        targetType: TargetType,
        documentsBuilt: Int,
        outputDirectory: URL,
        diagnostics: [ProjectDiagnostic] = [],
        timing: BuildTiming,
        artifacts: [BuildArtifact] = []
    ) {
        self.targetName = targetName
        self.targetType = targetType
        self.documentsBuilt = documentsBuilt
        self.outputDirectory = outputDirectory
        self.diagnostics = diagnostics
        self.timing = timing
        self.artifacts = artifacts
    }
}

/// Timing metrics for a build.
public struct BuildTiming: Sendable {
    public let totalDuration: TimeInterval
    public let parseDuration: TimeInterval
    public let renderDuration: TimeInterval
    public let writeDuration: TimeInterval

    public init(
        totalDuration: TimeInterval,
        parseDuration: TimeInterval = 0,
        renderDuration: TimeInterval = 0,
        writeDuration: TimeInterval = 0
    ) {
        self.totalDuration = totalDuration
        self.parseDuration = parseDuration
        self.renderDuration = renderDuration
        self.writeDuration = writeDuration
    }
}

/// A single build artifact (compiled document output).
public struct BuildArtifact: Sendable {
    public let sourcePath: String
    public let outputPath: String
    public let format: String
    public let size: Int

    public init(sourcePath: String, outputPath: String, format: String, size: Int) {
        self.sourcePath = sourcePath
        self.outputPath = outputPath
        self.format = format
        self.size = size
    }
}
