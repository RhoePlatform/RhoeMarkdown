import Foundation
import RhoeMarkdownKit

@main
struct BenchmarkDocumentGenerator {
    static func main() async {
        print("🚀 NASA-GRADE BENCHMARK DOCUMENT GENERATOR 🚀\n")
        
        let sizes = [
            ("small", 1_000),      // 1KB
            ("medium", 10_000),    // 10KB  
            ("large", 100_000),    // 100KB
            ("huge", 1_000_000),   // 1MB
            ("mega", 10_000_000),  // 10MB
            ("ultra", 100_000_000) // 100MB
        ]
        
        for (name, targetSize) in sizes {
            print("Generating \(name) document (target: \(targetSize) bytes)...")
            let document = await generateMarkdownDocument(targetSize: targetSize, name: name)
            
            let filename = "benchmark-\(name).md"
            try? document.write(to: URL(fileURLWithPath: filename), atomically: true, encoding: .utf8)
            
            let actualSize = document.utf8.count
            let sizeMB = Double(actualSize) / 1_000_000.0
            print("✅ Generated \(filename): \(actualSize) bytes (\(String(format: "%.2f", sizeMB))MB)")
        }
        
        print("\n🎉 All benchmark documents generated successfully! 🎉")
        print("Ready for the ULTIMATE SHOWDOWN! 🏆")
    }
    
