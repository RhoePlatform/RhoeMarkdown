#if os(macOS)
import Combine
import Foundation
import RhoeMDServer

@MainActor
final class PreviewMenuStore: ObservableObject {
    @Published private(set) var snapshot = PreviewDaemonSnapshot(
        state: .offline,
        record: nil,
        health: nil,
        routes: [],
        errorMessage: nil
    )
    @Published private(set) var isBusy = false
    @Published private(set) var lastMessage: String?

    private var pollingTask: Task<Void, Never>?

    init() {
        pollingTask = Task { [weak self] in
            await self?.poll()
        }
    }

    deinit {
        pollingTask?.cancel()
    }

    var routes: [PreviewRouteSummary] {
        snapshot.routes
    }

    var statusTitle: String {
        switch snapshot.state {
        case .online:
            return snapshot.routes.isEmpty ? "RhoeMD" : "RhoeMD \(snapshot.routes.count)"
        case .stale:
            return "RhoeMD Stale"
        case .error:
            return "RhoeMD Error"
        case .offline:
            return "RhoeMD Off"
        }
    }

    var statusSystemImage: String {
        switch snapshot.state {
        case .online:
            return "bolt.horizontal.circle.fill"
        case .stale:
            return "clock.badge.exclamationmark"
        case .error:
            return "exclamationmark.triangle.fill"
        case .offline:
            return "pause.circle"
        }
    }

    var statusDetail: String {
        switch snapshot.state {
        case .online:
            let base = snapshot.baseURLString ?? "localhost"
            let count = snapshot.routes.count == 1 ? "1 document" : "\(snapshot.routes.count) documents"
            return "\(base) · \(count)"
        case .stale:
            return "Stale daemon record"
        case .error:
            return snapshot.errorMessage ?? "Unable to reach daemon"
        case .offline:
            return "No preview server running"
        }
    }

    func refresh() async {
        snapshot = await PreviewDaemonControlClient.snapshot()
    }

    func startServer() {
        runBusyAction("Starting server") {
            _ = try await PreviewDaemonControlClient.startServer(relativeTo: Bundle.main.executablePath)
            await self.refresh()
        }
    }

    func stopServer() {
        runBusyAction("Stopping server") {
            _ = try await PreviewDaemonControlClient.stopServer()
            await self.refresh()
        }
    }

    func restartServer() {
        runBusyAction("Restarting server") {
            _ = try await PreviewDaemonControlClient.restartServer(relativeTo: Bundle.main.executablePath)
            await self.refresh()
        }
    }

    func stopWatching(route: String) {
        runBusyAction("Stopping route") {
            _ = try await PreviewDaemonControlClient.unregister(route: route)
            await self.refresh()
        }
    }

    func openDefaultBrowser(route: PreviewRouteSummary) {
        guard let url = urlString(for: route) else { return }
        _ = PreviewDaemonControlClient.openDefaultBrowser(urlString: url)
    }

    func openSafari(route: PreviewRouteSummary) {
        guard let url = urlString(for: route) else { return }
        _ = PreviewDaemonControlClient.openSafari(urlString: url)
    }

    func copyURL(route: PreviewRouteSummary) {
        guard let url = urlString(for: route) else { return }
        if PreviewDaemonControlClient.copyToPasteboard(url) {
            lastMessage = "Copied URL"
        }
    }

    func revealSource(route: PreviewRouteSummary) {
        _ = PreviewDaemonControlClient.revealSource(path: route.sourcePath)
    }

    func openLog() {
        guard let path = snapshot.record?.logPath, !path.isEmpty else { return }
        _ = PreviewDaemonControlClient.openLog(path: path)
    }

    func urlString(for route: PreviewRouteSummary) -> String? {
        guard let record = snapshot.record else { return nil }
        return "\(record.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")))\(route.route)"
    }

    private func runBusyAction(_ label: String, _ operation: @escaping @MainActor () async throws -> Void) {
        guard !isBusy else { return }
        isBusy = true
        lastMessage = label
        Task { @MainActor in
            do {
                try await operation()
                lastMessage = nil
            } catch {
                lastMessage = error.localizedDescription
            }
            isBusy = false
        }
    }

    private func poll() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(2))
        }
    }
}
#endif
