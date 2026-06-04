#!/usr/bin/env python3
"""Extract CommonMark-style embedded examples from a Markdown specification."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


EXAMPLE_START = re.compile(r"^`{32} example$")
EXAMPLE_END = "`" * 32


def extract_examples(spec: str) -> list[dict[str, object]]:
    lines = spec.splitlines(keepends=True)
    examples: list[dict[str, object]] = []
    section = ""
    index = 0
    number = 1

    while index < len(lines):
        line = lines[index]
        stripped = line.strip()
        if stripped.startswith("#"):
            section = stripped.lstrip("#").strip()

        if not EXAMPLE_START.match(stripped):
            index += 1
            continue

        start_line = index + 1
        index += 1
        markdown: list[str] = []
        html: list[str] = []
        target = markdown

        while index < len(lines):
            current = lines[index]
            if current.strip() == ".":
                target = html
                index += 1
                continue
            if current.strip() == EXAMPLE_END:
                break
            target.append(current)
            index += 1

        examples.append(
            {
                "number": number,
                "section": section,
                "startLine": start_line,
                "markdown": "".join(markdown),
                "html": "".join(html),
            }
        )
        number += 1
        index += 1

    return examples


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--suite", required=True)
    parser.add_argument("--suite-version", required=True)
    parser.add_argument("--upstream-ref", required=True)
    parser.add_argument("--upstream-url", required=True)
    args = parser.parse_args()

    spec = args.input.read_text(encoding="utf-8")
    examples = extract_examples(spec)
    payload = {
        "suite": args.suite,
        "version": args.suite_version,
        "upstreamRef": args.upstream_ref,
        "upstreamURL": args.upstream_url,
        "exampleCount": len(examples),
        "examples": examples,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"{args.suite}: extracted {len(examples)} examples to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
