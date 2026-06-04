# Third-Party Notices

RhoeMarkdownKit includes generated compatibility fixtures and bundled icon assets
from the following open-source projects. Each library's license text or
attribution note is reproduced below.

---

## CommonMark Specification Examples

- **Source**: https://github.com/commonmark/commonmark-spec
- **Upstream version**: `0.31.2`
- **Pinned ref**: `9103e341a973013013bb1a80e13567007c5cef6f`
- **Pinned source SHA-256**: `257c41ad946f7a1414a499aca402a1aa8fdac3678532266611348c1cf54f4b80`
- **Generated location**: `Tests/ExternalConformance/commonmark/spec.json`
- **Pinned fetch/extract script**: `Scripts/CI/fetch-external-conformance.sh`
- **Extractor**: `Scripts/CI/extract-markdown-spec-tests.py`
- **Regeneration command**: `bash Scripts/CI/fetch-external-conformance.sh`

The CommonMark specification contains embedded examples that are intended to be
used as conformance tests. RhoeMarkdown stores only the generated JSON fixture
extraction, not the full upstream specification prose. The CommonMark
specification is licensed by its authors under Creative Commons
Attribution-ShareAlike 4.0 International.

---

## GitHub Flavored Markdown Specification Examples

- **Source**: https://github.com/github/cmark-gfm
- **Formal specification**: https://github.github.com/gfm/
- **Upstream version**: `0.29.0.gfm.13`
- **Pinned ref**: `587a12bb54d95ac37241377e6ddc93ea0e45439b`
- **Pinned source SHA-256**: `7d8e5814befec287ac116786d81ff14e0adc9b13295b4494649e995408fd871c`
- **Generated location**: `Tests/ExternalConformance/gfm/spec.json`
- **Pinned fetch/extract script**: `Scripts/CI/fetch-external-conformance.sh`
- **Extractor**: `Scripts/CI/extract-markdown-spec-tests.py`
- **Regeneration command**: `bash Scripts/CI/fetch-external-conformance.sh`

The GitHub Flavored Markdown specification is based on the CommonMark
specification and adds GFM extension examples. RhoeMarkdown stores only the
generated JSON fixture extraction, not the full upstream specification prose.
The formal GFM specification states that it is based on CommonMark and licensed
under Creative Commons Attribution-ShareAlike 4.0 International; the cmark-gfm
reference implementation is BSD-2-Clause licensed.

---

## Fluent UI System Icons

**Source**: https://github.com/microsoft/fluentui-system-icons
**Location**: `Sources/RhoeMarkdownRendering/Resources/Icons/Fluent`
**License**: MIT

```
MIT License

Copyright (c) 2020 Microsoft Corporation

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Heroicons

**Source**: https://github.com/tailwindlabs/heroicons
**Location**: `Sources/RhoeMarkdownRendering/Resources/Icons/Heroicons`
**License**: MIT

```
MIT License

Copyright (c) 2020 Refactoring UI Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Lucide

**Source**: https://github.com/lucide-icons/lucide
**Location**: `Sources/RhoeMarkdownRendering/Resources/Icons/Lucide`
**License**: ISC

```
ISC License

Copyright (c) for portions of Lucide are held by Cole Bemis 2013-2022 as part
of Feather (MIT). All other copyright (c) for Lucide are held by Lucide
Contributors 2022.

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.
```
