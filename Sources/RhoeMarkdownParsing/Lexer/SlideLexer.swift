//
//  SlideLexer.swift
//  RhoeMarkdownKit
//
//  EBNF-compliant lexer for slide markdown syntax
//

import Foundation
import RhoeMarkdownModel

/// EBNF-compliant lexer for slide markdown, implementing LL(2) parsing requirements
public struct SlideLexer: Sendable {
    
    // MARK: - Token Types
    
    /// Token types matching EBNF grammar productions
    public enum TokenType: Sendable, Equatable {
        // Slide structure tokens
        case slideSeparator(SlideType) // %%%, %%%%, %%%%%, %%%%%%
        case gridSpec(String)         // D4, F8, etc. after %%%
        case frontmatterDelimiter     // ---
        case frontmatterContent(String)
        
        // Grid system tokens
        case gridMarker               // %% (for grid layout)
        case cellMarker               // % (for grid cells)
        case cellReference(String)    // A1, B2:C3, etc.
        case cellAlignment(String)    // .TL, .C, .BR, etc.
        
        // Slot system tokens  
        case slotMarker               // %%
        case slotPosition(SlotType)   // TL, HC, FBR, etc.
        
        // Shape system tokens
        case shapeMarker              // !!!
        case shapeName(String)        // Circle, Rect, Arrow, etc.
        
        // Special content tokens
        case liquidVariable           // {{ ... }}
        case liquidTag                // {% ... %}
        case liquidFilter             // | within liquid
        
        // Attributes
        case attributeBlock(String)   // { ... }
        case classAttribute(String)   // .class-name
        case idAttribute(String)      // #id-name
        case keyValueAttribute(String, String) // key="value"
        
        // Markdown tokens
        case heading(level: Int)
        case bold
        case italic
        case code
        case strikethrough
        case link
        case image
        case listMarker(String)       // -, +, *, 1.
        case tableSeparator
        case blockQuote
        case codeBlock(String?)       // ``` with optional language
        case mathInline               // $...$
        case mathDisplay              // $$...$$
        
        // Structural tokens
        case text(String)
        case whitespace(Int)          // count of spaces/tabs
        case newline
        case indent(Int)              // indentation level
        case inlineSeparator          // |
        
        // Special tokens
        case eof                      // End of file
    }
    
    /// Slot position types
    public enum SlotType: String, Sendable {
        // Slide slots
        case topLeft = "TL"
        case top = "T"
        case topRight = "TR"
        case left = "L"
        case center = "C"
        case right = "R"
        case bottomLeft = "BL"
        case bottom = "B"
        case bottomRight = "BR"
        
        // Header slots
        case headerTopLeft = "HTL"
        case headerTop = "HT"
        case headerTopRight = "HTR"
        case headerLeft = "HL"
        case headerCenter = "HC"
        case headerRight = "HR"
        case headerBottomLeft = "HBL"
        case headerBottom = "HB"
        case headerBottomRight = "HBR"
        
        // Footer slots
        case footerTopLeft = "FTL"
        case footerTop = "FT"
        case footerTopRight = "FTR"
        case footerLeft = "FL"
        case footerCenter = "FC"
        case footerRight = "FR"
        case footerBottomLeft = "FBL"
        case footerBottom = "FB"
        case footerBottomRight = "FBR"
    }
    
    /// Token with position information
    public struct Token: Sendable {
        public let type: TokenType
        public let value: String
        public let line: Int
        public let column: Int
        public let length: Int
        
        public init(type: TokenType, value: String, line: Int, column: Int, length: Int) {
            self.type = type
            self.value = value
            self.line = line
            self.column = column
            self.length = length
        }
    }
    
    // MARK: - Lexer State
    
    private let input: String
    private var position: String.Index
    private var line: Int
    private var column: Int
    private var tokens: [Token] = []
    
    // MARK: - Initialization
    
    public init(input: String) {
        self.input = input
        self.position = input.startIndex
        self.line = 1
        self.column = 1
    }
    
    // MARK: - Public API
    
    /// Tokenize the input and return all tokens
    public mutating func tokenize() -> [Token] {
        tokens = []
        
        while !isAtEnd {
            scanToken()
        }
        
        addToken(.eof, value: "")
        return tokens
    }
    
    // MARK: - Scanning
    
