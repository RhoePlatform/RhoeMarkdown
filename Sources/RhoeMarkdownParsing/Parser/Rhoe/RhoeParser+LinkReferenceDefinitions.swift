import Foundation
import RhoeMarkdownModel

extension RhoeParser {

    // MARK: - Link Reference Definition Extraction

    struct LinkReferenceExtraction {
        let markdown: String
        let definitions: [String: LinkReferenceDefinition]
    }

    struct LinkReferenceDefinition {
        let destination: String
        let title: String?
    }

    struct LinkReferenceLineContext {
        enum Scope {
            case topLevel
            case blockQuote
        }

        let scope: Scope
        let body: String
    }

    struct ParsedLinkReferenceDefinition {
        let key: String
        let definition: LinkReferenceDefinition
        let consumedLineCount: Int
        let scope: LinkReferenceLineContext.Scope
    }

    func extractLinkReferenceDefinitions(from markdown: String) -> LinkReferenceExtraction {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard !lines.isEmpty else {
            return LinkReferenceExtraction(markdown: markdown, definitions: [:])
        }

        var rewrittenLines = lines
        var definitions: [String: LinkReferenceDefinition] = [:]
        var index = 0
        var fencedCode: (marker: Character, length: Int)?

        while index < lines.count {
            if let fence = fencedCode {
                if closesReferenceExtractionFence(lines[index], fence: fence) {
                    fencedCode = nil
                }
                index += 1
                continue
            }

            if let openingFence = opensReferenceExtractionFence(lines[index]) {
                fencedCode = openingFence
                index += 1
                continue
            }

            guard previousLineAllowsReferenceDefinition(in: rewrittenLines, at: index) else {
                index += 1
                continue
            }

            if let parsed = parseLinkReferenceDefinition(in: lines, at: index) {
                if definitions[parsed.key] == nil {
                    definitions[parsed.key] = parsed.definition
                }

                let replacement = parsed.scope == .blockQuote ? ">" : ""
                for offset in 0..<parsed.consumedLineCount where index + offset < rewrittenLines.count {
                    rewrittenLines[index + offset] = replacement
                }
                index += parsed.consumedLineCount
            } else {
                index += 1
            }
        }

        return LinkReferenceExtraction(
            markdown: rewrittenLines.joined(separator: "\n"),
            definitions: definitions
        )
    }

    func parseLinkReferenceDefinition(
        in lines: [String],
        at lineIndex: Int
    ) -> ParsedLinkReferenceDefinition? {
        guard let openingContext = linkReferenceLineContext(for: lines[lineIndex]),
              let label = parseLinkReferenceOpening(in: lines, at: lineIndex, context: openingContext)
        else {
            return nil
        }

        let key = normalizedLinkReferenceLabel(label.rawLabel)
        guard !key.isEmpty else { return nil }

        var consumedLineCount = label.consumedLineCount
        var destinationLine = label.remainder.trimmingCharacters(in: .horizontalWhitespace)

        if destinationLine.isEmpty {
            let nextIndex = lineIndex + consumedLineCount
            guard nextIndex < lines.count,
                  let nextContext = linkReferenceContinuationContext(for: lines[nextIndex], scope: openingContext.scope),
                  nextContext.scope == openingContext.scope
            else {
                return nil
            }
            destinationLine = nextContext.body.trimmingCharacters(in: .horizontalWhitespace)
            consumedLineCount += 1
        }

        guard let destination = parseReferenceDestination(from: destinationLine) else {
            return nil
        }

        guard destination.remainder.isEmpty || destination.remainder.first?.isHorizontalWhitespace == true else {
            return nil
        }

        let trimmedRemainder = destination.remainder.trimmingCharacters(in: .horizontalWhitespace)
        var title: String?
        if !trimmedRemainder.isEmpty {
            let continuationBodies = referenceContinuationBodies(
                in: lines,
                from: lineIndex + consumedLineCount,
                scope: openingContext.scope
            )
            guard let parsedTitle = parseReferenceTitle(from: [trimmedRemainder] + continuationBodies, startingAt: 0)
            else {
                return nil
            }
            title = parsedTitle.title
            consumedLineCount += max(0, parsedTitle.consumedLineCount - 1)
        } else if let parsedTitle = parseFollowingReferenceTitle(
            in: lines,
            from: lineIndex + consumedLineCount,
            scope: openingContext.scope
        ) {
            title = parsedTitle.title
            consumedLineCount += parsedTitle.consumedLineCount
        }

        return ParsedLinkReferenceDefinition(
            key: key,
            definition: LinkReferenceDefinition(destination: destination.destination, title: title),
            consumedLineCount: consumedLineCount,
            scope: openingContext.scope
        )
    }

