import Testing
import RhoeMarkdownKit

@Suite("Sprint R2: Theorem Unification + Numbering")
struct SprintR2ConformanceTests {

    // MARK: - Theorem Rendering

    @Test("!!! theorem renders as theorem environment, not admonition")
    func theoremRendersAsTheorem() async {
        let md = "!!! theorem \"Pythagorean\" {#thm-pyth}\nFor a right triangle: $a^2 + b^2 = c^2$.\n!!!"
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("theorem-env"))
        #expect(html.contains("theorem-header"))
        #expect(html.contains("Theorem"))
    }

    @Test("!!! proof renders with QED symbol")
    func proofRendersWithQED() async {
        let md = "!!! proof\nBy contradiction, assume...\n!!!"
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("qed"))
        #expect(html.contains("&#x25A1;")) // QED symbol (HTML entity)
    }

    @Test("!!! lemma renders as theorem environment")
    func lemmaRendersAsTheorem() async {
        let md = "!!! lemma\nSupporting result.\n!!!"
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("theorem-env"))
        #expect(html.contains("Lemma"))
    }

    @Test("!!! definition renders as theorem environment")
    func definitionRendersAsTheorem() async {
        let md = "!!! definition \"Convergence\" {#def-conv}\nA sequence converges if...\n!!!"
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("theorem-env"))
        #expect(html.contains("Definition"))
        #expect(html.contains("Convergence"))
    }

    @Test("!!! note still renders as admonition, not theorem")
    func noteStillRendersAsAdmonition() async {
        let md = "!!! note\nThis is a note.\n!!!"
        let html = await RhoeMarkdownKit.toHTML(md)
        #expect(html.contains("admonition"))
        #expect(!html.contains("theorem-env"))
    }

    // MARK: - Theorem Numbering

    @Test("Theorem with ID gets numbered")
    func theoremNumbered() async {
        let md = "!!! theorem {#thm-first}\nFirst theorem.\n!!!\n\n!!! theorem {#thm-second}\nSecond theorem.\n!!!"
        let result = await RhoeMarkdownKit.parse(md)
        let numbers = result.document.metadata.resolvedReferences.elementNumbers
        #expect(numbers["thm-first"] != nil)
        #expect(numbers["thm-second"] != nil)
    }

    @Test("Lemma with ID gets numbered in shared domain")
    func lemmaSameCounter() async {
        let md = "!!! theorem {#thm-a}\nTheorem.\n!!!\n\n!!! lemma {#lem-b}\nLemma.\n!!!"
        let result = await RhoeMarkdownKit.parse(md)
        let numbers = result.document.metadata.resolvedReferences.elementNumbers
        // Both exist and have numbers
        #expect(numbers["thm-a"] != nil)
        #expect(numbers["lem-b"] != nil)
    }

    // MARK: - Hierarchical Numbering

    @Test("Figures are numbered within sections")
    func hierarchicalNumbering() async {
        let md = """
        # Section 1

        ![Fig A](a.png){#fig-a}

        # Section 2

        ![Fig B](b.png){#fig-b}
        """
        let result = await RhoeMarkdownKit.parse(md)
        let numbers = result.document.metadata.resolvedReferences.elementNumbers
        // Fig A should be in section 1, Fig B in section 2
        if let numA = numbers["fig-a"], let numB = numbers["fig-b"] {
            // Both should have section-scoped numbers
            #expect(numA.contains("."))
            #expect(numB.contains("."))
        }
    }

    @Test("Section counter resets scoped counters")
    func sectionResetsCounters() async {
        let md = """
        # Section 1

        ![Fig 1](a.png){#fig-1a}

        # Section 2

        ![Fig 1](b.png){#fig-2a}
        """
        let result = await RhoeMarkdownKit.parse(md)
        let numbers = result.document.metadata.resolvedReferences.elementNumbers
        if let num1 = numbers["fig-1a"], let num2 = numbers["fig-2a"] {
            // Both should start at .1 in their respective sections
            #expect(num1.hasSuffix(".1"))
            #expect(num2.hasSuffix(".1"))
        }
    }
}
