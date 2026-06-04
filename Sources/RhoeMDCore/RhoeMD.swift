import Foundation
import RhoeMarkdownKit

/// Shared implementation for the `rhoemd` command-line compiler.
///
/// `RhoeMD` is intentionally small and dependency-light: it parses CLI options,
/// selects a Markdown flavor, dispatches to `RhoeMarkdownKit`, and packages the
/// rendered output plus optional benchmark metrics for the executable target.
public enum RhoeMD {
    /// Markdown compatibility profile used by the CLI.
    public enum MarkdownFlavor: String, CaseIterable, Sendable {
        /// RhoeMarkdown's default authoring profile.
        case `default`
        /// GitHub Flavored Markdown compatibility profile.
        case github
        /// Strict CommonMark compatibility profile.
        case strict
        /// Alias for the default RhoeMarkdown profile.
        case rhoe

        /// Parser configuration associated with the CLI flavor.
        public var configuration: RhoeMarkdownKit.Configuration {
            switch self {
            case .default, .rhoe:
                return .default
            case .github:
                return .github
            case .strict:
                return .strict
            }
        }

        /// HTML renderer configuration associated with the CLI flavor.
        ///
        /// Strict CommonMark and GFM runs disable Rhoe-specific implicit figure
        /// projection so conformance output remains compatible with upstream
        /// fixture expectations.
        public func htmlConfiguration(prettyPrint: Bool) -> RhoeMarkdownKit.HTMLConfiguration {
            switch self {
            case .strict, .github:
                return RhoeMarkdownKit.HTMLConfiguration(
                    prettyPrint: prettyPrint,
                    enableImplicitFigures: false
                )
            case .default, .rhoe:
                return RhoeMarkdownKit.HTMLConfiguration(prettyPrint: prettyPrint)
            }
        }
    }

    /// Parsed command-line options for single-file compilation mode.
    public struct Options: Sendable {
        /// Markdown input file path.
        public var inputPath: String?
        /// Optional output file path. Text formats write to stdout when omitted.
        public var outputPath: String?
        /// Markdown parser/rendering compatibility flavor.
        public var flavor: MarkdownFlavor
        /// Explicit output format. If nil, the CLI infers from the output path.
        public var format: RhoeMarkdownKit.OutputFormat?
        /// Whether to pretty-print HTML output.
        public var prettyPrint: Bool
        /// Whether to wrap HTML output in the default standalone CSS shell.
        public var includeCSS: Bool
        /// Whether to generate a table of contents in HTML output.
        public var tableOfContents: Bool
        /// Maximum heading depth included in the generated table of contents.
        public var tocDepth: Int
        /// Whether to collect and print performance metrics.
        public var benchmark: Bool
        /// Whether to print verbose output for file writes and command progress.
        public var verbose: Bool
        /// Whether the user requested CLI help.
        public var help: Bool
        /// Whether the user requested the CLI version.
        public var version: Bool

        /// Creates an option set for `rhoemd` single-file compilation.
        public init(
            inputPath: String? = nil,
            outputPath: String? = nil,
            flavor: MarkdownFlavor = .default,
            format: RhoeMarkdownKit.OutputFormat? = nil,
            prettyPrint: Bool = false,
            includeCSS: Bool = false,
            tableOfContents: Bool = false,
            tocDepth: Int = 3,
            benchmark: Bool = false,
            verbose: Bool = false,
            help: Bool = false,
            version: Bool = false
        ) {
            self.inputPath = inputPath
            self.outputPath = outputPath
            self.flavor = flavor
            self.format = format
            self.prettyPrint = prettyPrint
            self.includeCSS = includeCSS
            self.tableOfContents = tableOfContents
            self.tocDepth = tocDepth
            self.benchmark = benchmark
            self.verbose = verbose
            self.help = help
            self.version = version
        }

        /// Resolve the output format from explicit flag, output extension, or default.
        public func resolvedFormat() -> RhoeMarkdownKit.OutputFormat {
            if let format = format { return format }
            if let outputPath = outputPath {
                let ext = (outputPath as NSString).pathExtension
                if let detected = RhoeMarkdownKit.OutputFormat.fromExtension(ext) {
                    return detected
                }
            }
            return .html
        }
    }

