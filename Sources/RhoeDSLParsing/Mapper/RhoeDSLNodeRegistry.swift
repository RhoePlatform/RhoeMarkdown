import Foundation

/// Registry of known DSL node types and their body type expectations.
public enum DSLNodeRegistry {

    /// What kind of body a DSL node accepts.
    public enum BodyType {
        case structural   // Body contains child NodeDeclarations
        case leafProse    // Body contains inline Markdown text
        case rawText      // Body contains literal text (no Markdown parsing)
        case noBody       // Node has no body (params only)
    }

    /// Look up the expected body type for a DSL node name.
    public static func bodyType(for nodeName: String) -> BodyType {
        switch nodeName.lowercased() {
        // Structural nodes (accept child nodes)
        case "document", "section":
            return .structural
        case "list":
            return .structural
        case "quote", "blockquote":
            return .structural
        case "admonition", "note", "tip", "warning", "danger", "info", "success",
             "important", "caution", "abstract", "todo", "example", "question", "bug", "failure":
            return .structural
        case "theorem", "lemma", "corollary", "proposition", "definition", "proof", "remark",
             "claim", "assumption", "conjecture":
            return .structural
        case "speakernotes":
            return .structural
        case "table", "tablehead", "tablebody", "tablefoot", "tablerow":
            return .structural
        case "figure":
            return .structural
        case "deck", "slide":
            return .structural
        case "form":
            return .structural
        case "grid", "columns":
            return .structural
        case "div":
            return .structural
        case "extension":
            return .structural
        case "lineblock":
            return .structural

        // Leaf-prose nodes (accept inline Markdown text)
        case "paragraph", "p":
            return .leafProse
        case "h1", "h2", "h3", "h4", "h5", "h6":
            return .leafProse
        case "listitem":
            return .leafProse
        case "quoteline":
            return .leafProse
        case "caption":
            return .leafProse
        case "tablecell", "cell":
            return .leafProse
        case "line":
            return .leafProse
        case "markdown":
            return .leafProse

        // Raw text nodes (literal text, no Markdown parsing)
        case "code", "executablecode":
            return .rawText
        case "text":
            return .rawText
        case "diagram":
            return .rawText

        // No-body nodes (params only)
        case "image", "img":
            return .noBody
        case "field":
            return .noBody
        case "shape":
            return .noBody
        case "horizontalrule", "hr", "thematicbreak":
            return .noBody
        case "abbreviationdefinition":
            return .noBody

        default:
            // Unknown nodes default to structural
            return .structural
        }
    }

    /// Check if a name is a known admonition type.
    public static func isAdmonitionType(_ name: String) -> Bool {
        let admonitionTypes: Set<String> = [
            "note", "tip", "warning", "danger", "info", "success",
            "important", "caution", "abstract", "todo", "example",
            "question", "bug", "failure"
        ]
        return admonitionTypes.contains(name.lowercased())
    }

    /// Check if a name is a theorem-family alias.
    public static func isTheoremType(_ name: String) -> Bool {
        let theoremTypes: Set<String> = [
            "theorem", "lemma", "corollary", "proposition", "definition",
            "example", "proof", "remark", "claim", "assumption", "conjecture"
        ]
        return theoremTypes.contains(name.lowercased())
    }

    /// Heading level for H1-H6 nodes, or nil if not a heading.
    public static func headingLevel(_ name: String) -> Int? {
        switch name.lowercased() {
        case "h1": return 1
        case "h2": return 2
        case "h3": return 3
        case "h4": return 4
        case "h5": return 5
        case "h6": return 6
        default: return nil
        }
    }
}
