---
title: "Five-Minute RhoeMarkdown Onboarding"
author: "RhoePlatform"
status: "example"
---

> Run: `rhoemd Examples/sources/onboarding-guide.md -o Examples/outputs/onboarding-guide.html --format html --css --pretty`

# Five-Minute RhoeMarkdown Onboarding {#onboarding}

This guide is a runnable document. Compile it, open the HTML, then inspect the
source to see how little ceremony is required.

## 1. Build The CLI

```bash
swift build -c release --product rhoemd
```

## 2. Render A Document

```bash
rhoemd Examples/sources/onboarding-guide.md \
  -o Examples/outputs/onboarding-guide.html \
  --format html \
  --css \
  --pretty
```

!!! tip "New user move"
Start with HTML because it is the fastest way to see structure, styling,
admonitions, code blocks, and tables in one browser window.
!!!

## 3. Change One Thing

Try editing the heading, adding a row to the table below, and rerunning the
command.

| Task | Why it matters |
| --- | --- |
| Edit source | proves plain-text workflow |
| Rerun compiler | proves deterministic output |
| Compare output | proves canonical examples are useful |

## 4. Explore More Outputs

- Use `--format typst` for publication pipelines.
- Use `--format latex` for academic workflows.
- Use the Wasm target when embedding the compiler in tools.

!!! note "What to remember"
RhoeMarkdown is not trying to hide Markdown. It keeps Markdown readable while
preserving enough structure for serious compilers.
!!!
