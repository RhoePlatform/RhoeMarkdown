import Foundation
import RhoeMarkdownModel

package enum SlideFrontmatterBodyMode: Sendable {
    case preserveOriginalWhenUnclosed
    case emptyWhenUnclosed
}

package struct ParsedSlideFrontmatterSection: Sendable {
    package let values: [String: String]
    package let body: String
    package let isClosed: Bool
}

package struct SlideFrontmatterParser: Sendable {
    package init() {}

    package func parseSection(
        from markdown: String,
        bodyMode: SlideFrontmatterBodyMode
    ) -> ParsedSlideFrontmatterSection {
        guard markdown.hasPrefix("---") else {
            return ParsedSlideFrontmatterSection(values: [:], body: markdown, isClosed: false)
        }

        var lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first == "---" else {
            return ParsedSlideFrontmatterSection(values: [:], body: markdown, isClosed: false)
        }

        lines.removeFirst()

        var frontmatterLines: [String] = []

        while !lines.isEmpty {
            let line = lines.removeFirst()
            if line == "---" || line == "..." {
                return ParsedSlideFrontmatterSection(
                    values: parseStringValues(from: frontmatterLines),
                    body: lines.joined(separator: "\n"),
                    isClosed: true
                )
            }

            frontmatterLines.append(line)
        }

        return ParsedSlideFrontmatterSection(
            values: parseStringValues(from: frontmatterLines),
            body: bodyMode == .preserveOriginalWhenUnclosed ? markdown : "",
            isClosed: false
        )
    }

    package func parseStringValues(from markdown: String) -> [String: String] {
        parseSection(from: markdown, bodyMode: .preserveOriginalWhenUnclosed).values
    }

    package func parseTypedValues(fromLines lines: [String]) -> [String: YAMLValue] {
        parseTypedValues(from: parseStringValues(from: lines))
    }

    package func parseTypedValues(from values: [String: String]) -> [String: YAMLValue] {
        var result: [String: YAMLValue] = [:]

        for (key, value) in values {
            if let intValue = Int(value) {
                result[key] = .int(intValue)
            } else if let doubleValue = Double(value) {
                result[key] = .double(doubleValue)
            } else if value == "true" || value == "false" {
                result[key] = .bool(value == "true")
            } else {
                result[key] = .string(value)
            }
        }

        return result
    }

    package func presentationMetadata(from frontmatter: Frontmatter?) -> PresentationMetadata {
        PresentationMetadata(
            title: frontmatter?.title,
            author: frontmatter?.author,
            date: frontmatter?.date,
            theme: frontmatter?.theme,
            customFields: frontmatter?.content ?? [:]
        )
    }

    private func parseStringValues(from lines: [String]) -> [String: String] {
        var result: [String: String] = [:]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let separator = trimmed.firstIndex(of: ":") else { continue }

            let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            result[key] = value
        }

        return result
    }
}
