# RhoeMarkdownPresentation

Slide presentation engine for the Rhoe language.

## Architecture

### Core (Slide Parsing)
- `Slides/` — SlideParser, SlideChunker, SlideBodyConverter, SlideMetadataNormalizer
- `Slides/Internal/` — PresentationFrontmatterMetadataParser, PresentationAttributeParser

### Layout
- `Grid/` — GridLayoutEngine
- `Grids/` — GridShape, GridShapeRenderer
- `Shapes/` — ShapeRenderer, ShapeLayoutEngine, ShapeStyler, StickerShape, ShapeIntegration, ShapeRendererExtensions
- `Gradients/` — MeshGradient, MeshGradientParser, MeshGradientRenderer

### Output Formats
- `PPTX/` — PPTXWriter, PPTXSlideGenerator, PPTXMarkdownConverter, PPTXDesignSystem, PPTXDesignParser, PPTXStructure, PPTXMasterGenerator, PPTXXMLGenerator
- `Rendering/` — ShapeHTMLRenderer (HTML slide output)

### Infrastructure
- `Parallel/` — ParallelParser, ParallelHTMLRenderer, ASTMerger, ChunkSplitter
- `Extensions/` — SlideContentSizer, SlideContentSplitter, SlideOverflowConfiguration
- `Icons/` — IconManager, IconSystemManager
- `Emoji/` — EmojiManager
- `PresentationCompatibility.swift` — Top-level compatibility shims

## Dependencies
- RhoeMarkdownModel (AST types)
- RhoeMarkdownParsing (parser)
- RhoeMarkdownRendering (HTML renderer for slide content)
- RhoeLoggingKit (structured logging)
