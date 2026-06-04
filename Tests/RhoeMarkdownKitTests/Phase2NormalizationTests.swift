import Testing
import Foundation
import RhoeMarkdownKit

@Suite("Phase 2: Post-Transform Normalization")
struct Phase2NormalizationTests {

    // MARK: - Helpers

    private func attrs(id: String? = nil, classes: [String] = [], keyValues: [String: String] = [:]) -> RhoeMarkdownKit.Attributes {
        RhoeMarkdownKit.Attributes(id: id, classes: classes, keyValues: keyValues)
    }

    private func normalize(_ blocks: [Block]) -> [Block] {
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let pass = Phase2NormalizationPass()
        return pass.process(doc).blocks
    }

    // MARK: - Empty Container Repair

    @Test("Empty blockquote is preserved because it is Markdown-significant")
    func emptyBlockquotePreserved() {
        let blocks: [Block] = [
            .blockQuote([], attributes: attrs()),
            .paragraph([.text("Remaining")], attributes: attrs()),
        ]
        let result = normalize(blocks)
        #expect(result.count == 2)
        if case .blockQuote(let content, _) = result[0] {
            #expect(content.isEmpty)
        } else {
            Issue.record("Expected empty blockquote to remain")
        }
    }

    @Test("Empty div without ID is removed")
    func emptyDivWithoutIdRemoved() {
        let blocks: [Block] = [
            .div(content: [], attributes: attrs()),
            .paragraph([.text("Content")], attributes: attrs()),
        ]
        let result = normalize(blocks)
        #expect(result.count == 1)
    }

    @Test("Div with ID is preserved even if empty (collect target)")
    func emptyDivWithIdPreserved() {
        let blocks: [Block] = [
            .div(content: [], attributes: attrs(id: "theorem-index")),
            .paragraph([.text("Content")], attributes: attrs()),
        ]
        let result = normalize(blocks)
        #expect(result.count == 2)
        if case .div(let content, let a) = result[0] {
            #expect(a.id == "theorem-index")
            #expect(content.isEmpty)
        } else {
            Issue.record("Expected empty div with ID to be preserved")
        }
    }

    @Test("Empty list with no items is removed")
    func emptyListRemoved() {
        let blocks: [Block] = [
            .list(type: .unordered, items: [], attributes: attrs()),
            .paragraph([.text("After list")], attributes: attrs()),
        ]
        let result = normalize(blocks)
        #expect(result.count == 1)
    }

    @Test("List items that become empty after repair are preserved")
    func listWithEmptyItemsPreserved() {
        let blocks: [Block] = [
            .list(
                type: .unordered,
                items: [ListItem(content: [
                    // Nested empty div gets removed, leaving a valid empty item.
                    .div(content: [], attributes: attrs())
                ])],
                attributes: attrs()
            ),
            .paragraph([.text("After")], attributes: attrs()),
        ]
        let result = normalize(blocks)
        #expect(result.count == 2)
        if case .list(_, let items, _) = result[0] {
            #expect(items.count == 1)
            #expect(items[0].content.isEmpty)
        } else {
            Issue.record("Expected repaired empty list item to be preserved")
        }
    }

    @Test("Admonition with empty content is preserved (structure maintained)")
    func admonitionWithEmptyContentPreserved() {
        let blocks: [Block] = [
            .admonition(type: "note", title: "Empty Note",
                       content: [],
                       collapsible: nil, attributes: attrs(id: "empty-note")),
        ]
        let result = normalize(blocks)
        #expect(result.count == 1)
        if case .admonition(_, let title, _, _, _) = result[0] {
            #expect(title == "Empty Note")
        }
    }

    @Test("Nested empty div is removed while empty blockquote is preserved")
    func nestedEmptyDivRemovedAndBlockquotePreserved() {
        let blocks: [Block] = [
            .blockQuote([
                .div(content: [], attributes: attrs()),
                .blockQuote([], attributes: attrs()),
            ], attributes: attrs()),
        ]
        let result = normalize(blocks)
        #expect(result.count == 1)
        if case .blockQuote(let children, _) = result[0] {
            #expect(children.count == 1)
            if case .blockQuote(let nested, _) = children[0] {
                #expect(nested.isEmpty)
            } else {
                Issue.record("Expected nested empty blockquote to remain")
            }
        } else {
            Issue.record("Expected outer blockquote to remain")
        }
    }

    // MARK: - ID Deduplication

