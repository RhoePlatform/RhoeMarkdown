import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
#if os(macOS)
import AppKit
#endif

public enum PreviewDaemonState: String, Codable, Sendable {
    case offline
    case stale
    case online
    case error
}

public struct PreviewDaemonSnapshot: Codable, Sendable {
    public let state: PreviewDaemonState
    public let record: PreviewDaemonRecord?
    public let health: PreviewHealthResponse?
    public let routes: [PreviewRouteSummary]
    public let errorMessage: String?

    public init(
        state: PreviewDaemonState,
        record: PreviewDaemonRecord?,
        health: PreviewHealthResponse?,
        routes: [PreviewRouteSummary],
        errorMessage: String?
    ) {
        self.state = state
        self.record = record
        self.health = health
        self.routes = routes
        self.errorMessage = errorMessage
    }

    public var baseURLString: String? {
        record?.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

public struct PreviewDaemonStartResponse: Sendable {
    public let record: PreviewDaemonRecord
    public let reused: Bool
}

public enum PreviewDaemonStopMode: String, Codable, Sendable {
    case notRunning
    case endpoint
    case signal
    case staleRecord
}

public struct PreviewDaemonStopResponse: Codable, Sendable {
    public let mode: PreviewDaemonStopMode
    public let pid: Int32?
}

public enum PreviewDaemonControlError: LocalizedError {
    case daemonExecutableNotFound
    case daemonRegistryMissing
    case invalidURL
    case requestFailed(String)

    public var errorDescription: String? {
        switch self {
        case .daemonExecutableNotFound:
            return "Unable to locate rhoemd to start the preview daemon"
        case .daemonRegistryMissing:
            return "No RhoeMarkdown preview daemon registry record exists"
        case .invalidURL:
            return "Unable to construct preview daemon control URL"
        case .requestFailed(let detail):
            return "Preview daemon control request failed: \(detail)"
        }
    }
}

public enum PreviewDaemonControlClient {
    public static func snapshot(registryURL: URL = PreviewDaemonRegistry.defaultRecordURL) async -> PreviewDaemonSnapshot {
        guard let record = PreviewDaemonRegistry.load(from: registryURL) else {
            return .init(state: .offline, record: nil, health: nil, routes: [], errorMessage: nil)
        }

        guard PreviewProcess.processMayExist(pid: record.pid) else {
            return .init(state: .stale, record: record, health: nil, routes: [], errorMessage: "Recorded daemon process is not running")
        }

        do {
            let health = try await health(record: record)
            let routes = try await routes(record: record)
            return .init(state: .online, record: record, health: health, routes: routes, errorMessage: nil)
        } catch {
            return .init(state: .error, record: record, health: nil, routes: [], errorMessage: error.localizedDescription)
        }
    }

    public static func startServer(
        executablePath: String? = nil,
        relativeTo siblingExecutablePath: String? = nil,
        host: String = "127.0.0.1",
        port: Int = 37911,
        verbose: Bool = false
    ) async throws -> PreviewDaemonStartResponse {
        if let record = PreviewDaemonRegistry.load(),
           PreviewProcess.processMayExist(pid: record.pid),
           (try? await health(record: record)) != nil {
            return .init(record: record, reused: true)
        }

        PreviewDaemonRegistry.remove()
        guard let executableURL = PreviewDaemonExecutableResolver.resolveDaemonExecutable(
            preferred: executablePath,
            relativeTo: siblingExecutablePath
        ) else {
            throw PreviewDaemonControlError.daemonExecutableNotFound
        }

        let record = try spawnDaemon(
            executableURL: executableURL,
            host: host,
            port: port,
            verbose: verbose
        )
        for _ in 0..<40 {
            if (try? await health(record: record)) != nil {
                return .init(record: record, reused: false)
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return .init(record: record, reused: false)
    }

    public static func stopServer(registryURL: URL = PreviewDaemonRegistry.defaultRecordURL) async throws -> PreviewDaemonStopResponse {
        guard let record = PreviewDaemonRegistry.load(from: registryURL) else {
            return .init(mode: .notRunning, pid: nil)
        }

        guard PreviewProcess.processMayExist(pid: record.pid) else {
            PreviewDaemonRegistry.remove(registryURL)
            return .init(mode: .staleRecord, pid: record.pid)
        }

        if (try? await postShutdown(record: record)) != nil {
            PreviewDaemonRegistry.remove(registryURL)
            return .init(mode: .endpoint, pid: record.pid)
        }

        _ = PreviewProcess.terminate(pid: record.pid)
        PreviewDaemonRegistry.remove(registryURL)
        return .init(mode: .signal, pid: record.pid)
    }

    public static func restartServer(
        executablePath: String? = nil,
        relativeTo siblingExecutablePath: String? = nil,
        host: String = "127.0.0.1",
        port: Int = 37911,
        verbose: Bool = false
    ) async throws -> PreviewDaemonStartResponse {
        _ = try await stopServer()
        try? await Task.sleep(for: .milliseconds(250))
        return try await startServer(
            executablePath: executablePath,
            relativeTo: siblingExecutablePath,
            host: host,
            port: port,
            verbose: verbose
        )
    }

    public static func unregister(route: String, registryURL: URL = PreviewDaemonRegistry.defaultRecordURL) async throws -> PreviewRouteMutationResponse {
        guard let record = PreviewDaemonRegistry.load(from: registryURL) else {
            throw PreviewDaemonControlError.daemonRegistryMissing
        }
        guard let url = URL(string: "/__rhoemd/preview/routes?path=\(route.urlQueryEscaped)", relativeTo: record.baseURL) else {
            throw PreviewDaemonControlError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(PreviewRouteMutationResponse.self, from: data)
    }

    public static func health(record: PreviewDaemonRecord) async throws -> PreviewHealthResponse {
        guard let url = URL(string: "/__rhoemd/preview/health", relativeTo: record.baseURL) else {
            throw PreviewDaemonControlError.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(PreviewHealthResponse.self, from: data)
    }

    public static func routes(record: PreviewDaemonRecord) async throws -> [PreviewRouteSummary] {
        guard let url = URL(string: "/__rhoemd/preview/routes", relativeTo: record.baseURL) else {
            throw PreviewDaemonControlError.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)
        return try decodeRoutes(data)
    }

    public static func decodeRoutes(_ data: Data) throws -> [PreviewRouteSummary] {
        try JSONDecoder().decode([PreviewRouteSummary].self, from: data)
    }

    public static func openDefaultBrowser(urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        #if os(macOS)
        return NSWorkspace.shared.open(url)
        #else
        return false
        #endif
    }

    public static func openSafari(urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        #if os(macOS)
        let safariURL = URL(fileURLWithPath: "/Applications/Safari.app")
        guard FileManager.default.fileExists(atPath: safariURL.path) else { return false }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: safariURL, configuration: configuration)
        return true
        #else
        return false
        #endif
    }

    public static func revealSource(path: String) -> Bool {
        #if os(macOS)
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        return true
        #else
        return false
        #endif
    }

    public static func copyToPasteboard(_ value: String) -> Bool {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(value, forType: .string)
        #else
        return false
        #endif
    }

    public static func openLog(path: String) -> Bool {
        #if os(macOS)
        return NSWorkspace.shared.open(URL(fileURLWithPath: path))
        #else
        return false
        #endif
    }

    private static func spawnDaemon(
        executableURL: URL,
        host: String,
        port: Int,
        verbose: Bool
    ) throws -> PreviewDaemonRecord {
        let registryURL = PreviewDaemonRegistry.defaultRecordURL
        let logURL = PreviewDaemonRegistry.defaultLogURL
        try FileManager.default.createDirectory(
            at: registryURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: logURL.path) == false {
            _ = FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "__preview-daemon",
            "--host", host,
            "--port", String(port),
            "--registry", registryURL.path,
            "--log", logURL.path,
        ] + (verbose ? ["--verbose"] : [])
        if let logHandle = try? FileHandle(forWritingTo: logURL) {
            _ = try? logHandle.seekToEnd()
            process.standardOutput = logHandle
            process.standardError = logHandle
        }
        try process.run()

        let record = PreviewDaemonRecord(
            pid: process.processIdentifier,
            host: host,
            port: port,
            logPath: logURL.path,
            startedAt: Date()
        )
        try PreviewDaemonRegistry.save(record, to: registryURL)
        return record
    }

    private static func postShutdown(record: PreviewDaemonRecord) async throws -> PreviewShutdownResponse {
        guard let url = URL(string: "/__rhoemd/preview/shutdown", relativeTo: record.baseURL) else {
            throw PreviewDaemonControlError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(PreviewShutdownResponse.self, from: data)
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PreviewDaemonControlError.requestFailed(String(data: data, encoding: .utf8) ?? "unknown error")
        }
    }
}

public struct PreviewMenuRecord: Codable, Sendable {
    public let pid: Int32
    public let executablePath: String
    public let startedAt: Date
}

public enum PreviewMenuRegistry {
    public static var defaultRecordURL: URL {
        PreviewDaemonRegistry.defaultDirectory.appendingPathComponent("preview-menu.json")
    }

    public static func load(from url: URL = defaultRecordURL) -> PreviewMenuRecord? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PreviewMenuRecord.self, from: data)
    }

    public static func save(_ record: PreviewMenuRecord, to url: URL = defaultRecordURL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(record).write(to: url, options: .atomic)
    }

    public static func saveCurrentProcess(executablePath: String = CommandLine.arguments.first ?? "") {
        try? save(.init(
            pid: ProcessInfo.processInfo.processIdentifier,
            executablePath: executablePath,
            startedAt: Date()
        ))
    }

    public static func runningRecord(from url: URL = defaultRecordURL) -> PreviewMenuRecord? {
        guard let record = load(from: url), PreviewProcess.processMayExist(pid: record.pid) else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return record
    }

    public static func remove(_ url: URL = defaultRecordURL) {
        try? FileManager.default.removeItem(at: url)
    }
}

public enum PreviewMenuLauncher {
    @discardableResult
    public static func launchIfNeeded(
        relativeTo executablePath: String?,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        #if os(macOS)
        guard shouldLaunch(environment: environment) else { return false }
        guard PreviewMenuRegistry.runningRecord() == nil else { return false }
        guard let executableURL = PreviewDaemonExecutableResolver.resolveMenuExecutable(relativeTo: executablePath) else {
            return false
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["--background"]
        if let null = FileHandle(forWritingAtPath: "/dev/null") {
            process.standardOutput = null
            process.standardError = null
        }
        do {
            try process.run()
            try? PreviewMenuRegistry.save(.init(
                pid: process.processIdentifier,
                executablePath: executableURL.path,
                startedAt: Date()
            ))
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    public static func shouldLaunch(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        let value = environment["RHOEMD_PREVIEW_MENU"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !["0", "false", "no", "off"].contains(value ?? "")
    }
}

public enum PreviewDaemonExecutableResolver {
    public static func resolveDaemonExecutable(preferred: String? = nil, relativeTo siblingExecutablePath: String? = nil) -> URL? {
        resolveExecutable(named: "rhoemd", preferred: preferred, relativeTo: siblingExecutablePath)
    }

    public static func resolveMenuExecutable(relativeTo siblingExecutablePath: String? = nil) -> URL? {
        resolveExecutable(named: "rhoemd-preview-menu", preferred: nil, relativeTo: siblingExecutablePath)
    }

    private static func resolveExecutable(named name: String, preferred: String?, relativeTo siblingExecutablePath: String?) -> URL? {
        let fileManager = FileManager.default
        if let preferred {
            let url = URL(fileURLWithPath: preferred).standardizedFileURL
            if fileManager.isExecutableFile(atPath: url.path), url.lastPathComponent == name {
                return url
            }
        }

        if let siblingExecutablePath {
            let sibling = URL(fileURLWithPath: siblingExecutablePath)
                .deletingLastPathComponent()
                .appendingPathComponent(name)
                .standardizedFileURL
            if fileManager.isExecutableFile(atPath: sibling.path) {
                return sibling
            }
        }

        for directory in ProcessInfo.processInfo.environment["PATH", default: ""].split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(name)
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }
}

public enum PreviewMenuTitleFormatter {
    public static let maxMenuTitleLength = 30

    public static func title(for route: PreviewRouteSummary) -> String {
        let fileName = URL(fileURLWithPath: route.sourcePath).lastPathComponent
        let base = route.route == "/" ? fileName : route.route
        return shortened(base.isEmpty ? fileName : base, maxLength: maxMenuTitleLength)
    }

    public static func shortened(_ value: String, maxLength: Int = maxMenuTitleLength) -> String {
        guard value.count > maxLength else { return value }
        guard maxLength > 3 else { return String(value.prefix(maxLength)) }
        return String(value.prefix(maxLength - 3)) + "..."
    }
}

public enum PreviewProcess {
    public static func processMayExist(pid: Int32) -> Bool {
        #if canImport(Darwin) || canImport(Glibc)
        return kill(pid, 0) == 0
        #else
        return true
        #endif
    }

    @discardableResult
    public static func terminate(pid: Int32) -> Bool {
        #if canImport(Darwin) || canImport(Glibc)
        return kill(pid, SIGTERM) == 0
        #else
        return false
        #endif
    }

    public static func terminateCurrentProcess() {
        #if canImport(Darwin) || canImport(Glibc)
        exit(0)
        #endif
    }
}

private extension String {
    var urlQueryEscaped: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
