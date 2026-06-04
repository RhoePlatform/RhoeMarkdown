import Foundation
import RhoeMarkdownParsing

package struct PresentationHeaderParts: Sendable {
    package let header: String
    package let attributes: String?
}

package struct PresentationAttributeParser: Sendable {
    private let sharedParser: SlideAttributeParser

    package init() {
        self.sharedParser = SlideAttributeParser()
    }

    package func splitHeaderAndAttributes(_ line: String) -> PresentationHeaderParts {
        guard let start = line.firstIndex(of: "{"), let end = line.lastIndex(of: "}") else {
            return PresentationHeaderParts(header: line, attributes: nil)
        }

        let header = String(line[..<start]).trimmingCharacters(in: .whitespacesAndNewlines)
        let attributes = String(line[line.index(after: start)..<end])

        return PresentationHeaderParts(header: header, attributes: attributes)
    }

    package func parse(_ attributes: String?) -> [String: String] {
        guard let attributes, !attributes.isEmpty else { return [:] }
        return sharedParser.parseAttributeMap(attributes)
    }
}
