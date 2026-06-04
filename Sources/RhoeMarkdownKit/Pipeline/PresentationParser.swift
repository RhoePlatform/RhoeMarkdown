import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownPresentation

public struct PresentationParser: Sendable {

    public let documentParser: DocumentParser

    public init(
        documentParser: DocumentParser = DocumentParser()
    ) {
        self.documentParser = documentParser
    }

    public func parse(_ markdown: String) async throws -> PresentationParseResult {
        await CanonicalParsedPresentationEngine(
            documentParser: documentParser
        ).parse(markdown)
    }
}
