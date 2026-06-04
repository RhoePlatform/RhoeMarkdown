//
//  ShapeHTMLRenderer.swift
//  RhoeMarkdownKit
//
//  HTML renderer for shape system demo
//

import Foundation
import RhoeMarkdownModel

/// HTML renderer for presentations with shapes
public struct ShapeHTMLRenderer {
    
    private let presentation: Presentation
    private let options: RenderOptions
    
    public struct RenderOptions {
        public let slideWidth: Int
        public let slideHeight: Int
        public let includeNavigation: Bool
        public let includeStyles: Bool
        
        public init(
            slideWidth: Int = 1024,
            slideHeight: Int = 768,
            includeNavigation: Bool = true,
            includeStyles: Bool = true
        ) {
            self.slideWidth = slideWidth
            self.slideHeight = slideHeight
            self.includeNavigation = includeNavigation
            self.includeStyles = includeStyles
        }
    }
    
    public init(presentation: Presentation, options: RenderOptions = RenderOptions()) {
        self.presentation = presentation
        self.options = options
    }
    
    /// Render presentation to HTML
    public func render() -> String {
        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(presentation.title ?? "Presentation")</title>
        """
        
        if options.includeStyles {
            html += "\n" + generateStyles()
        }
        
        html += """
        </head>
        <body>
            <div class="presentation">
        """
        
        // Render each slide
        for (index, slide) in presentation.slides.enumerated() {
            html += renderSlide(slide, index: index)
        }
        
        html += """
            </div>
        """
        
        if options.includeNavigation {
            html += generateNavigation()
        }
        
        html += generateScript()
        
        html += """
        </body>
        </html>
        """
        
        return html
    }
    
    private func renderSlide(_ slide: Slide, index: Int) -> String {
        let slideClass = "slide \(slideTypeClass(slide.type))"
        let slideId = slide.attributes?.id ?? "slide-\(index)"
        
        var html = """
        
                <div class="\(slideClass)" id="\(slideId)" data-index="\(index)">
        """
        
        // Add custom classes from attributes
        if let classes = slide.attributes?.classes {
            html = html.replacingOccurrences(
                of: "class=\"\(slideClass)\"",
                with: "class=\"\(slideClass) \(classes.joined(separator: " "))\""
            )
        }
        
        // Handle different slide types
        if slide.type == .regular && slide.gridSpec != nil {
            html += renderGridSlide(slide)
        } else {
            html += renderSpecialSlide(slide)
        }
        
        html += """
                </div>
        """
        
        return html
    }
    
    private func renderGridSlide(_ slide: Slide) -> String {
        guard let gridSpec = slide.gridSpec else { return "" }
        
        var html = """
                    <div class="grid" style="grid-template-columns: repeat(\(gridSpec.columns), 1fr); grid-template-rows: repeat(\(gridSpec.rows), 1fr);">
        """
        
        // Process grid elements
        for content in slide.content {
            if case .grid(let element) = content {
                html += renderGridElement(element, gridSpec: gridSpec)
            }
        }
        
        html += """
                    </div>
        """
        
        // Add slots
        html += renderSlots(slide)
        
        return html
    }
    
    private func renderGridElement(_ element: GridElement, gridSpec: GridSpec) -> String {
        let gridArea = calculateGridArea(element.reference)
        let alignmentClass = alignmentToClass(element.alignment)
        
        var html = """
                        <div class="grid-cell \(alignmentClass)" style="grid-area: \(gridArea);">
        """
        
        switch element.content {
        case .shape(let shapeContent):
            html += renderShape(shapeContent)
            
        case .blocks(let blocks):
            for block in blocks {
                html += renderBlock(block)
            }
            
        case .inline(let inline):
            html += "<p>\(renderInlineContent(inline))</p>"
        }

        html += """
                        </div>
        """
        
        return html
    }
    
    private func renderShape(_ shapeContent: ShapeContent) -> String {
        let cellBounds = CellBounds(
            width: Double(options.slideWidth) / 4,  // Approximate
            height: Double(options.slideHeight) / 4
        )
        
        let renderable = ShapeIntegration.processShape(shapeContent, in: cellBounds)
        
        return """
                            <div class="shape shape-\(shapeContent.shape.rawValue.lowercased())">
                                \(renderable.svg)
                            </div>
        """
    }
    
    private func renderSpecialSlide(_ slide: Slide) -> String {
        var html = ""
        
        // Title elements
        if let titleElements = slide.titleElements {
            if let supertitle = titleElements.supertitle {
                html += """
                    <h3 class="supertitle">\(escapeHTML(supertitle))</h3>
        """
            }
            
            if let title = titleElements.title {
                html += """
                    <h1 class="title">\(escapeHTML(title))</h1>
        """
            }
            
            if let subtitle = titleElements.subtitle {
                html += """
                    <h2 class="subtitle">\(escapeHTML(subtitle))</h2>
        """
            }
        }
        
        // Add slots
        html += renderSlots(slide)
        
        return html
    }
    
    private func renderSlots(_ slide: Slide) -> String {
        var html = ""
        
        for content in slide.content {
            if case .slot(let slot) = content {
                let positionClass = "slot slot-\(slot.position.rawValue.lowercased())"
                html += """
                    <div class="\(positionClass)">
        """
                
                for block in slot.content {
                    html += renderBlock(block)
                }
                
                html += """
                    </div>
        """
            }
        }
        
        return html
    }
    
    private func renderBlock(_ block: Block) -> String {
        switch block {
        case .heading(let level, let content, _):
            return "<h\(level)>\(renderInlines(content))</h\(level)>"
            
        case .paragraph(let content, _):
            return "<p>\(renderInlines(content))</p>"
            
        case .list(let type, let items, _):
            let tag = type == .unordered ? "ul" : "ol"
            var html = "<\(tag)>"
            for item in items {
                html += "<li>"
                for block in item.content {
                    html += renderBlock(block)
                }
                html += "</li>"
            }
            html += "</\(tag)>"
            return html
            
        default:
            return ""
        }
    }
    
    private func renderInlines(_ inlines: [Inline]) -> String {
        return inlines.map { inline in
            switch inline {
            case .text(let str):
                return escapeHTML(str)
            case .strong(let content):
                return "<strong>\(renderInlines(content))</strong>"
            case .emphasis(let content):
                return "<em>\(renderInlines(content))</em>"
            case .codeSpan(let str, _):
                return "<code>\(escapeHTML(str))</code>"
            case .image(let alt, let url, _, _):
                return "<img src=\"\(url)\" alt=\"\(renderInlines(alt))\">"
            default:
                return ""
            }
        }.joined()
    }
    
    private func renderInlineContent(_ inline: InlineContent) -> String {
        return inline.items.map { item in
            renderInlines(item.content)
        }.joined(separator: " | ")
    }
    
    private func generateStyles() -> String {
        return """
            <style>
                * { box-sizing: border-box; margin: 0; padding: 0; }
                
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background: #1a1a1a;
                    color: #333;
                    overflow: hidden;
                }
                