    /// Rendered CLI output and optional metrics.
    public struct CompileResult: Sendable {
        /// Rendered bytes. Text formats are UTF-8 encoded; binary formats are raw data.
        public let data: Data
        /// Output format used for rendering.
        public let format: RhoeMarkdownKit.OutputFormat
        /// Optional benchmark metrics, present only when benchmarking is enabled.
        public let metrics: PerformanceMetrics?
    }

    /// Timing and throughput measurements for a single compilation.
    public struct PerformanceMetrics: Sendable {
        /// Input size in bytes.
        public let inputSize: Int
        /// Output size in bytes.
        public let outputSize: Int
        /// Parser duration in milliseconds.
        public let parseTime: Double
        /// Renderer duration in milliseconds.
        public let renderTime: Double
        /// Total parse plus render duration in milliseconds.
        public let totalTime: Double

        /// Creates benchmark metrics for one CLI compilation.
        public init(
            inputSize: Int,
            outputSize: Int,
            parseTime: Double,
            renderTime: Double,
            totalTime: Double
        ) {
            self.inputSize = inputSize
            self.outputSize = outputSize
            self.parseTime = parseTime
            self.renderTime = renderTime
            self.totalTime = totalTime
        }

        /// Effective input throughput in MiB per second.
        public var throughput: Double {
            guard totalTime > 0 else { return 0 }
            return Double(inputSize) / (totalTime / 1000.0) / (1024.0 * 1024.0)
        }

        /// Human-readable multi-line metrics summary for stderr output.
        public func format() -> String {
            """
            Input size:  \(formatBytes(inputSize))
            Output size: \(formatBytes(outputSize))
            Parse time:  \(String(format: "%.2f", parseTime)) ms
            Render time: \(String(format: "%.2f", renderTime)) ms
            Total time:  \(String(format: "%.2f", totalTime)) ms
            Throughput:  \(String(format: "%.2f", throughput)) MB/s
            """
        }

        private func formatBytes(_ bytes: Int) -> String {
            if bytes < 1024 {
                return "\(bytes) B"
            }
            if bytes < 1024 * 1024 {
                return String(format: "%.1f KB", Double(bytes) / 1024.0)
            }
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }

    /// Parse command-line arguments into single-file compilation options.
    ///
    /// Project and server subcommands are dispatched by the executable before
    /// this parser is invoked.
    public static func parseArguments(_ arguments: [String]) -> Options {
        var options = Options()
        var index = 1

        while index < arguments.count {
            let argument = arguments[index]

            switch argument {
            case "-o", "--output":
                index += 1
                if index < arguments.count {
                    options.outputPath = arguments[index]
                }
            case "-F", "--format":
                index += 1
                if index < arguments.count,
                   let fmt = RhoeMarkdownKit.OutputFormat(rawValue: arguments[index].lowercased()) {
                    options.format = fmt
                }
            case "-f", "--flavor":
                index += 1
                if index < arguments.count, let flavor = MarkdownFlavor(rawValue: arguments[index]) {
                    options.flavor = flavor
                }
            case "-p", "--pretty":
                options.prettyPrint = true
            case "-c", "--css":
                options.includeCSS = true
            case "--toc":
                options.tableOfContents = true
            case "--toc-depth":
                index += 1
                if index < arguments.count, let depth = Int(arguments[index]) {
                    options.tocDepth = depth
                }
            case "-b", "--benchmark":
                options.benchmark = true
            case "-v", "--verbose":
                options.verbose = true
            case "-h", "--help":
                options.help = true
            case "--version":
                options.version = true
            default:
                if !argument.hasPrefix("-") {
                    options.inputPath = argument
                }
            }

            index += 1
        }

        return options
    }

