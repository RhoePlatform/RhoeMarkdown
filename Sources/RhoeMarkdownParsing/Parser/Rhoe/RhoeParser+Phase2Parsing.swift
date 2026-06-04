import Foundation
import RhoeMarkdownModel

extension RhoeParser {

    /// Parse a Phase 2 directive from `{@ command args @}` tokens.
    ///
    /// Inline form: `{@ hide role=decorative in=llm @}`
    /// Block form:
    /// ```
    /// {@ collect @}
    /// select: family=theorem
    /// into: #theorem-index
    /// {@ endcollect @}
    /// ```
    func parsePhase2Directive(
        _ state: inout RhoeParserState,
        command: String,
        arguments: String?
    ) -> Block {
        guard configuration.enablePhase2Transforms else {
            state.advance() // consume the token
            return .paragraph([.text("{@ \(command) \(arguments ?? "") @}")], attributes: .init())
        }

        state.advance() // consume the phase2DirectiveOpen token

        let canonicalCommand = command.lowercased()

        // Check for block form: collect body until {@ endcommand @}
        var body: String? = nil
        if arguments == nil || arguments?.isEmpty == true {
            // This might be a block form opener — look for matching close
            body = collectPhase2BlockBody(&state, command: canonicalCommand)
        }

        // Parse arguments into key=value pairs
        let parsedArgs = parsePhase2Arguments(arguments)

        return .phase2Directive(
            command: canonicalCommand,
            arguments: parsedArgs,
            body: body
        )
    }

    /// Collect the body of a block-form Phase 2 directive until `{@ endcommand @}`.
    private func collectPhase2BlockBody(
        _ state: inout RhoeParserState,
        command: String
    ) -> String? {
        var bodyLines: [String] = []

        while let token = state.current {
            switch token.type {
            case .phase2DirectiveClose(let closeCmd):
                if closeCmd == command {
                    state.advance() // consume the close token
                    return bodyLines.isEmpty ? nil : bodyLines.joined(separator: "\n")
                }
                // Mismatched close — treat as body content
                bodyLines.append(token.content)
                state.advance()

            case .text(let text):
                bodyLines.append(text)
                state.advance()

            case .newline:
                state.advance()

            default:
                bodyLines.append(token.content)
                state.advance()
            }
        }

        return bodyLines.isEmpty ? nil : bodyLines.joined(separator: "\n")
    }

    /// Parse Phase 2 argument string into key=value pairs.
    ///
    /// Input: `"family=theorem in=#chapter-2 as=defs"`
    /// Output: `["family": "theorem", "in": "#chapter-2", "as": "defs"]`
    private func parsePhase2Arguments(_ raw: String?) -> [String: String] {
        guard let raw, !raw.isEmpty else { return [:] }

        var result: [String: String] = [:]

        // Split on whitespace, then parse each atom as key=value
        let atoms = raw.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        for atom in atoms {
            if let eqIndex = atom.firstIndex(of: "=") {
                let key = String(atom[atom.startIndex..<eqIndex])
                let value = String(atom[atom.index(after: eqIndex)...])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                result[key] = value
            } else {
                // Bare keyword — store as flag
                result[atom] = "true"
            }
        }

        return result
    }
}
