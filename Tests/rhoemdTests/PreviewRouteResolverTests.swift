import Foundation
@testable import RhoeMDServer
import Testing

@Suite("rhoemd Preview Route Resolver")
struct PreviewRouteResolverTests {
    @Test func routeFallsBackToSourceStemWhenOutputIsMissing() {
        let route = PreviewRouteResolver.route(fromOutput: nil, sourcePath: "/tmp/research-note.md")
        #expect(route == "/research-note")
    }

    @Test func routeAcceptsURLPathAndPlainOutputNames() {
        #expect(
            PreviewRouteResolver.route(
                fromOutput: "http://127.0.0.1:37911/lab/draft.html",
                sourcePath: "/tmp/input.md"
            ) == "/lab/draft.html"
        )
        #expect(
            PreviewRouteResolver.route(fromOutput: "preview.html", sourcePath: "/tmp/input.md") == "/preview.html"
        )
    }

    @Test func routeNormalizesQueriesWhitespaceAndFileURLs() {
        #expect(
            PreviewRouteResolver.route(fromOutput: "  docs//draft?cache=false  ", sourcePath: "/tmp/input.md")
                == "/docs/draft"
        )
        #expect(
            PreviewRouteResolver.route(fromOutput: "file:///tmp/preview.html", sourcePath: "/tmp/input.md")
                == "/preview.html"
        )
        #expect(
            PreviewRouteResolver.route(fromOutput: "/", sourcePath: "/tmp/input.md")
                == "/"
        )
    }

    @Test func routeCollisionAddsDotNumberBeforeExtension() {
        let first = PreviewRouteResolver.route(
            "/lab/draft.html",
            avoiding: ["/lab/draft.html"]
        )
        #expect(first.route == "/lab/draft.1.html")
        #expect(first.fallbackApplied)

        let second = PreviewRouteResolver.route(
            "/lab/draft.html",
            avoiding: ["/lab/draft.html", "/lab/draft.1.html"]
        )
        #expect(second.route == "/lab/draft.2.html")
        #expect(second.fallbackApplied)
    }

    @Test func routeCollisionWithoutExtensionAppendsDotNumber() {
        let resolved = PreviewRouteResolver.route(
            "/lab/draft",
            avoiding: ["/lab/draft", "/lab/draft.1"]
        )
        #expect(resolved.route == "/lab/draft.2")
        #expect(resolved.fallbackApplied)
    }

    @Test func unregisterRemovesRouteFromRegistry() async throws {
        let sourceURL = try temporaryMarkdown(named: "preview-unregister.md")
        let registry = PreviewDocumentRegistry()

        _ = try await registry.register(
            sourcePath: sourceURL.path,
            requestedRoute: "/demo",
            options: .init(openBrowser: false),
            host: "127.0.0.1",
            port: 37911
        )
        #expect(await registry.routes().map(\.route) == ["/demo"])

        let response = await registry.unregister(route: "/demo")

        #expect(response.route == "/demo")
        #expect(response.removed)
        #expect(response.documentCount == 0)
        #expect(await registry.routes().isEmpty)
    }

    @Test func shutdownClearsRegisteredRoutes() async throws {
        let sourceURL = try temporaryMarkdown(named: "preview-shutdown.md")
        let registry = PreviewDocumentRegistry()

        _ = try await registry.register(
            sourcePath: sourceURL.path,
            requestedRoute: "/shutdown-demo",
            options: .init(openBrowser: false),
            host: "127.0.0.1",
            port: 37911
        )

        let response = await registry.shutdown()

        #expect(response.status == "shutting_down")
        #expect(response.documentCount == 1)
        #expect(await registry.routes().isEmpty)
    }

    @Test func controlClientReportsOfflineWhenRegistryIsMissing() async {
        let registryURL = temporaryDirectory().appendingPathComponent("missing-preview-daemon.json")

        let snapshot = await PreviewDaemonControlClient.snapshot(registryURL: registryURL)

        #expect(snapshot.state == .offline)
        #expect(snapshot.routes.isEmpty)
        #expect(snapshot.record == nil)
    }

    @Test func controlClientRemovesStaleRegistryOnStop() async throws {
        let registryURL = temporaryDirectory().appendingPathComponent("stale-preview-daemon.json")
        let record = PreviewDaemonRecord(
            pid: 999_999,
            host: "127.0.0.1",
            port: 37911,
            logPath: temporaryDirectory().appendingPathComponent("stale.log").path,
            startedAt: Date()
        )
        try PreviewDaemonRegistry.save(record, to: registryURL)

        let response = try await PreviewDaemonControlClient.stopServer(registryURL: registryURL)

        #expect(response.mode == .staleRecord)
        #expect(response.pid == 999_999)
        #expect(FileManager.default.fileExists(atPath: registryURL.path) == false)
    }

    @Test func routeListDecodingSupportsControlClientPayload() throws {
        let json = """
        [
          {
            "route": "/demo",
            "sourcePath": "/tmp/demo.md",
            "version": 3,
            "lastError": null
          }
        ]
        """

        let routes = try PreviewDaemonControlClient.decodeRoutes(Data(json.utf8))

        #expect(routes.count == 1)
        #expect(routes.first?.route == "/demo")
        #expect(routes.first?.sourcePath == "/tmp/demo.md")
        #expect(routes.first?.version == 3)
        #expect(routes.first?.lastError == nil)
    }

    @Test func menuTitleFormatterCapsLabelsAtThirtyCharacters() {
        let route = PreviewRouteSummary(
            route: "/research/very-long-preview-document-name.html",
            sourcePath: "/tmp/very-long-preview-document-name.md",
            version: 1,
            lastError: nil
        )

        let title = PreviewMenuTitleFormatter.title(for: route)

        #expect(title.count <= PreviewMenuTitleFormatter.maxMenuTitleLength)
        #expect(title.hasSuffix("..."))
    }

    private func temporaryMarkdown(named name: String) throws -> URL {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try "# Preview\n\nA menu-bar smoke fixture.\n".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("rhoemd-preview-tests", isDirectory: true)
    }
}
