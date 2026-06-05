import Foundation
import RhoeMDCore
import RhoeMDServer
import RhoeMarkdownKit

let args = CommandLine.arguments

// Check for subcommands first
if args.count >= 2 {
    switch args[1] {
    case "build":
        try await handleBuildCommand(args)
        exit(0)
    case "project":
        try await handleProjectCommand(args)
        exit(0)
    case "serve":
        try await handleServeCommand(args)
        exit(0)
    case "preview":
        try await handlePreviewCommand(args)
        exit(0)
    case "__preview-daemon":
        try await handlePreviewDaemonCommand(args)
        exit(0)
    default:
        break // Fall through to single-file mode
    }
}

// Single-file compilation mode (original behavior)
let options = RhoeMD.parseArguments(args)

if options.help {
    print(RhoeMD.usage())
    exit(0)
}

if options.version {
    print("RhoeMarkdownKit \(RhoeMarkdownKit.version)")
    exit(0)
}

guard let inputPath = options.inputPath else {
    writeStandardError("rhoemd: missing input file\n\(RhoeMD.usage())\n")
    exit(1)
}

let inputURL = URL(fileURLWithPath: inputPath)

do {
    let markdown = try String(contentsOf: inputURL, encoding: .utf8)
    let result = try await RhoeMD.compileMarkdown(markdown, options: options)

    let outputFormat = result.format

    if let outputPath = options.outputPath {
        try result.data.write(to: URL(fileURLWithPath: outputPath))
        if options.verbose {
            print("Wrote \(outputFormat.fileExtension) → \(outputPath) (\(result.data.count) bytes)")
        }
    } else if outputFormat.isBinary {
        writeStandardError("rhoemd: \(outputFormat.rawValue) format requires -o <output path>\n")
        exit(1)
    } else {
        if let text = String(data: result.data, encoding: .utf8) {
            print(text)
        }
    }

    if let metrics = result.metrics {
        writeStandardError(metrics.format() + "\n")
    }
} catch {
    writeStandardError("rhoemd: \(error.localizedDescription)\n")
    exit(1)
}

// MARK: - Serve Subcommand

func handleServeCommand(_ args: [String]) async throws {
    guard args.count >= 3 else {
        writeStandardError("Usage: rhoemd serve <file.md> [--port 3000] [--host 127.0.0.1] [--no-open] [--no-menu] [-v]\n")
        exit(1)
    }

    let file = args[2]
    var port = 3000
    var host = "127.0.0.1"
    var openBrowser = true
    var launchMenu = true
    var verbose = false

    var i = 3
    while i < args.count {
        switch args[i] {
        case "--port":
            i += 1; if i < args.count { port = Int(args[i]) ?? 3000 }
        case "--host":
            i += 1; if i < args.count { host = args[i] }
        case "--no-open":
            openBrowser = false
        case "--no-menu":
            launchMenu = false
        case "-v", "--verbose":
            verbose = true
        default: break
        }
        i += 1
    }

    let inputURL = URL(fileURLWithPath: file)
    guard FileManager.default.fileExists(atPath: inputURL.path) else {
        writeStandardError("rhoemd serve: file not found: \(file)\n")
        exit(1)
    }

    let server = PreviewServer(
        file: inputURL.path,
        configuration: .init(
            host: host,
            port: port,
            openBrowser: openBrowser,
            launchMenu: launchMenu,
            verbose: verbose,
            menuExecutableHint: CommandLine.arguments[0]
        )
    )
    try await server.start()
}

// MARK: - Preview Subcommand

