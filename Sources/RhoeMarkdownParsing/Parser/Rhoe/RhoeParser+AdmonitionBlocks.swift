import Foundation
import RhoeMarkdownModel

extension RhoeParser {
    func parseAdmonition(
        _ state: inout RhoeParserState,
        type: String,
        title: String?,
        collapsible: AdmonitionCollapsible?
    ) -> Block {
        // Capture the admonition start token's line for attribute extraction
        let startTokenLine = state.current?.line ?? 0

        state.advance() // consume admonitionStart token

        // Case-normalize language-owned identifiers.
        let canonicalType = type.lowercased()

        // Try to consume inline attribute list emitted by lexer.
        var inlineAttrs = consumeAttributeList(&state) ?? RhoeMarkdownKit.Attributes()

        // If no attribute list token was found, try extracting from source line
        if inlineAttrs.keyValues.isEmpty && startTokenLine > 0 && startTokenLine <= state.sourceLines.count {
            let sourceLine = state.sourceLines[startTokenLine - 1]
            if let braceStart = sourceLine.firstIndex(of: "{"),
               let braceEnd = sourceLine.lastIndex(of: "}") {
                let attrContent = String(sourceLine[sourceLine.index(after: braceStart)..<braceEnd])
                inlineAttrs = parseAttributes(from: attrContent)
            }
        }

        let contentBlocks = collectAdmonitionBlocks(&state)
        consumeAdmonitionEndIfPresent(&state)

        // Check for trailing attribute block after the closing !!!
        let trailingAttrs = consumeAttributeList(&state) ?? RhoeMarkdownKit.Attributes()

        // Merge inline and trailing attributes
        let attributes = RhoeMarkdownKit.Attributes(
            id: inlineAttrs.id ?? trailingAttrs.id,
            classes: inlineAttrs.classes + trailingAttrs.classes,
            keyValues: inlineAttrs.keyValues.merging(trailingAttrs.keyValues) { a, _ in a }
        )

        // NB-5: Detect contract directives — `!!! input` or `!!! output`
        if canonicalType == "input" || canonicalType == "output" {
            let contractKind: ContractKind = canonicalType == "input" ? .input : .output
            let bodyText = contentBlocks.compactMap { block -> String? in
                if case .paragraph(let inlines, _) = block {
                    return inlines.compactMap { inline -> String? in
                        if case .text(let t) = inline { return t }
                        return nil
                    }.joined()
                }
                return nil
            }.joined(separator: "\n")
            return .contractDirective(kind: contractKind, content: bodyText, attributes: attributes)
        }

        // Detect component declarations: `!!! component {name=callout}`.
        if canonicalType == "component" {
            let name = (attributes.keyValues["name"] ?? "").lowercased()
            let args = attributes.keyValues["args"]
            let slots = attributes.keyValues["slots"]

            let cleanKV = attributes.keyValues.filter { $0.key != "name" && $0.key != "args" && $0.key != "slots" }
            let cleanAttrs = RhoeMarkdownKit.Attributes(id: attributes.id, classes: attributes.classes, keyValues: cleanKV)

            return .componentDeclaration(
                family: .semantic,
                name: name,
                args: args,
                slots: slots,
                body: contentBlocks,
                attributes: cleanAttrs
            )
        }

        // Inject projection defaults for speaker notes.
        var finalAttrs = attributes
        if canonicalType == "speakernotes" {
            var kv = attributes.keyValues
            if kv["visible"] == nil && kv["hidden"] == nil {
                kv["visible"] = "presenter"
                kv["hidden"] = "audience,print,llm"
            }
            finalAttrs = RhoeMarkdownKit.Attributes(id: attributes.id, classes: attributes.classes, keyValues: kv)
        }

        return .admonition(
            type: canonicalType,
            title: title,
            content: contentBlocks,
            collapsible: collapsible,
            attributes: finalAttrs
        )
    }
}