    func parseLinkReferenceOpening(
        in lines: [String],
        at lineIndex: Int,
        context openingContext: LinkReferenceLineContext
    ) -> (rawLabel: String, remainder: String, consumedLineCount: Int)? {
        if let sameLineLabel = parseLinkReferenceLabel(from: openingContext.body) {
            return (sameLineLabel.rawLabel, sameLineLabel.remainder, 1)
        }

        guard openingContext.body.first == "[" else {
            return nil
        }

        var rawLabel = String(openingContext.body.dropFirst())
        var consumedLineCount = 1

        while lineIndex + consumedLineCount < lines.count {
            guard let continuation = linkReferenceContinuationContext(
                for: lines[lineIndex + consumedLineCount],
                scope: openingContext.scope
            ) else {
                return nil
            }

            rawLabel += "\n" + continuation.body
            consumedLineCount += 1

            if let closing = closingReferenceLabel(in: rawLabel) {
                let label = String(rawLabel[..<closing.labelEnd])
                guard !label.isEmpty, label.count <= 999 else {
                    return nil
                }
                guard !containsUnescapedReferenceLabelBracket(label) else {
                    return nil
                }
                return (label, String(rawLabel[closing.remainderStart...]), consumedLineCount)
            }
        }

        return nil
    }

    func containsUnescapedReferenceLabelBracket(_ label: String) -> Bool {
        var index = label.startIndex
        while index < label.endIndex {
            let character = label[index]
            if character == "\\" {
                let next = label.index(after: index)
                guard next < label.endIndex else {
                    return true
                }
                index = label.index(after: next)
                continue
            }
            if character == "[" || character == "]" {
                return true
            }
            index = label.index(after: index)
        }
        return false
    }

    func closingReferenceLabel(in rawLabel: String) -> (labelEnd: String.Index, remainderStart: String.Index)? {
        var index = rawLabel.startIndex

        while index < rawLabel.endIndex {
            let character = rawLabel[index]
            if character == "\\" {
                let next = rawLabel.index(after: index)
                guard next < rawLabel.endIndex else {
                    return nil
                }
                index = rawLabel.index(after: next)
                continue
            }

            if character == "]" {
                let afterBracket = rawLabel.index(after: index)
                guard afterBracket < rawLabel.endIndex, rawLabel[afterBracket] == ":" else {
                    return nil
                }
                return (index, rawLabel.index(after: afterBracket))
            }

            index = rawLabel.index(after: index)
        }

        return nil
    }

    func linkReferenceLineContext(for line: String) -> LinkReferenceLineContext? {
        let line = line.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
        var index = line.startIndex
        var leadingSpaces = 0

        while index < line.endIndex, line[index] == " ", leadingSpaces < 4 {
            leadingSpaces += 1
            index = line.index(after: index)
        }

        guard leadingSpaces <= 3 else {
            return nil
        }

        if index < line.endIndex, line[index] == ">" {
            index = line.index(after: index)
            if index < line.endIndex, line[index] == " " || line[index] == "\t" {
                index = line.index(after: index)
            }

            var quoteInnerSpaces = 0
            while index < line.endIndex, line[index] == " ", quoteInnerSpaces < 4 {
                quoteInnerSpaces += 1
                index = line.index(after: index)
            }

            guard quoteInnerSpaces <= 3 else {
                return nil
            }

            return LinkReferenceLineContext(scope: .blockQuote, body: String(line[index...]))
        }

        return LinkReferenceLineContext(scope: .topLevel, body: String(line[index...]))
    }

