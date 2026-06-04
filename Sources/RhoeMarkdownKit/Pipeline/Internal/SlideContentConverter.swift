import Foundation
import RhoeMarkdownModel

struct SlideContentConverter: Sendable {
    private let documentParser: DocumentParser

    init(documentParser: DocumentParser) {
        self.documentParser = documentParser
    }

    func lowerRegularSlide(
        descriptor: PresentationSlideDescriptor,
        bodyMarkdown: String
    ) async -> Slide {
        let document = await documentParser.parse(bodyMarkdown)

        return Slide(
            id: descriptor.id,
            type: descriptor.type,
            attributes: Attributes(
                id: descriptor.id.uuidString,
                keyValues: descriptor.customMetadata
            ),
            content: document.document.blocks.map(SlideContent.markdown)
        )
    }
}
