import Foundation

package struct SlideBodyConverter: Sendable {
    package init() {}

    package func blocks(from markdownBody: String) -> [SlideBlock] {
        [SlideBlock(type: .content, content: markdownBody)]
    }

    package func markdownBody(from blocks: [SlideBlock]) -> String {
        blocks
            .map(\.content)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }
}
