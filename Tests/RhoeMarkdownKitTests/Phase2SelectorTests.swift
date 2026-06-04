import Testing
import Foundation
import RhoeMarkdownKit

@Suite("Phase 2: Selector Engine")
struct Phase2SelectorTests {

    // MARK: - family= Atom

    @Test("family=theorem matches admonition with type theorem")
    func familyMatchesAdmonitionType() {
        let block = Block.admonition(
            type: "theorem", title: "Pythagorean",
            content: [.paragraph([.text("a^2 + b^2 = c^2")])],
            collapsible: nil, attributes: .init(id: "thm-1")
        )
        let selector = Phase2Selector(from: ["family": "theorem"])
        #expect(selector.matches(block))
    }

    @Test("family=heading matches heading blocks")
    func familyMatchesHeading() {
        let block = Block.heading(level: 2, content: [.text("Introduction")], attributes: .init(id: "sec-intro"))
        let selector = Phase2Selector(from: ["family": "heading"])
        #expect(selector.matches(block))
    }

    @Test("family=section is an alias for heading")
    func familySectionAliasForHeading() {
        let block = Block.heading(level: 3, content: [.text("Methods")], attributes: .init())
        let selector = Phase2Selector(from: ["family": "section"])
        #expect(selector.matches(block))
    }

    @Test("family=table matches table blocks")
    func familyMatchesTable() {
        let block = Block.table(
            headers: [TableCell(content: [.text("Col A")])],
            rows: [[TableCell(content: [.text("1")])]],
            caption: nil, attributes: .init(id: "tbl-1")
        )
        let selector = Phase2Selector(from: ["family": "table"])
        #expect(selector.matches(block))
    }

    @Test("family=code matches codeBlock")
    func familyMatchesCode() {
        let block = Block.codeBlock(language: "python", content: "print(42)", attributes: .init())
        let selector = Phase2Selector(from: ["family": "code"])
        #expect(selector.matches(block))
    }

    @Test("family=paragraph matches paragraph blocks")
    func familyMatchesParagraph() {
        let block = Block.paragraph([.text("Some text")], attributes: .init())
        let selector = Phase2Selector(from: ["family": "paragraph"])
        #expect(selector.matches(block))
    }

    @Test("family=list matches list blocks")
    func familyMatchesList() {
        let block = Block.list(
            type: .unordered,
            items: [ListItem(content: [.paragraph([.text("Item")])])],
            attributes: .init()
        )
        let selector = Phase2Selector(from: ["family": "list"])
        #expect(selector.matches(block))
    }

    @Test("family=visual matches visualBlock")
    func familyMatchesVisual() {
        let block = Block.visualBlock(
            name: "timeline",
            content: [.paragraph([.text("Event 1")])],
            attributes: .init()
        )
        let selector = Phase2Selector(from: ["family": "visual"])
        #expect(selector.matches(block))
    }

    @Test("family=theorem does not match a heading")
    func familyDoesNotMatchWrongType() {
        let block = Block.heading(level: 1, content: [.text("Title")], attributes: .init())
        let selector = Phase2Selector(from: ["family": "theorem"])
        #expect(!selector.matches(block))
    }

    // MARK: - role= Atom

    @Test("role= matches keyValues role attribute")
    func roleMatchesKeyValue() {
        let block = Block.paragraph(
            [.text("Important note")],
            attributes: .init(keyValues: ["role": "warning"])
        )
        let selector = Phase2Selector(from: ["role": "warning"])
        #expect(selector.matches(block))
    }

    @Test("role= does not match when role differs")
    func roleDoesNotMatchDifferentRole() {
        let block = Block.paragraph(
            [.text("Some text")],
            attributes: .init(keyValues: ["role": "info"])
        )
        let selector = Phase2Selector(from: ["role": "warning"])
        #expect(!selector.matches(block))
    }

    // MARK: - id= Atom

    @Test("id= matches block by exact ID")
    func idMatchesExact() {
        let block = Block.heading(level: 2, content: [.text("Ch 1")], attributes: .init(id: "chapter-1"))
        let selector = Phase2Selector(from: ["id": "chapter-1"])
        #expect(selector.matches(block))
    }

    @Test("id= strips leading # prefix")
    func idStripsHashPrefix() {
        let block = Block.heading(level: 2, content: [.text("Ch 1")], attributes: .init(id: "chapter-1"))
        let selector = Phase2Selector(from: ["id": "#chapter-1"])
        #expect(selector.matches(block))
    }

    // MARK: - class= Atom

    @Test("class= matches block with that class")
    func classMatchesMembership() {
        let block = Block.div(
            content: [.paragraph([.text("Highlighted")])],
            attributes: .init(classes: ["key-result", "important"])
        )
        let selector = Phase2Selector(from: ["class": "key-result"])
        #expect(selector.matches(block))
    }

    @Test("class= strips leading . prefix")
    func classStripsDotPrefix() {
        let block = Block.div(
            content: [.paragraph([.text("Content")])],
            attributes: .init(classes: ["highlight"])
        )
        let selector = Phase2Selector(from: ["class": ".highlight"])
        #expect(selector.matches(block))
    }