                .presentation {
                    width: 100vw;
                    height: 100vh;
                    display: flex;
                    scroll-snap-type: x mandatory;
                    overflow-x: auto;
                }
                
                .slide {
                    min-width: 100vw;
                    height: 100vh;
                    scroll-snap-align: start;
                    background: white;
                    display: flex;
                    flex-direction: column;
                    justify-content: center;
                    align-items: center;
                    padding: 60px;
                    position: relative;
                }
                
                .slide.title-slide {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    text-align: center;
                }
                
                .slide.section-slide {
                    background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
                    color: white;
                    text-align: center;
                }
                
                .slide.separator-slide {
                    background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
                    color: white;
                    text-align: center;
                }
                
                .supertitle {
                    font-size: 24px;
                    font-weight: 300;
                    letter-spacing: 0.1em;
                    text-transform: uppercase;
                    margin-bottom: 20px;
                    opacity: 0.8;
                }
                
                .title {
                    font-size: 72px;
                    font-weight: 700;
                    margin-bottom: 30px;
                    line-height: 1.1;
                }
                
                .subtitle {
                    font-size: 36px;
                    font-weight: 400;
                    opacity: 0.9;
                }
                
                .grid {
                    display: grid;
                    gap: 20px;
                    width: 100%;
                    height: 100%;
                    max-width: \(options.slideWidth)px;
                    max-height: \(options.slideHeight - 120)px;
                }
                
                .grid-cell {
                    display: flex;
                    padding: 20px;
                    overflow: hidden;
                }
                
                .grid-cell.align-c { justify-content: center; align-items: center; }
                .grid-cell.align-tl { justify-content: flex-start; align-items: flex-start; }
                .grid-cell.align-tr { justify-content: flex-end; align-items: flex-start; }
                .grid-cell.align-bl { justify-content: flex-start; align-items: flex-end; }
                .grid-cell.align-br { justify-content: flex-end; align-items: flex-end; }
                
                .shape {
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    width: 100%;
                    height: 100%;
                }
                
                .shape svg {
                    max-width: 100%;
                    max-height: 100%;
                    width: auto;
                    height: auto;
                }
                
                /* Slot positioning */
                .slot {
                    position: absolute;
                    padding: 20px;
                }
                
