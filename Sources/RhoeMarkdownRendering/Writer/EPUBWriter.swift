import Foundation
import RhoeMarkdownModel

/// Generates EPUB 3.2 documents from parsed RhoeMarkdown ASTs.
///
/// Produces a ZIP-based EPUB archive containing XHTML chapters,
/// navigation, CSS styling, and OPF manifest. Chapters are split
/// at heading boundaries (configurable via `chapterLevel`).
/// Uses the HTML renderer internally for XHTML content generation.
public struct EPUBWriter: DocumentWriter, Sendable {
    public typealias Output = Data

    private let configuration: RhoeMarkdownKit.EPUBConfiguration

    public init(configuration: RhoeMarkdownKit.EPUBConfiguration = .default) {
        self.configuration = configuration
    }

    public func write(_ document: RhoeMarkdownKit.Document) -> Data {
        do {
            return try generateEPUB(document)
        } catch {
            return Data()
        }
    }

    private func generateEPUB(_ document: RhoeMarkdownKit.Document) throws -> Data {
        let fm = document.metadata.yamlFrontmatter
        let title = stringFromYAML(fm?["title"]) ?? "Untitled"
        let author = stringFromYAML(fm?["author"]) ?? ""
        let language = configuration.language
        let bookId = UUID().uuidString

        // Split document into chapters
        let chapters = splitChapters(document.blocks)

        // Create temp directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("epub-\(UUID().uuidString)")

        let dirs = ["META-INF", "OEBPS", "OEBPS/text"]
        for dir in dirs {
            try FileManager.default.createDirectory(
                at: tempDir.appendingPathComponent(dir),
                withIntermediateDirectories: true
            )
        }

        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Write mimetype (must be first, uncompressed)
        try writeFile("mimetype", in: tempDir, content: "application/epub+zip")

        // Write META-INF/container.xml
        try writeFile("META-INF/container.xml", in: tempDir, content: containerXML())

        // Write OEBPS/content.opf
        try writeFile("OEBPS/content.opf", in: tempDir, content: contentOPF(
            title: title, author: author, language: language,
            bookId: bookId, chapterCount: chapters.count
        ))

        // Write OEBPS/nav.xhtml
        try writeFile("OEBPS/nav.xhtml", in: tempDir, content: navXHTML(
            title: title, chapters: chapters
        ))

        // Write CSS
        try writeFile("OEBPS/style.css", in: tempDir, content: defaultCSS())

        // Write chapter files
        for (index, chapter) in chapters.enumerated() {
            let xhtml = chapterXHTML(
                title: chapter.title,
                content: renderBlocksToHTML(chapter.blocks),
                language: language
            )
            try writeFile("OEBPS/text/chapter-\(index + 1).xhtml", in: tempDir, content: xhtml)
        }

        // Create ZIP with mimetype first and uncompressed
        return try createEPUBZip(from: tempDir)
    }

    // MARK: - Chapter Splitting

    private struct Chapter {
        let title: String
        let blocks: [Block]
    }

    private func splitChapters(_ blocks: [Block]) -> [Chapter] {
        var chapters: [Chapter] = []
        var currentTitle = "Chapter"
        var currentBlocks: [Block] = []

        for block in blocks {
            if case .heading(let level, let content, _) = block, level <= configuration.chapterLevel {
                // Save previous chapter if it has content
                if !currentBlocks.isEmpty {
                    chapters.append(Chapter(title: currentTitle, blocks: currentBlocks))
                }
                currentTitle = inlinesToPlainText(content)
                currentBlocks = [block]
            } else {
                currentBlocks.append(block)
            }
        }

        // Save final chapter
        if !currentBlocks.isEmpty {
            chapters.append(Chapter(title: currentTitle, blocks: currentBlocks))
        }

        // If no chapters were created, wrap everything in a single chapter
        if chapters.isEmpty {
            chapters.append(Chapter(title: "Content", blocks: blocks))
        }

        return chapters
    }

    // MARK: - HTML Rendering

    private func renderBlocksToHTML(_ blocks: [Block]) -> String {
        let renderer = RhoeHTMLRenderer()
        return blocks.map { renderer.renderBlock($0) }.joined(separator: "\n")
    }

    // MARK: - XHTML Templates

