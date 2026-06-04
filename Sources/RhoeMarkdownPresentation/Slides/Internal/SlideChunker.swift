import Foundation

package struct SlideChunk: Sendable {
    package let header: String
    package let body: String
    package let notes: String?
    package let raw: String
}

package struct SlideChunker: Sendable {
    package init() {}

    package func split(_ markdown: String) -> [SlideChunk] {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)

        var chunks: [SlideChunk] = []
        var currentHeader: String?
        var currentBody: [String] = []
        var currentNotes: [String] = []
        var currentRaw: [String] = []
        var inNotes = false

        func flush() {
            guard let currentHeader else { return }
            chunks.append(
                SlideChunk(
                    header: currentHeader,
                    body: currentBody.joined(separator: "\n"),
                    notes: currentNotes.isEmpty ? nil : currentNotes.joined(separator: "\n"),
                    raw: currentRaw.joined(separator: "\n")
                )
            )
        }

        for line in lines {
            let stringLine = String(line)

            if isDelimiter(stringLine) {
                flush()
                currentHeader = stringLine
                currentBody = []
                currentNotes = []
                currentRaw = [stringLine]
                inNotes = false
                continue
            }

            guard currentHeader != nil else { continue }
            currentRaw.append(stringLine)

            if stringLine.hasPrefix("%") && !stringLine.hasPrefix("%%") {
                inNotes = true
                currentNotes.append(String(stringLine.dropFirst()).trimmingCharacters(in: .whitespaces))
                continue
            }

            if inNotes {
                currentNotes.append(stringLine)
            } else {
                currentBody.append(stringLine)
            }
        }

        flush()
        return chunks
    }

    private func isDelimiter(_ line: String) -> Bool {
        return line.hasPrefix("%%%") && !line.hasPrefix("%%%%")
    }
}
