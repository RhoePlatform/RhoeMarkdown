import Foundation

extension RhoeMarkdownKit.Attributes {
    public var style: String? {
        keyValues["style"]
    }

    public func resolvedStyles() -> [String: String] {
        var styles: [String: String] = [:]

        if let inlineStyle = style {
            for declaration in inlineStyle.split(separator: ";") {
                let parts = declaration.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { continue }
                let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty, !value.isEmpty else { continue }
                styles[key] = value
            }
        }

        for (key, value) in keyValues where key != "style" {
            styles[key] = value
        }

        return styles
    }
}
