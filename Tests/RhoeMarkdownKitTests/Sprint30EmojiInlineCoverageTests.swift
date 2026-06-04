import Testing
import RhoeMarkdownKit

@Suite("Sprint 30: Emoji Inline Coverage")
struct Sprint30EmojiInlineCoverageTests {

    @Test("Known shortcode parses to a first-class emoji inline node")
    func knownShortcodeParsesToEmoji() async {
        let result = await RhoeMarkdownKit.parse("Launch :rocket: now")
        guard case .paragraph(let inlines, _) = result.document.blocks.first else {
            Issue.record("Expected paragraph")
            return
        }

        for inline in inlines {
            if case .emoji(let name, let unicode) = inline {
                #expect(name == "rocket")
                #expect(unicode == "🚀")
                return
            }
        }

        Issue.record("No emoji inline found in parsed paragraph: \(inlines)")
    }

    @Test("Unknown shortcode stays a first-class emoji inline node without unicode metadata")
    func unknownShortcodeParsesToEmojiWithoutUnicode() async {
        let result = await RhoeMarkdownKit.parse("Launch :madeup: now")
        guard case .paragraph(let inlines, _) = result.document.blocks.first else {
            Issue.record("Expected paragraph")
            return
        }

        for inline in inlines {
            if case .emoji(let name, let unicode) = inline {
                #expect(name == "madeup")
                #expect(unicode == nil)
                return
            }
        }

        Issue.record("No emoji inline found in parsed paragraph: \(inlines)")
    }
}
