import Foundation
import RhoeMarkdownModel
import RhoeMarkdownPresentation

struct CanonicalParsedPresentationEngine: Sendable {
    private let frontmatterParser = PresentationFrontmatterMetadataParser()
    private let chunker = SlideChunker()
    private let metadataNormalizer = SlideMetadataNormalizer()
    private let descriptorLowerer = ParsedPresentationDescriptorLowerer()
    private let resultAssembler: PresentationParseResultAssembler

    init(documentParser: DocumentParser) {
        self.resultAssembler = PresentationParseResultAssembler(documentParser: documentParser)
    }

    func parse(_ markdown: String) async -> PresentationParseResult {
        let startTime = Date().timeIntervalSinceReferenceDate
        let metadata = frontmatterParser.metadata(from: markdown)
        let slideChunks = chunker.split(frontmatterParser.body(from: markdown))
        var items: [PresentationSlideAssemblyItem] = []
        items.reserveCapacity(slideChunks.count)

        for (index, chunk) in slideChunks.enumerated() {
            let headerMetadata = metadataNormalizer.parse(
                chunk.header
            )

            items.append(descriptorLowerer.canonicalItem(
                index: index,
                metadata: headerMetadata,
                notes: chunk.notes,
                bodyMarkdown: chunk.body
            ))
        }

        return await resultAssembler.assemble(
            metadata: metadata,
            items: items,
            parseTime: Date().timeIntervalSinceReferenceDate - startTime
        )
    }
}
