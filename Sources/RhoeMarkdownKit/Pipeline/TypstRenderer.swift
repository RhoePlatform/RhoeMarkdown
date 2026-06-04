import Foundation
import RhoeMarkdownRendering

public struct TypstRenderer: Sendable {
    public let configuration: RhoeMarkdownKit.TypstConfiguration

    public init(configuration: RhoeMarkdownKit.TypstConfiguration = .default) {
        self.configuration = configuration
    }

    public func render(_ document: RhoeMarkdownKit.Document) -> String {
        TypstWriter(configuration: configuration).write(document)
    }
}