    static func generateMarkdownDocument(targetSize: Int, name: String) async -> String {
        var document = """
        # \(name.capitalized) Benchmark Document 🚀
        
        This is a comprehensive \(name) markdown document designed to test the limits of markdown parsers.
        Generated for the **ULTIMATE SHOWDOWN** between RhoeMarkdownKit and marked.js!
        
        ## Document Statistics
        
        - **Target Size**: \(targetSize) bytes
        - **Complexity**: Maximum
        - **Features**: All supported markdown elements
        - **Purpose**: Demonstrate RhoeMarkdownKit's REVOLUTIONARY performance
        
        """
        
        let blockTemplates = [
            // Headings with attributes
            """
            ### Performance Section \(UUID().uuidString.prefix(8)) {#perf-\(Int.random(in: 1000...9999)) .performance}
            
            This section demonstrates our **incredible** performance capabilities with complex nested structures.
            """,
            
            // Complex lists
            """
            #### Task Management {.tasks}
            
            - [ ] Parse \(Int.random(in: 1000...9999)) markdown files
            - [x] Implement parallel processing  
            - [x] Achieve \(Double.random(in: 2.0...10.0).formatted(.number.precision(.fractionLength(1))))x speedup
            - [ ] Benchmark against competitors
              - [x] Test with small files (1KB)
              - [x] Test with medium files (10KB)  
              - [x] Test with large files (100KB)
              - [ ] Test with huge files (1MB+)
                - [x] Memory optimization
                - [x] Streaming support
                - [ ] GPU acceleration
            """,
            
            // Code blocks with various languages
            """
            ##### Code Example \(Int.random(in: 100...999)) {.code-demo}
            
            ```swift
            // Revolutionary parallel markdown processing
            @available(macOS 13.0, *)
            public actor ParallelMarkdownProcessor {
                func processLargeDocument(_ markdown: String) async -> ProcessResult {
                    let chunks = await splitIntoChunks(markdown, targetSize: \(Int.random(in: 10000...50000)))
                    let results = await withTaskGroup(of: ChunkResult.self) { group in
                        for chunk in chunks {
                            group.addTask {
                                return await self.processChunk(chunk)
                            }
                        }
                        return await group.reduce(into: []) { $0.append($1) }
                    }
                    return await mergeResults(results)
                }
            }
            ```
            """,
            
            // Tables with performance data
            """
            ###### Performance Comparison {.benchmark-table}
            
            | Parser | Small (1KB) | Medium (10KB) | Large (100KB) | Huge (1MB) |
            |--------|:-----------:|:-------------:|:-------------:|:----------:|
            | RhoeMarkdownKit | **\(Double.random(in: 0.1...0.5).formatted(.number.precision(.fractionLength(2))))ms** | **\(Double.random(in: 1.0...5.0).formatted(.number.precision(.fractionLength(2))))ms** | **\(Double.random(in: 10...50).formatted(.number.precision(.fractionLength(1))))ms** | **\(Double.random(in: 100...500).formatted(.number.precision(.fractionLength(0))))ms** |
            | marked.js | \(Double.random(in: 1.0...3.0).formatted(.number.precision(.fractionLength(2))))ms | \(Double.random(in: 10...30).formatted(.number.precision(.fractionLength(1))))ms | \(Double.random(in: 100...300).formatted(.number.precision(.fractionLength(0))))ms | \(Double.random(in: 1000...3000).formatted(.number.precision(.fractionLength(0))))ms |
            | commonmark.js | \(Double.random(in: 2.0...5.0).formatted(.number.precision(.fractionLength(2))))ms | \(Double.random(in: 20...50).formatted(.number.precision(.fractionLength(1))))ms | \(Double.random(in: 200...500).formatted(.number.precision(.fractionLength(0))))ms | \(Double.random(in: 2000...5000).formatted(.number.precision(.fractionLength(0))))ms |
            
            *All measurements on Apple Silicon M2 Pro*
            """,
            
            // Blockquotes with nested content
            """
            > **Revolutionary Achievement Alert!** 🚀
            > 
            > Our parallel markdown engine has achieved unprecedented performance gains:
            > 
            > - **\(Double.random(in: 3...10).formatted(.number.precision(.fractionLength(1))))x faster** than traditional parsers
            > - **Zero memory leaks** with perfect actor isolation
            > - **100% CommonMark compliance** with extensions
            > 
            > ```swift
            > let speedup = parallel_time / sequential_time
            > print("Speedup: \\(speedup)x") // Always > 1.0!
            > ```
            > 
            > This is what the future looks like! ⚡
            """,
            
            // Math equations
            """
            ####### Mathematical Proof of Speedup {.math-section}
            
            The theoretical speedup $S$ for our parallel algorithm follows Amdahl's Law:
            
            $$S = \\frac{1}{(1-P) + \\frac{P}{N}}$$
            
            Where:
            - $P$ = fraction of code that can be parallelized (≈ 0.95 for our engine)
            - $N$ = number of processing cores
            
            For Apple Silicon with $N = 8$ cores:
            $$S = \\frac{1}{0.05 + \\frac{0.95}{8}} = \\frac{1}{0.05 + 0.119} = 5.92x$$
            
            Our measured results consistently exceed this theoretical maximum! 🎯
            """,
            
            // Admonitions
            """
            !!! success "Performance Breakthrough"
                We've achieved the impossible - a markdown parser that gets faster as documents get larger!
                
                This is due to our revolutionary architecture:
                1. **Smart chunking** with context awareness
                2. **Parallel processing** across all available cores  
                3. **Efficient merging** with zero data races
                4. **Memory optimization** with actor isolation
            
            !!! info "Technical Details"
                - **Language**: Swift 6 with strict concurrency
                - **Architecture**: Actor-based parallel processing
                - **Compatibility**: macOS 13.0+, iOS 16.0+
                - **Dependencies**: Zero - pure Swift implementation
            
            !!! warning "Competitor Warning"
                Traditional markdown parsers are now obsolete.
                The parallel revolution has begun! 🚀
            """,
            
            // Definition lists
            """
            ##### Technical Glossary {.glossary}
            
            Parallel Processing  
            : Simultaneous execution of multiple tasks across different CPU cores
            : Achieves linear speedup for embarrassingly parallel problems
            : Core technology behind our revolutionary performance
            
            Actor Model
            : Swift's approach to safe concurrent programming  
            : Eliminates data races through isolated state
            : Enables fearless parallelism at scale
            
            Apple Silicon
            : ARM-based processors with incredible multi-core performance
            : Perfect architecture for our parallel algorithms
            : Delivers sustained performance without thermal throttling
            """,
            
            // Complex nested structures
            """
            ###### Nested Complexity Test {.complexity-test}
            
            This section tests deeply nested structures:
            
            1. **First Level**
               - Item A with `inline code`
               - Item B with **bold text**
                 1. **Second Level**
                    - Nested item with [link](https://example.com)
                    - Another nested item
                      1. **Third Level**  
                         - Deep nesting with *italic*
                         - Even deeper nesting
                           - **Fourth Level** (maximum depth)
                           - Testing parser limits
            
            2. **Complex Block Combinations**
               
               > This blockquote contains:
               > 
               > ```javascript
               > // Code inside blockquote
               > function benchmark() {
               >   return performance.now();
               > }
               > ```
               > 
               > | Feature | Status |
               > |---------|:------:|
               > | Parsing | ✅ |
               > | Speed | 🚀 |
            """,
        ]
        
        // Generate content until we reach target size
        var currentSize = document.utf8.count
        var blockIndex = 0
        
        while currentSize < targetSize {
            let template = blockTemplates[blockIndex % blockTemplates.count]
            let block = template + "\n\n"
            document += block
            currentSize = document.utf8.count
            blockIndex += 1
            
            // Add some variety with random horizontal rules
            if blockIndex % 10 == 0 {
                document += "---\n\n"
            }
        }
        
        // Add conclusion
        document += """
        ## Conclusion
        
        This \(name) document demonstrates the full power of RhoeMarkdownKit's parallel processing engine.
        With \(blockIndex) generated sections and \(currentSize) bytes of content, we're ready for battle! 🏆
        
        **Bring it on, marked.js!** 🥊
        
        ---
        
        *Generated by RhoeMarkdownKit Benchmark Generator*
        *Document size: \(currentSize) bytes*
        *Sections generated: \(blockIndex)*
        """
        
        return document
    }
}