    @Test("class= does not match when class absent")
    func classDoesNotMatchAbsent() {
        let block = Block.div(
            content: [.paragraph([.text("Content")])],
            attributes: .init(classes: ["other"])
        )
        let selector = Phase2Selector(from: ["class": "highlight"])
        #expect(!selector.matches(block))
    }

    // MARK: - in= Atom (Container Scope)

    @Test("in= matches when containerId equals specified ID")
    func inContainerMatches() {
        let block = Block.paragraph([.text("Inside")], attributes: .init())
        let selector = Phase2Selector(from: ["in": "#chapter-2"])
        #expect(selector.matches(block, containerId: "chapter-2"))
    }

    @Test("in= does not match with different containerId")
    func inContainerDoesNotMatch() {
        let block = Block.paragraph([.text("Inside")], attributes: .init())
        let selector = Phase2Selector(from: ["in": "chapter-2"])
        #expect(!selector.matches(block, containerId: "chapter-3"))
    }

    // MARK: - ancestor= Atom

    @Test("ancestor= matches when ancestor is in ancestry chain")
    func ancestorMatchesInChain() {
        let block = Block.paragraph([.text("Deep content")], attributes: .init(id: "p-1"))
        let selector = Phase2Selector(from: ["ancestor": "#part-1"])
        #expect(selector.matches(block, ancestorIds: ["section-2", "part-1"]))
    }

    @Test("ancestor= does not match when ancestor is absent")
    func ancestorDoesNotMatch() {
        let block = Block.paragraph([.text("Content")], attributes: .init())
        let selector = Phase2Selector(from: ["ancestor": "part-1"])
        #expect(!selector.matches(block, ancestorIds: ["section-2", "chapter-1"]))
    }

    @Test("ancestor= uses Phase2ScopeTracker for real ancestry")
    func ancestorWithScopeTracker() {
        let blocks: [Block] = [
            .div(content: [
                .admonition(
                    type: "theorem", title: "Main Thm",
                    content: [.paragraph([.text("Proof sketch")], attributes: .init(id: "inner-p"))],
                    collapsible: nil, attributes: .init(id: "thm-1")
                )
            ], attributes: .init(id: "chapter-1"))
        ]
        let tracker = Phase2ScopeTracker(blocks: blocks)
        let ancestors = tracker.ancestors(of: "inner-p")
        #expect(ancestors.contains("thm-1"))
        #expect(ancestors.contains("chapter-1"))
    }

    // MARK: - kind= Atom

    @Test("kind= matches keyValues kind attribute")
    func kindMatches() {
        let block = Block.admonition(
            type: "theorem", title: "Analytic Continuation",
            content: [.paragraph([.text("Proof")])],
            collapsible: nil,
            attributes: .init(keyValues: ["kind": "analytic"])
        )
        let selector = Phase2Selector(from: ["kind": "analytic"])
        #expect(selector.matches(block))
    }

    // MARK: - visible= Atom

    @Test("visible= matches when domain is in visible attribute")
    func visibleMatches() {
        let block = Block.paragraph(
            [.text("Screen content")],
            attributes: .init(keyValues: ["visible": "screen,print"])
        )
        let selector = Phase2Selector(from: ["visible": "screen"])
        #expect(selector.matches(block))
    }

    @Test("visible= does not match when domain is absent")
    func visibleDoesNotMatch() {
        let block = Block.paragraph(
            [.text("Print only")],
            attributes: .init(keyValues: ["visible": "print"])
        )
        let selector = Phase2Selector(from: ["visible": "screen"])
        #expect(!selector.matches(block))
    }

    // MARK: - has= Atom

    @Test("has=title matches admonition with title")
    func hasTitleMatchesAdmonition() {
        let block = Block.admonition(
            type: "note", title: "Important",
            content: [.paragraph([.text("Content")])],
            collapsible: nil, attributes: .init()
        )
        let selector = Phase2Selector(from: ["has": "title"])
        #expect(selector.matches(block))
    }

    @Test("has=id matches block with an ID")
    func hasIdMatchesBlock() {
        let block = Block.paragraph([.text("Text")], attributes: .init(id: "p-1"))
        let selector = Phase2Selector(from: ["has": "id"])
        #expect(selector.matches(block))
    }

    @Test("has= matches generic key in keyValues")
    func hasGenericKey() {
        let block = Block.paragraph(
            [.text("Annotated")],
            attributes: .init(keyValues: ["data-source": "api"])
        )
        let selector = Phase2Selector(from: ["has": "data-source"])
        #expect(selector.matches(block))
    }

    @Test("has=title does not match block without title")
    func hasTitleDoesNotMatch() {
        let block = Block.paragraph([.text("Plain")], attributes: .init())
        let selector = Phase2Selector(from: ["has": "title"])
        #expect(!selector.matches(block))
    }

    // MARK: - numbered= Atom

