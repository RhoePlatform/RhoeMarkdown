import Testing
import RhoeMarkdownKit
import RhoeMarkdownRendering

@Suite("Sprint 9: Diagram Engine Integration")
struct Sprint9ConformanceTests {

    // MARK: - 9.1 DiagramConfiguration

    @Test("DiagramConfiguration defaults are correct")
    func configurationDefaults() {
        let config = RhoeMarkdownKit.DiagramConfiguration.default
        #expect(config.enableDiagramRendering == true)
        #expect(config.mermaidClientSide == true)
        #expect(config.additionalSearchPaths.isEmpty)
    }

    @Test("DiagramConfiguration disabled preset")
    func configurationDisabled() {
        let config = RhoeMarkdownKit.DiagramConfiguration.disabled
        #expect(config.enableDiagramRendering == false)
    }

    // MARK: - 9.2 ToolDiscovery

    @Test("ToolDiscovery returns nil for nonexistent tool")
    func toolDiscoveryNonexistent() {
        let path = ToolDiscovery.findTool(named: "nonexistent_tool_xyz_12345")
        #expect(path == nil)
    }

    @Test("ToolDiscovery finds common system tools")
    func toolDiscoveryFindsSystem() {
        // /usr/bin/which should always be available on macOS/Linux
        let path = ToolDiscovery.findTool(named: "which")
        #expect(path != nil)
    }

    @Test("ToolDiscovery checks additional paths")
    func toolDiscoveryAdditionalPaths() {
        // Non-existent additional path should not crash
        let path = ToolDiscovery.findTool(
            named: "dot",
            additionalPaths: ["/nonexistent/path"]
        )
        // dot likely not installed, but should not crash
        _ = path
    }

    // MARK: - 9.3 DiagramEngine Language Matching

    @Test("DiagramEngine recognizes Mermaid language")
    func engineRecognizesMermaid() {
        let engine = DiagramEngine()
        #expect(engine.isDiagramLanguage("mermaid"))
        #expect(engine.isDiagramLanguage("Mermaid"))
    }

    @Test("DiagramEngine recognizes Graphviz languages")
    func engineRecognizesGraphviz() {
        let engine = DiagramEngine()
        #expect(engine.isDiagramLanguage("dot"))
        #expect(engine.isDiagramLanguage("graphviz"))
        #expect(engine.isDiagramLanguage("neato"))
        #expect(engine.isDiagramLanguage("circo"))
    }

    @Test("DiagramEngine recognizes PlantUML language")
    func engineRecognizesPlantUML() {
        let engine = DiagramEngine()
        #expect(engine.isDiagramLanguage("plantuml"))
    }

    @Test("DiagramEngine recognizes D2 language")
    func engineRecognizesD2() {
        let engine = DiagramEngine()
        #expect(engine.isDiagramLanguage("d2"))
    }

    @Test("DiagramEngine rejects non-diagram languages")
    func engineRejectsNonDiagram() {
        let engine = DiagramEngine()
        #expect(!engine.isDiagramLanguage("python"))
        #expect(!engine.isDiagramLanguage("javascript"))
        #expect(!engine.isDiagramLanguage("swift"))
    }

    @Test("DiagramEngine finds correct renderer for language")
    func engineRendererDispatch() {
        let engine = DiagramEngine()
        let mermaidRenderer = engine.renderer(for: "mermaid")
        #expect(mermaidRenderer != nil)
        #expect(mermaidRenderer?.supportedLanguages.contains("mermaid") == true)

        let dotRenderer = engine.renderer(for: "dot")
        #expect(dotRenderer != nil)
        #expect(dotRenderer?.supportedLanguages.contains("dot") == true)

        let d2Renderer = engine.renderer(for: "d2")
        #expect(d2Renderer != nil)
        #expect(d2Renderer?.supportedLanguages.contains("d2") == true)

        let noRenderer = engine.renderer(for: "python")
        #expect(noRenderer == nil)
    }

    // MARK: - 9.4 DiagramCache

    @Test("DiagramCache stores and retrieves results")
    func cacheRoundTrip() {
        let cache = DiagramCache()
        let result = DiagramResult(svg: "<svg>test</svg>", warnings: [])

        #expect(cache.lookup(language: "dot", source: "digraph {}") == nil)

        cache.store(language: "dot", source: "digraph {}", result: result)
        let retrieved = cache.lookup(language: "dot", source: "digraph {}")
        #expect(retrieved == result)
        #expect(cache.count == 1)
    }

    @Test("DiagramCache differentiates by language")
    func cacheDifferentiatesByLanguage() {
        let cache = DiagramCache()
        let result1 = DiagramResult(svg: "<svg>dot</svg>")
        let result2 = DiagramResult(svg: "<svg>d2</svg>")

        cache.store(language: "dot", source: "same", result: result1)
        cache.store(language: "d2", source: "same", result: result2)

        #expect(cache.lookup(language: "dot", source: "same")?.svg == "<svg>dot</svg>")
        #expect(cache.lookup(language: "d2", source: "same")?.svg == "<svg>d2</svg>")
    }

