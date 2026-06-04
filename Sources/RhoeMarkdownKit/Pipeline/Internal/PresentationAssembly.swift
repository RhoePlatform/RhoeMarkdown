import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownPresentation

struct PresentationSlideAssemblyItem: Sendable {
    let descriptor: PresentationSlideDescriptor
    let bodyMarkdown: String
}

struct ParsedPresentationDescriptorLowerer: Sendable {

    func canonicalItem(
        index: Int,
        metadata: SlideHeaderMetadata,
        notes: String?,
        bodyMarkdown: String
    ) -> PresentationSlideAssemblyItem {
        PresentationSlideAssemblyItem(
            descriptor: makeDescriptor(
                index: index,
                id: UUID(),
                title: metadata.title,
                subtitle: metadata.subtitle,
                layout: metadata.layout,
                transition: metadata.transition,
                duration: metadata.duration,
                autoAdvance: metadata.autoAdvance,
                background: metadata.background,
                speakerNotes: notes,
                animations: metadata.animations,
                customMetadata: metadata.customMetadata
            ),
            bodyMarkdown: bodyMarkdown
        )
    }

    private func makeDescriptor(
        index: Int,
        id: UUID,
        title: String?,
        subtitle: String?,
        layout: SlideLayout,
        transition: SlideTransition,
        duration: TimeInterval?,
        autoAdvance: Bool,
        background: SlideBackground?,
        speakerNotes: String?,
        animations: [SlideAnimation],
        customMetadata: [String: String]
    ) -> PresentationSlideDescriptor {
        PresentationSlideDescriptor(
            index: index,
            id: id,
            type: .regular,
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            subtitle: subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            layout: layout,
            transition: transition,
            duration: duration,
            autoAdvance: autoAdvance,
            background: normalizeBackground(background),
            speakerNotes: speakerNotes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            animations: animations,
            customMetadata: customMetadata
        )
    }

    private func normalizeBackground(_ background: SlideBackground?) -> SlideBackground? {
        guard let background else { return nil }
        return SlideBackground(
            type: background.type,
            blur: background.blur,
            overlay: background.overlay?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
    }
}

struct PresentationParseResultAssembler: Sendable {
    private let contentLowerer: SlideContentConverter

    init(documentParser: DocumentParser) {
        self.contentLowerer = SlideContentConverter(documentParser: documentParser)
    }

    func assemble(
        metadata: PresentationMetadata,
        items: [PresentationSlideAssemblyItem],
        diagnostics: [RhoeMarkdownKit.Diagnostic] = [],
        parseTime: TimeInterval
    ) async -> PresentationParseResult {
        var slides: [Slide] = []
        slides.reserveCapacity(items.count)

        var descriptors: [PresentationSlideDescriptor] = []
        descriptors.reserveCapacity(items.count)

        for item in items {
            slides.append(await contentLowerer.lowerRegularSlide(
                descriptor: item.descriptor,
                bodyMarkdown: item.bodyMarkdown
            ))
            descriptors.append(item.descriptor)
        }

        return PresentationParseResult(
            presentation: Presentation(slides: slides, metadata: metadata),
            slideDescriptors: descriptors,
            diagnostics: diagnostics,
            parseTime: parseTime
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
