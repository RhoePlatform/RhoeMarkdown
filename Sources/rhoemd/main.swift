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
    fputs("rhoemd: missing input file\n\(RhoeMD.usage())\n", stderr)
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
        fputs("rhoemd: \(outputFormat.rawValue) format requires -o <output path>\n", stderr)
        exit(1)
    } else {
        if let text = String(data: result.data, encoding: .utf8) {
            print(text)
        }
    }

    if let metrics = result.metrics {
        fputs(metrics.format() + "\n", stderr)
    }
} catch {
    fputs("rhoemd: \(error.localizedDescription)\n", stderr)
    exit(1)
}

// MARK: - Serve Subcommand

func handleServeCommand(_ args: [String]) async throws {
    guard args.count >= 3 else {
        fputs("Usage: rhoemd serve <file.md> [--port 3000] [--host 127.0.0.1] [--no-open] [-v]\n", stderr)
        exit(1)
    }

    let file = args[2]
    var port = 3000
    var host = "127.0.0.1"
    var openBrowser = true
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
        case "-v", "--verbose":
            verbose = true
        default: break
        }
        i += 1
    }

    let inputURL = URL(fileURLWithPath: file)
    guard FileManager.default.fileExists(atPath: inputURL.path) else {
        fputs("rhoemd serve: file not found: \(file)\n", stderr)
        exit(1)
    }

    let server = PreviewServer(
        file: inputURL.path,
        configuration: .init(host: host, port: port, openBrowser: openBrowser, verbose: verbose)
    )
    try await server.start()
}

// MARK: - Project Subcommand Handlers

func handleBuildCommand(_ args: [String]) async throws {
    let finder = ProjectFinder()
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    guard let configURL = finder.find(from: cwd) else {
        fputs("rhoemd build: no project configuration found (rhoe.project.yaml)\n", stderr)
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
        fputs("Usage: rhoemd project <validate|targets>\n", stderr)
        exit(1)
    }

    let finder = ProjectFinder()
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    guard let configURL = finder.find(from: cwd) else {
        fputs("rhoemd project: no project configuration found (rhoe.project.yaml)\n", stderr)
        exit(1)
    }

    let verbose = args.contains("-v") || args.contains("--verbose")

    switch args[2] {
    case "validate":
        try ProjectCommands.executeValidate(configURL: configURL, verbose: verbose)
    case "targets":
        try ProjectCommands.executeTargets(configURL: configURL)
    default:
        fputs("Unknown project command: \(args[2])\n", stderr)
        fputs("Usage: rhoemd project <validate|targets>\n", stderr)
        exit(1)
    }
}
