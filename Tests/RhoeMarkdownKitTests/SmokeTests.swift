import Testing
import RhoeMarkdownKit

@Suite("RhoeMarkdownKit Smoke Tests")
struct RhoeMarkdownKitSmokeTests {
    @Test("Facade parses markdown and renders HTML")
    func facadeParsesAndRendersHTML() async {
        let result = await RhoeMarkdownKit.parse("# Hello\n\n**World**")
        let html = RhoeMarkdownKit.renderHTML(result.document)

        // v4.0: heading + paragraph are wrapped in a single Section block
        #expect(result.document.blocks.count == 1)
        #expect(html.contains(">Hello</h1>"))
        #expect(html.contains("<strong>World</strong>"))
    }

    @Test("Pipeline parser and renderer are available alongside the facade")
    func pipelineParsesAndRendersHTML() async {
        let parser = DocumentParser(configuration: .github)
        let renderer = HTMLRenderer(configuration: .init(prettyPrint: false))

        let result = await parser.parse("# Hello\n\n**World**")
        let html = renderer.render(result.document)

        // v4.0: heading + paragraph are wrapped in a single Section block
        #expect(result.document.blocks.count == 1)
        #expect(result.diagnostics.isEmpty)
        #expect(html.contains(">Hello</h1>"))
        #expect(html.contains("<strong>World</strong>"))
    }

    @Test("Enhanced slide parser produces a presentation")
    func enhancedSlideParserProducesPresentation() async throws {
        let parser = SlideParser()
        let presentation = try await parser.parse(
            """
            %%% Intro {transition=zoom duration=2}
            # Deck Title
            ## Next Steps
            """
        )

        let slide = presentation.slides[0]
        let combinedBlockContent = slide.blocks.map(\.content).joined(separator: "\n")

        #expect(presentation.slides.count == 1)
        #expect(slide.metadata.title == "Intro")
        #expect(slide.metadata.transition == .zoom)
        #expect(combinedBlockContent.contains("# Deck Title"))
        #expect(combinedBlockContent.contains("## Next Steps"))
    }

    @Test("Presentation parser normalizes enhanced metadata and parses body markdown")
    func canonicalPresentationParserProducesUnifiedPresentation() async throws {
        let parser = PresentationParser()
        let result = try await parser.parse(
            """
            %%% Intro | Next Steps {layout=full-image transition=zoom background='image(https://example.com/hero.png, 0.35)' overlay='rgba(1, 2, 3, 0.4)'}
            # Deck Title

            Body copy
            """
        )

        #expect(result.presentation.slides.count == 1)
        #expect(result.slideDescriptors.count == 1)

        let descriptor = result.slideDescriptors[0]
        #expect(descriptor.title == "Intro")
        #expect(descriptor.subtitle == "Next Steps")
        #expect(descriptor.layout == .fullImage)
        #expect(descriptor.transition == .zoom)
        #expect(descriptor.background?.overlay == "rgba(1, 2, 3, 0.4)")

        if let background = descriptor.background {
            switch background.type {
            case .image(let url, let opacity):
                #expect(url == "https://example.com/hero.png")
                #expect(opacity == 0.35)
            default:
                #expect(Bool(false))
            }
        } else {
            #expect(Bool(false))
        }

        let slide = result.presentation.slides[0]
        // v4.0: heading + body copy are wrapped in a single Section block
        #expect(slide.content.count == 1)
    }

    @Test("Presentation parser extracts frontmatter and preserves custom metadata")
    func canonicalPresentationParserExtractsFrontmatterAndMetadata() async throws {
        let parser = PresentationParser()
        let result = try await parser.parse(
            """
            ---
            title: Launch Deck
            author: Team Rhoe
            theme: sunrise
            aspect-ratio: 4:3
            ---
            %%% Intro | Roadmap {track="north star" audience=internal}
            # Welcome
            % First note line
            Second note line
            """
        )

        #expect(result.presentation.metadata.title == "Launch Deck")
        #expect(result.presentation.metadata.author == "Team Rhoe")
        #expect(result.presentation.metadata.theme == "sunrise")
        #expect(result.presentation.metadata.customFields["aspectRatio"] == .string("4:3"))
        #expect(result.presentation.slides.count == 1)

        let descriptor = result.slideDescriptors[0]
        #expect(descriptor.title == "Intro")
        #expect(descriptor.subtitle == "Roadmap")
        #expect(descriptor.customMetadata["track"] == "north star")
        #expect(descriptor.customMetadata["audience"] == "internal")
        #expect(descriptor.speakerNotes == "First note line\nSecond note line")
    }

    @Test("Presentation parser handles multiple slides")
    func presentationParserHandlesMultipleSlides() async throws {
        let parser = PresentationParser()
        let result = try await parser.parse(
            """
            %%% First
            # Slide One

            Content.

            %%% Second
            # Slide Two

            More content.
            """
        )

        #expect(result.presentation.slides.count == 2)
        #expect(result.slideDescriptors[0].title == "First")
        #expect(result.slideDescriptors[1].title == "Second")
    }

    @Test("Resource manager exposes bundled assets")
    func resourceManagerExposesBundledAssets() {
        let manager = ResourceManager.shared

        #expect(manager.getEmoji(for: "rocket") == "🚀")
        #expect(manager.loadIcon(set: .fluent, name: "grid") != nil)
    }

    @Test("Icon system renders SVG")
    func iconSystemRendersSVG() async throws {
        let manager = IconSystemManager.shared
        try await manager.initialize()

        let svg = try await manager.getIcon(
            .init(
                provider: .fluent,
                name: "home",
                style: .regular,
                size: .medium,
                color: "#111111"
            )
        )

        #expect(svg.contains("<svg"))
        #expect(svg.contains("width=\"24\""))
        #expect(svg.contains("#111111"))
    }
}