func handlePreviewCommand(_ args: [String]) async throws {
    guard args.count >= 3 else {
        writeStandardError("Usage: rhoemd preview <file.md> [-o /url-path] [--port 37911] [--host 127.0.0.1] [--no-open] [--no-menu] [-p] [-v]\n")
        exit(1)
    }

    let file = args[2]
    var output: String?
    var port = 37911
    var host = "127.0.0.1"
    var openBrowser = true
    var launchMenu = true
    var prettyPrint = false
    var verbose = false

    var i = 3
    while i < args.count {
        switch args[i] {
        case "-o", "--output":
            i += 1; if i < args.count { output = args[i] }
        case "--port":
            i += 1; if i < args.count { port = Int(args[i]) ?? 37911 }
        case "--host":
            i += 1; if i < args.count { host = args[i] }
        case "--no-open":
            openBrowser = false
        case "--no-menu":
            launchMenu = false
        case "-p", "--pretty":
            prettyPrint = true
        case "-v", "--verbose":
            verbose = true
        default:
            break
        }
        i += 1
    }

    do {
        let result = try await PreviewDaemonClient.startOrAttach(
            executablePath: CommandLine.arguments[0],
            options: .init(
                sourcePath: file,
                output: output,
                host: host,
                port: port,
                openBrowser: openBrowser,
                prettyPrint: prettyPrint,
                verbose: verbose
            )
        )
        let response = result.response
        print("Preview: \(response.url)")
        print("Route: \(response.route)\(response.fallbackApplied ? " (fallback applied)" : "")")
        print("Daemon PID: \(response.pid)\(result.daemonReused ? " (reused)" : " (started)")")
        print("Log: \(result.logPath)")
        if launchMenu {
            _ = PreviewMenuLauncher.launchIfNeeded(relativeTo: CommandLine.arguments[0])
        }
    } catch {
        writeStandardError("rhoemd preview: \(error.localizedDescription)\n")
        exit(1)
    }
}

func handlePreviewDaemonCommand(_ args: [String]) async throws {
    var port = 37911
    var host = "127.0.0.1"
    var verbose = false
    var registryURL = PreviewDaemonRegistry.defaultRecordURL
    var logURL = PreviewDaemonRegistry.defaultLogURL

    var i = 2
    while i < args.count {
        switch args[i] {
        case "--port":
            i += 1; if i < args.count { port = Int(args[i]) ?? 37911 }
        case "--host":
            i += 1; if i < args.count { host = args[i] }
        case "--registry":
            i += 1; if i < args.count { registryURL = URL(fileURLWithPath: args[i]) }
        case "--log":
            i += 1; if i < args.count { logURL = URL(fileURLWithPath: args[i]) }
        case "-v", "--verbose":
            verbose = true
        default:
            break
        }
        i += 1
    }

    let daemon = PreviewDaemon(
        configuration: .init(
            host: host,
            port: port,
            verbose: verbose,
            registryURL: registryURL,
            logURL: logURL
        )
    )
    try await daemon.run()
}

// MARK: - Project Subcommand Handlers

func handleBuildCommand(_ args: [String]) async throws {
    let finder = ProjectFinder()
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    guard let configURL = finder.find(from: cwd) else {
        writeStandardError("rhoemd build: no project configuration found (rhoe.project.yaml)\n")
        exit(1)
    }

    var target: String?
    var allTargets = false
    var profile: String?
    var clean = false
    var verbose = false

    var i = 2
    while i < args.count {
        switch args[i] {
        case "--target":
            i += 1; if i < args.count { target = args[i] }
        case "--all-targets":
            allTargets = true
        case "--profile":
            i += 1; if i < args.count { profile = args[i] }
        case "--clean":
            clean = true
        case "-v", "--verbose":
            verbose = true
        default: break
        }
        i += 1
    }

    try await ProjectCommands.executeBuild(
        projectRoot: finder.projectRoot(from: configURL),
        configURL: configURL,
        target: target,
        allTargets: allTargets,
        profile: profile,
        clean: clean,
        verbose: verbose
    )
}

func handleProjectCommand(_ args: [String]) async throws {
    guard args.count >= 3 else {
        writeStandardError("Usage: rhoemd project <validate|targets>\n")
        exit(1)
    }

    let finder = ProjectFinder()
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    guard let configURL = finder.find(from: cwd) else {
        writeStandardError("rhoemd project: no project configuration found (rhoe.project.yaml)\n")
        exit(1)
    }

    let verbose = args.contains("-v") || args.contains("--verbose")

    switch args[2] {
    case "validate":
        try ProjectCommands.executeValidate(configURL: configURL, verbose: verbose)
    case "targets":
        try ProjectCommands.executeTargets(configURL: configURL)
    default:
        writeStandardError("Unknown project command: \(args[2])\n")
        writeStandardError("Usage: rhoemd project <validate|targets>\n")
        exit(1)
    }
}

private func writeStandardError(_ message: String) {
    FileHandle.standardError.write(Data(message.utf8))
}