    func parseLinkReferenceLabel(from body: String) -> (rawLabel: String, remainder: String)? {
        guard body.first == "[" else { return nil }

        var index = body.index(after: body.startIndex)
        var rawLabel = ""

        while index < body.endIndex {
            let character = body[index]
            if character == "\\" {
                let next = body.index(after: index)
                guard next < body.endIndex else {
                    return nil
                }
                rawLabel.append(character)
                rawLabel.append(body[next])
                index = body.index(after: next)
                continue
            }

            if character == "]" {
                let afterClosingBracket = body.index(after: index)
                guard afterClosingBracket < body.endIndex,
                      body[afterClosingBracket] == ":"
                else {
                    return nil
                }

                guard !rawLabel.isEmpty, rawLabel.count <= 999 else {
                    return nil
                }
                guard !containsUnescapedReferenceLabelBracket(rawLabel) else {
                    return nil
                }

                let remainderStart = body.index(after: afterClosingBracket)
                return (rawLabel, String(body[remainderStart...]))
            }

            rawLabel.append(character)
            index = body.index(after: index)
        }

        return nil
    }

    func linkReferenceContinuationContext(
        for line: String,
        scope: LinkReferenceLineContext.Scope
    ) -> LinkReferenceLineContext? {
        let line = line.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
        var index = line.startIndex

        switch scope {
        case .topLevel:
            while index < line.endIndex, line[index].isHorizontalWhitespace {
                index = line.index(after: index)
            }
            return LinkReferenceLineContext(scope: .topLevel, body: String(line[index...]))
        case .blockQuote:
            while index < line.endIndex, line[index].isHorizontalWhitespace {
                index = line.index(after: index)
            }
            guard index < line.endIndex, line[index] == ">" else {
                return nil
            }
            index = line.index(after: index)
            if index < line.endIndex, line[index].isHorizontalWhitespace {
                index = line.index(after: index)
            }
            while index < line.endIndex, line[index].isHorizontalWhitespace {
                index = line.index(after: index)
            }
            return LinkReferenceLineContext(scope: .blockQuote, body: String(line[index...]))
        }
    }

    func parseReferenceDestination(from line: String) -> (destination: String, remainder: String)? {
        var index = line.startIndex
        guard index < line.endIndex else {
            return nil
        }

        if line[index] == "<" {
            guard let rawDestination = consumeReferenceAngleDestination(in: line, at: &index) else {
                return nil
            }
            let destination = normalizeCommonMarkLinkDestination(rawDestination, percentEncodeSpaces: true)
            return (destination, String(line[index...]))
        }

        guard let rawDestination = consumeReferenceBareDestination(in: line, at: &index),
              !rawDestination.isEmpty
        else {
            return nil
        }

        let destination = normalizeCommonMarkLinkDestination(rawDestination, percentEncodeSpaces: false)
        return (destination, String(line[index...]))
    }

    func consumeReferenceAngleDestination(
        in text: String,
        at index: inout String.Index
    ) -> String? {
        guard index < text.endIndex, text[index] == "<" else {
            return nil
        }
        index = text.index(after: index)

        var destination = ""
        while index < text.endIndex {
            let character = text[index]
            if character == "\n" || character == "<" {
                return nil
            }
            if character == "\\" {
                let next = text.index(after: index)
                guard next < text.endIndex else {
                    return nil
                }
                destination.append(character)
                destination.append(text[next])
                index = text.index(after: next)
                continue
            }
            if character == ">" {
                index = text.index(after: index)
                return destination
            }

            destination.append(character)
            index = text.index(after: index)
        }

        return nil
    }

    func consumeReferenceBareDestination(
        in text: String,
        at index: inout String.Index
    ) -> String? {
        var destination = ""
        var parenthesisDepth = 0

        while index < text.endIndex {
            let character = text[index]
            if character == " " || character == "\t" {
                break
            }

            if character == "\\" {
                let next = text.index(after: index)
                guard next < text.endIndex else {
                    return nil
                }
                destination.append(character)
                destination.append(text[next])
                index = text.index(after: next)
                continue
            }

            if character == "(" {
                parenthesisDepth += 1
                destination.append(character)
                index = text.index(after: index)
                continue
            }

            if character == ")" {
                if parenthesisDepth == 0 {
                    break
                }
                parenthesisDepth -= 1
                destination.append(character)
                index = text.index(after: index)
                continue
            }

            destination.append(character)
            index = text.index(after: index)
        }

        guard parenthesisDepth == 0 else {
            return nil
        }
        return destination
    }

