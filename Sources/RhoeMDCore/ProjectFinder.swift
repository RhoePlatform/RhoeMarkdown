import Foundation

/// Locates the project configuration file by searching upward from the current directory.
public struct ProjectFinder: Sendable {

    /// Known config file names, in priority order.
    private static let configFileNames = [
        "rhoe.project.yaml",
        "rhoe.project.yml",
        "_config.yml"
    ]

    public init() {}

    /// Find the project configuration file, searching upward from the given directory.
    public func find(from directory: URL) -> URL? {
        var current = directory.standardizedFileURL

        while true {
            for name in Self.configFileNames {
                let candidate = current.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }

            let parent = current.deletingLastPathComponent().standardizedFileURL
            if parent.path == current.path { break } // reached root
            current = parent
        }

        return nil
    }

    /// Get the project root directory from a config file URL.
    public func projectRoot(from configURL: URL) -> URL {
        configURL.deletingLastPathComponent()
    }
}
