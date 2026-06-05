# rhoemd CLI

`rhoemd` compiles Markdown files through the RhoeMarkdown engine. Homebrew also
installs `markdown` as an alias to the same executable.

## Common Commands

```bash
rhoemd input.md -o output.html --format html --css
rhoemd input.md -o output.typ --format typst
rhoemd preview input.md -o /draft --no-open
rhoemd --version
markdown --version
rhoemd --help
```

Use `rhoemd` in scripts when you want the explicit RhoePlatform identity. Use
`markdown` for interactive shell work when the full language name is clearer.

## Supported Formats

Output format is selected with `--format` or inferred from the output path.
The public `rhoemd` CLI surface includes HTML, LaTeX, Typst, DOCX, PDF, and
EPUB. JSON serialization is available through Swift API and WebAssembly helpers,
but is not a `rhoemd --format` option in `0.1.1`.

## Live Preview Daemon

Use `rhoemd preview` when you want to edit a Markdown file in an editor while a
browser keeps showing the current rendered HTML. The command starts a shared
local Hummingbird daemon when needed, registers the document with that daemon,
prints the preview URL plus daemon PID, and then returns control to the shell.

```bash
rhoemd preview Examples/sources/research-note.md -o /research-note
rhoemd preview Examples/sources/release-note.md -o /release-note --no-open
rhoemd preview draft.md -o http://127.0.0.1:37911/docs/draft
```

The `-o`/`--output` value is interpreted as the preview route for this mode:

- Omit `-o` to use the Markdown file stem, such as `/research-note`.
- Pass a URL path, such as `/docs/draft`, to choose the route explicitly.
- Pass a full local URL, such as `http://127.0.0.1:37911/docs/draft`, when that
  is more convenient from scripts.
- If another document already owns the route, the daemon assigns a fallback
  route such as `/docs/draft.1` or `/docs/draft.2`.

The daemon stores its process record and log under `~/.rhoe/rhoemd/`:

- `preview-daemon.json`: current shared daemon host, port, PID, and log path.
- `preview-daemon.log`: daemon stdout/stderr for troubleshooting.

Useful options:

```bash
rhoemd preview input.md --port 37911 --host 127.0.0.1
rhoemd preview input.md --no-open
rhoemd preview input.md --no-menu
rhoemd preview input.md --pretty
rhoemd preview input.md --verbose
```

The preview HTML polls `/__rhoemd/preview/version` and reloads when the watched
file changes. The daemon also exposes `/__rhoemd/preview/health` and
`/__rhoemd/preview/routes` for lightweight automation and diagnostics.

Use `rhoemd serve <file.md>` when you want a foreground, Ctrl-C-managed preview
server for a single document at `/`.

## macOS Menu Bar Extra

On macOS 26, `rhoemd preview` and `rhoemd serve` launch the
`rhoemd-preview-menu` companion by default. It is a menu-bar-only control panel
that shows the current daemon status, watched files, preview routes, PID, and
log path.

Use it to:

- Open a watched file in the default browser or Safari.
- Copy a preview URL.
- Reveal the Markdown source in Finder.
- Stop watching one route.
- Start, stop, or restart the shared preview daemon.
- Open the daemon log.

Disable automatic menu launch for scripts or minimal sessions with either form:

```bash
rhoemd preview input.md --no-menu
RHOEMD_PREVIEW_MENU=0 rhoemd preview input.md
```

The companion also supports a headless status check:

```bash
rhoemd-preview-menu --status-json
```

Linux builds intentionally remain CLI-only; invoking `rhoemd-preview-menu`
outside macOS prints a harmless unsupported message.

## Generated Artifacts

Generated manual pages and shell completions are planned for the next CLI
hygiene sprint after the current hand-written parser is migrated to
`swift-argument-parser`.