    func parseFollowingReferenceTitle(
        in lines: [String],
        from lineIndex: Int,
        scope: LinkReferenceLineContext.Scope
    ) -> (title: String, consumedLineCount: Int)? {
        let bodies = referenceContinuationBodies(in: lines, from: lineIndex, scope: scope)
        guard !bodies.isEmpty else {
            return nil
        }

        return parseReferenceTitle(from: bodies, startingAt: 0)
    }

    func referenceContinuationBodies(
        in lines: [String],
        from lineIndex: Int,
        scope: LinkReferenceLineContext.Scope
    ) -> [String] {
        guard lineIndex < lines.count else {
            return []
        }

        var bodies: [String] = []
        var index = lineIndex
        while index < lines.count,
              let context = linkReferenceContinuationContext(for: lines[index], scope: scope),
              context.scope == scope {
            bodies.append(context.body)
            index += 1
        }
        return bodies
    }

    func parseReferenceTitle(
        from lines: [String],
        startingAt startIndex: Int,
        scope: LinkReferenceLineContext.Scope? = nil
    ) -> (title: String, consumedLineCount: Int)? {
        guard startIndex < lines.count else {
            return nil
        }

        var titleLines: [String] = []
        var consumed = 0

        for index in startIndex..<lines.count {
            let line: String
            if let scope {
                guard let context = linkReferenceLineContext(for: lines[index]),
                      context.scope == scope
                else {
                    break
                }
                line = context.body
            } else {
                line = lines[index]
            }

            if !titleLines.isEmpty,
               line.trimmingCharacters(in: .horizontalWhitespace).isEmpty {
                return nil
            }

            titleLines.append(line)
            consumed += 1

            let titleCandidate = titleLines.joined(separator: "\n")
            if let parsed = parseReferenceTitleCandidate(titleCandidate) {
                return (parsed, consumed)
            }
        }

        return nil
    }

    func parseReferenceTitleCandidate(_ text: String) -> String? {
        var index = text.startIndex
        while index < text.endIndex, text[index] == " " || text[index] == "\t" {
            index = text.index(after: index)
        }

        guard index < text.endIndex else {
            return nil
        }

        let opener = text[index]
        let closer: Character
        if opener == "\"" || opener == "'" {
            closer = opener
        } else if opener == "(" {
            closer = ")"
        } else {
            return nil
        }

        index = text.index(after: index)
        var title = ""
        var escaped = false

        while index < text.endIndex {
            let character = text[index]

            if escaped {
                title.append("\\")
                title.append(character)
                escaped = false
                index = text.index(after: index)
                continue
            }

            if character == "\\" {
                escaped = true
                index = text.index(after: index)
                continue
            }

            if character == closer {
                let afterCloser = text.index(after: index)
                let remainder = text[afterCloser...].trimmingCharacters(in: .horizontalWhitespace)
                guard remainder.isEmpty else {
                    return nil
                }
                return decodeCommonMarkCharacterReferences(unescapeCommonMarkBackslashEscapes(title))
            }

            title.append(character)
            index = text.index(after: index)
        }

        return nil
    }

