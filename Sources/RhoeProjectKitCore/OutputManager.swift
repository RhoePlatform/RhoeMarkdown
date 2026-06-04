import Foundation

/// Manages output directory creation and file writing for project builds.
public struct OutputManager: Sendable {

    public init() {}

    /// Ensure the output directory exists.
    public func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }

    /// Write data to an output path, creating parent directories as needed.
    public func write(data: Data, to outputPath: URL) throws {
        let parentDir = outputPath.deletingLastPathComponent()
        try ensureDirectory(parentDir)
        try data.write(to: outputPath)
    }

    /// Copy static assets from source to output directory.
    public func copyAssets(from source: URL, to destination: URL) throws {
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        try ensureDirectory(destination.deletingLastPathComponent())

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
    }

    /// Clean an output directory (remove all contents).
    public func clean(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try ensureDirectory(url)
    }
}
