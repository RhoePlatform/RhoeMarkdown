import Foundation
import RhoeMarkdownModel

extension RhoeParser {

    // MARK: - Public Entry Point

    public func parseYAMLContent(
        _ content: String
    ) -> [String: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue] {
        let lines = content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var anchors: [String: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue] = [:]
        var index = 0

        guard let mapping = parseYAMLMapping(
            lines: lines, at: &index, indent: 0, anchors: &anchors
        ) else {
            return [:]
        }

        return mapping
    }

    // MARK: - Mapping (key-value pairs at a given indent level)

    fileprivate func parseYAMLMapping(
        lines: [String],
        at index: inout Int,
        indent: Int,
        anchors: inout [String: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue]
    ) -> [String: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue]? {
        var result: [String: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue] = [:]

        while index < lines.count {
            let line = lines[index]

            // Skip blank lines and comments
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                index += 1
                continue
            }

            let lineIndent = measureIndent(line)
            if lineIndent < indent {
                break // Dedent — return to parent
            }
            if lineIndent > indent && result.isEmpty {
                break // Unexpected indent at start — not a mapping
            }
            if lineIndent > indent {
                break // Deeper indent belongs to a child block
            }

            // Must be a key: value pair or a list item at this indent
            if trimmed.hasPrefix("- ") || trimmed == "-" {
                break // This is a list, not a mapping entry
            }

            guard let colonIndex = findMappingColon(in: trimmed) else {
                index += 1
                continue
            }

            let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let valueString = String(trimmed[trimmed.index(after: colonIndex)...])
                .trimmingCharacters(in: .whitespaces)

            guard !key.isEmpty else {
                index += 1
                continue
            }

            index += 1

            let value = parseYAMLValueWithContext(
                valueString, lines: lines, at: &index,
                parentIndent: lineIndent, anchors: &anchors
            )

            // Handle anchor on key line: `key: &anchor value`
            let (resolvedValue, anchorName) = extractAnchor(from: value, rawValue: valueString)
            if let anchorName {
                anchors[anchorName] = resolvedValue
            }

            result[key] = resolvedValue
        }