    func normalizedLinkReferenceLabel(_ rawLabel: String) -> String {
        let unescaped = unescapeCommonMarkBackslashEscapes(rawLabel)
        let decoded = decodeCommonMarkCharacterReferences(unescaped)
        return decoded
            .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" })
            .joined(separator: " ")
            .folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    func previousLineAllowsReferenceDefinition(in lines: [String], at lineIndex: Int) -> Bool {
        guard lineIndex > 0 else {
            return true
        }

        let previous = lines[lineIndex - 1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !previous.isEmpty, previous != ">" else {
            return true
        }

        if previous.hasPrefix("#") || previous.hasPrefix(">") ||
            previous.hasPrefix("```") || previous.hasPrefix("~~~") ||
            previous == "---" || previous == "***" || previous == "___" {
            return true
        }

        return false
    }

    func opensReferenceExtractionFence(_ line: String) -> (marker: Character, length: Int)? {
        let trimmed = line.drop(while: { $0.isHorizontalWhitespace })
        guard let marker = trimmed.first, marker == "`" || marker == "~" else {
            return nil
        }

        let length = trimmed.prefix(while: { $0 == marker }).count
        guard length >= 3 else {
            return nil
        }

        return (marker, length)
    }

    func closesReferenceExtractionFence(
        _ line: String,
        fence: (marker: Character, length: Int)
    ) -> Bool {
        let trimmed = line.drop(while: { $0.isHorizontalWhitespace })
        let markerCount = trimmed.prefix(while: { $0 == fence.marker }).count
        guard markerCount >= fence.length else {
            return false
        }

        let afterFence = trimmed.dropFirst(markerCount)
        return afterFence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Link Reference Resolution

    func resolveLinkReferences(
        in blocks: [Block],
        definitions: [String: LinkReferenceDefinition]
    ) -> [Block] {
        guard !definitions.isEmpty else {
            return blocks
        }

        return blocks.map { resolveLinkReferences(in: $0, definitions: definitions) }
    }

    func resolveLinkReferences(
        in block: Block,
        definitions: [String: LinkReferenceDefinition]
    ) -> Block {
        switch block {
        case .paragraph(let inlines, let attributes):
            return .paragraph(resolveLinkReferences(in: inlines, definitions: definitions), attributes: attributes)
        case .heading(let level, let content, let attributes):
            return .heading(level: level, content: resolveLinkReferences(in: content, definitions: definitions), attributes: attributes)
        case .blockQuote(let blocks, let attributes):
            return .blockQuote(resolveLinkReferences(in: blocks, definitions: definitions), attributes: attributes)
        case .list(let type, let items, let attributes):
            let resolvedItems = items.map { item in
                ListItem(
                    content: resolveLinkReferences(in: item.content, definitions: definitions),
                    checked: item.checked,
                    isLoose: item.isLoose
                )
            }
            return .list(type: type, items: resolvedItems, attributes: attributes)
        case .table(let headers, let rows, let caption, let attributes):
            return .table(
                headers: headers.map { resolveLinkReferences(in: $0, definitions: definitions) },
                rows: rows.map { $0.map { resolveLinkReferences(in: $0, definitions: definitions) } },
                caption: caption.map { resolveLinkReferences(in: $0, definitions: definitions) },
                attributes: attributes
            )
        case .definitionList(let items, let attributes):
            let resolvedItems = items.map { item in
                DefinitionListItem(
                    term: resolveLinkReferences(in: item.term, definitions: definitions),
                    definitions: item.definitions.map { resolveLinkReferences(in: $0, definitions: definitions) }
                )
            }
            return .definitionList(items: resolvedItems, attributes: attributes)
        case .footnoteDefinition(let id, let content):
            return .footnoteDefinition(id: id, content: resolveLinkReferences(in: content, definitions: definitions))
        case .admonition(let type, let title, let content, let collapsible, let attributes):
            return .admonition(type: type, title: title, content: resolveLinkReferences(in: content, definitions: definitions), collapsible: collapsible, attributes: attributes)
        case .div(let content, let attributes):
            return .div(content: resolveLinkReferences(in: content, definitions: definitions), attributes: attributes)
        case .lineBlock(let lines):
            return .lineBlock(lines: lines.map { resolveLinkReferences(in: $0, definitions: definitions) })
        case .visualBlock(let name, let content, let attributes):
            return .visualBlock(name: name, content: resolveLinkReferences(in: content, definitions: definitions), attributes: attributes)
        case .componentDeclaration(let family, let name, let args, let slots, let body, let attributes):
            return .componentDeclaration(family: family, name: name, args: args, slots: slots, body: resolveLinkReferences(in: body, definitions: definitions), attributes: attributes)
        case .form(let name, let content, let attributes):
            return .form(name: name, content: resolveLinkReferences(in: content, definitions: definitions), attributes: attributes)
        case .widget(let title, let content, let attributes):
            return .widget(title: title, content: resolveLinkReferences(in: content, definitions: definitions), attributes: attributes)
        case .tab(let title, let content, let attributes):
            return .tab(title: title, content: resolveLinkReferences(in: content, definitions: definitions), attributes: attributes)
        case .stage(let kind, let content, let attributes):
            return .stage(kind: kind, content: resolveLinkReferences(in: content, definitions: definitions), attributes: attributes)
        case .lane(let content, let attributes):
            return .lane(content: resolveLinkReferences(in: content, definitions: definitions), attributes: attributes)
        case .module(let family, let name, let content, let attributes):
            return .module(family: family, name: name, content: resolveLinkReferences(in: content, definitions: definitions), attributes: attributes)
        case .section(let level, let title, let children, let attributes):
            return .section(
                level: level,
                title: resolveLinkReferences(in: title, definitions: definitions),
                children: resolveLinkReferences(in: children, definitions: definitions),
                attributes: attributes
            )
        case .formalBlock(let family, let title, let number, let content, let attributes):
            return .formalBlock(
                family: family,
                title: title.map { resolveLinkReferences(in: $0, definitions: definitions) },
                number: number,
                content: resolveLinkReferences(in: content, definitions: definitions),
                attributes: attributes
            )
        case .speakerNotes(let content, let attributes):
            return .speakerNotes(content: resolveLinkReferences(in: content, definitions: definitions), attributes: attributes)
        case .grid(let content, let attributes):
            return .grid(content: resolveLinkReferences(in: content, definitions: definitions), attributes: attributes)
        case .columns(let content, let attributes):
            return .columns(content: resolveLinkReferences(in: content, definitions: definitions), attributes: attributes)
        case .figure(let content, let caption, let attributes):
            return .figure(
                content: resolveLinkReferences(in: content, definitions: definitions),
                caption: caption.map { resolveLinkReferences(in: $0, definitions: definitions) },
                attributes: attributes
            )
        case .tableHead(let rows, let attributes):
            return .tableHead(rows: rows.map { $0.map { resolveLinkReferences(in: $0, definitions: definitions) } }, attributes: attributes)
        case .tableBody(let rows, let attributes):
            return .tableBody(rows: rows.map { $0.map { resolveLinkReferences(in: $0, definitions: definitions) } }, attributes: attributes)
        case .tableFoot(let rows, let attributes):
            return .tableFoot(rows: rows.map { $0.map { resolveLinkReferences(in: $0, definitions: definitions) } }, attributes: attributes)
        case .tableRow(let cells, let attributes):
            return .tableRow(cells: cells.map { resolveLinkReferences(in: $0, definitions: definitions) }, attributes: attributes)
        case .deck(let slides, let attributes):
            return .deck(slides: resolveLinkReferences(in: slides, definitions: definitions), attributes: attributes)
        case .slide(let title, let content, let attributes):
            return .slide(
                title: title.map { resolveLinkReferences(in: $0, definitions: definitions) },
                content: resolveLinkReferences(in: content, definitions: definitions),
                attributes: attributes
            )
        case .slotContent(let name, let content, let attributes):
            return .slotContent(name: name, content: resolveLinkReferences(in: content, definitions: definitions), attributes: attributes)
        case .extension_(let vendor, let name, let content, let attributes):
            return .extension_(vendor: vendor, name: name, content: resolveLinkReferences(in: content, definitions: definitions), attributes: attributes)
        case .shape(let content, let attributes):
            return .shape(content: resolveLinkReferences(in: content, definitions: definitions), attributes: attributes)
        default:
            return block
        }
    }

    func resolveLinkReferences(
        in cell: TableCell,
        definitions: [String: LinkReferenceDefinition]
    ) -> TableCell {
        TableCell(
            content: resolveLinkReferences(in: cell.content, definitions: definitions),
            alignment: cell.alignment,
            blockContent: cell.blockContent.map { resolveLinkReferences(in: $0, definitions: definitions) },
            rowSpan: cell.rowSpan,
            colSpan: cell.colSpan
        )
    }

    func resolveLinkReferences(
        in inlines: [Inline],
        definitions: [String: LinkReferenceDefinition]
    ) -> [Inline] {
        let recursivelyResolved = inlines.map { resolveLinkReferences(in: $0, definitions: definitions) }
        let merged = mergeAdjacentTextInlines(recursivelyResolved)

        return merged.flatMap { inline -> [Inline] in
            guard case .text(let text) = inline else {
                return [inline]
            }
            return resolveReferenceSyntax(in: text, definitions: definitions)
        }
    }

    func resolveLinkReferences(
        in inline: Inline,
        definitions: [String: LinkReferenceDefinition]
    ) -> Inline {
        switch inline {
        case .emphasis(let content):
            return .emphasis(resolveLinkReferences(in: content, definitions: definitions))
        case .strong(let content):
            return .strong(resolveLinkReferences(in: content, definitions: definitions))
        case .strikethrough(let content):
            return .strikethrough(resolveLinkReferences(in: content, definitions: definitions))
        case .link(let text, let url, let title, let attributes):
            return .link(text: text, url: url, title: title, attributes: attributes)
        case .image(let alt, let url, let title, let attributes):
            return .image(alt: resolveLinkReferences(in: alt, definitions: definitions), url: url, title: title, attributes: attributes)
        case .superscript(let content):
            return .superscript(resolveLinkReferences(in: content, definitions: definitions))
        case .subscript(let content):
            return .subscript(resolveLinkReferences(in: content, definitions: definitions))
        case .highlight(let content):
            return .highlight(resolveLinkReferences(in: content, definitions: definitions))
        case .span(let content, let attributes):
            return .span(content: resolveLinkReferences(in: content, definitions: definitions), attributes: attributes)
        case .inlineFootnote(let content):
            return .inlineFootnote(content: resolveLinkReferences(in: content, definitions: definitions))
        default:
            return inline
        }
    }

    func mergeAdjacentTextInlines(_ inlines: [Inline]) -> [Inline] {
        var merged: [Inline] = []

        for inline in inlines {
            if case .text(let text) = inline,
               case .text(let previous)? = merged.last {
                merged.removeLast()
                merged.append(.text(previous + text))
            } else {
                merged.append(inline)
            }
        }

        return merged
    }

    func resolveReferenceSyntax(
        in text: String,
        definitions: [String: LinkReferenceDefinition]
    ) -> [Inline] {
        var resolved: [Inline] = []
        var literalBuffer = ""
        var index = text.startIndex

        func flushLiteralBuffer() {
            guard !literalBuffer.isEmpty else { return }
            resolved.append(.text(literalBuffer))
            literalBuffer = ""
        }

        while index < text.endIndex {
            if text[index] == "\u{E000}" {
                let next = text.index(after: index)
                if next < text.endIndex {
                    literalBuffer.append(text[next])
                    index = text.index(after: next)
                } else {
                    index = next
                }
                continue
            }

            if let invalidReference = parseEscapedExplicitReferenceLiteral(in: text, at: index) {
                literalBuffer.append(invalidReference.literal)
                index = invalidReference.endIndex
                continue
            }

            if let image = parseReferenceImage(in: text, at: index, definitions: definitions) {
                flushLiteralBuffer()
                resolved.append(image.inline)
                index = image.endIndex
                continue
            }

            if let link = parseReferenceLink(in: text, at: index, definitions: definitions) {
                flushLiteralBuffer()
                resolved.append(contentsOf: link.inlines)
                index = link.endIndex
                continue
            }

            literalBuffer.append(text[index])
            index = text.index(after: index)
        }

        flushLiteralBuffer()
        return resolved
    }

    func parseEscapedExplicitReferenceLiteral(
        in text: String,
        at index: String.Index
    ) -> (literal: String, endIndex: String.Index)? {
        guard index < text.endIndex, text[index] == "[",
              let linkText = consumeReferenceBracketedContent(in: text, openingBracket: index),
              linkText.endIndex < text.endIndex,
              text[linkText.endIndex] == "[",
              let explicitLabel = consumeReferenceBracketedContent(in: text, openingBracket: linkText.endIndex),
              containsDisallowedExplicitReferenceLabelEscape(explicitLabel.rawContent)
        else {
            return nil
        }

        let rawLiteral = String(text[index..<explicitLabel.endIndex])
        return (unescapeCommonMarkBackslashEscapes(rawLiteral), explicitLabel.endIndex)
    }

    func parseReferenceLink(
        in text: String,
        at index: String.Index,
        definitions: [String: LinkReferenceDefinition]
    ) -> (inlines: [Inline], endIndex: String.Index)? {
        guard index < text.endIndex, text[index] == "[" else {
            return nil
        }
        guard let linkText = consumeReferenceBracketedContent(in: text, openingBracket: index) else {
            return nil
        }

        let reference = referenceDefinition(
            in: text,
            after: linkText.endIndex,
            fallbackLabel: linkText.rawContent,
            definitions: definitions
        )

        guard let reference else {
            return nil
        }

        let labelInlines = resolveLinkReferences(
            in: referenceTextInlines(linkText.rawContent),
            definitions: definitions
        )

        if containsLinkInline(labelInlines) {
            var suppressed: [Inline] = [.text("[")]
            suppressed.append(contentsOf: labelInlines)
            suppressed.append(.text("]"))
            return (suppressed, linkText.endIndex)
        }

        return (
            [.link(
                text: labelInlines,
                url: reference.definition.destination,
                title: reference.definition.title
            )],
            reference.endIndex
        )
    }

    func parseReferenceImage(
        in text: String,
        at index: String.Index,
        definitions: [String: LinkReferenceDefinition]
    ) -> (inline: Inline, endIndex: String.Index)? {
        guard index < text.endIndex, text[index] == "!" else {
            return nil
        }

        let bracketIndex = text.index(after: index)
        guard bracketIndex < text.endIndex, text[bracketIndex] == "[",
              let altText = consumeReferenceBracketedContent(in: text, openingBracket: bracketIndex)
        else {
            return nil
        }

        let reference = referenceDefinition(
            in: text,
            after: altText.endIndex,
            fallbackLabel: altText.rawContent,
            definitions: definitions
        )

        guard let reference else {
            return nil
        }

        return (
            .image(
                alt: referenceTextInlines(altText.rawContent),
                url: reference.definition.destination,
                title: reference.definition.title
            ),
            reference.endIndex
        )
    }

    func referenceDefinition(
        in text: String,
        after endOfFirstLabel: String.Index,
        fallbackLabel: String,
        definitions: [String: LinkReferenceDefinition]
    ) -> (definition: LinkReferenceDefinition, endIndex: String.Index)? {
        if endOfFirstLabel < text.endIndex, text[endOfFirstLabel] == "[" {
            if let explicitLabel = consumeReferenceBracketedContent(in: text, openingBracket: endOfFirstLabel) {
                let label = explicitLabel.rawContent.isEmpty ? fallbackLabel : explicitLabel.rawContent
                if !explicitLabel.rawContent.isEmpty,
                   containsDisallowedExplicitReferenceLabelEscape(label) {
                    return nil
                }
                let key = normalizedLinkReferenceLabel(label)
                if let definition = definitions[key] {
                    return (definition, explicitLabel.endIndex)
                }
                return nil
            }
        }

        let key = normalizedLinkReferenceLabel(fallbackLabel)
        guard let definition = definitions[key] else {
            return nil
        }
        return (definition, endOfFirstLabel)
    }

    func consumeReferenceBracketedContent(
        in text: String,
        openingBracket: String.Index
    ) -> (rawContent: String, endIndex: String.Index)? {
        guard openingBracket < text.endIndex, text[openingBracket] == "[" else {
            return nil
        }

        var index = text.index(after: openingBracket)
        var depth = 0
        var rawContent = ""

        while index < text.endIndex {
            let character = text[index]
            if character == "\\" {
                let next = text.index(after: index)
                guard next < text.endIndex else {
                    return nil
                }
                rawContent.append(character)
                rawContent.append(text[next])
                index = text.index(after: next)
                continue
            }

            if character == "[" {
                depth += 1
                rawContent.append(character)
                index = text.index(after: index)
                continue
            }

            if character == "]" {
                if depth == 0 {
                    return (rawContent, text.index(after: index))
                }
                depth -= 1
                rawContent.append(character)
                index = text.index(after: index)
                continue
            }

            rawContent.append(character)
            index = text.index(after: index)
        }

        return nil
    }

    func containsDisallowedExplicitReferenceLabelEscape(_ rawLabel: String) -> Bool {
        var index = rawLabel.startIndex

        while index < rawLabel.endIndex {
            guard rawLabel[index] == "\\" else {
                index = rawLabel.index(after: index)
                continue
            }

            let next = rawLabel.index(after: index)
            guard next < rawLabel.endIndex else {
                return true
            }

            if rawLabel[next] != "[" {
                return true
            }

            index = rawLabel.index(after: next)
        }

        return false
    }

    func referenceTextInlines(_ rawText: String) -> [Inline] {
        let unescaped = unescapeCommonMarkBackslashEscapes(rawText)
        let decoded = decodeCommonMarkCharacterReferences(unescaped)
        var state = RhoeParserState(tokens: lexer.tokenize(decoded), source: decoded)
        return parseInlines(&state, until: { $0.type == .eof })
    }
}

private extension CharacterSet {
    static let horizontalWhitespace = CharacterSet(charactersIn: " \t")
}

private extension Character {
    var isHorizontalWhitespace: Bool {
        self == " " || self == "\t"
    }
}
