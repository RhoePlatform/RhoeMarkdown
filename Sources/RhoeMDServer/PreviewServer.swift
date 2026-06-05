import Foundation
import RhoeMarkdownKit

/// Live-preview server for RhoeMarkdown documents.
///
/// Serves rendered HTML via HTTP and refreshes browser previews by polling the
/// shared daemon's version endpoint when the source file changes. Uses
/// `LivePreviewEngine` for cached re-rendering on document edits.
///
/// ## Usage
/// ```swift
/// let server = PreviewServer(file: "/path/to/document.md")
/// try await server.start(port: 3000)
/// // Opens http://localhost:3000 in browser
/// // File changes trigger daemon re-rendering and browser reloads
/// ```
public actor PreviewServer {

    /// Server configuration.
    public struct Configuration: Sendable {
        public var host: String
        public var port: Int
        public var openBrowser: Bool
        public var launchMenu: Bool
        public var verbose: Bool
        public var menuExecutableHint: String?

        public init(
            host: String = "127.0.0.1",
            port: Int = 3000,
            openBrowser: Bool = true,
            launchMenu: Bool = false,
            verbose: Bool = false,
            menuExecutableHint: String? = nil
        ) {
            self.host = host
            self.port = port
            self.openBrowser = openBrowser
            self.launchMenu = launchMenu
            self.verbose = verbose
            self.menuExecutableHint = menuExecutableHint
        }
    }

    private let filePath: String
    private let configuration: Configuration

    public init(
        file: String,
        configuration: Configuration = .init(),
        parserConfiguration: RhoeMarkdownKit.Configuration = .default,
        htmlConfiguration: RhoeMarkdownKit.HTMLConfiguration = .init()
    ) {
        self.filePath = file
        self.configuration = configuration
    }

    /// Start the preview server and begin watching for file changes.
    public func start() async throws {
        let port = configuration.port
        let host = configuration.host
        let verbose = configuration.verbose
        let daemon = PreviewDaemon(
            configuration: .init(
                host: host,
                port: port,
                verbose: verbose,
                registryURL: PreviewDaemonRegistry.defaultRecordURL,
                logURL: PreviewDaemonRegistry.defaultLogURL
            )
        )
        let registration = try await daemon.registerInitialDocument(
            sourcePath: filePath,
            requestedRoute: "/",
            options: .init(openBrowser: false)
        )

        if configuration.openBrowser {
            openInBrowser(url: registration.url)
        }
        if configuration.launchMenu {
            _ = PreviewMenuLauncher.launchIfNeeded(relativeTo: configuration.menuExecutableHint)
        }

        print("Preview server running at \(registration.url)")
        print("Watching: \(filePath)")
        print("Press Ctrl+C to stop.")
        try await daemon.run()
    }

    /// Reset the engine (e.g., when switching files).
    public func reset() async {
        // Kept for source compatibility with older preview integrations. The
        // shared daemon owns per-document engine state and watcher tasks.
    }

    // MARK: - Browser Launch

    private nonisolated func openInBrowser(url: String) {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url]
        try? process.run()
        #endif
    }

}
