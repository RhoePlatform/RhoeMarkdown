import Testing
import Foundation
@testable import RhoeMDCore

@Suite("rhoemd Smoke Tests")
struct RhoeMDSmokeTests {
    @Test("CLI arguments parse into options")
    func parseArguments() {
        let options = RhoeMD.parseArguments(["rhoemd", "--output", "output.html", "--pretty", "input.md"])

        #expect(options.inputPath == "input.md")
        #expect(options.outputPath == "output.html")
        #expect(options.prettyPrint)
    }

    @Test("CLI compiler renders HTML")
    func compileMarkdown() async throws {
        let markdown = "# Hello\n\nThis is **rhoemd**."
        let options = RhoeMD.Options(includeCSS: true, benchmark: true)

        let result = try await RhoeMD.compileMarkdown(markdown, options: options)
        let html = String(data: result.data, encoding: .utf8)!

        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains(">Hello</h1>"))
        #expect(html.contains("<strong>rhoemd</strong>"))
        #expect(result.metrics != nil)
    }

    @Test("CLI strict flavor disables implicit figure rendering")
    func strictFlavorDisablesImplicitFigureRendering() async throws {
        let result = try await RhoeMD.compileMarkdown(
            "![foo](/url \"title\")\n",
            options: RhoeMD.Options(flavor: .strict)
        )
        let html = String(data: result.data, encoding: .utf8)!

        #expect(html == "<p data-rhoe-node=\"paragraph\"><img alt=\"foo\" src=\"/url\" title=\"title\"></p>")
    }

    @Test("CLI usage text contains format options")
    func usageText() {
        #expect(RhoeMD.usage().contains("rhoemd"))
        #expect(RhoeMD.usage().contains("--format"))
    }
}