    private func containerXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
    }

    private func contentOPF(
        title: String, author: String, language: String,
        bookId: String, chapterCount: Int
    ) -> String {
        var manifest = ""
        var spine = ""

        // Navigation document
        manifest += "    <item id=\"nav\" href=\"nav.xhtml\" media-type=\"application/xhtml+xml\" properties=\"nav\"/>\n"
        manifest += "    <item id=\"css\" href=\"style.css\" media-type=\"text/css\"/>\n"

        // Chapter items
        for i in 1...max(chapterCount, 1) {
            manifest += "    <item id=\"chapter-\(i)\" href=\"text/chapter-\(i).xhtml\" media-type=\"application/xhtml+xml\"/>\n"
            spine += "    <itemref idref=\"chapter-\(i)\"/>\n"
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="bookid">urn:uuid:\(bookId)</dc:identifier>
            <dc:title>\(xmlEscape(title))</dc:title>
            <dc:creator>\(xmlEscape(author))</dc:creator>
            <dc:language>\(language)</dc:language>
            <meta property="dcterms:modified">\(isoDate())</meta>
          </metadata>
          <manifest>
        \(manifest)  </manifest>
          <spine>
        \(spine)  </spine>
        </package>
        """
    }

    private func navXHTML(title: String, chapters: [Chapter]) -> String {
        var tocItems = ""
        for (index, chapter) in chapters.enumerated() {
            tocItems += "      <li><a href=\"text/chapter-\(index + 1).xhtml\">\(xmlEscape(chapter.title))</a></li>\n"
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="\(configuration.language)">
        <head>
          <meta charset="UTF-8"/>
          <title>\(xmlEscape(title))</title>
          <link rel="stylesheet" href="style.css" type="text/css"/>
        </head>
        <body>
          <nav epub:type="toc">
            <h1>Table of Contents</h1>
            <ol>
        \(tocItems)    </ol>
          </nav>
        </body>
        </html>
        """
    }

    private func chapterXHTML(title: String, content: String, language: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" lang="\(language)">
        <head>
          <meta charset="UTF-8"/>
          <title>\(xmlEscape(title))</title>
          <link rel="stylesheet" href="../style.css" type="text/css"/>
        </head>
        <body>
        \(content)
        </body>
        </html>
        """
    }

    private func defaultCSS() -> String {
        configuration.cssContent ?? """
        body {
          font-family: Georgia, "Times New Roman", serif;
          line-height: 1.6;
          margin: 1em;
          color: #333;
        }
        h1, h2, h3, h4, h5, h6 {
          font-family: "Helvetica Neue", Arial, sans-serif;
          margin-top: 1.5em;
          margin-bottom: 0.5em;
        }
        h1 { font-size: 1.8em; }
        h2 { font-size: 1.4em; }
        h3 { font-size: 1.2em; }
        code {
          font-family: "Courier New", Courier, monospace;
          background-color: #f5f5f5;
          padding: 0.1em 0.3em;
          border-radius: 3px;
        }
        pre {
          background-color: #f5f5f5;
          padding: 1em;
          overflow-x: auto;
          border-radius: 4px;
        }
        blockquote {
          border-left: 3px solid #ccc;
          margin-left: 0;
          padding-left: 1em;
          color: #666;
        }
        table {
          border-collapse: collapse;
          margin: 1em 0;
        }
        th, td {
          border: 1px solid #ddd;
          padding: 0.5em;
          text-align: left;
        }
        th { background-color: #f0f0f0; }
        """
    }

    // MARK: - Helpers

    private func inlinesToPlainText(_ inlines: [Inline]) -> String {
        inlines.map { inlineToPlainText($0) }.joined()
    }

    private func inlineToPlainText(_ inline: Inline) -> String {
        switch inline {
        case .text(let t): return t
        case .emphasis(let c), .strong(let c), .strikethrough(let c),
             .superscript(let c), .subscript(let c), .highlight(let c):
            return inlinesToPlainText(c)
        case .codeSpan(let t, _): return t
        case .link(let text, _, _, _): return inlinesToPlainText(text)
        case .image(let alt, _, _, _): return inlinesToPlainText(alt)
        case .placeholderInline(let fields):
            if let name = fields["name"] { return "[\(name)]" }
            return "[\(fields.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))]"
        default: return ""
        }
    }

    private func xmlEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func isoDate() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withTimeZone]
        return formatter.string(from: Date())
    }

    private func stringFromYAML(_ value: RhoeMarkdownKit.YAMLValue?) -> String? {
        guard let value = value else { return nil }
        switch value {
        case .string(let s): return s
        case .int(let i): return String(i)
        default: return nil
        }
    }

    private func writeFile(_ path: String, in directory: URL, content: String) throws {
        let fileURL = directory.appendingPathComponent(path)
        try content.data(using: .utf8)?.write(to: fileURL)
    }

    private func createEPUBZip(from sourceDir: URL) throws -> Data {
        #if os(WASI)
        return Data()
        #else
        let epubFile = sourceDir.appendingPathComponent("output.epub")

        let mimetypeProcess = Process()
        mimetypeProcess.currentDirectoryURL = sourceDir
        mimetypeProcess.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        mimetypeProcess.arguments = ["-0", "-X", "output.epub", "mimetype"]

        try mimetypeProcess.run()
        mimetypeProcess.waitUntilExit()
        guard mimetypeProcess.terminationStatus == 0 else { return Data() }

        let contentProcess = Process()
        contentProcess.currentDirectoryURL = sourceDir
        contentProcess.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        contentProcess.arguments = ["-r", "-q", "output.epub", "META-INF", "OEBPS",
                                     "-x", "output.epub"]

        try contentProcess.run()
        contentProcess.waitUntilExit()
        guard contentProcess.terminationStatus == 0 else { return Data() }

        return try Data(contentsOf: epubFile)
        #endif
    }
}
