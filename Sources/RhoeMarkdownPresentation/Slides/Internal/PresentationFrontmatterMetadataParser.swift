import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing

package struct PresentationFrontmatterMetadataParser: Sendable {
    private let sharedParser = SlideFrontmatterParser()

    package init() {}

    package func metadata(from markdown: String) -> PresentationMetadata {
        let values = sharedParser.parseStringValues(from: markdown)
        let formatter = ISO8601DateFormatter()

        let title = values["title"] ?? "Untitled Presentation"
        let author = values["author"]
        let theme = values["theme"] ?? "default"
        let aspectRatio = values["aspect-ratio"] ?? values["aspectRatio"] ?? "16:9"
        let parsedDate = values["date"].flatMap(formatter.date(from:))

        return PresentationMetadata(
            title: title,
            author: author,
            date: parsedDate,
            theme: theme,
            customFields: ["aspectRatio": .string(aspectRatio)]
        )
    }

    package func body(from markdown: String) -> String {
        return sharedParser.parseSection(from: markdown, bodyMode: .emptyWhenUnclosed).body
    }
}
