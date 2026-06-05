import Foundation
import RhoeMDServer

#if os(macOS)
import AppKit
import SwiftUI

@main
enum RhoeMarkdownPreviewMenuMain {
    static func main() {
        if CommandLine.arguments.contains("--status-json") {
            PreviewMenuStatusPrinter.printStatus()
            return
        }
        RhoeMarkdownPreviewMenuApp.main()
    }
}

private final class PreviewMenuAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        PreviewMenuRegistry.saveCurrentProcess(executablePath: Bundle.main.executablePath ?? CommandLine.arguments.first ?? "")
    }

    func applicationWillTerminate(_ notification: Notification) {
        PreviewMenuRegistry.remove()
    }
}

struct RhoeMarkdownPreviewMenuApp: App {
    @NSApplicationDelegateAdaptor(PreviewMenuAppDelegate.self) private var appDelegate
    @StateObject private var store = PreviewMenuStore()

    var body: some Scene {
        MenuBarExtra {
            PreviewMenuView(store: store)
                .task {
                    await store.refresh()
                }
        } label: {
            Label(store.statusTitle, systemImage: store.statusSystemImage)
        }
        .menuBarExtraStyle(.menu)
    }
}
#else
@main
enum RhoeMarkdownPreviewMenuMain {
    static func main() {
        if CommandLine.arguments.contains("--status-json") {
            PreviewMenuStatusPrinter.printStatus()
        } else {
            print("rhoemd-preview-menu is only available as a macOS menu bar extra.")
        }
    }
}
#endif

enum PreviewMenuStatusPrinter {
    static func printStatus() {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            let snapshot = await PreviewDaemonControlClient.snapshot()
            let payload = PreviewMenuStatusPayload(snapshot: snapshot)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            if let data = try? encoder.encode(payload), let json = String(data: data, encoding: .utf8) {
                print(json)
            } else {
                print("{\"state\":\"error\",\"documentCount\":0}")
            }
            semaphore.signal()
        }
        semaphore.wait()
    }
}

struct PreviewMenuStatusPayload: Codable {
    struct Route: Codable {
        let route: String
        let sourcePath: String
        let version: Int
        let lastError: String?
        let url: String?
    }

    let state: String
    let documentCount: Int
    let pid: Int32?
    let baseURL: String?
    let errorMessage: String?
    let routes: [Route]

    init(snapshot: PreviewDaemonSnapshot) {
        self.state = snapshot.state.rawValue
        self.documentCount = snapshot.routes.count
        self.pid = snapshot.record?.pid
        self.baseURL = snapshot.baseURLString
        self.errorMessage = snapshot.errorMessage
        self.routes = snapshot.routes.map { route in
            Route(
                route: route.route,
                sourcePath: route.sourcePath,
                version: route.version,
                lastError: route.lastError,
                url: snapshot.record.map { "\($0.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")))\(route.route)" }
            )
        }
    }
}