    @Test("Duplicate IDs are renamed after clone operation")
    func duplicateIdsRenamed() {
        let blocks: [Block] = [
            .paragraph([.text("Original")], attributes: attrs(id: "p-1")),
            .paragraph([.text("Clone")], attributes: attrs(id: "p-1")),
        ]
        let result = normalize(blocks)
        #expect(result.count == 2)
        // First occurrence keeps original ID
        if case .paragraph(_, let a1) = result[0] {
            #expect(a1.id == "p-1")
        }
        // Second occurrence gets renamed
        if case .paragraph(_, let a2) = result[1] {
            #expect(a2.id != "p-1")
            #expect(a2.id?.contains("p-1-dup-") == true)
        }
    }

    @Test("First occurrence keeps original ID")
    func firstOccurrenceKeepsId() {
        let blocks: [Block] = [
            .heading(level: 2, content: [.text("Section")], attributes: attrs(id: "sec-1")),
            .heading(level: 2, content: [.text("Cloned Section")], attributes: attrs(id: "sec-1")),
            .heading(level: 2, content: [.text("Another Clone")], attributes: attrs(id: "sec-1")),
        ]
        let result = normalize(blocks)
        if case .heading(_, _, let a) = result[0] {
            #expect(a.id == "sec-1")
        }
        if case .heading(_, _, let a) = result[1] {
            #expect(a.id != "sec-1")
        }
        if case .heading(_, _, let a) = result[2] {
            #expect(a.id != "sec-1")
        }
    }

    @Test("Unique IDs are not modified")
    func uniqueIdsUnchanged() {
        let blocks: [Block] = [
            .paragraph([.text("First")], attributes: attrs(id: "p-1")),
            .paragraph([.text("Second")], attributes: attrs(id: "p-2")),
            .paragraph([.text("Third")], attributes: attrs(id: "p-3")),
        ]
        let result = normalize(blocks)
        if case .paragraph(_, let a) = result[0] { #expect(a.id == "p-1") }
        if case .paragraph(_, let a) = result[1] { #expect(a.id == "p-2") }
        if case .paragraph(_, let a) = result[2] { #expect(a.id == "p-3") }
    }

    @Test("Duplicate IDs in nested containers are detected and renamed")
    func nestedDuplicateIds() {
        let blocks: [Block] = [
            .admonition(type: "theorem", title: "T1",
                       content: [.paragraph([.text("Inner")], attributes: attrs(id: "shared-id"))],
                       collapsible: nil, attributes: attrs(id: "thm-1")),
            .paragraph([.text("Outer")], attributes: attrs(id: "shared-id")),
        ]
        let result = normalize(blocks)
        // One of the two "shared-id" blocks should be renamed
        var ids: [String?] = []
        if case .admonition(_, _, let content, _, _) = result[0] {
            if case .paragraph(_, let a) = content.first { ids.append(a.id) }
        }
        if case .paragraph(_, let a) = result[1] { ids.append(a.id) }
        let nonNilIds = ids.compactMap { $0 }
        let uniqueIds = Set(nonNilIds)
        #expect(uniqueIds.count == 2, "Both IDs should be unique after deduplication")
    }

    // MARK: - Structural Repair of Nested Containers

    @Test("VisualBlock preserves children during structural repair")
    func visualBlockPreservesChildren() {
        let blocks: [Block] = [
            .visualBlock(
                name: "timeline",
                content: [
                    .paragraph([.text("Event 1")], attributes: attrs(id: "ev-1")),
                    .div(content: [], attributes: attrs()), // Empty extension container should be removed.
                    .paragraph([.text("Event 2")], attributes: attrs(id: "ev-2")),
                ],
                attributes: attrs(id: "tl-1")
            ),
        ]
        let result = normalize(blocks)
        if case .visualBlock(_, let content, _) = result.first {
            #expect(content.count == 2, "Empty div inside visualBlock should be removed")
        } else {
            Issue.record("Expected visualBlock to survive normalization")
        }
    }

    // MARK: - Normalization Pass Registration

    @Test("Normalization pass is registered in pipeline after Phase2ExecutionPass")
    func normalizationRegisteredInPipeline() {
        let config = RhoeMarkdownKit.Configuration(enablePhase2Transforms: true)
        let pipeline = buildDocumentPipeline(for: config)

        // Run a document with duplicate IDs through the full pipeline
        let blocks: [Block] = [
            .paragraph([.text("Original")], attributes: attrs(id: "dup")),
            .paragraph([.text("Duplicate")], attributes: attrs(id: "dup")),
        ]
        let doc = RhoeMarkdownKit.Document(blocks: blocks)
        let result = pipeline.run(doc)

        // After the pipeline, IDs should be unique
        var allIds: [String] = []
        for block in result.blocks {
            if case .paragraph(_, let a) = block, let id = a.id {
                allIds.append(id)
            }
        }
        let uniqueIds = Set(allIds)
        #expect(uniqueIds.count == allIds.count, "Pipeline should deduplicate IDs")
    }
}