    private mutating func scanToken() {
        let startLine = line
        let startColumn = column
        
        // Skip whitespace but track it
        if scanWhitespace() {
            return
        }
        
        // Check for newline
        if current == "\n" {
            advance()
            addToken(.newline, value: "\n", line: startLine, column: startColumn)
            line += 1
            column = 1
            return
        }
        
        // Check for slide separators (%%%, %%%%, %%%%%, %%%%%%)
        if current == "%" && peek() == "%" && peek(2) == "%" {
            scanSlideSeparator()
            return
        }
        
        // Check for slot marker %%
        if current == "%" && peek() == "%" && peek(2) != "%" {
            scanSlotMarker()
            return
        }
        
        // Check for grid cell marker %
        if current == "%" && peek() != "%" {
            scanCellMarker()
            return
        }
        
        // Check for shape marker !!!
        if current == "!" && peek() == "!" && peek(2) == "!" {
            scanShapeMarker()
            return
        }

        // Inline cell separator / literal pipe
        if current == "|" {
            advance()
            addToken(.inlineSeparator, value: "|", line: startLine, column: startColumn)
            return
        }
        
        // Check for frontmatter delimiter ---
        if column == 1 && current == "-" && peek() == "-" && peek(2) == "-" {
            scanFrontmatterDelimiter()
            return
        }
        
        // Check for liquid tags
        if current == "{" {
            if peek() == "{" {
                scanLiquidVariable()
                return
            } else if peek() == "%" {
                scanLiquidTag()
                return
            } else if scanAttributeBlock() {
                return
            }
        }
        
        // Check for markdown constructs
        if scanMarkdownToken() {
            return
        }
        
        // Default: scan text
        scanText()
    }
    
    // MARK: - Slide-specific Scanners
    
    private mutating func scanSlideSeparator() {
        let startCol = column
        var percentCount = 0
        
        // Count % characters
        while !isAtEnd && current == "%" && percentCount < 6 {
            percentCount += 1
            advance()
        }
        
        // Determine slide type
        let slideType: SlideType
        switch percentCount {
        case 3: slideType = .regular
        case 4: slideType = .separator
        case 5: slideType = .section
        case 6: slideType = .title
        default:
            // Invalid number of %, treat as regular
            slideType = .regular
        }

        let separatorValue = String(repeating: "%", count: percentCount)
        addToken(.slideSeparator(slideType), value: separatorValue, line: line, column: startCol)
        
        // Skip whitespace
        while !isAtEnd && (current == " " || current == "\t") {
            advance()
        }
        
        // Check for grid spec (only for regular slides)
        if slideType == .regular && !isAtEnd && current.isLetter {
            let gridStart = position
            
            // Column letter(s)
            while !isAtEnd && current.isLetter {
                advance()
            }
            
            // Row number(s)
            if !isAtEnd && current.isNumber {
                while !isAtEnd && current.isNumber {
                    advance()
                }
                
                let gridSpec = String(input[gridStart..<position])
                addToken(.gridSpec(gridSpec), value: gridSpec, line: line, column: startCol + percentCount + 1)
            }
        }

        // Continue tokenizing the rest of the header line so optional
        // attribute blocks remain visible to the parser.
    }
    
    private mutating func scanSlotMarker() {
        let startCol = column
        addToken(.slotMarker, value: "%%", line: line, column: startCol)
        advance(2) // Skip %%
        
        // Skip whitespace
        while !isAtEnd && (current == " " || current == "\t") {
            advance()
        }
        
        // Scan slot position
        let posStart = position
        while !isAtEnd && (current.isLetter || current.isNumber) {
            advance()
        }
        
        let posStr = String(input[posStart..<position])
        if let slotType = SlotType(rawValue: posStr) {
            addToken(.slotPosition(slotType), value: posStr, line: line, column: startCol + 3)
        }
    }
    
    private mutating func scanCellMarker() {
        let startCol = column
        addToken(.cellMarker, value: "%", line: line, column: startCol)
        advance() // Skip %
        
        // Skip whitespace
        while !isAtEnd && (current == " " || current == "\t") {
            advance()
        }
        
        // Scan cell reference
        let refStart = position
        
        // First cell reference
        if current.isLetter {
            while !isAtEnd && current.isLetter {
                advance()
            }
            while !isAtEnd && current.isNumber {
                advance()
            }
            
            // Check for range (:)
            if !isAtEnd && current == ":" {
                advance()
                // Second cell reference
                while !isAtEnd && current.isLetter {
                    advance()
                }
                while !isAtEnd && current.isNumber {
                    advance()
                }
            }
            
            let cellRef = String(input[refStart..<position])
            if !cellRef.isEmpty {
                addToken(.cellReference(cellRef), value: cellRef, line: line, column: startCol + 2)
            }
        }
        
        // Check for alignment
        if !isAtEnd && current == "." {
            let alignStart = position
            advance() // Skip .
            
            while !isAtEnd && current.isLetter {
                advance()
            }
            
            let align = String(input[alignStart..<position])
            addToken(.cellAlignment(align), value: align, line: line, column: startCol + 2)
        }
    }
    
