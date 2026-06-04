import Testing
import RhoeMarkdownKit

@Suite("External Markdown Conformance Regression Tests")
struct ExternalConformanceRegressionTests {
    @Test("Tab-indented line parses as an indented code block")
    func tabIndentedLineParsesAsCodeBlock() async {
        let html = await renderStrictHTML("\tfoo\tbaz\t\tbim\n")

        #expect(html == "<pre><code data-rhoe-node=\"code\">foo\tbaz\t\tbim\n</code></pre>")
    }

    @Test("Four-space indented line parses as an indented code block")
    func fourSpaceIndentedLineParsesAsCodeBlock() async {
        let html = await renderStrictHTML("    alpha\n    beta\n")

        #expect(html == "<pre><code data-rhoe-node=\"code\">alpha\nbeta\n</code></pre>")
    }

    @Test("Final paragraph newline does not become a soft break")
    func finalParagraphNewlineDoesNotBecomeSoftBreak() async {
        let html = await renderStrictHTML("A paragraph.\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">A paragraph.</p>")
    }

    @Test("Trailing whitespace-only EOF tail terminates lexing")
    func trailingWhitespaceOnlyEOFTailTerminatesLexing() async {
        let html = await renderStrictHTML("A paragraph.\n  ")

        #expect(html == "<p data-rhoe-node=\"paragraph\">A paragraph.</p>")
    }

    @Test("ATX heading accepts tab after opening marker")
    func atxHeadingAcceptsTabAfterOpeningMarker() async {
        let html = await renderStrictHTML("#\tFoo\n")

        #expect(html.contains("<h1>Foo</h1>"))
    }

    @Test("Plus signs are not thematic breaks")
    func plusSignsAreNotThematicBreaks() async {
        let html = await renderStrictHTML("+++\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">+++</p>")
    }

    @Test("Underscores are thematic breaks")
    func underscoresAreThematicBreaks() async {
        let html = await renderStrictHTML("___\n")

        #expect(html == "<hr>")
    }

    @Test("Code span closes on matching backtick run length")
    func codeSpanClosesOnMatchingBacktickRunLength() async {
        let html = await renderStrictHTML("`` foo ` bar ``\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><code>foo ` bar</code></p>")
    }

    @Test("Multiline code span normalizes line endings to spaces")
    func multilineCodeSpanNormalizesLineEndingsToSpaces() async {
        let html = await renderStrictHTML("``\nfoo\nbar  \nbaz\n``\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><code>foo bar   baz</code></p>")
    }

    @Test("Code spans can close inside escaped text tokens")
    func codeSpansCanCloseInsideEscapedTextTokens() async {
        let html = await renderStrictHTML("`foo\\`bar`\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><code>foo\\</code>bar`</p>")
    }

    @Test("Code spans can close inside HTML-looking tokens")
    func codeSpansCanCloseInsideHTMLLookingTokens() async {
        let html = await renderStrictHTML("`<a href=\"`\">`\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><code>&lt;a href=&quot;</code>&quot;&gt;`</p>")
    }

    @Test("Code spans can close inside autolink-looking tokens")
    func codeSpansCanCloseInsideAutolinkLookingTokens() async {
        let html = await renderStrictHTML("`<https://foo.bar.`baz>`\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><code>&lt;https://foo.bar.</code>baz&gt;`</p>")
    }

    @Test("Fenced code block preserves trailing content newline")
    func fencedCodeBlockPreservesTrailingContentNewline() async {
        let html = await renderStrictHTML("```\n<\n >\n```\n")

        #expect(html == "<pre><code data-rhoe-node=\"code\">&lt;\n &gt;\n</code></pre>")
    }

    @Test("Unclosed fenced code inside blockquote preserves content newline")
    func unclosedFencedCodeInsideBlockquotePreservesContentNewline() async {
        let html = await renderStrictHTML("""
        > ```
        > aaa

        bbb

        """)

        #expect(html == "<blockquote data-rhoe-node=\"blockquote\">\n<pre><code data-rhoe-node=\"code\">aaa\n</code></pre>\n</blockquote><p data-rhoe-node=\"paragraph\">bbb</p>")
    }

    @Test("Fenced code strips opening indentation from content and closing fence")
    func fencedCodeStripsOpeningIndentationFromContentAndClosingFence() async {
        let html = await renderStrictHTML("""
           ```
           aaa
            aaa
          aaa
           ```
        """)

        #expect(html == "<pre><code data-rhoe-node=\"code\">aaa\n aaa\naaa\n</code></pre>")
    }

    @Test("Fenced code closing fence allows up to three spaces only")
    func fencedCodeClosingFenceAllowsUpToThreeSpacesOnly() async {
        let valid = await renderStrictHTML("```\naaa\n  ```\n")
        let invalid = await renderStrictHTML("```\naaa\n    ```\n")

        #expect(valid == "<pre><code data-rhoe-node=\"code\">aaa\n</code></pre>")
        #expect(invalid == "<pre><code data-rhoe-node=\"code\">aaa\n    ```\n</code></pre>")
    }

    @Test("Backtick fenced code rejects info strings containing backticks")
    func backtickFencedCodeRejectsInfoStringsContainingBackticks() async {
        let html = await renderStrictHTML("``` aa ```\nfoo\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><code>aa</code>\nfoo</p>")
    }

    @Test("Fenced code closing fence rejects trailing nonspace text")
    func fencedCodeClosingFenceRejectsTrailingNonspaceText() async {
        let html = await renderStrictHTML("```\n``` aaa\n```\n")

        #expect(html == "<pre><code data-rhoe-node=\"code\">``` aaa\n</code></pre>")
    }

    @Test("Two trailing spaces create an internal hard break")
    func twoTrailingSpacesCreateHardBreak() async {
        let html = await renderStrictHTML("foo  \nbaz\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">foo<br>\nbaz</p>")
    }

    @Test("Escaped line ending creates an internal hard break")
    func escapedLineEndingCreatesHardBreak() async {
        let html = await renderStrictHTML("foo\\\nbaz\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">foo<br>\nbaz</p>")
    }

    @Test("Terminal escaped line ending remains literal")
    func terminalEscapedLineEndingRemainsLiteral() async {
        let html = await renderStrictHTML("foo\\\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">foo\\</p>")
    }

    @Test("Non-punctuation backslash escapes stay literal")
    func nonPunctuationBackslashEscapesStayLiteral() async {
        let html = await renderStrictHTML("\\A\\a\\ \\3\\φ\\«\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">\\A\\a\\ \\3\\φ\\«</p>")
    }

    @Test("Escaped Markdown triggers stay literal in strict mode")
    func escapedMarkdownTriggersStayLiteralInStrictMode() async {
        let html = await renderStrictHTML("""
        \\*not emphasized*
        \\<br/> not a tag
        \\[not a link](/foo)
        \\`not code`
        \\# not a heading

        """)

        #expect(html == "<p data-rhoe-node=\"paragraph\">*not emphasized*\n&lt;br/&gt; not a tag\n[not a link](/foo)\n`not code`\n# not a heading</p>")
    }

    @Test("ATX heading strips optional closing marker")
    func atxHeadingStripsOptionalClosingMarker() async {
        let html = await renderStrictHTML("## foo ##\n### bar ###     \n")

        #expect(html.contains("<h2>foo</h2>"))
        #expect(html.contains("<h3>bar</h3>"))
    }

    @Test("ATX heading preserves escaped closing marker hashes")
    func atxHeadingPreservesEscapedClosingMarkerHashes() async {
        let html = await renderStrictHTML("""
        ### foo \\###
        ## foo #\\##
        # foo \\#
        """)

        #expect(html.contains("<h3>foo ###</h3>"))
        #expect(html.contains("<h2>foo ###</h2>"))
        #expect(html.contains("<h1>foo #</h1>"))
    }

    @Test("ATX heading parses inline emphasis and escaped emphasis markers")
    func atxHeadingParsesInlineEmphasisAndEscapedEmphasisMarkers() async {
        let html = await renderStrictHTML("# foo *bar* \\*baz\\*\n")

        #expect(html.contains("<h1>foo <em>bar</em> *baz*</h1>"))
    }

    @Test("Empty ATX headings parse without literal hashes")
    func emptyATXHeadingsParseWithoutLiteralHashes() async {
        let h2 = await renderStrictHTML("## \n")
        let h1 = await renderStrictHTML("#\n")
        let h3 = await renderStrictHTML("### ###\n")

        #expect(h2.contains("<h2></h2>"))
        #expect(h1.contains("<h1></h1>"))
        #expect(h3.contains("<h3></h3>"))
    }

    @Test("Fenced code info string uses first unescaped word as language")
    func fencedCodeInfoStringUsesFirstUnescapedWordAsLanguage() async {
        let html = await renderStrictHTML("~~~~    ruby startline=3 $%@#$\ndef foo\nend\n~~~~~~~\n")

        #expect(html == "<pre><code class=\"language-ruby\" data-rhoe-node=\"code\">def foo\nend\n</code></pre>")
    }

    @Test("Fenced code info string resolves escaped punctuation")
    func fencedCodeInfoStringResolvesEscapedPunctuation() async {
        let html = await renderStrictHTML("``` foo\\+bar\nfoo\n```\n")

        #expect(html == "<pre><code class=\"language-foo+bar\" data-rhoe-node=\"code\">foo\n</code></pre>")
    }

    @Test("Named character references decode before HTML escaping")
    func namedCharacterReferencesDecodeBeforeHTMLEscaping() async {
        let html = await renderStrictHTML("&nbsp; &amp; &copy; &AElig; &Dcaron;\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">\u{00A0} &amp; © Æ Ď</p>")
    }

    @Test("Numeric character references decode valid and replacement scalars")
    func numericCharacterReferencesDecodeValidAndReplacementScalars() async {
        let html = await renderStrictHTML("&#35; &#1234; &#992; &#0; &#X22; &#XD06; &#xcab;\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"># Ӓ Ϡ � &quot; ആ ಫ</p>")
    }

    @Test("Overlong numeric character references stay literal")
    func overlongNumericCharacterReferencesStayLiteral() async {
        let html = await renderStrictHTML("&#87654321; &#x1234567;\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">&amp;#87654321; &amp;#x1234567;</p>")
    }

    @Test("Decoded entity delimiters do not retrigger Markdown parsing")
    func decodedEntityDelimitersDoNotRetriggerMarkdownParsing() async {
        let html = await renderStrictHTML("&#42;foo&#42;\n*foo*\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">*foo*\n<em>foo</em></p>")
    }

    @Test("Fenced code info string decodes character references")
    func fencedCodeInfoStringDecodesCharacterReferences() async {
        let html = await renderStrictHTML("``` f&ouml;&ouml;\nfoo\n```\n")

        #expect(html == "<pre><code class=\"language-föö\" data-rhoe-node=\"code\">foo\n</code></pre>")
    }

    @Test("Link href attributes are escaped exactly once")
    func linkHrefAttributesAreEscapedExactlyOnce() async {
        let html = await renderStrictHTML("<https://example.com?a=1&b=2>\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"https://example.com?a=1&amp;b=2\">https://example.com?a=1&amp;b=2</a></p>")
    }

    @Test("Inline link rejects bare destinations with spaces")
    func inlineLinkRejectsBareDestinationsWithSpaces() async {
        let html = await renderStrictHTML("[link](/my uri)\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">[link](/my uri)</p>")
    }

    @Test("Malformed link labels roll back around code spans")
    func malformedLinkLabelsRollBackAroundCodeSpans() async {
        let html = await renderStrictHTML("[not a `link](/foo`)\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">[not a <code>link](/foo</code>)</p>")
    }

    @Test("Code spans take precedence over link label closers")
    func codeSpansTakePrecedenceOverLinkLabelClosers() async {
        let inline = await renderStrictHTML("[foo`](/uri)`\n")
        let reference = await renderStrictHTML("""
        [foo`][ref]`

        [ref]: /uri

        """)

        #expect(inline == "<p data-rhoe-node=\"paragraph\">[foo<code>](/uri)</code></p>")
        #expect(reference == "<p data-rhoe-node=\"paragraph\">[foo<code>][ref]</code></p>")
    }

    @Test("Malformed inline links keep literal closing bracket")
    func malformedInlineLinksKeepLiteralClosingBracket() async {
        let html = await renderStrictHTML("[foo]\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">[foo]</p>")
    }

    @Test("Inline link angle destination percent-encodes spaces")
    func inlineLinkAngleDestinationPercentEncodesSpaces() async {
        let html = await renderStrictHTML("[link](</my uri>)\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"/my%20uri\">link</a></p>")
    }

    @Test("Inline link angle destination accepts parentheses before closing angle")
    func inlineLinkAngleDestinationAcceptsParenthesesBeforeClosingAngle() async {
        let html = await renderStrictHTML("[a](<b)c>)\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"b)c\">a</a></p>")
    }

    @Test("Failed angle destinations preserve inline HTML fallback")
    func failedAngleDestinationsPreserveInlineHTMLFallback() async {
        let html = await renderStrictHTML("""
        [a](<b)c
        [a](<b)c>
        [a](<b>c)
        """)

        #expect(html == "<p data-rhoe-node=\"paragraph\">[a](&lt;b)c\n[a](&lt;b)c&gt;\n[a](<b>c)</p>")
    }

    @Test("Escaped raw HTML tags remain literal text")
    func escapedRawHTMLTagsRemainLiteralText() async {
        let html = await renderStrictHTML("\\<br/> not a tag\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">&lt;br/&gt; not a tag</p>")
    }

    @Test("GitHub escaped raw HTML tags remain literal text")
    func githubEscapedRawHTMLTagsRemainLiteralText() async {
        let html = await renderGitHubHTML("\\<br/> not a tag\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">&lt;br/&gt; not a tag</p>")
    }

    @Test("GitHub angle destinations reject escaped closing brackets")
    func githubAngleDestinationsRejectEscapedClosingBrackets() async {
        let html = await renderGitHubHTML("[link](<foo\\>)\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">[link](&lt;foo&gt;)</p>")
    }

    @Test("Inline link bare destination unescapes balanced parentheses")
    func inlineLinkBareDestinationUnescapesBalancedParentheses() async {
        let html = await renderStrictHTML("[link](\\(foo\\))\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"(foo)\">link</a></p>")
    }

    @Test("Inline link bare destination accepts escaped closing delimiters")
    func inlineLinkBareDestinationAcceptsEscapedClosingDelimiters() async {
        let html = await renderStrictHTML("[link](foo\\(and\\(bar\\))\n[link](foo\\)\\:)\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"foo(and(bar)\">link</a>\n<a href=\"foo):\">link</a></p>")
    }

    @Test("Inline link destinations accept literal emphasis delimiters")
    func inlineLinkDestinationsAcceptLiteralEmphasisDelimiters() async {
        let html = await renderStrictHTML("[foo *bar](baz*)\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"baz*\">foo *bar</a></p>")
    }

    @Test("Malformed bracket labels allow surrounding emphasis to close")
    func malformedBracketLabelsAllowSurroundingEmphasisToClose() async {
        let html = await renderStrictHTML("*foo [bar* baz]\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><em>foo [bar</em> baz]</p>")
    }

    @Test("Inline link title accepts escaped quote and multiline spacing")
    func inlineLinkTitleAcceptsEscapedQuoteAndMultilineSpacing() async {
        let html = await renderStrictHTML("""
        [quote](/url "title \\\"&quot;")
        [multiline](   /uri
          "title"  )
        """)

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"/url\" title=\"title &quot;&quot;\">quote</a>\n<a href=\"/uri\" title=\"title\">multiline</a></p>")
    }

    @Test("Inline link parser preserves text after closing parenthesis")
    func inlineLinkParserPreservesTextAfterClosingParenthesis() async {
        let html = await renderStrictHTML("[link](/uri)tail\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"/uri\">link</a>tail</p>")
    }

    @Test("Inline link labels parse nested emphasis")
    func inlineLinkLabelsParseNestedEmphasis() async {
        let emphasized = await renderStrictHTML("*foo [*bar*](/url)*\n")
        let strong = await renderStrictHTML("**foo [*bar*](/url)**\n")

        #expect(emphasized == "<p data-rhoe-node=\"paragraph\"><em>foo <a href=\"/url\"><em>bar</em></a></em></p>")
        #expect(strong == "<p data-rhoe-node=\"paragraph\"><strong>foo <a href=\"/url\"><em>bar</em></a></strong></p>")
    }

    @Test("Inline links support nested bracket labels without nested links")
    func inlineLinksSupportNestedBracketLabelsWithoutNestedLinks() async {
        let html = await renderStrictHTML("[link [foo [bar]]](/uri)\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"/uri\">link [foo [bar]]</a></p>")
    }

    @Test("Inline links suppress outer links when label contains a link")
    func inlineLinksSuppressOuterLinksWhenLabelContainsLink() async {
        let direct = await renderStrictHTML("[foo [bar](/uri)](/uri)\n")
        let unclosedOuter = await renderStrictHTML("[link [bar](/uri)\n")
        let emphasized = await renderStrictHTML("[foo *[bar [baz](/uri)](/uri)*](/uri)\n")

        #expect(direct == "<p data-rhoe-node=\"paragraph\">[foo <a href=\"/uri\">bar</a>](/uri)</p>")
        #expect(unclosedOuter == "<p data-rhoe-node=\"paragraph\">[link <a href=\"/uri\">bar</a></p>")
        #expect(emphasized == "<p data-rhoe-node=\"paragraph\">[foo <em>[bar <a href=\"/uri\">baz</a>](/uri)</em>](/uri)</p>")
    }

    @Test("Reference link labels use token inline parsing")
    func referenceLinkLabelsUseTokenInlineParsing() async {
        let html = await renderStrictHTML("""
        [link *foo **bar** `#`*][ref]

        [ref]: /uri

        """)

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"/uri\">link <em>foo <strong>bar</strong> <code>#</code></em></a></p>")
    }

    @Test("Reference links suppress outer links when labels contain links")
    func referenceLinksSuppressOuterLinksWhenLabelsContainLinks() async {
        let direct = await renderStrictHTML("""
        [foo [bar](/uri)][ref]

        [ref]: /uri

        """)
        let nestedReference = await renderStrictHTML("""
        [foo *bar [baz][ref]*][ref]

        [ref]: /uri

        """)

        #expect(direct == "<p data-rhoe-node=\"paragraph\">[foo <a href=\"/uri\">bar</a>]<a href=\"/uri\">ref</a></p>")
        #expect(nestedReference == "<p data-rhoe-node=\"paragraph\">[foo <em>bar <a href=\"/uri\">baz</a></em>]<a href=\"/uri\">ref</a></p>")
    }

    @Test("Scheme autolinks accept CommonMark schemes")
    func schemeAutolinksAcceptCommonMarkSchemes() async {
        let html = await renderStrictHTML("<a+b+c:d>\n<localhost:5001/foo>\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"a+b+c:d\">a+b+c:d</a>\n<a href=\"localhost:5001/foo\">localhost:5001/foo</a></p>")
    }

    @Test("Email autolinks render mailto destinations")
    func emailAutolinksRenderMailtoDestinations() async {
        let html = await renderStrictHTML("<foo+special@Bar.baz-bar0.com>\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"mailto:foo+special@Bar.baz-bar0.com\">foo+special@Bar.baz-bar0.com</a></p>")
    }

    @Test("Autolinks reject whitespace in angle brackets")
    func autolinksRejectWhitespaceInAngleBrackets() async {
        let html = await renderStrictHTML("< https://foo.bar >\n<https://foo.bar/baz bim>\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">&lt; https://foo.bar &gt;\n&lt;https://foo.bar/baz bim&gt;</p>")
    }

    @Test("Autolink href percent-encodes backslash and bracket characters")
    func autolinkHrefPercentEncodesBackslashAndBracketCharacters() async {
        let html = await renderStrictHTML("<https://example.com?find=\\*>\n<https://example.com/\\[\\>\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"https://example.com?find=%5C*\">https://example.com?find=\\*</a>\n<a href=\"https://example.com/%5C%5B%5C\">https://example.com/\\[\\</a></p>")
    }

    @Test("Autolinks encode backticks and invalid escaped emails stay literal")
    func autolinksEncodeBackticksAndInvalidEscapedEmailsStayLiteral() async {
        let html = await renderStrictHTML("<https://foo.bar.`baz>\n<foo\\+@bar.example.com>\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"https://foo.bar.%60baz\">https://foo.bar.`baz</a>\n&lt;foo+@bar.example.com&gt;</p>")
    }

    @Test("Emphasis delimiters respect CommonMark flanking rules")
    func emphasisDelimitersRespectCommonMarkFlankingRules() async {
        let leadingSpace = await renderStrictHTML("a * foo bar*\n")
        let intrawordUnderscore = await renderStrictHTML("foo_bar_\n")
        let mismatchedMarkers = await renderStrictHTML("_foo*\n")

        #expect(leadingSpace == "<p data-rhoe-node=\"paragraph\">a * foo bar*</p>")
        #expect(intrawordUnderscore == "<p data-rhoe-node=\"paragraph\">foo_bar_</p>")
        #expect(mismatchedMarkers == "<p data-rhoe-node=\"paragraph\">_foo*</p>")
    }

    @Test("Emphasis delimiter runs support residual opener and closer markers")
    func emphasisDelimiterRunsSupportResidualOpenersAndClosers() async {
        let leadingResidual = await renderStrictHTML("**foo*\n")
        let trailingResidual = await renderStrictHTML("*foo**\n")
        let strongLeadingResidual = await renderStrictHTML("***foo**\n")
        let strongTrailingResidual = await renderStrictHTML("**foo***\n")

        #expect(leadingResidual == "<p data-rhoe-node=\"paragraph\">*<em>foo</em></p>")
        #expect(trailingResidual == "<p data-rhoe-node=\"paragraph\"><em>foo</em>*</p>")
        #expect(strongLeadingResidual == "<p data-rhoe-node=\"paragraph\">*<strong>foo</strong></p>")
        #expect(strongTrailingResidual == "<p data-rhoe-node=\"paragraph\"><strong>foo</strong>*</p>")
    }

    @Test("Emphasis delimiter runs nest repeated strong and emphasis wrappers")
    func emphasisDelimiterRunsNestRepeatedStrongAndEmphasisWrappers() async {
        let triple = await renderStrictHTML("***foo***\n")
        let quadruple = await renderStrictHTML("****foo****\n")
        let sextuple = await renderStrictHTML("******foo******\n")
        let mixedText = await renderStrictHTML("foo***bar***baz\n")

        #expect(triple == "<p data-rhoe-node=\"paragraph\"><em><strong>foo</strong></em></p>")
        #expect(quadruple == "<p data-rhoe-node=\"paragraph\"><strong><strong>foo</strong></strong></p>")
        #expect(sextuple == "<p data-rhoe-node=\"paragraph\"><strong><strong><strong>foo</strong></strong></strong></p>")
        #expect(mixedText == "<p data-rhoe-node=\"paragraph\">foo<em><strong>bar</strong></em>baz</p>")
    }

    @Test("GitHub flavor collapses repeated strong delimiter runs")
    func githubFlavorCollapsesRepeatedStrongDelimiterRuns() async {
        let nestedStrong = await renderGitHubHTML("__foo, __bar__, baz__\n")
        let longRun = await renderGitHubHTML("foo******bar*********baz\n")
        let quadruple = await renderGitHubHTML("****foo****\n")
        let quintuple = await renderGitHubHTML("_____foo_____\n")

        #expect(nestedStrong == "<p data-rhoe-node=\"paragraph\"><strong>foo, bar, baz</strong></p>")
        #expect(longRun == "<p data-rhoe-node=\"paragraph\">foo<strong>bar</strong>***baz</p>")
        #expect(quadruple == "<p data-rhoe-node=\"paragraph\"><strong>foo</strong></p>")
        #expect(quintuple == "<p data-rhoe-node=\"paragraph\"><em><strong>foo</strong></em></p>")
    }

    @Test("Emphasis delimiter runs honor the CommonMark rule of three")
    func emphasisDelimiterRunsHonorCommonMarkRuleOfThree() async {
        let literalMiddleRun = await renderStrictHTML("*foo**bar*\n")
        let nestedCloseRun = await renderStrictHTML("*foo *bar**\n")

        #expect(literalMiddleRun == "<p data-rhoe-node=\"paragraph\"><em>foo**bar</em></p>")
        #expect(nestedCloseRun == "<p data-rhoe-node=\"paragraph\"><em>foo <em>bar</em></em></p>")
    }

    @Test("Underscore delimiter runs preserve residual markers")
    func underscoreDelimiterRunsPreserveResidualMarkers() async {
        let nestedUnderscore = await renderStrictHTML("__foo_ bar_\n")
        let leadingResidual = await renderStrictHTML("__foo_\n")
        let trailingResidual = await renderStrictHTML("_foo__\n")

        #expect(nestedUnderscore == "<p data-rhoe-node=\"paragraph\"><em><em>foo</em> bar</em></p>")
        #expect(leadingResidual == "<p data-rhoe-node=\"paragraph\">_<em>foo</em></p>")
        #expect(trailingResidual == "<p data-rhoe-node=\"paragraph\"><em>foo</em>_</p>")
    }

    @Test("Literal inner delimiter openers remain inside outer emphasis")
    func literalInnerDelimiterOpenersRemainInsideOuterEmphasis() async {
        let crossedUnderscore = await renderStrictHTML("*foo _bar* baz_\n")
        let crossedStrong = await renderStrictHTML("*foo __bar *baz bim__ bam*\n")

        #expect(crossedUnderscore == "<p data-rhoe-node=\"paragraph\"><em>foo _bar</em> baz_</p>")
        #expect(crossedStrong == "<p data-rhoe-node=\"paragraph\"><em>foo <strong>bar *baz bim</strong> bam</em></p>")
    }

    @Test("Emphasis can wrap delimiter literals")
    func emphasisCanWrapDelimiterLiterals() async {
        let emphasizedUnderscore = await renderStrictHTML("foo *_*\n")
        let strongUnderscore = await renderStrictHTML("foo **_**\n")
        let emphasizedStar = await renderStrictHTML("foo _*_\n")
        let strongStar = await renderStrictHTML("foo __*__\n")

        #expect(emphasizedUnderscore == "<p data-rhoe-node=\"paragraph\">foo <em>_</em></p>")
        #expect(strongUnderscore == "<p data-rhoe-node=\"paragraph\">foo <strong>_</strong></p>")
        #expect(emphasizedStar == "<p data-rhoe-node=\"paragraph\">foo <em>*</em></p>")
        #expect(strongStar == "<p data-rhoe-node=\"paragraph\">foo <strong>*</strong></p>")
    }

    @Test("Inline link destinations percent-encode CommonMark URL scalars")
    func inlineLinkDestinationsPercentEncodeCommonMarkURLScalars() async {
        let html = await renderStrictHTML("[backslash](foo\\bar)\n[entity](foo%20b&auml;)\n[quote](\"title\")\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"foo%5Cbar\">backslash</a>\n<a href=\"foo%20b%C3%A4\">entity</a>\n<a href=\"%22title%22\">quote</a></p>")
    }

    @Test("Reference definitions resolve shortcut and full links")
    func referenceDefinitionsResolveShortcutAndFullLinks() async {
        let html = await renderStrictHTML("""
        [foo]: /url "title"
        [Bar]: /bar

        [foo] and [bar][BAR]

        """)

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"/url\" title=\"title\">foo</a> and <a href=\"/bar\">bar</a></p>")
    }

    @Test("Reference definitions resolve forward references and duplicate definitions use first destination")
    func referenceDefinitionsResolveForwardReferencesAndFirstDefinitionWins() async {
        let html = await renderStrictHTML("""
        [foo]

        [foo]: /first
        [foo]: /second

        """)

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"/first\">foo</a></p>")
    }

    @Test("Shortcut reference labels preserve escaped closing brackets")
    func shortcutReferenceLabelsPreserveEscapedClosingBrackets() async {
        let html = await renderStrictHTML("""
        [Foo*bar\\]]:my_(url) 'title (with parens)'

        [Foo*bar\\]]

        """)

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"my_(url)\" title=\"title (with parens)\">Foo*bar]</a></p>")
    }

    @Test("Shortcut reference labels ending in emphasis delimiters stay referenceable")
    func shortcutReferenceLabelsEndingInEmphasisDelimitersStayReferenceable() async {
        let html = await renderStrictHTML("""
        [foo*]: /url

        *[foo*]

        """)

        #expect(html == "<p data-rhoe-node=\"paragraph\">*<a href=\"/url\">foo*</a></p>")
    }

    @Test("Escaped opening bracket blocks shortcut reference resolution")
    func escapedOpeningBracketBlocksShortcutReferenceResolution() async {
        let html = await renderStrictHTML("""
        \\[foo]

        [foo]: /url "title"

        """)

        #expect(html == "<p data-rhoe-node=\"paragraph\">[foo]</p>")
    }

    @Test("Explicit reference labels with escapes stay literal")
    func explicitReferenceLabelsWithEscapesStayLiteral() async {
        let escapedBang = await renderStrictHTML("""
        [bar][foo\\!]

        [foo!]: /url

        """)
        let escapedLeftBracket = await renderStrictHTML("""
        [foo][ref\\[]

        [ref\\[]: /uri

        """)

        #expect(escapedBang == "<p data-rhoe-node=\"paragraph\">[bar][foo!]</p>")
        #expect(escapedLeftBracket == "<p data-rhoe-node=\"paragraph\"><a href=\"/uri\">foo</a></p>")
    }

    @Test("Reference labels use CommonMark Unicode case folding")
    func referenceLabelsUseCommonMarkUnicodeCaseFolding() async {
        let html = await renderStrictHTML("""
        [ẞ]

        [SS]: /url

        """)

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"/url\">ẞ</a></p>")
    }

    @Test("Reference definitions alone render no visible output")
    func referenceDefinitionsAloneRenderNoVisibleOutput() async {
        let html = await renderStrictHTML("[foo]: /url\n")

        #expect(html == "")
    }

    @Test("Reference definitions reject blank-line titles and malformed labels")
    func referenceDefinitionsRejectBlankLineTitlesAndMalformedLabels() async {
        let blankTitle = await renderStrictHTML("""
        [foo]: /url 'title

        with blank line'

        [foo]

        """)
        let malformedLabel = await renderStrictHTML("""
        [foo][ref[]

        [ref[]: /uri

        """)

        #expect(blankTitle == "<p data-rhoe-node=\"paragraph\">[foo]: /url &#39;title</p><p data-rhoe-node=\"paragraph\">with blank line&#39;</p><p data-rhoe-node=\"paragraph\">[foo]</p>")
        #expect(malformedLabel == "<p data-rhoe-node=\"paragraph\">[foo][ref[]</p><p data-rhoe-node=\"paragraph\">[ref[]: /uri</p>")
    }

    @Test("Collapsed references and image references resolve")
    func collapsedReferencesAndImageReferencesResolve() async {
        let html = await renderStrictHTML("""
        [foo]: /url
        [image]: /image.png "Image title"

        [foo][] and ![image][]

        """)

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"/url\">foo</a> and <img alt=\"image\" src=\"/image.png\" title=\"Image title\"></p>")
    }

    @Test("Strict conformance rendering keeps standalone images inline")
    func strictConformanceRenderingKeepsStandaloneImagesInline() async {
        let html = await renderStrictHTML("![foo](/url \"title\")\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\"><img alt=\"foo\" src=\"/url\" title=\"title\"></p>")
    }

    @Test("Image alt text renders as CommonMark plain text")
    func imageAltTextRendersAsCommonMarkPlainText() async {
        let emphasized = await renderStrictHTML("![foo *bar*](/url)\n")
        let nestedLink = await renderStrictHTML("![foo [bar](/url)](/url2)\n")
        let nestedImage = await renderStrictHTML("![foo ![bar](/url)](/url2)\n")

        #expect(emphasized == "<p data-rhoe-node=\"paragraph\"><img alt=\"foo bar\" src=\"/url\"></p>")
        #expect(nestedLink == "<p data-rhoe-node=\"paragraph\"><img alt=\"foo bar\" src=\"/url2\"></p>")
        #expect(nestedImage == "<p data-rhoe-node=\"paragraph\"><img alt=\"foo bar\" src=\"/url2\"></p>")
    }

    @Test("Formatted image reference labels resolve before inline reference links")
    func formattedImageReferenceLabelsResolveBeforeInlineReferenceLinks() async {
        let shortcut = await renderStrictHTML("""
        ![foo *bar*]

        [foo *bar*]: train.jpg "train & tracks"

        """)
        let collapsed = await renderStrictHTML("""
        ![*foo* bar][]

        [*foo* bar]: /url "title"

        """)
        let full = await renderStrictHTML("""
        ![foo *bar*][foobar]

        [FOOBAR]: train.jpg "train & tracks"

        """)

        #expect(shortcut == "<p data-rhoe-node=\"paragraph\"><img alt=\"foo bar\" src=\"train.jpg\" title=\"train &amp; tracks\"></p>")
        #expect(collapsed == "<p data-rhoe-node=\"paragraph\"><img alt=\"foo bar\" src=\"/url\" title=\"title\"></p>")
        #expect(full == "<p data-rhoe-node=\"paragraph\"><img alt=\"foo bar\" src=\"train.jpg\" title=\"train &amp; tracks\"></p>")
    }

    @Test("Escaped image markers keep link and image precedence")
    func escapedImageMarkersKeepLinkAndImagePrecedence() async {
        let escapedBracket = await renderStrictHTML("""
        !\\[foo]

        [foo]: /url "title"

        """)
        let escapedBang = await renderStrictHTML("""
        \\![foo]

        [foo]: /url "title"

        """)

        #expect(escapedBracket == "<p data-rhoe-node=\"paragraph\">![foo]</p>")
        #expect(escapedBang == "<p data-rhoe-node=\"paragraph\">!<a href=\"/url\" title=\"title\">foo</a></p>")
    }

    @Test("Block quote reference definitions leave an empty quote container")
    func blockQuoteReferenceDefinitionsLeaveEmptyQuoteContainer() async {
        let html = await renderStrictHTML("""
        [foo]

        > [foo]: /url

        """)

        #expect(html == "<p data-rhoe-node=\"paragraph\"><a href=\"/url\">foo</a></p><blockquote data-rhoe-node=\"blockquote\">\n</blockquote>")
    }

    @Test("Reference definitions accept indented continuations and multiline titles")
    func referenceDefinitionsAcceptIndentedContinuationsAndMultilineTitles() async {
        let indented = await renderStrictHTML("""
           [foo]: 
              /url  
                   'the title'  

        [foo]

        """)
        let multilineTitle = await renderStrictHTML("""
        [foo]: /url '
        title
        line1
        line2
        '

        [foo]

        """)

        #expect(indented == "<p data-rhoe-node=\"paragraph\"><a href=\"/url\" title=\"the title\">foo</a></p>")
        #expect(multilineTitle == "<p data-rhoe-node=\"paragraph\"><a href=\"/url\" title=\"\ntitle\nline1\nline2\n\">foo</a></p>")
    }

    @Test("Reference definitions reject unseparated titles and ignore fenced code")
    func referenceDefinitionsRejectUnseparatedTitlesAndIgnoreFencedCode() async {
        let unseparated = await renderStrictHTML("""
        [foo]: <bar>(baz)

        [foo]

        """)
        let fenced = await renderStrictHTML("""
        ```
        [foo]: /url
        ```

        [foo]

        """)

        #expect(unseparated == "<p data-rhoe-node=\"paragraph\">[foo]: <bar>(baz)</p><p data-rhoe-node=\"paragraph\">[foo]</p>")
        #expect(fenced == "<pre><code data-rhoe-node=\"code\">[foo]: /url\n</code></pre><p data-rhoe-node=\"paragraph\">[foo]</p>")
    }

    @Test("Reference definitions support multiline labels and cannot interrupt paragraphs")
    func referenceDefinitionsSupportMultilineLabelsAndCannotInterruptParagraphs() async {
        let multilineLabel = await renderStrictHTML("""
        [
        foo
        ]: /url
        bar

        """)
        let interruptingParagraph = await renderStrictHTML("""
        Foo
        [bar]: /baz

        [bar]

        """)

        #expect(multilineLabel == "<p data-rhoe-node=\"paragraph\">bar</p>")
        #expect(interruptingParagraph == "<p data-rhoe-node=\"paragraph\">Foo\n[bar]: /baz</p><p data-rhoe-node=\"paragraph\">[bar]</p>")
    }

    @Test("Block quotes reparse contained Markdown blocks")
    func blockQuotesReparseContainedMarkdownBlocks() async {
        let html = await renderStrictHTML("""
        > # Foo
        > bar
        > baz

        """)

        #expect(html == "<blockquote data-rhoe-node=\"blockquote\">\n<section id=\"foo\" data-rhoe-node=\"Section\"><h1>Foo</h1><p data-rhoe-node=\"paragraph\">bar\nbaz</p></section>\n</blockquote>")
    }

    @Test("Block quotes support lazy paragraph continuation lines")
    func blockQuotesSupportLazyParagraphContinuationLines() async {
        let simple = await renderStrictHTML("""
        > bar
        baz

        """)
        let interleaved = await renderStrictHTML("""
        > bar
        baz
        > foo

        """)

        #expect(simple == "<blockquote data-rhoe-node=\"blockquote\">\n<p data-rhoe-node=\"paragraph\">bar\nbaz</p>\n</blockquote>")
        #expect(interleaved == "<blockquote data-rhoe-node=\"blockquote\">\n<p data-rhoe-node=\"paragraph\">bar\nbaz\nfoo</p>\n</blockquote>")
    }

    @Test("Empty block quotes render without phantom blank content")
    func emptyBlockQuotesRenderWithoutPhantomBlankContent() async {
        let single = await renderStrictHTML(">\n")
        let repeated = await renderStrictHTML(">\n>  \n> \n")

        #expect(single == "<blockquote data-rhoe-node=\"blockquote\">\n</blockquote>")
        #expect(repeated == "<blockquote data-rhoe-node=\"blockquote\">\n</blockquote>")
    }

    @Test("GitHub flavor preserves empty block quote containers")
    func githubFlavorPreservesEmptyBlockQuoteContainers() async {
        let html = await renderGitHubHTML(">\n")

        #expect(html == "<blockquote data-rhoe-node=\"blockquote\">\n</blockquote>")
    }

    @Test("GitHub flavor disables Rhoe wikilinks")
    func githubFlavorDisablesRhoeWikilinks() async {
        let html = await renderGitHubHTML("""
        [[foo]]

        [[[foo]]]: /url

        """)

        #expect(!html.contains("class=\"wikilink\""))
        #expect(html.contains("[[foo]]"))
    }

    @Test("Blank quoted lines stop lazy block quote continuation")
    func blankQuotedLinesStopLazyBlockQuoteContinuation() async {
        let html = await renderStrictHTML("""
        > bar
        >
        baz

        """)

        #expect(html == "<blockquote data-rhoe-node=\"blockquote\">\n<p data-rhoe-node=\"paragraph\">bar</p>\n</blockquote><p data-rhoe-node=\"paragraph\">baz</p>")
    }

    @Test("Nested block quote marker depth renders nested containers")
    func nestedBlockQuoteMarkerDepthRendersNestedContainers() async {
        let html = await renderStrictHTML("""
        > > > foo
        bar

        """)

        #expect(html == "<blockquote data-rhoe-node=\"blockquote\">\n<blockquote data-rhoe-node=\"blockquote\">\n<blockquote data-rhoe-node=\"blockquote\">\n<p data-rhoe-node=\"paragraph\">foo\nbar</p>\n</blockquote>\n</blockquote>\n</blockquote>")
    }

    @Test("Mixed-depth block quote markers lazily continue nested paragraph")
    func mixedDepthBlockQuoteMarkersLazilyContinueNestedParagraph() async {
        let html = await renderStrictHTML("""
        >>> foo
        > bar
        >>baz

        """)

        #expect(html == "<blockquote data-rhoe-node=\"blockquote\">\n<blockquote data-rhoe-node=\"blockquote\">\n<blockquote data-rhoe-node=\"blockquote\">\n<p data-rhoe-node=\"paragraph\">foo\nbar\nbaz</p>\n</blockquote>\n</blockquote>\n</blockquote>")
    }

    @Test("Block quote lazy continuation keeps setext-looking line literal")
    func blockQuoteLazyContinuationKeepsSetextLookingLineLiteral() async {
        let html = await renderStrictHTML("""
        > foo
        bar
        ===

        """)

        #expect(html == "<blockquote data-rhoe-node=\"blockquote\">\n<p data-rhoe-node=\"paragraph\">foo\nbar\n===</p>\n</blockquote>")
    }

    @Test("Block quote lazy continuation keeps indented list marker literal")
    func blockQuoteLazyContinuationKeepsIndentedListMarkerLiteral() async {
        let html = await renderStrictHTML("""
        > foo
            - bar

        """)

        #expect(html == "<blockquote data-rhoe-node=\"blockquote\">\n<p data-rhoe-node=\"paragraph\">foo\n- bar</p>\n</blockquote>")
    }

    @Test("Block quote lazy continuation reaches nested list item blockquotes")
    func blockQuoteLazyContinuationReachesNestedListItemBlockquotes() async {
        let html = await renderStrictHTML("""
        > 1. > Blockquote
        continued here.

        """)

        #expect(html == """
        <blockquote data-rhoe-node="blockquote">
        <ol data-rhoe-node="list">
        <li><blockquote data-rhoe-node="blockquote">
        <p data-rhoe-node="paragraph">Blockquote
        continued here.</p>
        </blockquote></li>
        </ol>
        </blockquote>
        """)
    }

    @Test("Quoted blank lines keep following partial markers in the same quote")
    func quotedBlankLinesKeepFollowingPartialMarkersInSameQuote() async {
        let html = await renderStrictHTML("""
        >>- one
        >>
          >  > two

        """)

        #expect(html == """
        <blockquote data-rhoe-node="blockquote">
        <blockquote data-rhoe-node="blockquote">
        <ul data-rhoe-node="list">
        <li>one</li>
        </ul>
        <p data-rhoe-node="paragraph">two</p>
        </blockquote>
        </blockquote>
        """)
    }

    @Test("Setext equals underline promotes paragraph to h1")
    func setextEqualsUnderlinePromotesParagraphToH1() async {
        let html = await renderStrictHTML("Foo *bar*\n=========\n")

        #expect(html.contains("<h1>Foo <em>bar</em></h1>"))
    }

    @Test("Setext dash underline promotes paragraph to h2")
    func setextDashUnderlinePromotesParagraphToH2() async {
        let html = await renderStrictHTML("Foo *bar*\n---------\n")

        #expect(html.contains("<h2>Foo <em>bar</em></h2>"))
    }

    @Test("Setext heading supports multiline content")
    func setextHeadingSupportsMultilineContent() async {
        let html = await renderStrictHTML("Foo\nBar\n---\n")

        #expect(html.contains("<h2>Foo\nBar</h2>"))
    }

    @Test("Setext heading preserves escaped punctuation")
    func setextHeadingPreservesEscapedPunctuation() async {
        let html = await renderStrictHTML("\\> foo\n------\n")

        #expect(html.contains("<h2>&gt; foo</h2>"))
    }

    @Test("Setext heading trims trailing tabs")
    func setextHeadingTrimsTrailingTabs() async {
        let html = await renderStrictHTML("  Foo *bar\nbaz*\t\n====\n")

        #expect(html.contains("<h1>Foo <em>bar\nbaz</em></h1>"))
    }

    @Test("Setext headings take precedence over multiline code spans and HTML tags")
    func setextHeadingsTakePrecedenceOverMultilineInlineConstructs() async {
        let html = await renderStrictHTML("""
        `Foo
        ----
        `

        <a title="a lot
        ---
        of dashes"/>

        """)

        #expect(html == """
        <section id="foo" data-rhoe-node="Section"><h2>`Foo</h2><p data-rhoe-node="paragraph">`</p></section><section id="a-titlea-lot" data-rhoe-node="Section"><h2>&lt;a title=&quot;a lot</h2><p data-rhoe-node="paragraph">of dashes&quot;/&gt;</p></section>
        """)
    }

    @Test("Strict mode treats document-start dashes as Markdown")
    func strictModeTreatsDocumentStartDashesAsMarkdown() async {
        let html = await renderStrictHTML("---\n---\n")

        #expect(html == "<hr><hr>")
    }

    @Test("Default mode still parses YAML frontmatter")
    func defaultModeStillParsesYAMLFrontmatter() async {
        let parser = DocumentParser()
        let result = await parser.parse("---\ntitle: Frontmatter\n---\n# Body\n")

        if case .string(let title) = result.document.metadata.yamlFrontmatter?["title"] {
            #expect(title == "Frontmatter")
        } else {
            #expect(Bool(false), "Expected title frontmatter string")
        }
    }

    @Test("List item terminal newline does not become content")
    func listItemTerminalNewlineDoesNotBecomeContent() async {
        let html = await renderStrictHTML("- foo\n")

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li>foo</li>\n</ul>")
    }

    @Test("List marker padding up to four spaces is stripped")
    func listMarkerPaddingUpToFourSpacesIsStripped() async {
        let html = await renderStrictHTML("-    foo\n")

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li>foo</li>\n</ul>")
    }

    @Test("Ordered list markers are limited to nine digits")
    func orderedListMarkersAreLimitedToNineDigits() async {
        let valid = await renderStrictHTML("123456789. ok\n")
        let invalid = await renderStrictHTML("1234567890. not ok\n")

        #expect(valid.contains("<ol"))
        #expect(valid.contains("start=\"123456789\""))
        #expect(valid.contains("<li>ok</li>"))
        #expect(invalid == "<p data-rhoe-node=\"paragraph\">1234567890. not ok</p>")
    }

    @Test("Ordered dot and paren delimiters start separate lists")
    func orderedDotAndParenDelimitersStartSeparateLists() async {
        let html = await renderStrictHTML("1. foo\n2. bar\n3) baz\n")

        #expect(html == "<ol data-rhoe-node=\"list\">\n<li>foo</li>\n<li>bar</li>\n</ol><ol data-rhoe-node=\"list\" start=\"3\">\n<li>baz</li>\n</ol>")
    }

    @Test("Ordered markers above one do not interrupt paragraphs")
    func orderedMarkersAboveOneDoNotInterruptParagraphs() async {
        let html = await renderStrictHTML("""
        The number of windows in my house is
        14.  The number of doors is 6.

        """)

        #expect(html == "<p data-rhoe-node=\"paragraph\">The number of windows in my house is\n14.  The number of doors is 6.</p>")
    }

    @Test("Empty list markers do not interrupt paragraphs")
    func emptyListMarkersDoNotInterruptParagraphs() async {
        let html = await renderStrictHTML("""
        foo
        *

        foo
        1.

        """)

        #expect(html == "<p data-rhoe-node=\"paragraph\">foo\n*</p><p data-rhoe-node=\"paragraph\">foo\n1.</p>")
    }

    @Test("Empty bullet marker starts an empty list item")
    func emptyBulletMarkerStartsEmptyListItem() async {
        let html = await renderStrictHTML("-\n- bar\n")

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li></li>\n<li>bar</li>\n</ul>")
    }

    @Test("Empty marker line followed by content stays tight")
    func emptyMarkerLineFollowedByContentStaysTight() async {
        let html = await renderStrictHTML("-   \n  foo\n")

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li>foo</li>\n</ul>")
    }

    @Test("Middle empty bullet marker remains a list item")
    func middleEmptyBulletMarkerRemainsListItem() async {
        let html = await renderStrictHTML("- foo\n-\n- bar\n")

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li>foo</li>\n<li></li>\n<li>bar</li>\n</ul>")
    }

    @Test("Middle empty ordered marker remains a list item")
    func middleEmptyOrderedMarkerRemainsListItem() async {
        let html = await renderStrictHTML("1. foo\n2.\n3. bar\n")

        #expect(html == "<ol data-rhoe-node=\"list\">\n<li>foo</li>\n<li></li>\n<li>bar</li>\n</ol>")
    }

    @Test("Single empty bullet marker renders an empty list item")
    func singleEmptyBulletMarkerRendersEmptyListItem() async {
        let html = await renderStrictHTML("*\n")

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li></li>\n</ul>")
    }

    @Test("Blank line terminating a list item keeps the list tight")
    func blankLineTerminatingListItemKeepsListTight() async {
        let html = await renderStrictHTML("- one\n\n two\n")

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li>one</li>\n</ul><p data-rhoe-node=\"paragraph\">two</p>")
    }

    @Test("Empty item followed by two-space paragraph stays outside list")
    func emptyItemFollowedByTwoSpaceParagraphStaysOutsideList() async {
        let html = await renderStrictHTML("-\n\n  foo\n")

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li></li>\n</ul><p data-rhoe-node=\"paragraph\">foo</p>")
    }

    @Test("Fenced code blank lines do not loosen sibling list items")
    func fencedCodeBlankLinesDoNotLoosenSiblingListItems() async {
        let html = await renderStrictHTML("""
        - a
        - ```
          b


          ```
        - c

        """)

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li>a</li>\n<li><pre><code data-rhoe-node=\"code\">b\n\n\n</code></pre></li>\n<li>c</li>\n</ul>")
    }

    @Test("Blank lines between sibling items make the list loose")
    func blankLinesBetweenSiblingItemsMakeListLoose() async {
        let html = await renderStrictHTML("""
        - foo

        - bar


        - baz

        """)

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li><p data-rhoe-node=\"paragraph\">foo</p></li>\n<li><p data-rhoe-node=\"paragraph\">bar</p></li>\n<li><p data-rhoe-node=\"paragraph\">baz</p></li>\n</ul>")
    }

    @Test("Indented code after blank line makes list item loose")
    func indentedCodeAfterBlankLineMakesListItemLoose() async {
        let html = await renderStrictHTML("- foo\n\n      bar\n")

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li><p data-rhoe-node=\"paragraph\">foo</p><pre><code data-rhoe-node=\"code\">bar\n</code></pre></li>\n</ul>")
    }

    @Test("Nested child blank line does not loosen ancestor list item")
    func nestedChildBlankLineDoesNotLoosenAncestorListItem() async {
        let html = await renderStrictHTML("""
        - foo
          - bar
            - baz


              bim

        """)

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li>foo\n<ul data-rhoe-node=\"list\">\n<li>bar\n<ul data-rhoe-node=\"list\">\n<li><p data-rhoe-node=\"paragraph\">baz</p><p data-rhoe-node=\"paragraph\">bim</p></li>\n</ul></li>\n</ul></li>\n</ul>")
    }

    @Test("Loose list item absorbs blank-line indented continuation")
    func looseListItemAbsorbsBlankLineIndentedContinuation() async {
        let html = await renderStrictHTML("- one\n\n  two\n")

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li><p data-rhoe-node=\"paragraph\">one</p><p data-rhoe-node=\"paragraph\">two</p></li>\n</ul>")
    }

    @Test("Tab padded bullet content can start an indented code block")
    func tabPaddedBulletContentCanStartIndentedCodeBlock() async {
        let html = await renderStrictHTML("-\t\tfoo\n")

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li><pre><code data-rhoe-node=\"code\">  foo\n</code></pre></li>\n</ul>")
    }

    @Test("Tight nested list keeps parent paragraph unwrapped")
    func tightNestedListKeepsParentParagraphUnwrapped() async {
        let html = await renderStrictHTML("- foo\n  - bar\n")

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li>foo\n<ul data-rhoe-node=\"list\">\n<li>bar</li>\n</ul></li>\n</ul>")
    }

    @Test("Sibling list markers may be indented up to three columns")
    func siblingListMarkersMayBeIndentedUpToThreeColumns() async {
        let html = await renderStrictHTML("- foo\n - bar\n  - baz\n   - boo\n")

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li>foo</li>\n<li>bar</li>\n<li>baz</li>\n<li>boo</li>\n</ul>")
    }

    @Test("Overindented list marker remains literal continuation text")
    func overindentedListMarkerRemainsLiteralContinuationText() async {
        let html = await renderStrictHTML("""
        - a
         - b
          - c
           - d
            - e

        """)

        #expect(html == """
        <ul data-rhoe-node="list">
        <li>a</li>
        <li>b</li>
        <li>c</li>
        <li>d
        - e</li>
        </ul>
        """)
    }

    @Test("List item content can contain a thematic break")
    func listItemContentCanContainThematicBreak() async {
        let html = await renderStrictHTML("- Foo\n- * * *\n")

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li>Foo</li>\n<li><hr></li>\n</ul>")
    }

    @Test("Tight list sections render as flat heading content")
    func tightListSectionsRenderAsFlatHeadingContent() async {
        let html = await renderStrictHTML("""
        - # Foo
        - Bar
          ---
          baz

        """)

        #expect(html == """
      <ul data-rhoe-node="list">
      <li><h1>Foo</h1></li>
      <li><h2>Bar</h2>
      baz</li>
      </ul>
      """)
  }

    @Test("Thematic break precedence beats star list marker")
    func thematicBreakPrecedenceBeatsStarListMarker() async {
        let html = await renderStrictHTML("* Foo\n* * *\n* Bar\n")

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li>Foo</li>\n</ul><hr><ul data-rhoe-node=\"list\">\n<li>Bar</li>\n</ul>")
    }

    @Test("Loose ordered list item absorbs nested fenced code")
    func looseOrderedListItemAbsorbsNestedFencedCode() async {
        let html = await renderStrictHTML("""
        1.  foo

            ```
            bar
            ```

        """)

        #expect(html == "<ol data-rhoe-node=\"list\">\n<li><p data-rhoe-node=\"paragraph\">foo</p><pre><code data-rhoe-node=\"code\">bar\n</code></pre></li>\n</ol>")
    }

    @Test("Setext promotion does not cross blank line")
    func setextPromotionDoesNotCrossBlankLine() async {
        let html = await renderStrictHTML("Foo\nbar\n\n---\n\nbaz\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">Foo\nbar</p><hr><p data-rhoe-node=\"paragraph\">baz</p>")
    }

    @Test("Indented lines continue an open paragraph")
    func indentedLinesContinueOpenParagraph() async {
        let headingLike = await renderStrictHTML("foo\n    # bar\n")
        let setextLike = await renderStrictHTML("Foo\n    ---\n")
        let thematicLike = await renderStrictHTML("Foo\n    ***\n")

        #expect(headingLike == "<p data-rhoe-node=\"paragraph\">foo\n# bar</p>")
        #expect(setextLike == "<p data-rhoe-node=\"paragraph\">Foo\n---</p>")
        #expect(thematicLike == "<p data-rhoe-node=\"paragraph\">Foo\n***</p>")
    }

    @Test("Multiple indented lines continue paragraph with soft breaks")
    func multipleIndentedLinesContinueParagraphWithSoftBreaks() async {
        let html = await renderStrictHTML("aaa\n             bbb\n                                       ccc\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">aaa\nbbb\nccc</p>")
    }

    @Test("List item stops cleanly before following thematic break")
    func listItemStopsCleanlyBeforeFollowingThematicBreak() async {
        let html = await renderStrictHTML("- foo\n---\n")

        #expect(html == "<ul data-rhoe-node=\"list\">\n<li>foo</li>\n</ul><hr>")
    }

    @Test("CommonMark HTML block-level tags pass through until a blank line")
    func commonMarkHTMLBlockLevelTagsPassThroughUntilBlankLine() async {
        let markdown = """
        <table>
          <tr>
            <td>
                   hi
            </td>
          </tr>
        </table>

        okay.

        """

        let html = await renderStrictHTML(markdown)

        #expect(html == """
        <table>
          <tr>
            <td>
                   hi
            </td>
          </tr>
        </table>
        <p data-rhoe-node="paragraph">okay.</p>
        """)
    }

    @Test("CommonMark type seven HTML block starts at a complete tag line")
    func commonMarkTypeSevenHTMLBlockStartsAtCompleteTagLine() async {
        let html = await renderStrictHTML("""
        <a href="foo">
        *bar*
        </a>

        """)

        #expect(html == """
        <a href="foo">
        *bar*
        </a>

        """)
    }

    @Test("Raw inline HTML tags pass through inside paragraphs")
    func rawInlineHTMLTagsPassThroughInsideParagraphs() async {
        let html = await renderStrictHTML("Hello <span class=\"x\">*world*</span>.\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">Hello <span class=\"x\"><em>world</em></span>.</p>")
    }

    @Test("Interrupting HTML blocks stop an open paragraph")
    func interruptingHTMLBlocksStopAnOpenParagraph() async {
        let html = await renderStrictHTML("""
        foo
        <table>
        <tr>
        </tr>
        </table>

        """)

        #expect(html == """
        <p data-rhoe-node="paragraph">foo</p>
        <table>
        <tr>
        </tr>
        </table>

        """)
    }

    @Test("Raw HTML blocks inside list items start on their own line")
    func rawHTMLBlocksInsideListItemsStartOnTheirOwnLine() async {
        let html = await renderStrictHTML("""
        - <div>
        - foo

        """)

        #expect(html == """
        <ul data-rhoe-node="list">
        <li>
        <div>
        </li>
        <li>foo</li>
        </ul>
        """)
    }

    @Test("Pre HTML block consumes unclosed math-like text through closing tag")
    func preHTMLBlockConsumesUnclosedMathLikeTextThroughClosingTag() async {
        let html = await renderStrictHTML("""
        <pre language="haskell"><code>
        import Text.HTML.TagSoup

        main :: IO ()
        main = print $ parseTags tags
        </code></pre>
        okay

        """)

        #expect(html == """
        <pre language="haskell"><code>
        import Text.HTML.TagSoup

        main :: IO ()
        main = print $ parseTags tags
        </code></pre>
        <p data-rhoe-node="paragraph">okay</p>
        """)
    }

    @Test("Closing pre tag remains inline when resuming Markdown inside HTML block")
    func closingPreTagRemainsInlineWhenResumingMarkdownInsideHTMLBlock() async {
        let html = await renderStrictHTML("""
        <table><tr><td>
        <pre>
        **Hello**,

        _world_.
        </pre>
        </td></tr></table>

        """)

        #expect(html == """
        <table><tr><td>
        <pre>
        **Hello**,
        <p data-rhoe-node="paragraph"><em>world</em>.
        </pre></p>
        </td></tr></table>

        """)
    }

    @Test("CDATA HTML blocks stop at the closing sequence")
    func cdataHTMLBlocksStopAtClosingSequence() async {
        let html = await renderStrictHTML("""
        <![CDATA[
        function matchwo(a,b)
        {
          if (a < b && a < 0) then {
            return 1;

          } else {

            return 0;
          }
        }
        ]]>
        okay

        """)

        #expect(html == """
        <![CDATA[
        function matchwo(a,b)
        {
          if (a < b && a < 0) then {
            return 1;

          } else {

            return 0;
          }
        }
        ]]>
        <p data-rhoe-node="paragraph">okay</p>
        """)
    }

    @Test("Invalid raw HTML tags remain escaped paragraph text")
    func invalidRawHTMLTagsRemainEscapedParagraphText() async {
        let html = await renderStrictHTML("""
        <a h*#ref="hi">
        <a href='bar'title=title>
        </a href="foo">

        """)

        #expect(html == """
        <p data-rhoe-node="paragraph">&lt;a h*#ref=&quot;hi&quot;&gt;
        &lt;a href=&#39;bar&#39;title=title&gt;
        &lt;/a href=&quot;foo&quot;&gt;</p>
        """)
    }

    @Test("Raw HTML open tags support multiline boolean attributes")
    func rawHTMLOpenTagsSupportMultilineBooleanAttributes() async {
        let html = await renderStrictHTML("""
        <a foo="bar" bam = 'baz <em>"</em>'
        _boolean zoop:33=zoop:33 />

        """)

        #expect(html == """
        <p data-rhoe-node="paragraph"><a foo="bar" bam = 'baz <em>"</em>'
        _boolean zoop:33=zoop:33 /></p>
        """)
    }

    @Test("Invalid raw HTML fallback applies CommonMark escapes")
    func invalidRawHTMLFallbackAppliesCommonMarkEscapes() async {
        let html = await renderStrictHTML("<a href=\"\\\"\">\n")

        #expect(html == "<p data-rhoe-node=\"paragraph\">&lt;a href=&quot;&quot;&quot;&gt;</p>")
    }

    private func renderStrictHTML(_ markdown: String) async -> String {
        let parser = DocumentParser(configuration: .strict)
        let result = await parser.parse(markdown)
        return HTMLRenderer(
            configuration: .init(prettyPrint: false, enableImplicitFigures: false)
        ).render(result.document)
    }

    private func renderGitHubHTML(_ markdown: String) async -> String {
        let parser = DocumentParser(configuration: .github)
        let result = await parser.parse(markdown)
        return HTMLRenderer(
            configuration: .init(prettyPrint: false, enableImplicitFigures: false)
        ).render(result.document)
    }
}