                .slot-tl, .slot-htl, .slot-ftl { top: 20px; left: 20px; }
                .slot-t, .slot-ht, .slot-ft { top: 20px; left: 50%; transform: translateX(-50%); }
                .slot-tr, .slot-htr, .slot-ftr { top: 20px; right: 20px; }
                .slot-l, .slot-hl, .slot-fl { left: 20px; top: 50%; transform: translateY(-50%); }
                .slot-c, .slot-hc, .slot-fc { left: 50%; top: 50%; transform: translate(-50%, -50%); }
                .slot-r, .slot-hr, .slot-fr { right: 20px; top: 50%; transform: translateY(-50%); }
                .slot-bl, .slot-hbl, .slot-fbl { bottom: 20px; left: 20px; }
                .slot-b, .slot-hb, .slot-fb { bottom: 20px; left: 50%; transform: translateX(-50%); }
                .slot-br, .slot-hbr, .slot-fbr { bottom: 20px; right: 20px; }
                
                /* Navigation */
                .navigation {
                    position: fixed;
                    bottom: 30px;
                    left: 50%;
                    transform: translateX(-50%);
                    display: flex;
                    gap: 20px;
                    background: rgba(0,0,0,0.8);
                    padding: 15px 30px;
                    border-radius: 50px;
                    z-index: 1000;
                }
                
                .navigation button {
                    background: none;
                    border: none;
                    color: white;
                    font-size: 18px;
                    cursor: pointer;
                    padding: 5px 15px;
                    border-radius: 20px;
                    transition: background 0.3s;
                }
                
                .navigation button:hover {
                    background: rgba(255,255,255,0.2);
                }
                
                .slide-counter {
                    color: white;
                    display: flex;
                    align-items: center;
                    font-size: 14px;
                }
                
                /* Animations */
                .slide {
                    animation: slideIn 0.5s ease-out;
                }
                
                @keyframes slideIn {
                    from { opacity: 0; transform: translateX(50px); }
                    to { opacity: 1; transform: translateX(0); }
                }
            </style>
        """
    }
    
    private func generateNavigation() -> String {
        return """
            <div class="navigation">
                <button onclick="previousSlide()">←</button>
                <span class="slide-counter">
                    <span id="current-slide">1</span> / <span id="total-slides">\(presentation.slides.count)</span>
                </span>
                <button onclick="nextSlide()">→</button>
            </div>
        """
    }
    
    private func generateScript() -> String {
        return """
            <script>
                let currentSlide = 0;
                const slides = document.querySelectorAll('.slide');
                const totalSlides = slides.length;
                
                function showSlide(index) {
                    if (index < 0) index = 0;
                    if (index >= totalSlides) index = totalSlides - 1;
                    
                    currentSlide = index;
                    slides[index].scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'start' });
                    
                    document.getElementById('current-slide').textContent = index + 1;
                }
                
                function nextSlide() {
                    showSlide(currentSlide + 1);
                }
                
                function previousSlide() {
                    showSlide(currentSlide - 1);
                }
                
                // Keyboard navigation
                document.addEventListener('keydown', (e) => {
                    if (e.key === 'ArrowRight' || e.key === ' ') nextSlide();
                    if (e.key === 'ArrowLeft') previousSlide();
                    if (e.key === 'Home') showSlide(0);
                    if (e.key === 'End') showSlide(totalSlides - 1);
                });
                
                // Update slide counter on scroll
                const presentation = document.querySelector('.presentation');
                presentation.addEventListener('scroll', () => {
                    const slideWidth = presentation.offsetWidth;
                    const scrollLeft = presentation.scrollLeft;
                    const index = Math.round(scrollLeft / slideWidth);
                    if (index !== currentSlide) {
                        currentSlide = index;
                        document.getElementById('current-slide').textContent = index + 1;
                    }
                });
                
                // Initialize
                document.getElementById('total-slides').textContent = totalSlides;
            </script>
        """
    }
    
    // Helper methods
    private func slideTypeClass(_ type: SlideType) -> String {
        switch type {
        case .regular: return ""
        case .title: return "title-slide"
        case .section: return "section-slide"
        case .separator: return "separator-slide"
        }
    }
    
    private func calculateGridArea(_ reference: CellReference) -> String {
        switch reference {
        case .single(let col, let row):
            return "\(row) / \(col) / \(row + 1) / \(col + 1)"
        case .range(let startColumn, let startRow, let endColumn, let endRow):
            return "\(startRow) / \(startColumn) / \(endRow + 1) / \(endColumn + 1)"
        }
    }
    
    private func alignmentToClass(_ alignment: CellAlignment?) -> String {
        guard let alignment = alignment else { return "" }
        return "align-\(alignment.rawValue.lowercased())"
    }
    
    private func escapeHTML(_ str: String) -> String {
        return str
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
