#if os(macOS)
import AppKit
import RhoeMDServer
import SwiftUI

struct PreviewMenuView: View {
    @ObservedObject var store: PreviewMenuStore

    var body: some View {
        Section {
            Text("RhoeMarkdown Preview")
            Text(store.statusDetail)
        }

        if let message = store.lastMessage {
            Section {
                Text(PreviewMenuTitleFormatter.shortened(message))
            }
        }

        Section {
            Button("Refresh") {
                Task { await store.refresh() }
            }
            .keyboardShortcut("r")

            Button("Start Server") {
                store.startServer()
            }
            .disabled(store.isBusy || store.snapshot.state == .online)

            Button("Stop Server") {
                store.stopServer()
            }
            .disabled(store.isBusy || store.snapshot.state == .offline)

            Button("Restart Server") {
                store.restartServer()
            }
            .disabled(store.isBusy)

            Button("Open Log") {
                store.openLog()
            }
            .disabled(store.snapshot.record?.logPath.isEmpty ?? true)
        }

        Divider()

        if store.routes.isEmpty {
            Section {
                Text("No watched files")
                Text("Run rhoemd preview")
            }
        } else {
            Section("Watched Files") {
                ForEach(store.routes, id: \.route) { route in
                    Menu(PreviewMenuTitleFormatter.title(for: route)) {
                        if let url = store.urlString(for: route) {
                            Text(PreviewMenuTitleFormatter.shortened(url))
                        }
                        Button("Open Default Browser") {
                            store.openDefaultBrowser(route: route)
                        }
                        Button("Open Safari") {
                            store.openSafari(route: route)
                        }
                        Button("Copy URL") {
                            store.copyURL(route: route)
                        }
                        Button("Reveal Source") {
                            store.revealSource(route: route)
                        }
                        Divider()
                        Button("Stop Watching") {
                            store.stopWatching(route: route.route)
                        }
                    }
                }
            }
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
#endif