    /// Default CSS wrapper used by `rhoemd --css` for standalone HTML output.
    public static func getDefaultCSS() -> String {
        """
        <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            margin: 0 auto;
            max-width: 800px;
            padding: 2rem;
            line-height: 1.6;
        }
        code {
            font-family: ui-monospace, SFMono-Regular, monospace;
            background: #f3f4f6;
            padding: 0.15rem 0.35rem;
            border-radius: 0.25rem;
        }
        pre code {
            display: block;
            padding: 1rem;
            overflow-x: auto;
        }
        blockquote {
            border-left: 4px solid #d1d5db;
            margin: 1rem 0;
            padding-left: 1rem;
            color: #4b5563;
        }
        </style>
        """
    }

    /// Compile Markdown according to CLI options.
    ///
    /// - Parameters:
    ///   - markdown: UTF-8 Markdown source loaded by the executable.
    ///   - options: Parsed CLI options.
    /// - Returns: Rendered output data, selected format, and optional metrics.
    public static func compileMarkdown(
        _ markdown: String,
        options: Options
    ) async throws -> CompileResult {
        let outputFormat = options.resolvedFormat()

        let parseStart = Date().timeIntervalSinceReferenceDate
        let parsed = await DocumentParser(configuration: options.flavor.configuration).parse(markdown)
        let parseTime = (Date().timeIntervalSinceReferenceDate - parseStart) * 1000

        let renderStart = Date().timeIntervalSinceReferenceDate
        let outputData: Data

        switch outputFormat {
        case .html:
            let renderer = HTMLRenderer(
                configuration: options.flavor.htmlConfiguration(prettyPrint: options.prettyPrint)
            )
            var html = await renderer.renderAsync(parsed.document)
            if options.includeCSS {
                html = wrapHTMLDocument(body: html, css: getDefaultCSS())
            }
            outputData = Data(html.utf8)

        case .latex:
            let latex = LaTeXRenderer().render(parsed.document)
            outputData = Data(latex.utf8)

        case .typst:
            let typst = TypstRenderer().render(parsed.document)
            outputData = Data(typst.utf8)

        case .docx:
            outputData = DOCXRenderer().render(parsed.document)

        case .pdf:
            outputData = PDFRenderer().render(parsed.document)

        case .epub:
            outputData = EPUBRenderer().render(parsed.document)
        }

        let renderTime = (Date().timeIntervalSinceReferenceDate - renderStart) * 1000

        let metrics = options.benchmark
            ? PerformanceMetrics(
                inputSize: markdown.utf8.count,
                outputSize: outputData.count,
                parseTime: parseTime,
                renderTime: renderTime,
                totalTime: parseTime + renderTime
            )
            : nil

        return CompileResult(data: outputData, format: outputFormat, metrics: metrics)
    }

    /// User-facing help text for the single-file compiler and project commands.
    public static func usage() -> String {
        """
        Usage: rhoemd [options] <input.md>

        Options:
          -o, --output <path>    Output file path
          -F, --format <format>  Output format: html, latex, typst, docx, pdf, epub
          -f, --flavor <flavor>  Markdown flavor: default, github, strict, rhoe
          -p, --pretty           Pretty-print HTML output
          -c, --css              Include default CSS in HTML output
              --toc              Generate table of contents
              --toc-depth <N>    TOC heading depth (default: 3)
          -b, --benchmark        Show performance metrics
          -v, --verbose          Verbose logging
          -h, --help             Show this help
              --version          Show version

        Formats:
          html   HTML document (default)
          latex  LaTeX document (.tex)
          typst  Typst document (.typ)
          docx   Microsoft Word (.docx)
          pdf    PDF via Typst or LaTeX
          epub   EPUB 3.2 ebook

        Format auto-detection: if --format is not specified, the format is
        detected from the output file extension (e.g., -o doc.pdf → pdf).

        Project Commands:
          rhoemd build                       Build default target
          rhoemd build --target <name>       Build specific target
          rhoemd build --all-targets         Build all enabled targets
          rhoemd build --profile <name>      Use build profile
          rhoemd build --clean               Clean build
          rhoemd project validate            Validate project configuration
          rhoemd project targets             List defined targets
        """
    }

    private static func wrapHTMLDocument(body: String, css: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        \(css)
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }
}
