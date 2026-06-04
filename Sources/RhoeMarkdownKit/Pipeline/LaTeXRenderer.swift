import Foundation
import RhoeMarkdownRendering

public struct LaTeXRenderer: Sendable {
    public let configuration: RhoeMarkdownKit.LaTeXConfiguration

    public init(configuration: RhoeMarkdownKit.LaTeXConfiguration = .default) {
        self.configuration = configuration
    }

    public func render(_ document: RhoeMarkdownKit.Document) -> String {
        LaTeXWriter(configuration: configuration).write(document)
    }
}
