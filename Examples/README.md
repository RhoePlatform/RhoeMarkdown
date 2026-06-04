# RhoeMarkdown Example Gallery

This folder is the self-contained public gallery for RhoeMarkdown. It keeps
real Markdown source files, one-example Bash commands, a render-all command,
and checked-in canonical outputs together so a new user can inspect an example,
run it, and compare the generated result without hunting through the rest of
the repository.

These examples are intentionally not unit tests. Each one is a realistic
document or publishing artifact that demonstrates a useful slice of the public
compiler surface: semantic blocks, tables, math, citations, cross-references,
fenced divs, client-side diagrams, slide separators, Typst/LaTeX generation,
and styled HTML output.

## Quick Run

Render every example and refresh the canonical outputs in `Examples/outputs/`:

```bash
bash Examples/render-all.sh
```

Render one example through its dedicated script:

```bash
bash Examples/render-architecture-rfc.sh
```

Render the same example manually:

```bash
rhoemd Examples/sources/architecture-rfc.md \
  -o Examples/outputs/architecture-rfc.html \
  --format html \
  --css \
  --pretty
```

For a copy-paste command catalog, see `COMMANDS.md`. For tooling and future
website generation, see `gallery-manifest.json`.

## Source, Command, Output

| Example | Markdown source | Bash command | Canonical output | Demonstrates |
| --- | --- | --- | --- | --- |
| Research note | `sources/research-note.md` | `bash Examples/render-research-note.sh` | `outputs/research-note.html` | frontmatter, admonitions, tables, math, footnotes |
| Project brief | `sources/project-brief.md` | `bash Examples/render-project-brief.sh` | `outputs/project-brief.html` | briefs, decision tables, checklists, code |
| Slides outline | `sources/slides-outline.md` | `bash Examples/render-slides-outline.sh` | `outputs/slides-outline.html` | slide separators, narrative decks, speaker-ready structure |
| Typst paper | `sources/typst-paper.md` | `bash Examples/render-typst-paper.sh` | `outputs/typst-paper.typ` | publication export, math, theorem blocks, citations |
| Release note | `sources/release-note.md` | `bash Examples/render-release-note.sh` | `outputs/release-note.html` | launch notes, badges, compatibility tables |
| Language showcase | `sources/language-showcase.md` | `bash Examples/render-language-showcase.sh` | `outputs/language-showcase.html` | compact syntax tour and extension overview |
| Architecture RFC | `sources/architecture-rfc.md` | `bash Examples/render-architecture-rfc.sh` | `outputs/architecture-rfc.html` | RFC structure, diagrams, API contracts |
| Data report | `sources/data-report.md` | `bash Examples/render-data-report.sh` | `outputs/data-report.html` | metrics, equations, operational review |
| Onboarding guide | `sources/onboarding-guide.md` | `bash Examples/render-onboarding-guide.sh` | `outputs/onboarding-guide.html` | user education, step-by-step flows, callouts |
| Component playbook | `sources/component-playbook.md` | `bash Examples/render-component-playbook.sh` | `outputs/component-playbook.html` | design-system prose, fenced divs, reusable patterns |

## Folder Contract

- `README.md` explains the gallery and points to every source/command/output pair.
- `COMMANDS.md` lists the render-all command, every one-example Bash command,
  and the equivalent raw CLI invocation.
- `gallery-manifest.json` provides a machine-readable source/script/output index.
- `sources/` contains the Markdown source files.
- `render-*.sh` compiles one example into `outputs/`.
- `render-all.sh` compiles the full gallery into `outputs/`.
- `outputs/` contains checked-in canonical output files.

## Maintainer Check

The examples are part of the public release surface. Run this before release:

```bash
bash Scripts/CI/validate-examples.sh
```
