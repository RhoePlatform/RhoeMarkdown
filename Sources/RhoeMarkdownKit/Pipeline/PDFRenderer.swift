import Foundation
import RhoeMarkdownRendering

public struct PDFRenderer: Sendable {
    public let configuration: RhoeMarkdownKit.PDFConfiguration

    public init(configuration: RhoeMarkdownKit.PDFConfiguration = .default) {
        self.configuration = configuration
    }

    public func render(_ document: RhoeMarkdownKit.Document) -> Data {
        PDFWriter(configuration: configuration).write(document)
    }
}
