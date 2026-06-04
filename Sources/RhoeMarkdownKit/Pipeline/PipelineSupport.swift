import Foundation
import RhoeMarkdownModel
import RhoeMarkdownParsing
import RhoeMarkdownPresentation

public typealias SlideLayout = SlideParser.SlideLayout
public typealias SlideTransition = SlideParser.SlideTransition
public typealias SlideBackground = SlideParser.SlideBackground
public typealias SlideAnimation = SlideParser.SlideAnimation

public struct PresentationSlideDescriptor: Sendable {
    public let index: Int
    public let id: UUID
    public let type: SlideType
    public let supertitle: String?
    public let title: String?
    public let subtitle: String?
    public let layout: SlideLayout
    public let transition: SlideTransition
    public let duration: TimeInterval?
    public let autoAdvance: Bool
    public let background: SlideBackground?
    public let speakerNotes: String?
    public let animations: [SlideAnimation]
    public let customMetadata: [String: String]

    public init(
        index: Int,
        id: UUID,
        type: SlideType,
        supertitle: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        layout: SlideLayout = .titleAndContent,
        transition: SlideTransition = .fade,
        duration: TimeInterval? = nil,
        autoAdvance: Bool = false,
        background: SlideBackground? = nil,
        speakerNotes: String? = nil,
        animations: [SlideAnimation] = [],
        customMetadata: [String: String] = [:]
    ) {
        self.index = index
        self.id = id
        self.type = type
        self.supertitle = supertitle
        self.title = title
        self.subtitle = subtitle
        self.layout = layout
        self.transition = transition
        self.duration = duration
        self.autoAdvance = autoAdvance
        self.background = background
        self.speakerNotes = speakerNotes
        self.animations = animations
        self.customMetadata = customMetadata
    }
}

public struct PresentationParseResult: Sendable {
    public let presentation: Presentation
    public let slideDescriptors: [PresentationSlideDescriptor]
    public let diagnostics: [RhoeMarkdownKit.Diagnostic]
    public let parseTime: TimeInterval

    public init(
        presentation: Presentation,
        slideDescriptors: [PresentationSlideDescriptor],
        diagnostics: [RhoeMarkdownKit.Diagnostic] = [],
        parseTime: TimeInterval = 0
    ) {
        self.presentation = presentation
        self.slideDescriptors = slideDescriptors
        self.diagnostics = diagnostics
        self.parseTime = parseTime
    }
}

enum PipelineDiagnostics {
    static func normalizeCore(
        _ diagnostics: [RhoeMarkdownKit.Diagnostic],
        source: String
    ) -> [RhoeMarkdownKit.Diagnostic] {
        let map = SourceLineMap(source: source)
        return diagnostics.map { diagnostic in
            let range = diagnostic.sourceRange ?? map.collapsedRange(line: diagnostic.line, column: diagnostic.column)
            return RhoeMarkdownKit.Diagnostic(
                severity: diagnostic.severity,
                message: diagnostic.message,
                line: diagnostic.line,
                column: diagnostic.column,
                sourceRange: range
            )
        }
    }

}