    private mutating func scanShapeMarker() {
        let startCol = column
        addToken(.shapeMarker, value: "!!!", line: line, column: startCol)
        advance(3) // Skip !!!
        
        // Skip whitespace
        while !isAtEnd && (current == " " || current == "\t") {
            advance()
        }
        
        // Scan shape name (now supports Icon.name notation)
        let nameStart = position
        while !isAtEnd && (current.isLetter || current.isNumber || current == "." || current == "-" || current == "_") {
            advance()
        }
        
        let shapeName = String(input[nameStart..<position])
        if !shapeName.isEmpty {
            addToken(.shapeName(shapeName), value: shapeName, line: line, column: startCol + 4)
        }
    }
    
    // MARK: - Liquid Scanners
    
    private mutating func scanLiquidVariable() {
        let startCol = column
        advance(2) // Skip {{
        
        var content = ""
        while !isAtEnd && !(current == "}" && peek() == "}") {
            if current == "\n" {
                line += 1
                column = 0
            }
            content.append(current)
            advance()
        }
        
        if !isAtEnd {
            advance(2) // Skip }}
        }
        
        addToken(.liquidVariable, value: "{{\(content)}}", line: line, column: startCol)
    }
    
    private mutating func scanLiquidTag() {
        let startCol = column
        advance(2) // Skip {%
        
        var content = ""
        while !isAtEnd && !(current == "%" && peek() == "}") {
            if current == "\n" {
                line += 1
                column = 0
            }
            content.append(current)
            advance()
        }
        
        if !isAtEnd {
            advance(2) // Skip %}
        }
        
        addToken(.liquidTag, value: "{%\(content)%}", line: line, column: startCol)
    }
    
    // MARK: - Markdown Scanners
    
    private mutating func scanMarkdownToken() -> Bool {
        let startCol = column
        
        // Headings (at start of line)
        if column == 1 && current == "#" {
            var level = 0
            while !isAtEnd && current == "#" && level < 6 {
                level += 1
                advance()
            }
            addToken(.heading(level: level), value: String(repeating: "#", count: level), line: line, column: startCol)
            return true
        }
        
        // Bold/Italic
        if current == "*" || current == "_" {
            let marker = current
            var count = 0
            while !isAtEnd && current == marker && count < 3 {
                count += 1
                advance()
            }
            if count == 2 {
                addToken(.bold, value: String(repeating: String(marker), count: 2), line: line, column: startCol)
            } else if count == 1 {
                addToken(.italic, value: String(marker), line: line, column: startCol)
            }
            return true
        }
        
        // Code
        if current == "`" {
            if peek() == "`" && peek(2) == "`" {
                advance(3)
                // Scan language
                var lang = ""
                while !isAtEnd && current != "\n" {
                    lang.append(current)
                    advance()
                }
                addToken(.codeBlock(lang.isEmpty ? nil : lang.trimmingCharacters(in: .whitespaces)), 
                        value: "```", line: line, column: startCol)
            } else {
                advance()
                addToken(.code, value: "`", line: line, column: startCol)
            }
            return true
        }
        
        // Strikethrough
        if current == "~" && peek() == "~" {
            advance(2)
            addToken(.strikethrough, value: "~~", line: line, column: startCol)
            return true
        }
        
        // Images and Links
        if current == "!" && peek() == "[" {
            advance(2)
            addToken(.image, value: "![", line: line, column: startCol)
            return true
        }
        
        if current == "[" {
            advance()
            addToken(.link, value: "[", line: line, column: startCol)
            return true
        }
        
        // Math
        if current == "$" {
            if peek() == "$" {
                advance(2)
                addToken(.mathDisplay, value: "$$", line: line, column: startCol)
            } else {
                advance()
                addToken(.mathInline, value: "$", line: line, column: startCol)
            }
            return true
        }
        
        // Lists
        if column == 1 || (column > 1 && previousWasNewline()) {
            if current == ">" {
                advance()
                addToken(.blockQuote, value: ">", line: line, column: startCol)
                return true
            }

            if current == "-" || current == "+" || current == "*" {
                let marker = String(current)
                advance()
                if !isAtEnd && (current == " " || current == "\t") {
                    addToken(.listMarker(marker), value: marker, line: line, column: startCol)
                    return true
                }
                // Rewind if not a list marker
                position = input.index(before: position)
                column -= 1
            }
        }
        
        return false
    }
    
