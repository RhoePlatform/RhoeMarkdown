import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Hummingbird
import RhoeMarkdownKit

/// Render options used by the local preview daemon.
public struct PreviewRenderOptions: Codable, Sendable, Equatable {
    public var prettyPrint: Bool
    public var openBrowser: Bool

    public init(prettyPrint: Bool = false, openBrowser: Bool = true) {
        self.prettyPrint = prettyPrint
        self.openBrowser = openBrowser
    }
}

/// Request body accepted by the preview daemon registration endpoint.
public struct PreviewRegisterRequest: ResponseCodable, Sendable {
    public let sourcePath: String
    public let requestedRoute: String?
    public let options: PreviewRenderOptions

    public init(sourcePath: String, requestedRoute: String?, options: PreviewRenderOptions = .init()) {
        self.sourcePath = sourcePath
        self.requestedRoute = requestedRoute
        self.options = options
    }
}

/// Response returned after registering a document with the preview daemon.
public struct PreviewRegisterResponse: ResponseCodable, Sendable {
    public let route: String
    public let url: String
    public let sourcePath: String
    public let pid: Int32
    public let fallbackApplied: Bool

    public init(route: String, url: String, sourcePath: String, pid: Int32, fallbackApplied: Bool) {
        self.route = route
        self.url = url
        self.sourcePath = sourcePath
        self.pid = pid
        self.fallbackApplied = fallbackApplied
    }
}

public struct PreviewHealthResponse: ResponseCodable, Sendable {
    public let status: String
    public let pid: Int32
    public let documentCount: Int

    public init(status: String, pid: Int32, documentCount: Int) {
        self.status = status
        self.pid = pid
        self.documentCount = documentCount
    }
}

public struct PreviewRouteSummary: ResponseCodable, Sendable {
    public let route: String
    public let sourcePath: String
    public let version: Int
    public let lastError: String?

    public init(route: String, sourcePath: String, version: Int, lastError: String?) {
        self.route = route
        self.sourcePath = sourcePath
        self.version = version
        self.lastError = lastError
    }
}

public struct PreviewVersionResponse: ResponseCodable, Sendable {
    public let route: String
    public let version: Int
    public let lastError: String?

    public init(route: String, version: Int, lastError: String?) {
        self.route = route
        self.version = version
        self.lastError = lastError
    }
}

public struct PreviewRouteMutationResponse: ResponseCodable, Sendable {
    public let route: String
    public let removed: Bool
    public let documentCount: Int

    public init(route: String, removed: Bool, documentCount: Int) {
        self.route = route
        self.removed = removed
        self.documentCount = documentCount
    }
}

public struct PreviewShutdownResponse: ResponseCodable, Sendable {
    public let status: String
    public let pid: Int32
    public let documentCount: Int

    public init(status: String, pid: Int32, documentCount: Int) {
        self.status = status
        self.pid = pid
        self.documentCount = documentCount
    }
}

/// Normalizes user-provided preview routes and resolves route collisions.
public enum PreviewRouteResolver {
    public static func defaultRoute(for sourcePath: String) -> String {
        let url = URL(fileURLWithPath: sourcePath)
        let stem = url.deletingPathExtension().lastPathComponent
        return normalizeRoute(stem.isEmpty ? "preview" : stem)
    }

    public static func route(fromOutput output: String?, sourcePath: String) -> String {
        guard let output, !output.isEmpty else {
            return defaultRoute(for: sourcePath)
        }

        if let components = URLComponents(string: output),
           let scheme = components.scheme,
           ["http", "https"].contains(scheme.lowercased()),
           !components.path.isEmpty {
            return normalizeRoute(components.path)
        }

        return normalizeRoute(output)
    }

