import Foundation

package struct SlideHeaderMetadata: Sendable {
    package let title: String?
    package let subtitle: String?
    package let layout: SlideParser.SlideLayout
    package let transition: SlideParser.SlideTransition
    package let duration: TimeInterval?
    package let autoAdvance: Bool
    package let background: SlideParser.SlideBackground?
    package let animations: [SlideParser.SlideAnimation]
    package let customMetadata: [String: String]
}

package struct SlideMetadataNormalizer: Sendable {
    private let attributeParser: PresentationAttributeParser

    package init() {
        self.attributeParser = PresentationAttributeParser()
    }

    package func parse(_ line: String) -> SlideHeaderMetadata {
        let parts = attributeParser.splitHeaderAndAttributes(headerContent(from: line))
        let attributes = attributeParser.parse(parts.attributes)
        let titleComponents = parts.header.split(separator: "|", maxSplits: 1)

        let title: String? = titleComponents.first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap(\.nilIfEmpty)

        let subtitle: String? = if titleComponents.count > 1 {
            String(titleComponents[1])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
        } else {
            nil
        }

        let layout = SlideParser.SlideLayout(rawValue: attributes["layout"] ?? "") ?? .titleAndContent
        let transition = SlideParser.SlideTransition(rawValue: attributes["transition"] ?? "") ?? .fade
        let duration = attributes["duration"].flatMap(TimeInterval.init)
        let autoAdvance = (attributes["auto"] ?? "").lowercased() == "true"
        let overlay = attributes["overlay"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        let background = parseBackground(
            attributes["background"] ?? attributes["bg"],
            overlay: overlay
        )
        let animations = parseAnimations(attributes["animate"])

        var customMetadata = attributes
        for reservedKey in reservedKeys {
            customMetadata.removeValue(forKey: reservedKey)
        }

        return SlideHeaderMetadata(
            title: title,
            subtitle: subtitle,
            layout: layout,
            transition: transition,
            duration: duration,
            autoAdvance: autoAdvance,
            background: background,
            animations: animations,
            customMetadata: customMetadata
        )
    }

    private var reservedKeys: [String] {
        ["layout", "transition", "duration", "auto", "background", "bg", "overlay", "animate"]
    }

    private func headerContent(from line: String) -> String {
        if line.hasPrefix("%%%") {
            return String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if line.hasPrefix("%%") {
            return String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseBackground(
        _ rawValue: String?,
        overlay: String?
    ) -> SlideParser.SlideBackground? {
        guard let rawValue else { return nil }
        return parseCanonicalBackground(rawValue, overlay: overlay)
    }

    private func parseCanonicalBackground(
        _ rawValue: String,
        overlay: String?
    ) -> SlideParser.SlideBackground {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("gradient("), trimmed.hasSuffix(")") {
            let inner = String(trimmed.dropFirst("gradient(".count).dropLast())
            let parts = splitCommaSeparated(inner)
            let angle = parts.last.flatMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            let colors = angle == nil ? parts : Array(parts.dropLast())

            return SlideParser.SlideBackground(
                type: .gradient(
                    colors: colors.map { $0.trimmingCharacters(in: .whitespaces) },
                    angle: angle ?? 0
                ),
                overlay: overlay
            )
        }

        if trimmed.hasPrefix("image("), trimmed.hasSuffix(")") {
            let inner = String(trimmed.dropFirst("image(".count).dropLast())
            let parts = splitCommaSeparated(inner)
            let url = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let opacity = parts.dropFirst().first.flatMap {
                Double($0.trimmingCharacters(in: .whitespacesAndNewlines))
            } ?? 1.0

            return SlideParser.SlideBackground(
                type: .image(url: url, opacity: opacity),
                overlay: overlay
            )
        }

        if trimmed.hasPrefix("mesh("), trimmed.hasSuffix(")") {
            return SlideParser.SlideBackground(
                type: .mesh(points: [], colors: []),
                overlay: overlay
            )
        }

        return SlideParser.SlideBackground(type: .color(trimmed), overlay: overlay)
    }

    private func parseAnimations(_ rawValue: String?) -> [SlideParser.SlideAnimation] {
        guard let rawValue, !rawValue.isEmpty else { return [] }
        return splitCommaSeparated(rawValue).compactMap(parseCanonicalAnimation)
    }

    private func parseCanonicalAnimation(_ definition: String) -> SlideParser.SlideAnimation? {
        let parts = definition.split(separator: ":").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard parts.count >= 2 else { return nil }

        let type = SlideParser.SlideAnimation.AnimationType(rawValue: parts[1]) ?? .fadeIn
        let delay = parts.count > 2 ? TimeInterval(parts[2]) ?? 0 : 0
        let duration = parts.count > 3 ? TimeInterval(parts[3]) ?? 0.5 : 0.5

        return SlideParser.SlideAnimation(
            target: parts[0],
            type: type,
            delay: delay,
            duration: duration
        )
    }

    private func splitCommaSeparated(_ value: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var parenDepth = 0

        for character in value {
            if character == "(" {
                parenDepth += 1
            } else if character == ")" {
                parenDepth = max(0, parenDepth - 1)
            }

            if character == ",", parenDepth == 0 {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }

        if !current.isEmpty {
            parts.append(current)
        }

        return parts
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