    // MARK: - Attribute Scanner
    
    private mutating func scanAttributeBlock() -> Bool {
        let startPos = position
        let startCol = column
        
        if current != "{" {
            return false
        }
        
        advance() // Skip {
        var content = ""
        var braceCount = 1
        
        while !isAtEnd && braceCount > 0 {
            if current == "{" {
                braceCount += 1
            } else if current == "}" {
                braceCount -= 1
                if braceCount == 0 {
                    break
                }
            }
            content.append(current)
            advance()
        }
        
        if braceCount == 0 {
            advance() // Skip closing }
            addToken(.attributeBlock(content), value: "{\(content)}", line: line, column: startCol)
            return true
        }
        
        // Not a valid attribute block, rewind
        position = startPos
        column = startCol
        return false
    }
    
    // MARK: - Text Scanner
    
    private mutating func scanText() {
        let startCol = column
        var text = ""
        
        while !isAtEnd {
            // A single "~" is literal text in the slide lexer; only "~~" is special.
            let startsStrikethrough = current == "~" && peek() == "~"

            // Stop at special characters
            if current == "\n" || current == "%" || current == "!" || 
               current == "{" || current == "*" || current == "_" ||
               current == "`" || startsStrikethrough || current == "[" ||
               current == "$" || current == "|" {
                break
            }
            
            text.append(current)
            advance()
        }
        
        if !text.isEmpty {
            addToken(.text(text), value: text, line: line, column: startCol)
        }
    }
    
    // MARK: - Helper Methods
    
    private mutating func scanWhitespace() -> Bool {
        let startCol = column
        var count = 0
        
        while !isAtEnd && (current == " " || current == "\t") {
            count += current == "\t" ? 4 : 1
            advance()
        }
        
        if count > 0 {
            addToken(.whitespace(count), value: String(repeating: " ", count: count), line: line, column: startCol)
            return true
        }
        
        return false
    }
    
    private mutating func scanFrontmatterDelimiter() {
        let startCol = column
        advance(3) // Skip ---
        
        // Skip to end of line
        while !isAtEnd && current != "\n" {
            advance()
        }
        
        addToken(.frontmatterDelimiter, value: "---", line: line, column: startCol)
    }
    
    private func previousWasNewline() -> Bool {
        if let lastToken = tokens.last {
            return lastToken.type == .newline
        }
        return false
    }
    
    // MARK: - Character Navigation
    
    private var isAtEnd: Bool {
        position >= input.endIndex
    }
    
    private var current: Character {
        isAtEnd ? "\0" : input[position]
    }
    
    private func peek(_ offset: Int = 1) -> Character {
        var idx = position
        for _ in 0..<offset {
            if idx >= input.endIndex {
                return "\0"
            }
            idx = input.index(after: idx)
        }
        return idx >= input.endIndex ? "\0" : input[idx]
    }
    
    private mutating func advance(_ count: Int = 1) {
        for _ in 0..<count {
            if !isAtEnd {
                position = input.index(after: position)
                column += 1
            }
        }
    }
    
    private mutating func addToken(_ type: TokenType, value: String, line: Int? = nil, column: Int? = nil) {
        tokens.append(Token(
            type: type,
            value: value,
            line: line ?? self.line,
            column: column ?? self.column,
            length: value.count
        ))
    }
}

// MARK: - Extensions

extension Character {
    private var asciiScalarValue: UInt32? {
        guard unicodeScalars.count == 1, let scalar = unicodeScalars.first, scalar.isASCII else {
            return nil
        }

        return scalar.value
    }

    var isLetter: Bool {
        guard let value = asciiScalarValue else { return false }
        return (65...90).contains(value) || (97...122).contains(value)
    }
    
    var isNumber: Bool {
        guard let value = asciiScalarValue else { return false }
        return (48...57).contains(value)
    }
}
