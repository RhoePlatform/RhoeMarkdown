import Foundation

// MARK: - Attributes

extension RhoeMarkdownKit {

    /// Pandoc-style attributes that can be attached to blocks and inline elements
    public struct Attributes: Sendable, Equatable {
        /// Element ID (e.g., {#my-id})
        public let id: String?

        /// CSS classes (e.g., {.class1 .class2})
        public let classes: [String]

        /// Key-value pairs (e.g., {width=100 style="color: red"})
        public let keyValues: [String: String]

        public init(id: String? = nil, classes: [String] = [], keyValues: [String: String] = [:]) {
            self.id = id
            self.classes = classes
            self.keyValues = keyValues
        }

        /// Check if attributes are empty
        public var isEmpty: Bool {
            id == nil && classes.isEmpty && keyValues.isEmpty
        }

        // MARK: - Categorized Attribute Access

        /// Semantic attribute keys recognized by the structured attribute system.
        private static let semanticKeys: Set<String> = [
            "role", "alt", "longdesc", "summary", "label", "decorative",
            "scope", "kind", "reading-order", "short", "nav"
        ]

        /// Projection attribute keys
        private static let projectionKeys: Set<String> = [
            "visible", "hidden", "projection", "assistive-only"
        ]

        /// Interaction attribute keys
        private static let interactionKeys: Set<String> = [
            "required", "placeholder", "min", "max", "step",
            "collapsed", "open", "action", "method", "target"
        ]

        /// Presentational attribute keys
        private static let presentationalKeys: Set<String> = [
            "color", "bg", "width", "height", "align",
            "transition", "layout", "weight", "opacity", "rotation", "radius", "border"
        ]

        /// Writer-hint attribute key prefixes
        private static let writerHintPrefixes: [String] = [
            "html-", "typst-", "latex-", "swiftui-", "pdf-"
        ]

        /// Semantic attributes extracted from keyValues
        public var semantic: [String: String] {
            keyValues.filter { Self.semanticKeys.contains($0.key) }
        }

        /// Projection attributes extracted from keyValues
        public var projection: [String: String] {
            keyValues.filter { Self.projectionKeys.contains($0.key) }
        }

        /// Interaction attributes extracted from keyValues
        public var interaction: [String: String] {
            keyValues.filter { Self.interactionKeys.contains($0.key) }
        }

        /// Presentational attributes extracted from keyValues
        public var presentational: [String: String] {
            keyValues.filter { Self.presentationalKeys.contains($0.key) }
        }

        /// Writer-hint attributes extracted from keyValues
        public var writerHints: [String: String] {
            keyValues.filter { kv in Self.writerHintPrefixes.contains(where: { kv.key.hasPrefix($0) }) }
        }

        /// Uncategorized attributes (not matching any known category)
        public var uncategorized: [String: String] {
            let allKnown = Self.semanticKeys
                .union(Self.projectionKeys)
                .union(Self.interactionKeys)
                .union(Self.presentationalKeys)
            return keyValues.filter { kv in
                !allKnown.contains(kv.key) &&
                !Self.writerHintPrefixes.contains(where: { kv.key.hasPrefix($0) })
            }
        }

        /// Render just the id attribute as HTML (used when class is rendered separately)
        public func idAttribute() -> String {
            guard let id = id else { return "" }
            return " id=\"\(escapeHTML(id))\""
        }

        /// Render attributes as HTML attribute string
        public func toHTMLAttributes() -> String {
            var parts: [String] = []

            if let id = id {
                parts.append("id=\"\(escapeHTML(id))\"")
            }

            if !classes.isEmpty {
                let classStr = classes.map { escapeHTML($0) }.joined(separator: " ")
                parts.append("class=\"\(classStr)\"")
            }

            for (key, value) in keyValues.sorted(by: { $0.key < $1.key }) {
                let escapedKey = escapeHTML(key)
                let escapedValue = escapeHTML(value)
                parts.append("\(escapedKey)=\"\(escapedValue)\"")
            }

            return parts.isEmpty ? "" : " " + parts.joined(separator: " ")
        }

