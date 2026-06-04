import Testing
@testable import RhoeMarkdownKit

@Suite("Sprint 35: Hardening Boundaries")
struct Sprint35HardeningBoundaryTests {

    @Test("lineBlock remains an explicit canonical-freeze warning after editor promotion")
    func lineBlockStillFlagsAtFreezeBoundary() {
        let document = RhoeMarkdownKit.Document(blocks: [
            .lineBlock(lines: [
                [.text("First line")],
                [.text("Second line")],
            ])
        ])

        let result = CanonicalFreezeValidationPass().process(document)

        #expect(result.metadata.attributeValidationDiagnostics.count == 1)
        #expect(result.metadata.attributeValidationDiagnostics.first?.severity == .warning)
        #expect(result.metadata.attributeValidationDiagnostics.first?.message.contains("lineBlock (should be normalized to paragraph)") == true)
    }

    @Test("paragraph plus hard breaks stays clean at the canonical-freeze boundary")
    func normalizedParagraphDoesNotFlagAtFreezeBoundary() {
        let document = RhoeMarkdownKit.Document(blocks: [
            .paragraph([
                .text("First line"),
                .hardBreak,
                .text("Second line"),
            ])
        ])

        let result = CanonicalFreezeValidationPass().process(document)

        #expect(result.metadata.attributeValidationDiagnostics.isEmpty)
    }
}