        return result.isEmpty ? nil : result
    }

    // MARK: - Value parsing with multi-line context

    fileprivate func parseYAMLValueWithContext(
        _ valueString: String,
        lines: [String],
        at index: inout Int,
        parentIndent: Int,
        anchors: inout [String: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue]
    ) -> RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue {
        let trimmed = valueString.trimmingCharacters(in: .whitespaces)

        // Empty value — look for nested block on next lines
        if trimmed.isEmpty {
            return parseNestedBlock(
                lines: lines, at: &index,
                parentIndent: parentIndent, anchors: &anchors
            )
        }

        // Literal block scalar: |
        if trimmed == "|" || trimmed == "|-" || trimmed == "|+" {
            return parseLiteralBlock(
                lines: lines, at: &index,
                parentIndent: parentIndent, chomp: trimmed
            )
        }

        // Folded block scalar: >
        if trimmed == ">" || trimmed == ">-" || trimmed == ">+" {
            return parseFoldedBlock(
                lines: lines, at: &index,
                parentIndent: parentIndent, chomp: trimmed
            )
        }

        // Alias: *name
        if trimmed.hasPrefix("*") {
            let aliasName = String(trimmed.dropFirst())
            if let resolved = anchors[aliasName] {
                return resolved
            }
            return .string(trimmed)
        }

        // Anchor on value: &name value
        if trimmed.hasPrefix("&") {
            let parts = trimmed.dropFirst().split(separator: " ", maxSplits: 1)
            if let anchorName = parts.first {
                let rest = parts.count > 1 ? String(parts[1]) : ""
                let value = parseYAMLValue(rest)
                anchors[String(anchorName)] = value
                return value
            }
        }

        // Flow mapping: {key: value, ...}
        if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
            return parseFlowMapping(trimmed, anchors: &anchors)
        }

        // Flow array: [item, ...]
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            if let array = parseYAMLArray(trimmed, anchors: &anchors) {
                return .array(array)
            }
        }

        return parseYAMLValue(trimmed)
    }

    /// Parse the nested block (mapping or list) that appears indented under a key.
    fileprivate func parseNestedBlock(
        lines: [String],
        at index: inout Int,
        parentIndent: Int,
        anchors: inout [String: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue]
    ) -> RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue {
        // Skip blank lines to find the first content line
        var peekIndex = index
        while peekIndex < lines.count {
            let peek = lines[peekIndex].trimmingCharacters(in: .whitespaces)
            if peek.isEmpty || peek.hasPrefix("#") {
                peekIndex += 1
                continue
            }
            break
        }

        guard peekIndex < lines.count else { return .null }

        let childIndent = measureIndent(lines[peekIndex])
        guard childIndent > parentIndent else { return .null }

        let childTrimmed = lines[peekIndex].trimmingCharacters(in: .whitespaces)

        // Check if it's a list
        if childTrimmed.hasPrefix("- ") || childTrimmed == "-" {
            return parseYAMLList(
                lines: lines, at: &index,
                indent: childIndent, anchors: &anchors
            )
        }

        // Otherwise it's a nested mapping
        if let mapping = parseYAMLMapping(
            lines: lines, at: &index,
            indent: childIndent, anchors: &anchors
        ) {
            return .dictionary(mapping)
        }

        return .null
    }

    // MARK: - YAML List (dash-prefixed items)

    fileprivate func parseYAMLList(
        lines: [String],
        at index: inout Int,
        indent: Int,
        anchors: inout [String: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue]
    ) -> RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue {
        var items: [RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue] = []

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                index += 1
                continue
            }

            let lineIndent = measureIndent(line)
            if lineIndent < indent {
                break
            }
            if lineIndent > indent {
                break // Continuation of previous item — should have been consumed
            }

            guard trimmed.hasPrefix("- ") || trimmed == "-" else {
                break
            }

            let itemValue = trimmed == "-" ? "" : String(trimmed.dropFirst(2))
                .trimmingCharacters(in: .whitespaces)

            index += 1

            if itemValue.isEmpty {
                // The list item value is a nested block
                let nested = parseNestedBlock(
                    lines: lines, at: &index,
                    parentIndent: lineIndent, anchors: &anchors
                )
                items.append(nested)
            } else {
                // Check if the item value contains a colon (nested inline mapping)
                if let colonIdx = findMappingColon(in: itemValue) {
                    let key = String(itemValue[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                    let val = String(itemValue[itemValue.index(after: colonIdx)...])
                        .trimmingCharacters(in: .whitespaces)

                    if !key.isEmpty {
                        // Could be a single-line mapping or start of a nested mapping
                        let resolvedVal = parseYAMLValueWithContext(
                            val, lines: lines, at: &index,
                            parentIndent: lineIndent + 2, anchors: &anchors
                        )

                        // Check if more keys follow at the same deeper indent
                        var mapping: [String: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue] = [key: resolvedVal]
                        let nestedIndent = lineIndent + 2

                        while index < lines.count {
                            let nextLine = lines[index]
                            let nextTrimmed = nextLine.trimmingCharacters(in: .whitespaces)
                            if nextTrimmed.isEmpty || nextTrimmed.hasPrefix("#") {
                                index += 1
                                continue
                            }
                            let nextIndent = measureIndent(nextLine)
                            if nextIndent != nestedIndent { break }
                            if nextTrimmed.hasPrefix("- ") { break }
                            guard let nextColon = findMappingColon(in: nextTrimmed) else { break }
                            let nextKey = String(nextTrimmed[..<nextColon]).trimmingCharacters(in: .whitespaces)
                            let nextVal = String(nextTrimmed[nextTrimmed.index(after: nextColon)...])
                                .trimmingCharacters(in: .whitespaces)
                            guard !nextKey.isEmpty else { break }
                            index += 1
                            mapping[nextKey] = parseYAMLValueWithContext(
                                nextVal, lines: lines, at: &index,
                                parentIndent: nestedIndent, anchors: &anchors
                            )
                        }

                        items.append(.dictionary(mapping))
                        continue
                    }
                }

                items.append(parseYAMLValue(itemValue))
            }
        }

        return .array(items)
    }

    // MARK: - Literal Block Scalar ( | )

    fileprivate func parseLiteralBlock(
        lines: [String],
        at index: inout Int,
        parentIndent: Int,
        chomp: String
    ) -> RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue {
        var contentLines: [String] = []
        var blockIndent: Int?

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                if blockIndent != nil {
                    contentLines.append("")
                }
                index += 1
                continue
            }

            let lineIndent = measureIndent(line)
            if lineIndent <= parentIndent {
                break
            }

            if blockIndent == nil {
                blockIndent = lineIndent
            }

            // Strip the block indent
            let stripped = lineIndent >= (blockIndent ?? 0)
                ? String(repeating: " ", count: lineIndent - (blockIndent ?? 0)) + trimmed
                : trimmed
            contentLines.append(stripped)
            index += 1
        }

        var result = contentLines.joined(separator: "\n")

        // Apply chomping
        if chomp.hasSuffix("-") {
            result = result.trimmingCharacters(in: .newlines)
        } else if !chomp.hasSuffix("+") {
            // Default (clip): single trailing newline
            while result.hasSuffix("\n\n") {
                result = String(result.dropLast())
            }
            if !result.isEmpty && !result.hasSuffix("\n") {
                result += "\n"
            }
        }

        return .string(result)
    }

    // MARK: - Folded Block Scalar ( > )

    fileprivate func parseFoldedBlock(
        lines: [String],
        at index: inout Int,
        parentIndent: Int,
        chomp: String
    ) -> RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue {
        var contentLines: [String] = []
        var blockIndent: Int?

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                contentLines.append("")
                index += 1
                continue
            }

            let lineIndent = measureIndent(line)
            if lineIndent <= parentIndent {
                break
            }

            if blockIndent == nil {
                blockIndent = lineIndent
            }

            contentLines.append(trimmed)
            index += 1
        }

        // Fold: replace single newlines with spaces, preserve double newlines as paragraph breaks
        var result = ""
        var previousWasEmpty = false

        for (i, contentLine) in contentLines.enumerated() {
            if contentLine.isEmpty {
                previousWasEmpty = true
                result += "\n"
                continue
            }

            if i > 0 && !previousWasEmpty {
                result += " "
            }
            result += contentLine
            previousWasEmpty = false
        }

        // Apply chomping
        if chomp.hasSuffix("-") {
            result = result.trimmingCharacters(in: .newlines)
        } else if !chomp.hasSuffix("+") {
            while result.hasSuffix("\n\n") {
                result = String(result.dropLast())
            }
            if !result.isEmpty && !result.hasSuffix("\n") {
                result += "\n"
            }
        }

        return .string(result)
    }

    // MARK: - Flow Mapping ( { key: value } )

    fileprivate func parseFlowMapping(
        _ text: String,
        anchors: inout [String: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue]
    ) -> RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue {
        let content = String(text.dropFirst().dropLast())
            .trimmingCharacters(in: .whitespaces)

        if content.isEmpty {
            return .dictionary([:])
        }

        var mapping: [String: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue] = [:]
        let pairs = splitFlowItems(content)

        for pair in pairs {
            let trimmedPair = pair.trimmingCharacters(in: .whitespaces)
            guard let colonIdx = findMappingColon(in: trimmedPair) else { continue }

            let key = String(trimmedPair[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmedPair[trimmedPair.index(after: colonIdx)...])
                .trimmingCharacters(in: .whitespaces)

            guard !key.isEmpty else { continue }

            if value.hasPrefix("*") {
                let aliasName = String(value.dropFirst())
                if let resolved = anchors[aliasName] {
                    mapping[key] = resolved
                    continue
                }
            }

            mapping[key] = parseYAMLValue(value)
        }

        return .dictionary(mapping)
    }

    // MARK: - Simple Value Parsing (no context needed)

    func parseYAMLValue(_ value: String) -> RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue {
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty || trimmed == "null" || trimmed == "~" {
            return .null
        }

        if let boolean = parseYAMLBoolean(trimmed) {
            return .bool(boolean)
        }

        if let intValue = Int(trimmed) {
            return .int(intValue)
        }
        if let doubleValue = Double(trimmed) {
            return .double(doubleValue)
        }

        if let stringValue = parseQuotedYAMLString(trimmed) {
            return .string(stringValue)
        }

        // Inline flow array
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            var emptyAnchors: [String: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue] = [:]
            if let array = parseYAMLArray(trimmed, anchors: &emptyAnchors) {
                return .array(array)
            }
        }

        // Inline flow mapping
        if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
            var emptyAnchors: [String: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue] = [:]
            return parseFlowMapping(trimmed, anchors: &emptyAnchors)
        }

        return .string(trimmed)
    }

    // MARK: - Helpers

    fileprivate func parseYAMLBoolean(_ trimmed: String) -> Bool? {
        if trimmed == "true" || trimmed == "yes" || trimmed == "on" {
            return true
        }
        if trimmed == "false" || trimmed == "no" || trimmed == "off" {
            return false
        }
        return nil
    }

    fileprivate func parseQuotedYAMLString(_ trimmed: String) -> String? {
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
            (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return String(trimmed.dropFirst().dropLast())
        }

        return nil
    }

    fileprivate func parseYAMLArray(
        _ trimmed: String,
        anchors: inout [String: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue]
    ) -> [RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue]? {
        guard trimmed.hasPrefix("[") && trimmed.hasSuffix("]") else {
            return nil
        }

        let arrayContent = String(trimmed.dropFirst().dropLast())
            .trimmingCharacters(in: .whitespaces)

        if arrayContent.isEmpty {
            return []
        }

        return splitFlowItems(arrayContent).map { element in
            let trimmedElement = element.trimmingCharacters(in: .whitespaces)
            if trimmedElement.hasPrefix("*") {
                let aliasName = String(trimmedElement.dropFirst())
                if let resolved = anchors[aliasName] {
                    return resolved
                }
            }
            return parseYAMLValue(trimmedElement)
        }
    }

    /// Measure the number of leading spaces in a line.
    fileprivate func measureIndent(_ line: String) -> Int {
        var count = 0
        for char in line {
            if char == " " {
                count += 1
            } else if char == "\t" {
                count += 2 // Treat tab as 2 spaces
            } else {
                break
            }
        }
        return count
    }

    /// Find the first colon that acts as a mapping separator (not inside quotes or after `://`).
    fileprivate func findMappingColon(in text: String) -> String.Index? {
        var inSingleQuote = false
        var inDoubleQuote = false
        var prevChar: Character?

        for i in text.indices {
            let char = text[i]

            if char == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
            } else if char == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
            } else if char == ":" && !inSingleQuote && !inDoubleQuote {
                // Check it's not a URL scheme (e.g., `http://`)
                let afterColon = text.index(after: i)
                if afterColon < text.endIndex && text[afterColon] == "/" {
                    if let prev = prevChar, prev.isLetter {
                        // Looks like a URL scheme — skip
                        prevChar = char
                        continue
                    }
                }

                // Valid mapping colon: must be followed by space, end-of-string, or nothing
                if afterColon >= text.endIndex || text[afterColon] == " " {
                    return i
                }
            }

            prevChar = char
        }

        return nil
    }

    /// Split flow collection items by comma, respecting nesting.
    fileprivate func splitFlowItems(_ content: String) -> [String] {
        var items: [String] = []
        var current = ""
        var depth = 0
        var inSingleQuote = false
        var inDoubleQuote = false

        for char in content {
            if char == "'" && !inDoubleQuote { inSingleQuote.toggle() }
            else if char == "\"" && !inSingleQuote { inDoubleQuote.toggle() }
            else if !inSingleQuote && !inDoubleQuote {
                if char == "[" || char == "{" { depth += 1 }
                else if char == "]" || char == "}" { depth -= 1 }
                else if char == "," && depth == 0 {
                    items.append(current)
                    current = ""
                    continue
                }
            }
            current.append(char)
        }

        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(current)
        }

        return items
    }

    /// Extract an anchor declaration from a value string.
    fileprivate func extractAnchor(
        from value: RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue,
        rawValue: String
    ) -> (RhoeMarkdownModel.RhoeMarkdownKit.YAMLValue, String?) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("&") {
            let parts = trimmed.dropFirst().split(separator: " ", maxSplits: 1)
            if let anchorName = parts.first {
                return (value, String(anchorName))
            }
        }
        return (value, nil)
    }
}