    public static func normalizeRoute(_ route: String) -> String {
        let trimmed = route.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutQuery = trimmed.split(separator: "?", maxSplits: 1).first.map(String.init) ?? trimmed
        var normalized = withoutQuery
        if normalized.hasPrefix("file://"), let url = URL(string: normalized) {
            normalized = url.lastPathComponent
        }
        if normalized.isEmpty || normalized == "/" {
            return "/"
        }
        if !normalized.hasPrefix("/") {
            normalized = "/" + normalized
        }
        while normalized.contains("//") {
            normalized = normalized.replacingOccurrences(of: "//", with: "/")
        }
        return normalized
    }

    public static func route(_ requestedRoute: String, avoiding existingRoutes: Set<String>) -> (route: String, fallbackApplied: Bool) {
        let normalized = normalizeRoute(requestedRoute)
        guard existingRoutes.contains(normalized) else {
            return (normalized, false)
        }

        let nsPath = normalized as NSString
        let directory = nsPath.deletingLastPathComponent
        let last = nsPath.lastPathComponent
        let ext = (last as NSString).pathExtension
        let stem = ext.isEmpty ? last : (last as NSString).deletingPathExtension

        for index in 1...10_000 {
            let candidateName = ext.isEmpty ? "\(stem).\(index)" : "\(stem).\(index).\(ext)"
            let candidate = directory == "/" || directory == "."
                ? "/\(candidateName)"
                : "\(directory)/\(candidateName)"
            if !existingRoutes.contains(candidate) {
                return (candidate, true)
            }
        }

        return ("\(normalized).\(UUID().uuidString)", true)
    }
}

/// Location and process metadata for the shared local preview daemon.
public struct PreviewDaemonRecord: Codable, Sendable {
    public let pid: Int32
    public let host: String
    public let port: Int
    public let logPath: String
    public let startedAt: Date

    public init(pid: Int32, host: String, port: Int, logPath: String, startedAt: Date) {
        self.pid = pid
        self.host = host
        self.port = port
        self.logPath = logPath
        self.startedAt = startedAt
    }

    public var baseURL: URL {
        URL(string: "http://\(host):\(port)")!
    }
}

public enum PreviewDaemonRegistry {
    public static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".rhoe", isDirectory: true)
            .appendingPathComponent("rhoemd", isDirectory: true)
    }

    public static var defaultRecordURL: URL {
        defaultDirectory.appendingPathComponent("preview-daemon.json")
    }

    public static var defaultLogURL: URL {
        defaultDirectory.appendingPathComponent("preview-daemon.log")
    }

    public static func load(from url: URL = defaultRecordURL) -> PreviewDaemonRecord? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PreviewDaemonRecord.self, from: data)
    }

    public static func save(_ record: PreviewDaemonRecord, to url: URL = defaultRecordURL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(record).write(to: url, options: .atomic)
    }

    public static func remove(_ url: URL = defaultRecordURL) {
        try? FileManager.default.removeItem(at: url)
    }
}

/// Shared Hummingbird preview daemon that can serve many watched Markdown files.
public final class PreviewDaemon: @unchecked Sendable {
    public struct Configuration: Sendable {
        public var host: String
        public var port: Int
        public var verbose: Bool
        public var registryURL: URL?
        public var logURL: URL?
        public var shutdownAction: (@Sendable () -> Void)?

        public init(
            host: String = "127.0.0.1",
            port: Int = 37911,
            verbose: Bool = false,
            registryURL: URL? = PreviewDaemonRegistry.defaultRecordURL,
            logURL: URL? = PreviewDaemonRegistry.defaultLogURL,
            shutdownAction: (@Sendable () -> Void)? = nil
        ) {
            self.host = host
            self.port = port
            self.verbose = verbose
            self.registryURL = registryURL
            self.logURL = logURL
            self.shutdownAction = shutdownAction
        }
    }

