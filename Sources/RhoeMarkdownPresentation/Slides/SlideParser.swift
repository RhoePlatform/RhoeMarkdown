import Foundation
import RhoeMarkdownModel
import RhoeLoggingKit

/// Slide parser with presenter mode and advanced features.
public actor SlideParser {
    private let logger = RhoeLogger.shared
    private let logCategory = LogCategory(name: "SlideParser", subsystem: "RhoeMarkdownKit")
    private let frontmatterParser = PresentationFrontmatterMetadataParser()
    private let chunker = SlideChunker()
    private let metadataNormalizer = SlideMetadataNormalizer()
    private let bodyLowering = SlideBodyConverter()

    public init() {}

    public enum SlideTransition: String, Sendable, CaseIterable {
        case none = "none"
        case fade = "fade"
        case slide = "slide"
        case zoom = "zoom"
        case flip = "flip"
        case cube = "cube"
        case morph = "morph"
        case dissolve = "dissolve"
        case parallax = "parallax"
    }

    public enum SlideLayout: String, Sendable, CaseIterable {
        case title = "title"
        case titleAndContent = "title-content"
        case twoColumn = "two-column"
        case threeColumn = "three-column"
        case comparison = "comparison"
        case imageLeft = "image-left"
        case imageRight = "image-right"
        case fullImage = "full-image"
        case grid = "grid"
        case timeline = "timeline"
        case dashboard = "dashboard"
    }

    public struct SlideMetadata: Sendable {
        public let id: String
        public let title: String?
        public let subtitle: String?
        public let layout: SlideLayout
        public let transition: SlideTransition
        public let duration: TimeInterval?
        public let autoAdvance: Bool
        public let background: SlideBackground?
        public let speakerNotes: String?
        public let animations: [SlideAnimation]
        public let metadata: [String: String]

        public init(
            id: String = UUID().uuidString,
            title: String? = nil,
            subtitle: String? = nil,
            layout: SlideLayout = .titleAndContent,
            transition: SlideTransition = .fade,
            duration: TimeInterval? = nil,
            autoAdvance: Bool = false,
            background: SlideBackground? = nil,
            speakerNotes: String? = nil,
            animations: [SlideAnimation] = [],
            metadata: [String: String] = [:]
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.layout = layout
            self.transition = transition
            self.duration = duration
            self.autoAdvance = autoAdvance
            self.background = background
            self.speakerNotes = speakerNotes
            self.animations = animations
            self.metadata = metadata
        }
    }

    public struct SlideBackground: Sendable {
        public enum BackgroundType: Sendable {
            case color(String)
            case gradient(colors: [String], angle: Double)
            case image(url: String, opacity: Double)
            case video(url: String, loop: Bool)
            case pattern(name: String, scale: Double)
            case mesh(points: [[Double]], colors: [String])
        }

        public let type: BackgroundType
        public let blur: Double?
        public let overlay: String?

        public init(type: BackgroundType, blur: Double? = nil, overlay: String? = nil) {
            self.type = type
            self.blur = blur
            self.overlay = overlay
        }
    }

    public struct SlideAnimation: Sendable {
        public enum AnimationType: String, Sendable {
            case fadeIn = "fade-in"
            case slideIn = "slide-in"
            case zoomIn = "zoom-in"
            case bounceIn = "bounce-in"
            case flipIn = "flip-in"
            case typewriter = "typewriter"
            case pulse = "pulse"
        }

        public let target: String
        public let type: AnimationType
        public let delay: TimeInterval
        public let duration: TimeInterval
        public let easing: String

        public init(
            target: String,
            type: AnimationType,
            delay: TimeInterval = 0,
            duration: TimeInterval = 0.5,
            easing: String = "ease-in-out"
        ) {
            self.target = target
            self.type = type
            self.delay = delay
            self.duration = duration
            self.easing = easing
        }
    }

    public func parse(_ markdown: String) async throws -> ParsedPresentation {
        logger.info("Starting enhanced slide parsing", category: logCategory)
        let startTime = Date().timeIntervalSinceReferenceDate
        let slideChunks = chunker.split(markdown)

        var slides: [ParsedSlide] = []
        slides.reserveCapacity(slideChunks.count)

        for (index, chunk) in slideChunks.enumerated() {
            let metadata = metadataNormalizer.parse(chunk.header)
            let blocks = bodyLowering.blocks(from: chunk.body)

            slides.append(ParsedSlide(
                index: index,
                metadata: SlideMetadata(
                    title: metadata.title,
                    subtitle: metadata.subtitle,
                    layout: metadata.layout,
                    transition: metadata.transition,
                    duration: metadata.duration,
                    autoAdvance: metadata.autoAdvance,
                    background: metadata.background,
                    speakerNotes: chunk.notes,
                    animations: metadata.animations,
                    metadata: metadata.customMetadata
                ),
                blocks: blocks,
                rawContent: chunk.raw
            ))
        }

        let presentation = ParsedPresentation(
            slides: slides,
            metadata: frontmatterParser.metadata(from: markdown),
            parseTime: Date().timeIntervalSinceReferenceDate - startTime
        )

        logger.info(
            "Parsing completed in \(presentation.parseTime * 1000)ms for \(presentation.slides.count) slides",
            category: logCategory
        )
        return presentation
    }
}

public struct ParsedSlide: Sendable {
    public let index: Int
    public let metadata: SlideParser.SlideMetadata
    public let blocks: [SlideBlock]
    public let rawContent: String

    public init(
        index: Int,
        metadata: SlideParser.SlideMetadata,
        blocks: [SlideBlock],
        rawContent: String
    ) {
        self.index = index
        self.metadata = metadata
        self.blocks = blocks
        self.rawContent = rawContent
    }
}

public struct SlideBlock: Sendable {
    public enum BlockType: Sendable {
        case title
        case subtitle
        case content
        case image
        case code
        case table
        case chart
        case grid
        case shape
    }

    public let type: BlockType
    public let content: String
    public let attributes: [String: String]

    public init(type: BlockType, content: String, attributes: [String: String] = [:]) {
        self.type = type
        self.content = content
        self.attributes = attributes
    }
}

public struct ParsedPresentation: Sendable {
    public let slides: [ParsedSlide]
    public let metadata: PresentationMetadata
    public let parseTime: TimeInterval

    public init(
        slides: [ParsedSlide],
        metadata: PresentationMetadata,
        parseTime: TimeInterval
    ) {
        self.slides = slides
        self.metadata = metadata
        self.parseTime = parseTime
    }
}
