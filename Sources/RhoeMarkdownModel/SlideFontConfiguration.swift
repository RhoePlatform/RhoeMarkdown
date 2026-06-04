import Foundation

public struct FontSizeRange: Sendable, Equatable {
    public let min: Double
    public let max: Double

    public init(min: Double, max: Double) {
        self.min = min
        self.max = max
    }
}

public struct SlideFontConfiguration: Sendable, Equatable {
    public enum ElementType: Sendable, Equatable {
        case title
        case subtitle
        case heading(Int)
        case body
        case list
        case code
        case table
        case caption
        case unknown
    }

    public let title: FontSizeRange
    public let subtitle: FontSizeRange
    public let heading: FontSizeRange
    public let body: FontSizeRange
    public let list: FontSizeRange
    public let code: FontSizeRange
    public let table: FontSizeRange
    public let caption: FontSizeRange
    public let `default`: FontSizeRange

    public init(
        title: FontSizeRange = .init(min: 28, max: 44),
        subtitle: FontSizeRange = .init(min: 20, max: 30),
        heading: FontSizeRange = .init(min: 18, max: 28),
        body: FontSizeRange = .init(min: 12, max: 18),
        list: FontSizeRange = .init(min: 12, max: 18),
        code: FontSizeRange = .init(min: 11, max: 16),
        table: FontSizeRange = .init(min: 10, max: 14),
        caption: FontSizeRange = .init(min: 10, max: 12),
        default defaultRange: FontSizeRange = .init(min: 12, max: 18)
    ) {
        self.title = title
        self.subtitle = subtitle
        self.heading = heading
        self.body = body
        self.list = list
        self.code = code
        self.table = table
        self.caption = caption
        self.default = defaultRange
    }

    public func range(for elementType: ElementType) -> FontSizeRange {
        switch elementType {
        case .title:
            return title
        case .subtitle:
            return subtitle
        case .heading:
            return heading
        case .body:
            return body
        case .list:
            return list
        case .code:
            return code
        case .table:
            return table
        case .caption:
            return caption
        case .unknown:
            return `default`
        }
    }

    public static func parse(from frontmatter: [String: Any]) -> SlideFontConfiguration? {
        guard !frontmatter.isEmpty else {
            return nil
        }

        func range(prefix: String, fallback: FontSizeRange) -> FontSizeRange {
            let minKey = "\(prefix)Min"
            let maxKey = "\(prefix)Max"

            let minimum = (frontmatter[minKey] as? NSNumber)?.doubleValue ?? fallback.min
            let maximum = (frontmatter[maxKey] as? NSNumber)?.doubleValue ?? fallback.max
            return FontSizeRange(min: minimum, max: maximum)
        }

        let configuration = SlideFontConfiguration()
        return SlideFontConfiguration(
            title: range(prefix: "title", fallback: configuration.title),
            subtitle: range(prefix: "subtitle", fallback: configuration.subtitle),
            heading: range(prefix: "heading", fallback: configuration.heading),
            body: range(prefix: "body", fallback: configuration.body),
            list: range(prefix: "list", fallback: configuration.list),
            code: range(prefix: "code", fallback: configuration.code),
            table: range(prefix: "table", fallback: configuration.table),
            caption: range(prefix: "caption", fallback: configuration.caption),
            default: range(prefix: "default", fallback: configuration.default)
        )
    }
}