    private let configuration: Configuration
    private let registry = PreviewDocumentRegistry()

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    @discardableResult
    public func registerInitialDocument(
        sourcePath: String,
        requestedRoute: String?,
        options: PreviewRenderOptions = .init(openBrowser: false)
    ) async throws -> PreviewRegisterResponse {
        try await registry.register(
            sourcePath: sourcePath,
            requestedRoute: requestedRoute,
            options: options,
            host: configuration.host,
            port: configuration.port
        )
    }

    public func run() async throws {
        if let registryURL = configuration.registryURL {
            let logPath = configuration.logURL?.path ?? ""
            try PreviewDaemonRegistry.save(
                .init(
                    pid: ProcessInfo.processInfo.processIdentifier,
                    host: configuration.host,
                    port: configuration.port,
                    logPath: logPath,
                    startedAt: Date()
                ),
                to: registryURL
            )
        }

        let router = Router()
        router.get("/__rhoemd/preview/health") { _, _ async -> PreviewHealthResponse in
            await self.registry.health()
        }
        router.get("/__rhoemd/preview/routes") { _, _ async -> [PreviewRouteSummary] in
            await self.registry.routes()
        }
        router.delete("/__rhoemd/preview/routes") { request, _ async -> PreviewRouteMutationResponse in
            let route = request.uri.queryParameters["path"].map { String($0) } ?? "/"
            return await self.registry.unregister(route: route)
        }
        router.get("/__rhoemd/preview/version") { request, _ async throws -> PreviewVersionResponse in
            let route = request.uri.queryParameters["path"].map { String($0) } ?? "/"
            guard let response = await self.registry.version(for: route) else {
                throw HTTPError(.notFound)
            }
            return response
        }
        router.post("/__rhoemd/preview/register") { request, context async throws -> PreviewRegisterResponse in
            let registration = try await request.decode(as: PreviewRegisterRequest.self, context: context)
            return try await self.registry.register(
                sourcePath: registration.sourcePath,
                requestedRoute: registration.requestedRoute,
                options: registration.options,
                host: self.configuration.host,
                port: self.configuration.port
            )
        }
        router.post("/__rhoemd/preview/shutdown") { _, _ async -> PreviewShutdownResponse in
            let response = await self.registry.shutdown()
            if let registryURL = self.configuration.registryURL {
                PreviewDaemonRegistry.remove(registryURL)
            }
            let shutdownAction = self.configuration.shutdownAction ?? PreviewProcess.terminateCurrentProcess
            Task.detached {
                try? await Task.sleep(for: .milliseconds(150))
                shutdownAction()
            }
            return response
        }
        router.get("/**") { request, _ async -> Response in
            let route = PreviewRouteResolver.normalizeRoute(request.uri.path)
            guard let html = await self.registry.html(for: route) else {
                return Self.htmlResponse(Self.notFoundHTML(route: route), status: .notFound)
            }
            return Self.htmlResponse(html)
        }

        var app = Application(
            responder: router.buildResponder(),
            configuration: .init(
                address: .hostname(configuration.host, port: configuration.port),
                serverName: "rhoemd-preview"
            )
        )
        if configuration.verbose {
            app.logger.logLevel = .debug
        }
        print("rhoemd preview daemon listening at http://\(configuration.host):\(configuration.port)")
        try await app.runService()
    }

    private static func htmlResponse(_ html: String, status: HTTPResponse.Status = .ok) -> Response {
        Response(
            status: status,
            headers: [.contentType: "text/html; charset=utf-8"],
            body: .init(byteBuffer: ByteBuffer(string: html))
        )
    }

