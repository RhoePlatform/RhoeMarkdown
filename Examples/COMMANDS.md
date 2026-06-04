# RhoeMarkdown Gallery Commands

Run these commands from the repository root. Each command renders into
`Examples/outputs/`, which contains the checked-in canonical output for the
current release surface.

## Compile Everything

```bash
bash Examples/render-all.sh
```

## Per-Example Scripts

```bash
bash Examples/render-research-note.sh
bash Examples/render-project-brief.sh
bash Examples/render-slides-outline.sh
bash Examples/render-typst-paper.sh
bash Examples/render-release-note.sh
bash Examples/render-language-showcase.sh
bash Examples/render-architecture-rfc.sh
bash Examples/render-data-report.sh
bash Examples/render-onboarding-guide.sh
bash Examples/render-component-playbook.sh
```

## Raw CLI Commands

```bash
rhoemd Examples/sources/research-note.md -o Examples/outputs/research-note.html --format html --css --pretty
rhoemd Examples/sources/project-brief.md -o Examples/outputs/project-brief.html --format html --css --pretty
rhoemd Examples/sources/slides-outline.md -o Examples/outputs/slides-outline.html --format html --css --pretty
rhoemd Examples/sources/typst-paper.md -o Examples/outputs/typst-paper.typ --format typst
rhoemd Examples/sources/release-note.md -o Examples/outputs/release-note.html --format html --css --pretty
rhoemd Examples/sources/language-showcase.md -o Examples/outputs/language-showcase.html --format html --css --pretty
rhoemd Examples/sources/architecture-rfc.md -o Examples/outputs/architecture-rfc.html --format html --css --pretty
rhoemd Examples/sources/data-report.md -o Examples/outputs/data-report.html --format html --css --pretty
rhoemd Examples/sources/onboarding-guide.md -o Examples/outputs/onboarding-guide.html --format html --css --pretty
rhoemd Examples/sources/component-playbook.md -o Examples/outputs/component-playbook.html --format html --css --pretty
```

When running through SwiftPM before installing the CLI globally, prefix the
same arguments with `swift run rhoemd`:

```bash
swift run rhoemd Examples/sources/data-report.md -o Examples/outputs/data-report.html --format html --css --pretty
```

To render into a temporary directory without changing the checked-in canonical
outputs:

```bash
RHOEMD_EXAMPLE_OUTPUT_DIR=/tmp/rhoemarkdown-gallery bash Examples/render-all.sh
```
