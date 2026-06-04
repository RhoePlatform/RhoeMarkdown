import RhoeMarkdownModel

public typealias ShapeSize = ShapeRenderer.ShapeSize

public protocol SlideRenderer {
    func render(block: Block) -> String
}
