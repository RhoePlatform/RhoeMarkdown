import Foundation
import RhoeMarkdownRendering

public struct DOCXRenderer: Sendable {
    public let configuration: RhoeMarkdownKit.DOCXConfiguration

    public init(configuration: RhoeMarkdownKit.DOCXConfiguration = .default) {
        self.configuration = configuration
    }

    public func render(_ document: RhoeMarkdownKit.Document) -> Data {
        DOCXWriter(configuration: configuration).write(document)
    }
}
