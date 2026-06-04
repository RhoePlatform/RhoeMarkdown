import Foundation

#if !os(WASI)

/// Finds external binaries on the system by searching PATH and common locations.
public struct ToolDiscovery: Sendable {

    /// Standard locations to search beyond $PATH
    private static let commonPaths = [
        "/usr/local/bin",
        "/opt/homebrew/bin",
        "/usr/bin",
        "/bin"
    ]

    /// Find the full path to a named tool binary.
    ///
    /// Searches in order:
    /// 1. Additional paths provided by the caller
    /// 2. System PATH via `/usr/bin/which`
    /// 3. Common installation locations
    ///
    /// - Parameters:
    ///   - name: The tool name (e.g., "dot", "mmdc", "d2")
    ///   - additionalPaths: Extra directories to search first
    /// - Returns: The full path to the binary, or `nil` if not found
    public static func findTool(
        named name: String,
        additionalPaths: [String] = []
    ) -> String? {
        // 1. Check additional paths directly
        for dir in additionalPaths {
            let path = (dir as NSString).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // 2. Use /usr/bin/which to search $PATH
        if let path = whichTool(name) {
            return path
        }

        // 3. Check common locations
        for dir in commonPaths {
            let path = (dir as NSString).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }

    /// Run a synchronous process and capture its stdout.
    ///
    /// - Parameters:
    ///   - executablePath: Full path to the executable
    ///   - arguments: Command-line arguments
    ///   - stdinData: Optional data to pipe to stdin
    ///   - timeout: Maximum execution time in seconds (default 30)
    /// - Returns: Tuple of (stdout data, stderr string, exit code), or nil on failure
    public static func runProcess(
        executablePath: String,
        arguments: [String],
        stdinData: Data? = nil,
        timeout: TimeInterval = 30
    ) -> (stdout: Data, stderr: String, exitCode: Int32)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let stdinData = stdinData {
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            do {
                try process.run()
                stdinPipe.fileHandleForWriting.write(stdinData)
                stdinPipe.fileHandleForWriting.closeFile()
            } catch {
                return nil
            }
        } else {
            do {
                try process.run()
            } catch {
                return nil
            }
        }

        // Set up timeout
        let timeoutDate = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < timeoutDate {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            return nil
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrString = String(data: stderrData, encoding: .utf8) ?? ""

        return (stdoutData, stderrString, process.terminationStatus)
    }

    // MARK: - Private

    private static func whichTool(_ name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let result = path, !result.isEmpty else { return nil }
        return result
    }
}

#endif // !os(WASI)