    private static func notFoundHTML(route: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head><meta charset="utf-8"><title>RhoeMarkdown Preview Not Found</title></head>
        <body>
        <h1>Preview route not found</h1>
        <p>No RhoeMarkdown preview document is registered at <code>\(escapeHTML(route))</code>.</p>
        </body>
        </html>
        """
    }
}

actor PreviewDocumentRegistry {
    private final class Document: @unchecked Sendable {
        let route: String
        let sourceURL: URL
        let engine: LivePreviewEngine
        let options: PreviewRenderOptions
        var html: String = ""
        var version: Int = 0
        var lastError: String?
        var lastModified: Date?
        var watcherTask: Task<Void, Never>?

        init(route: String, sourceURL: URL, options: PreviewRenderOptions) {
            self.route = route
            self.sourceURL = sourceURL
            self.options = options
            self.engine = LivePreviewEngine(
                htmlConfiguration: .init(prettyPrint: options.prettyPrint)
            )
        }
    }

    private var documents: [String: Document] = [:]

    func health() -> PreviewHealthResponse {
        .init(
            status: "ok",
            pid: ProcessInfo.processInfo.processIdentifier,
            documentCount: documents.count
        )
    }

    func routes() -> [PreviewRouteSummary] {
        documents.values
            .sorted { $0.route < $1.route }
            .map {
                PreviewRouteSummary(
                    route: $0.route,
                    sourcePath: $0.sourceURL.path,
                    version: $0.version,
                    lastError: $0.lastError
                )
            }
    }

    func html(for route: String) -> String? {
        documents[PreviewRouteResolver.normalizeRoute(route)]?.html
    }

    func version(for route: String) -> PreviewVersionResponse? {
        let normalized = PreviewRouteResolver.normalizeRoute(route)
        guard let document = documents[normalized] else { return nil }
        return .init(route: normalized, version: document.version, lastError: document.lastError)
    }

    func unregister(route: String) -> PreviewRouteMutationResponse {
        let normalized = PreviewRouteResolver.normalizeRoute(route)
        let removed = documents.removeValue(forKey: normalized)
        removed?.watcherTask?.cancel()
        return .init(route: normalized, removed: removed != nil, documentCount: documents.count)
    }

    func shutdown() -> PreviewShutdownResponse {
        for document in documents.values {
            document.watcherTask?.cancel()
        }
        let count = documents.count
        documents.removeAll()
        return .init(status: "shutting_down", pid: ProcessInfo.processInfo.processIdentifier, documentCount: count)
    }

    func register(
        sourcePath: String,
        requestedRoute: String?,
        options: PreviewRenderOptions,
        host: String,
        port: Int
    ) async throws -> PreviewRegisterResponse {
        let sourceURL = URL(fileURLWithPath: sourcePath).standardizedFileURL
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw HTTPError(.badRequest, message: "Markdown source not found: \(sourceURL.path)")
        }

        let requested = requestedRoute ?? PreviewRouteResolver.defaultRoute(for: sourceURL.path)
        let existingForOtherSources = Set(
            documents.values
                .filter { $0.sourceURL != sourceURL }
                .map(\.route)
        )
        let resolved = PreviewRouteResolver.route(requested, avoiding: existingForOtherSources)

        if let existing = documents[resolved.route] {
            existing.watcherTask?.cancel()
        }

        let document = Document(route: resolved.route, sourceURL: sourceURL, options: options)
        documents[resolved.route] = document
        try await render(route: resolved.route)
        startWatcher(for: resolved.route)

        return .init(
            route: resolved.route,
            url: "http://\(host):\(port)\(resolved.route)",
            sourcePath: sourceURL.path,
            pid: ProcessInfo.processInfo.processIdentifier,
            fallbackApplied: resolved.fallbackApplied
        )
    }

    private func startWatcher(for route: String) {
        guard let document = documents[route] else { return }
        document.watcherTask?.cancel()
        document.lastModified = Self.modificationDate(for: document.sourceURL)
        document.watcherTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(350))
                guard let self else { return }
                await self.renderIfChanged(route: route)
            }
        }
    }

    private func renderIfChanged(route: String) async {
        guard let document = documents[route] else { return }
        let currentModified = Self.modificationDate(for: document.sourceURL)
        guard currentModified != document.lastModified else { return }
        document.lastModified = currentModified
        try? await render(route: route)
    }

    private func render(route: String) async throws {
        guard let document = documents[route] else { return }
        do {
            let markdown = try String(contentsOf: document.sourceURL, encoding: .utf8)
            let rendered = await document.engine.update(markdown)
            document.version += 1
            document.lastError = nil
            document.html = Self.wrapHTMLDocument(
                bodyHTML: rendered.html,
                route: route,
                version: document.version,
                sourcePath: document.sourceURL.path
            )
        } catch {
            document.version += 1
            document.lastError = error.localizedDescription
            document.html = Self.wrapErrorDocument(
                route: route,
                sourcePath: document.sourceURL.path,
                error: error.localizedDescription,
                version: document.version
            )
        }
    }

    private static func modificationDate(for url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
    }

    private static func wrapHTMLDocument(bodyHTML: String, route: String, version: Int, sourcePath: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>RhoeMarkdown Preview</title>
            <style>\(previewCSS)</style>
        </head>
        <body>
        <main class="rhoe-preview-document">
        \(bodyHTML)
        </main>
        \(statusBar(route: route, sourcePath: sourcePath))
        \(reloadScript(route: route, version: version))
        </body>
        </html>
        """
    }