    @Test("numbered=true matches theorem admonition")
    func numberedTrueMatchesTheorem() {
        let block = Block.admonition(
            type: "theorem", title: "FLT",
            content: [.paragraph([.text("No solutions")])],
            collapsible: nil, attributes: .init()
        )
        let selector = Phase2Selector(from: ["numbered": "true"])
        #expect(selector.matches(block))
    }

    @Test("numbered=true matches heading")
    func numberedTrueMatchesHeading() {
        let block = Block.heading(level: 2, content: [.text("Section 1")], attributes: .init())
        let selector = Phase2Selector(from: ["numbered": "true"])
        #expect(selector.matches(block))
    }

    @Test("numbered=false matches paragraph (not numbered)")
    func numberedFalseMatchesParagraph() {
        let block = Block.paragraph([.text("Text")], attributes: .init())
        let selector = Phase2Selector(from: ["numbered": "false"])
        #expect(selector.matches(block))
    }

    // MARK: - title= Atom

    @Test("title= matches admonition by title substring")
    func titleMatchesSubstring() {
        let block = Block.admonition(
            type: "example", title: "Worked Example 3",
            content: [.paragraph([.text("Solution")])],
            collapsible: nil, attributes: .init()
        )
        let selector = Phase2Selector(from: ["title": "Worked Example"])
        #expect(selector.matches(block))
    }

    @Test("title= is case-insensitive")
    func titleCaseInsensitive() {
        let block = Block.admonition(
            type: "note", title: "Important Note",
            content: [.paragraph([.text("Content")])],
            collapsible: nil, attributes: .init()
        )
        let selector = Phase2Selector(from: ["title": "important"])
        #expect(selector.matches(block))
    }

    @Test("title= strips surrounding quotes")
    func titleStripsQuotes() {
        let block = Block.admonition(
            type: "theorem", title: "Introduction",
            content: [.paragraph([.text("Content")])],
            collapsible: nil, attributes: .init()
        )
        let selector = Phase2Selector(from: ["title": "\"Introduction\""])
        #expect(selector.matches(block))
    }

    // MARK: - Conjunction (Multiple Atoms)

    @Test("Multiple atoms must ALL match (conjunction)")
    func conjunctionAllMustMatch() {
        let block = Block.admonition(
            type: "theorem", title: "Main Result",
            content: [.paragraph([.text("Proof")])],
            collapsible: nil,
            attributes: .init(id: "thm-main", classes: ["key-result"], keyValues: ["role": "primary"])
        )
        let selector = Phase2Selector(from: [
            "family": "theorem",
            "role": "primary",
            "class": "key-result"
        ])
        #expect(selector.matches(block))
    }

    @Test("Conjunction fails if any atom does not match")
    func conjunctionFailsOnMismatch() {
        let block = Block.admonition(
            type: "theorem", title: "Minor Result",
            content: [.paragraph([.text("Proof")])],
            collapsible: nil,
            attributes: .init(id: "thm-minor", keyValues: ["role": "secondary"])
        )
        let selector = Phase2Selector(from: [
            "family": "theorem",
            "role": "primary"
        ])
        #expect(!selector.matches(block))
    }

    // MARK: - Empty Selector

    @Test("Empty selector matches nothing")
    func emptySelectorMatchesNothing() {
        let block = Block.paragraph([.text("Any content")], attributes: .init(id: "p-1"))
        let selector = Phase2Selector(from: [:])
        #expect(!selector.matches(block))
    }

    // MARK: - Phase2ScopeTracker

    @Test("ScopeTracker builds correct ancestor chain for nested blocks")
    func scopeTrackerNestedAncestors() {
        let blocks: [Block] = [
            .div(content: [
                .div(content: [
                    .paragraph([.text("Leaf")], attributes: .init(id: "leaf"))
                ], attributes: .init(id: "inner")),
            ], attributes: .init(id: "outer"))
        ]
        let tracker = Phase2ScopeTracker(blocks: blocks)
        let ancestors = tracker.ancestors(of: "leaf")
        #expect(ancestors == ["inner", "outer"])
    }

    @Test("ScopeTracker returns empty array for top-level block")
    func scopeTrackerTopLevel() {
        let blocks: [Block] = [
            .paragraph([.text("Top level")], attributes: .init(id: "top"))
        ]
        let tracker = Phase2ScopeTracker(blocks: blocks)
        let ancestors = tracker.ancestors(of: "top")
        #expect(ancestors.isEmpty)
    }

    @Test("ScopeTracker isDescendant checks ancestry")
    func scopeTrackerIsDescendant() {
        let blocks: [Block] = [
            .div(content: [
                .admonition(
                    type: "theorem", title: "T1",
                    content: [.paragraph([.text("Body")], attributes: .init(id: "body-p"))],
                    collapsible: nil, attributes: .init(id: "thm-1")
                )
            ], attributes: .init(id: "section-1"))
        ]
        let tracker = Phase2ScopeTracker(blocks: blocks)
        #expect(tracker.isDescendant("body-p", of: "section-1"))
        #expect(tracker.isDescendant("body-p", of: "thm-1"))
        #expect(!tracker.isDescendant("body-p", of: "nonexistent"))
    }
}