        private func escapeHTML(_ string: String) -> String {
            string
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "'", with: "&#39;")
        }

        // MARK: - Structured Six-Bucket Model

        /// Returns the structured six-bucket representation of these attributes,
        /// matching the canonical RhoeJSON attribute model (Ring 0, ch.05).
        public func bucketized() -> BucketizedAttributes {
            var identityBucket = IdentityBucket(id: id, classes: classes)
            identityBucket.name = keyValues["name"]
            identityBucket.key = keyValues["key"]
            identityBucket.ref = keyValues["ref"]

            var presentationalBucket: [String: String] = [:]
            for key in Self.presentationalKeys where keyValues[key] != nil {
                presentationalBucket[key] = keyValues[key]
            }

            var semanticBucket: [String: String] = [:]
            for key in Self.semanticKeys where keyValues[key] != nil {
                semanticBucket[key] = keyValues[key]
            }

            var interactionBucket: [String: String] = [:]
            for key in Self.interactionKeys where keyValues[key] != nil {
                interactionBucket[key] = keyValues[key]
            }

            // Parse projection bucket (visible/hidden are comma-separated domain lists)
            let visible = keyValues["visible"]?.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) } ?? []
            let hidden = keyValues["hidden"]?.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) } ?? []
            let assistiveOnly = keyValues["assistive-only"] == "true"
            let projectionBucket = ProjectionBucket(visible: visible, hidden: hidden, assistiveOnly: assistiveOnly)

            // Parse writer hints (html-tag=aside -> html: {tag: aside})
            var writerHintsBucket: [String: [String: String]] = [:]
            for (key, value) in keyValues {
                for prefix in Self.writerHintPrefixes {
                    if key.hasPrefix(prefix) {
                        let namespace = String(prefix.dropLast()) // "html-" -> "html"
                        let hintKey = String(key.dropFirst(prefix.count))
                        writerHintsBucket[namespace, default: [:]][hintKey] = value
                    }
                }
            }

            return BucketizedAttributes(
                identity: identityBucket,
                presentational: presentationalBucket,
                semantic: semanticBucket,
                interaction: interactionBucket,
                projection: projectionBucket,
                writerHints: writerHintsBucket
            )
        }

        /// Structured six-bucket attribute representation matching the canonical
        /// RhoeJSON attribute model (Ring 0, ch.05 / ch.02a).
        public struct BucketizedAttributes: Sendable, Equatable {
            public var identity: IdentityBucket
            public var presentational: [String: String]
            public var semantic: [String: String]
            public var interaction: [String: String]
            public var projection: ProjectionBucket
            public var writerHints: [String: [String: String]]

            public var isEmpty: Bool {
                identity.isEmpty && presentational.isEmpty && semantic.isEmpty &&
                interaction.isEmpty && projection.isEmpty && writerHints.isEmpty
            }
        }

        /// Identity bucket: stable identity and classification.
        public struct IdentityBucket: Sendable, Equatable {
            public var id: String?
            public var classes: [String]
            public var name: String?
            public var key: String?
            public var ref: String?

            public init(id: String? = nil, classes: [String] = [], name: String? = nil, key: String? = nil, ref: String? = nil) {
                self.id = id
                self.classes = classes
                self.name = name
                self.key = key
                self.ref = ref
            }

            public var isEmpty: Bool {
                id == nil && classes.isEmpty && name == nil && key == nil && ref == nil
            }
        }

        /// Projection bucket: domain visibility and inclusion semantics.
        public struct ProjectionBucket: Sendable, Equatable {
            public var visible: [String]
            public var hidden: [String]
            public var assistiveOnly: Bool

            public init(visible: [String] = [], hidden: [String] = [], assistiveOnly: Bool = false) {
                self.visible = visible
                self.hidden = hidden
                self.assistiveOnly = assistiveOnly
            }

            public var isEmpty: Bool {
                visible.isEmpty && hidden.isEmpty && !assistiveOnly
            }
        }
    }
}
