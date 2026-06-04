#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

python3 - <<'PY'
import json
import re
from pathlib import Path

root = Path.cwd()
manifest_path = root / "Documentation/LanguageReference/rhoemarkdown-language-surface.json"
manifest = json.loads(manifest_path.read_text())

if manifest.get("repository") != "RhoePlatform/RhoeMarkdown":
    raise SystemExit("Language manifest repository mismatch")
if manifest.get("release") != "0.1.0":
    raise SystemExit("Language manifest release must be 0.1.0")

required_status = {
    "CommonMark",
    "GitHub Flavored Markdown",
    "RhoeMarkdown extension",
    "RhoePlatform projection",
    "Native only",
    "Wasm compatible",
    "Deferred",
}
actual_status = set(manifest.get("statusVocabulary", []))
missing_status = required_status - actual_status
if missing_status:
    raise SystemExit(f"Language manifest missing status labels: {sorted(missing_status)}")

for doc in manifest.get("canonicalDocumentation", []):
    path = root / doc
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"Missing canonical language documentation: {doc}")

source = (root / "Sources/RhoeMarkdownModel/RhoeMarkdownTypes.swift").read_text()

def enum_body(name: str) -> str:
    marker = f"public enum {name}:"
    start = source.index(marker)
    brace = source.index("{", start)
    depth = 0
    for offset, char in enumerate(source[brace:], start=brace):
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1:offset]
    raise RuntimeError(f"Could not find enum body for {name}")

def case_names(name: str) -> set[str]:
    body = enum_body(name)
    found = set()
    for match in re.finditer(r"^\s*case\s+(.+)$", body, re.MULTILINE):
        line = match.group(1).split("//", 1)[0].strip()
        token = re.match(r"`?([A-Za-z_][A-Za-z0-9_]*)`?", line)
        if token:
            found.add(token.group(1))
    return found

manifest_blocks = {item["name"] for item in manifest["blockElements"]}
manifest_inlines = {item["name"] for item in manifest["inlineElements"]}
source_blocks = case_names("Block")
source_inlines = case_names("Inline")

missing_blocks = source_blocks - manifest_blocks
missing_inlines = source_inlines - manifest_inlines
extra_blocks = manifest_blocks - source_blocks
extra_inlines = manifest_inlines - source_inlines

if missing_blocks or missing_inlines or extra_blocks or extra_inlines:
    raise SystemExit(
        "Language manifest drift:\n"
        f"  missing block cases: {sorted(missing_blocks)}\n"
        f"  extra block cases: {sorted(extra_blocks)}\n"
        f"  missing inline cases: {sorted(missing_inlines)}\n"
        f"  extra inline cases: {sorted(extra_inlines)}"
    )

public_text = "\n".join(
    (root / path).read_text()
    for path in [
        "README.md",
        "Documentation/README.md",
        "Documentation/CLI/README.md",
        "Sources/RhoeMarkdownKit/Documentation.docc/RhoeMarkdownKit.md",
        "Sources/RhoeMarkdownKit/Documentation.docc/LanguageReference/LanguageOverview.md",
        "Sources/RhoeMarkdownKit/Documentation.docc/LanguageReference/SyntaxReference.md",
        "Sources/RhoeMarkdownKit/Documentation.docc/LanguageReference/Block.md",
        "Sources/RhoeMarkdownKit/Documentation.docc/LanguageReference/Inline.md",
        "Sources/RhoeMarkdownKit/Documentation.docc/LanguageReference/CompatibilityAndDeferred.md",
    ]
)
for forbidden in ["v3.3", "v4.0", "v0.51", "RhoeLanguageSpec", "4.0.0-wasm"]:
    if forbidden in public_text:
        raise SystemExit(f"Forbidden stale public language reference found: {forbidden}")

if "json" in (root / "Documentation/CLI/README.md").read_text().lower():
    if "not a `rhoemd --format` option" not in (root / "Documentation/CLI/README.md").read_text():
        raise SystemExit("CLI docs mention JSON without clarifying API-only status")

print("LANGUAGE_REFERENCE_VALIDATION PASS")
PY
