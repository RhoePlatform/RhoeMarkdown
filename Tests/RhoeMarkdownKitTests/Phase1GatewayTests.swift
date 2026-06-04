import Testing
import Foundation
import RhoeMarkdownKit

@Suite("Phase 1: Generated Transform Gateway")
struct Phase1GatewayTests {

    // MARK: - Helpers

    private func preprocess(
        _ markdown: String,
        allowGeneratedTransforms: Bool = false,
        custom: [String: Any] = [:]
    ) async -> Phase1Result {
        let preprocessor = Phase1Preprocessor(allowGeneratedTransforms: allowGeneratedTransforms)
        return await preprocessor.preprocess(markdown, context: Phase1Context(custom: custom))
    }

    // MARK: - Clean Output

    @Test("Clean output without Phase 2 directives produces no gateway diagnostic")
    func cleanOutputNoDiagnostic() async {
        let result = await preprocess("# Hello World\n\nNo directives here.")
        let gatewayDiags = result.diagnostics.filter {
            $0.message.contains("Phase 2 directives") || $0.message.contains("Generated semantic")
        }
        #expect(gatewayDiags.isEmpty)
        #expect(!result.hasGeneratedTransforms)
    }

    // MARK: - Gateway Blocking

    @Test("Phase 2 directives blocked without allowGeneratedTransforms flag")
    func blockedWithoutFlag() async {
        let result = await preprocess(
            "Content with {@ hide family=example in=llm @} directive.",
            allowGeneratedTransforms: false
        )
        #expect(result.hasGeneratedTransforms)
        let hasError = result.diagnostics.contains { $0.severity == .error }
        #expect(hasError)
        let hasGatewayMsg = result.diagnostics.contains {
            $0.message.contains("Phase 2 directives")
        }
        #expect(hasGatewayMsg)
    }

    @Test("Phase 2 directives allowed with allowGeneratedTransforms flag")
    func allowedWithFlag() async {
        let result = await preprocess(
            "Content with {@ hide family=example in=llm @} directive.",
            allowGeneratedTransforms: true
        )
        #expect(result.hasGeneratedTransforms)
        // Should have info diagnostic, not error
        let hasError = result.diagnostics.contains { $0.severity == .error }
        #expect(!hasError)
        let hasInfo = result.diagnostics.contains { $0.severity == .info }
        #expect(hasInfo)
    }

    // MARK: - Multiple Blocks

    @Test("Multiple Phase 2 directive blocks detected")
    func multipleBlocks() async {
        let md = """
        {@ hide family=pii in=llm @}
        Some content
        {@ transform type=summary @}
        More content
        """
        let result = await preprocess(md, allowGeneratedTransforms: true)
        #expect(result.hasGeneratedTransforms)
        #expect(result.markdown.contains("{@"))
    }

    // MARK: - Partial Syntax

    @Test("Partial {@ without closing @} does not trigger gateway")
    func partialOpeningDelimiter() async {
        let result = await preprocess("This has {@ but no closing brace.")
        // hasGeneratedTransforms requires both {@ AND @}
        #expect(!result.hasGeneratedTransforms)
    }

    @Test("Partial @} without opening {@ does not trigger gateway")
    func partialClosingDelimiter() async {
        let result = await preprocess("This has @} but no opening brace.")
        #expect(!result.hasGeneratedTransforms)
    }

    // MARK: - hasGeneratedTransforms Flag

    @Test("hasGeneratedTransforms is true when directives present")
    func hasGeneratedTransformsTrue() async {
        let result = await preprocess(
            "{@ test @}",
            allowGeneratedTransforms: true
        )
        #expect(result.hasGeneratedTransforms == true)
    }

    @Test("hasGeneratedTransforms is false when no directives present")
    func hasGeneratedTransformsFalse() async {
        let result = await preprocess("Plain markdown content.")
        #expect(result.hasGeneratedTransforms == false)
    }
}
