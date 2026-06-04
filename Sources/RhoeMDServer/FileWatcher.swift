import Foundation

#if canImport(Darwin)

/// macOS file system watcher using FSEvents for detecting changes to markdown files.
///
/// Watches specified directories for file modifications and creations,
/// filtering for relevant extensions (.md, .markdown, .yaml, .yml, .css, .js).
/// Uses a debouncer to coalesce rapid changes into a single notification.
public class FileWatcher: @unchecked Sendable {
    private var eventStream: FSEventStreamRef?
    private var isWatching = false
    private let queue = DispatchQueue(label: "com.rhoe.filewatcher")
    private var changeHandler: (@Sendable (String) -> Void)?
    private let debouncer: Debouncer

    /// Initialize with debounce delay (default 300ms).
    public init(debounceDelay: TimeInterval = 0.3) {
        self.debouncer = Debouncer(delay: debounceDelay, queue: DispatchQueue.main)
    }

    /// Start watching the specified paths for file changes.
    public func watch(paths: [String], handler: @escaping @Sendable (String) -> Void) {
        stop()
        self.changeHandler = handler

        let cfPaths = paths as CFArray
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { (_, clientCallbackInfo, numEvents, eventPaths, eventFlags, _) in
                let watcher = Unmanaged<FileWatcher>.fromOpaque(clientCallbackInfo!).takeUnretainedValue()
                watcher.handleEvents(numEvents: numEvents, eventPaths: eventPaths, eventFlags: eventFlags)
            },
            &context,
            cfPaths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        guard let stream = eventStream else { return }

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        isWatching = true
    }

    /// Stop watching for file changes.
    public func stop() {
        guard let stream = eventStream, isWatching else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        eventStream = nil
        isWatching = false
        debouncer.cancel()
    }

    private func handleEvents(numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>) {
        let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]

        for i in 0..<numEvents {
            let path = paths[i]
            let flags = eventFlags[i]

            if flags & UInt32(kFSEventStreamEventFlagItemIsFile) != 0 {
                if isRelevantFile(path) {
                    if flags & UInt32(kFSEventStreamEventFlagItemModified) != 0 ||
                       flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 {
                        let handler = self.changeHandler
                        debouncer.debounce {
                            handler?(path)
                        }
                    }
                }
            }
        }
    }

    private func isRelevantFile(_ path: String) -> Bool {
        let extensions = [".md", ".markdown", ".yaml", ".yml", ".css", ".js", ".rhoe"]
        return extensions.contains { path.hasSuffix($0) }
    }

    deinit { stop() }
}

/// Coalesces rapid events into a single callback after a delay.
public class Debouncer: @unchecked Sendable {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue

    public init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }

    public func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem(block: action)
        workItem = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    public func cancel() { workItem?.cancel() }
}

#endif // canImport(Darwin)