    @Test("DiagramCache clear removes all entries")
    func cacheClear() {
        let cache = DiagramCache()
        cache.store(language: "dot", source: "a", result: DiagramResult(svg: "x"))
        cache.store(language: "d2", source: "b", result: DiagramResult(svg: "y"))
        #expect(cache.count == 2)

        cache.clear()
        #expect(cache.count == 0)
        #expect(cache.lookup(language: "dot", source: "a") == nil)
    }

    // MARK: - 9.5 Fallback Behavior

    @Test("Diagram code blocks pass through when rendering disabled")
    func diagramFallbackDisabled() async {
        let md = """
        ```mermaid
        graph TD
            A --> B
        ```
        """
        // Parse without diagram config — rendering is disabled by default
        let result = await RhoeMarkdownKit.parse(md)
        let html = RhoeMarkdownKit.renderHTML(result.document)
        // Should render as client-side Mermaid (existing behavior)
        #expect(html.contains("<pre class=\"mermaid\">"))
    }

    @Test("Diagram code blocks pass through when tool unavailable")
    func diagramFallbackToolUnavailable() async {
        let md = """
        ```dot
        digraph { A -> B }
        ```
        """
        let config = RhoeMarkdownKit.DiagramConfiguration(
            enableDiagramRendering: true,
            mermaidClientSide: false
        )
        let result = await RhoeMarkdownKit.parse(
            md,
            configuration: .default,
            diagramConfiguration: config
        )
        let html = RhoeMarkdownKit.renderHTML(result.document)
        // Graphviz not installed — should fall back to code block
        if !GraphvizDiagramRenderer().isAvailable() {
            #expect(html.contains("<code"))
            #expect(html.contains("digraph"))
        }
    }

    @Test("Unknown diagram language kept as code block")
    func unknownDiagramLanguage() async {
        let md = """
        ```python
        print("hello")
        ```
        """
        let config = RhoeMarkdownKit.DiagramConfiguration(enableDiagramRendering: true)
        let result = await RhoeMarkdownKit.parse(
            md,
            configuration: .default,
            diagramConfiguration: config
        )
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("<code class=\"language-python\""))
    }

    @Test("Mermaid kept as client-side when mermaidClientSide is true")
    func mermaidClientSideFallback() async {
        let md = """
        ```mermaid
        graph TD
            A --> B
        ```
        """
        let config = RhoeMarkdownKit.DiagramConfiguration(
            enableDiagramRendering: true,
            mermaidClientSide: true
        )
        let result = await RhoeMarkdownKit.parse(
            md,
            configuration: .default,
            diagramConfiguration: config
        )
        let html = RhoeMarkdownKit.renderHTML(result.document)
        // Even with diagram rendering enabled, Mermaid should stay client-side
        #expect(html.contains("<pre class=\"mermaid\">"))
    }

    // MARK: - 9.6 Renderer Availability

    @Test("Renderers report availability correctly")
    func rendererAvailability() {
        // These tests verify the availability check runs without crashing
        let mermaid = MermaidDiagramRenderer()
        let graphviz = GraphvizDiagramRenderer()
        let plantuml = PlantUMLDiagramRenderer()
        let d2 = D2DiagramRenderer()

        // Just verify they return a bool without crashing
        _ = mermaid.isAvailable()
        _ = graphviz.isAvailable()
        _ = plantuml.isAvailable()
        _ = d2.isAvailable()
    }

    @Test("Renderers return nil when tool not available")
    func rendererReturnsNilWhenUnavailable() {
        // If Graphviz is not installed, render should return nil
        let graphviz = GraphvizDiagramRenderer()
        if !graphviz.isAvailable() {
            let result = graphviz.render(source: "digraph { A -> B }")
            #expect(result == nil)
        }
    }

    // MARK: - 9.7 Conditional Tool Tests (only run when tool is installed)

    @Test("Graphviz renders DOT to SVG when available")
    func graphvizRenderingSVG() throws {
        let graphviz = GraphvizDiagramRenderer()
        guard graphviz.isAvailable() else { return }

        let source = "digraph { A -> B -> C }"
        let result = graphviz.render(source: source)
        #expect(result != nil)
        #expect(result?.svg.contains("<svg") == true)
        #expect(result?.svg.contains("</svg>") == true)
    }

    @Test("D2 renders to SVG when available")
    func d2RenderingSVG() throws {
        let d2 = D2DiagramRenderer()
        guard d2.isAvailable() else { return }

        let source = "x -> y -> z"
        let result = d2.render(source: source)
        #expect(result != nil)
        #expect(result?.svg.contains("<svg") == true)
    }

    @Test("DiagramRenderingPass wraps SVG in figure when tool available")
    func diagramPassWrapsSVG() async throws {
        let graphviz = GraphvizDiagramRenderer()
        guard graphviz.isAvailable() else { return }

        let md = """
        ```dot
        digraph { A -> B }
        ```
        """
        let config = RhoeMarkdownKit.DiagramConfiguration(
            enableDiagramRendering: true,
            mermaidClientSide: true
        )
        let result = await RhoeMarkdownKit.parse(
            md,
            configuration: .default,
            diagramConfiguration: config
        )
        let html = RhoeMarkdownKit.renderHTML(result.document)
        #expect(html.contains("<figure class=\"diagram dot\">"))
        #expect(html.contains("<svg"))
    }
}
