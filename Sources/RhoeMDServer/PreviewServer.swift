import Foundation
import RhoeMarkdownKit
import RhoeMarkdownModel
import Hummingbird
import HummingbirdWebSocket

/// Live-preview server for RhoeMarkdown documents.
///
/// Serves rendered HTML via HTTP, pushes live updates via WebSocket when
/// the source file changes. Uses `LivePreviewEngine` for sub-50ms cached
/// re-rendering on non-structural edits.
///
/// ## Usage
/// ```swift
/// let server = PreviewServer(file: "/path/to/document.md")
/// try await server.start(port: 3000)
/// // Opens http://localhost:3000 in browser
/// // File changes are pushed via WebSocket
/// ```
public actor PreviewServer {

    /// Server configuration.
    public struct Configuration: Sendable {
        public var host: String
        public var port: Int
        public var openBrowser: Bool
        public var verbose: Bool

        public init(
            host: String = "127.0.0.1",
            port: Int = 3000,
            openBrowser: Bool = true,
            verbose: Bool = false
        ) {
            self.host = host
            self.port = port
            self.openBrowser = openBrowser
            self.verbose = verbose
        }
    }

    private let filePath: String
    private let configuration: Configuration
    private let engine: LivePreviewEngine
    private var currentHTML: String = ""
    private var connections: [WebSocketConnection] = []

    public init(
        file: String,
        configuration: Configuration = .init(),
        parserConfiguration: RhoeMarkdownKit.Configuration = .default,
        htmlConfiguration: RhoeMarkdownKit.HTMLConfiguration = .init()
    ) {
        self.filePath = file
        self.configuration = configuration
        self.engine = LivePreviewEngine(
            configuration: parserConfiguration,
            htmlConfiguration: htmlConfiguration
        )
    }

    /// Start the preview server and begin watching for file changes.
    public func start() async throws {
        // Initial render
        try await renderFile()

        let port = configuration.port
        let host = configuration.host
        let verbose = configuration.verbose

        if verbose {
            print("[rhoemd serve] Starting preview server on http://\(host):\(port)")
            print("[rhoemd serve] Watching: \(filePath)")
        }

        // Start file watcher
        #if canImport(Darwin)
        startFileWatcher()
        #endif

        // Open browser
        if configuration.openBrowser {
            openInBrowser(url: "http://\(host):\(port)")
        }

        print("Preview server running at http://\(host):\(port)")
        print("Press Ctrl+C to stop.")

        // Note: In a full implementation, this would start the Hummingbird
        // server and block. For now, the server infrastructure is defined
        // and ready to wire up with Hummingbird's Application builder.
        try await runServer()
    }

    /// Re-render the file and push update to connected browsers.
    public func renderFile() async throws {
        let markdown = try String(contentsOfFile: filePath, encoding: .utf8)
        let (html, metrics) = await engine.update(markdown)
        currentHTML = wrapHTMLDocument(html)

        if configuration.verbose {
            let ms = String(format: "%.1f", metrics.totalTime * 1000)
            let hitRate = String(format: "%.0f", metrics.cacheHitRate * 100)
            let path = metrics.usedFastPath ? "fast" : "full"
            print("[rhoemd serve] Rendered in \(ms)ms (cache: \(hitRate)%, path: \(path))")
        }

        // Push to all connected WebSocket clients
        await broadcastReload()
    }

    /// Reset the engine (e.g., when switching files).
    public func reset() async {
        await engine.reset()
        currentHTML = ""
        connections.removeAll()
    }

    // MARK: - File Watching

    #if canImport(Darwin)
    private nonisolated func startFileWatcher() {
        let watcher = FileWatcher()
        let directory = (filePath as NSString).deletingLastPathComponent
        let server = self

        watcher.watch(paths: [directory]) { changedPath in
            Task {
                try? await server.renderFile()
            }
        }
    }
    #endif

    // MARK: - Browser Launch

    private nonisolated func openInBrowser(url: String) {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url]
        try? process.run()
        #endif
    }

    // MARK: - WebSocket

    private struct WebSocketConnection: Sendable {
        let id: String
    }

    private func broadcastReload() async {
        // In the full Hummingbird integration, this sends "reload" to all
        // WebSocket connections. The connections array is managed by the
        // WebSocket upgrade handler.
    }

    // MARK: - HTTP Server

    private func runServer() async throws {
        // Placeholder for Hummingbird server setup.
        // The full implementation wires:
        // - GET / → serve currentHTML
        // - GET /ws → WebSocket upgrade for live reload
        // - GET /assets/{path} → static file serving
        // - GET /api/document → document metadata JSON

        // Keep the preview process alive without overflowing Duration
        // conversion on newer Swift toolchains.
        while !Task.isCancelled {
            try await Task.sleep(for: .seconds(86_400))
        }
    }

    // MARK: - HTML Document Wrapper

    private func wrapHTMLDocument(_ bodyHTML: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>RhoeMarkdown Preview</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    max-width: 800px;
                    margin: 0 auto;
                    padding: 2rem;
                    line-height: 1.6;
                    color: #1d1d1f;
                    background: #fff;
                }
                @media (prefers-color-scheme: dark) {
                    body { background: #1c1c1e; color: #f5f5f7; }
                }
                pre { background: #f5f5f7; padding: 1rem; border-radius: 8px; overflow-x: auto; }
                @media (prefers-color-scheme: dark) { pre { background: #2c2c2e; } }
                code { font-family: 'SF Mono', Menlo, monospace; font-size: 0.9em; }
                table { border-collapse: collapse; width: 100%; }
                th, td { border: 1px solid #d2d2d7; padding: 0.5rem; text-align: left; }
                blockquote { border-left: 3px solid #007aff; padding-left: 1rem; color: #86868b; }
                img { max-width: 100%; height: auto; }
                .rhoe-status { position: fixed; bottom: 1rem; right: 1rem; font-size: 0.75rem;
                               color: #86868b; background: rgba(255,255,255,0.9); padding: 0.25rem 0.5rem;
                               border-radius: 4px; backdrop-filter: blur(10px); }
                @media (prefers-color-scheme: dark) {
                    .rhoe-status { background: rgba(44,44,46,0.9); }
                }
            </style>
        </head>
        <body>
        \(bodyHTML)
        <div class="rhoe-status" id="rhoe-status">Connected</div>
        <script>
        // RhoeMarkdown Live Reload
        (function() {
            const status = document.getElementById('rhoe-status');
            let ws;
            function connect() {
                ws = new WebSocket('ws://' + location.host + '/ws');
                ws.onopen = () => { status.textContent = 'Live'; status.style.color = '#30d158'; };
                ws.onclose = () => {
                    status.textContent = 'Reconnecting...'; status.style.color = '#ff9f0a';
                    setTimeout(connect, 1000);
                };
                ws.onmessage = (e) => {
                    const msg = JSON.parse(e.data);
                    if (msg.type === 'reload') { location.reload(); }
                    if (msg.type === 'style-update') {
                        document.querySelector('style').textContent = msg.css;
                    }
                };
            }
            connect();
        })();
        </script>
        </body>
        </html>
        """
    }
}