    private static func wrapErrorDocument(route: String, sourcePath: String, error: String, version: Int) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>RhoeMarkdown Preview Error</title>
            <style>\(previewCSS)</style>
        </head>
        <body>
        <main class="rhoe-preview-document rhoe-preview-error">
            <h1>Preview render failed</h1>
            <p><strong>Source:</strong> <code>\(escapeHTML(sourcePath))</code></p>
            <pre><code>\(escapeHTML(error))</code></pre>
        </main>
        \(statusBar(route: route, sourcePath: sourcePath))
        \(reloadScript(route: route, version: version))
        </body>
        </html>
        """
    }

    private static func statusBar(route: String, sourcePath: String) -> String {
        """
        <aside class="rhoe-preview-status">
            <span id="rhoe-preview-live">Live</span>
            <code>\(escapeHTML(route))</code>
            <span title="\(escapeHTML(sourcePath))">Watching source</span>
        </aside>
        """
    }

    private static func reloadScript(route: String, version: Int) -> String {
        let escapedRoute = route.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        return """
        <script>
        (function() {
            let version = \(version);
            const status = document.getElementById('rhoe-preview-live');
            async function poll() {
                try {
                    const response = await fetch('/__rhoemd/preview/version?path=' + encodeURIComponent('\(escapedRoute)'), { cache: 'no-store' });
                    if (!response.ok) { throw new Error('Preview route disappeared'); }
                    const payload = await response.json();
                    status.textContent = payload.lastError ? 'Error' : 'Live';
                    status.className = payload.lastError ? 'error' : '';
                    if (payload.version !== version) { location.reload(); }
                } catch (error) {
                    status.textContent = 'Reconnecting';
                    status.className = 'warning';
                }
            }
            setInterval(poll, 700);
        })();
        </script>
        """
    }

    private static let previewCSS = """
    :root {
        color-scheme: light dark;
        --rhoe-bg: #fbfaf6;
        --rhoe-ink: #18201f;
        --rhoe-muted: #66706e;
        --rhoe-card: rgba(255, 255, 255, 0.78);
        --rhoe-line: rgba(24, 32, 31, 0.12);
        --rhoe-accent: #0d7f68;
    }
    @media (prefers-color-scheme: dark) {
        :root {
            --rhoe-bg: #111614;
            --rhoe-ink: #edf4ef;
            --rhoe-muted: #9eaaa5;
            --rhoe-card: rgba(29, 38, 35, 0.78);
            --rhoe-line: rgba(237, 244, 239, 0.14);
            --rhoe-accent: #59d4b6;
        }
    }
    body {
        margin: 0;
        background:
            radial-gradient(circle at 12% 10%, rgba(13, 127, 104, 0.15), transparent 28rem),
            linear-gradient(135deg, var(--rhoe-bg), color-mix(in srgb, var(--rhoe-bg), var(--rhoe-accent) 7%));
        color: var(--rhoe-ink);
        font-family: Charter, "Iowan Old Style", "Avenir Next", serif;
        line-height: 1.62;
    }
    .rhoe-preview-document {
        width: min(860px, calc(100vw - 3rem));
        margin: 4rem auto 7rem;
        padding: clamp(1.5rem, 3vw, 3rem);
        background: var(--rhoe-card);
        border: 1px solid var(--rhoe-line);
        border-radius: 28px;
        box-shadow: 0 24px 80px rgba(0, 0, 0, 0.12);
        backdrop-filter: blur(16px);
    }
    .rhoe-preview-document h1,
    .rhoe-preview-document h2,
    .rhoe-preview-document h3 {
        line-height: 1.12;
        letter-spacing: -0.025em;
    }
    .rhoe-preview-document code {
        font-family: "SF Mono", Menlo, monospace;
        font-size: 0.92em;
        background: color-mix(in srgb, var(--rhoe-accent), transparent 88%);
        border-radius: 0.35rem;
        padding: 0.1rem 0.3rem;
    }
    .rhoe-preview-document pre {
        overflow-x: auto;
        padding: 1rem;
        border-radius: 16px;
        border: 1px solid var(--rhoe-line);
        background: color-mix(in srgb, var(--rhoe-bg), black 6%);
    }
    .rhoe-preview-error pre {
        white-space: pre-wrap;
        border-color: rgba(190, 45, 45, 0.4);
    }
    .rhoe-preview-status {
        position: fixed;
        right: 1rem;
        bottom: 1rem;
        display: flex;
        gap: 0.65rem;
        align-items: center;
        max-width: calc(100vw - 2rem);
        padding: 0.55rem 0.75rem;
        border: 1px solid var(--rhoe-line);
        border-radius: 999px;
        background: var(--rhoe-card);
        color: var(--rhoe-muted);
        font: 12px/1.2 "Avenir Next", sans-serif;
        box-shadow: 0 14px 44px rgba(0, 0, 0, 0.12);
        backdrop-filter: blur(16px);
    }
    .rhoe-preview-status #rhoe-preview-live {
        color: var(--rhoe-accent);
        font-weight: 700;
    }
    .rhoe-preview-status #rhoe-preview-live.warning { color: #c77d05; }
    .rhoe-preview-status #rhoe-preview-live.error { color: #be2d2d; }
    .rhoe-preview-status code {
        color: var(--rhoe-ink);
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
    }
    """
}

private func escapeHTML(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

/// Client used by `rhoemd preview` to reuse or launch the shared daemon.
public enum PreviewDaemonClient {
    public struct StartOptions: Sendable {
        public var sourcePath: String
        public var output: String?
        public var host: String
        public var port: Int
        public var openBrowser: Bool
        public var prettyPrint: Bool
        public var verbose: Bool

        public init(
            sourcePath: String,
            output: String? = nil,
            host: String = "127.0.0.1",
            port: Int = 37911,
            openBrowser: Bool = true,
            prettyPrint: Bool = false,
            verbose: Bool = false
        ) {
            self.sourcePath = sourcePath
            self.output = output
            self.host = host
            self.port = port
            self.openBrowser = openBrowser
            self.prettyPrint = prettyPrint
            self.verbose = verbose
        }
    }

    public struct StartResult: Sendable {
        public let response: PreviewRegisterResponse
        public let daemonReused: Bool
        public let logPath: String
    }

    public static func startOrAttach(executablePath: String, options: StartOptions) async throws -> StartResult {
        let sourceURL = URL(fileURLWithPath: options.sourcePath).standardizedFileURL
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw PreviewClientError.sourceNotFound(sourceURL.path)
        }

        let requestedRoute = PreviewRouteResolver.route(fromOutput: options.output, sourcePath: sourceURL.path)
        let record = await existingOrStartedDaemon(executablePath: executablePath, options: options)
        let response = try await register(
            sourcePath: sourceURL.path,
            requestedRoute: requestedRoute,
            options: .init(prettyPrint: options.prettyPrint, openBrowser: options.openBrowser),
            record: record.record
        )

        if options.openBrowser {
            openInBrowser(url: response.url)
        }

        return .init(response: response, daemonReused: record.reused, logPath: record.record.logPath)
    }

    private static func existingOrStartedDaemon(
        executablePath: String,
        options: StartOptions
    ) async -> (record: PreviewDaemonRecord, reused: Bool) {
        if let record = PreviewDaemonRegistry.load(),
           await isDaemonHealthy(record) {
            return (record, true)
        }

        PreviewDaemonRegistry.remove()
        let record = spawnDaemon(executablePath: executablePath, options: options)
        for _ in 0..<40 {
            if await isDaemonHealthy(record) {
                return (record, false)
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return (record, false)
    }

    private static func spawnDaemon(executablePath: String, options: StartOptions) -> PreviewDaemonRecord {
        let registryURL = PreviewDaemonRegistry.defaultRecordURL
        let logURL = PreviewDaemonRegistry.defaultLogURL
        try? FileManager.default.createDirectory(
            at: registryURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let executableURL = URL(fileURLWithPath: executablePath).standardizedFileURL
        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "__preview-daemon",
            "--host", options.host,
            "--port", String(options.port),
            "--registry", registryURL.path,
            "--log", logURL.path,
        ] + (options.verbose ? ["--verbose"] : [])

        if FileManager.default.fileExists(atPath: logURL.path) == false {
            _ = FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        if let logHandle = try? FileHandle(forWritingTo: logURL) {
            _ = try? logHandle.seekToEnd()
            process.standardOutput = logHandle
            process.standardError = logHandle
        }
        try? process.run()

        let record = PreviewDaemonRecord(
            pid: process.processIdentifier,
            host: options.host,
            port: options.port,
            logPath: logURL.path,
            startedAt: Date()
        )
        try? PreviewDaemonRegistry.save(record, to: registryURL)
        return record
    }

    private static func isDaemonHealthy(_ record: PreviewDaemonRecord) async -> Bool {
        guard processMayExist(pid: record.pid) else { return false }
        guard let url = URL(string: "/__rhoemd/preview/health", relativeTo: record.baseURL) else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private static func register(
        sourcePath: String,
        requestedRoute: String,
        options: PreviewRenderOptions,
        record: PreviewDaemonRecord
    ) async throws -> PreviewRegisterResponse {
        guard let url = URL(string: "/__rhoemd/preview/register", relativeTo: record.baseURL) else {
            throw PreviewClientError.invalidDaemonURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = try JSONEncoder().encode(
            PreviewRegisterRequest(
                sourcePath: sourcePath,
                requestedRoute: requestedRoute,
                options: options
            )
        )
        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PreviewClientError.registrationFailed(String(data: data, encoding: .utf8) ?? "unknown error")
        }
        return try JSONDecoder().decode(PreviewRegisterResponse.self, from: data)
    }

    private static func processMayExist(pid: Int32) -> Bool {
        #if canImport(Darwin) || canImport(Glibc)
        return kill(pid, 0) == 0
        #else
        return true
        #endif
    }

    private static func openInBrowser(url: String) {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url]
        try? process.run()
        #endif
    }
}

public enum PreviewClientError: LocalizedError {
    case sourceNotFound(String)
    case invalidDaemonURL
    case registrationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .sourceNotFound(let path):
            return "Preview source not found: \(path)"
        case .invalidDaemonURL:
            return "Unable to construct preview daemon URL"
        case .registrationFailed(let detail):
            return "Preview daemon registration failed: \(detail)"
        }
    }
}
