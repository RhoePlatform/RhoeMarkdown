#!/usr/bin/env python3
"""Run rhoemd against generated CommonMark/GFM conformance fixtures."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path


RHOE_SECTION_OPEN = re.compile(r"<section\b(?=[^>]*\bdata-rhoe-node=\"Section\")[^>]*>")
DATA_RHOE_ATTR = re.compile(r"\sdata-rhoe-[a-zA-Z0-9_-]+=\"[^\"]*\"")
HEADING_ID_ATTR = re.compile(r"(<h[1-6])\s+id=\"[^\"]*\"")
CLASS_ATTR = re.compile(r"\sclass=\"([^\"]*)\"")
TABLE_EXTRA_ATTRS = re.compile(r"\s(?:scope|role|aria-hidden|style)=\"[^\"]*\"")
HTML_OPEN_TAG = re.compile(r"<([A-Za-z][A-Za-z0-9:-]*)([^<>]*?)(\s*/?)>")
HTML_ATTRIBUTE = re.compile(r"\s+([A-Za-z_:][A-Za-z0-9_:.-]*)(?:=\"([^\"]*)\")?")
VOID_TAGS = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}


def clean_class_attr(match: re.Match[str]) -> str:
    classes = [
        cls
        for cls in match.group(1).split()
        if not cls.startswith("rhoe-")
        and cls
        not in {
            "figure",
            "task-list-item",
            "task-list-item-checkbox",
        }
    ]
    if not classes:
        return ""
    return ' class="' + " ".join(classes) + '"'


def canonicalize_open_tag(match: re.Match[str]) -> str:
    tag = match.group(1)
    raw_attributes = match.group(2)
    attributes: list[tuple[str, str | None]] = []
    cursor = 0

    for attribute in HTML_ATTRIBUTE.finditer(raw_attributes):
        if raw_attributes[cursor : attribute.start()].strip():
            return match.group(0)
        attributes.append((attribute.group(1), attribute.group(2)))
        cursor = attribute.end()

    if raw_attributes[cursor:].strip():
        return match.group(0)

    canonical_attributes = "".join(
        f' {name}="{value}"' if value is not None else f" {name}"
        for name, value in sorted(attributes, key=lambda item: (item[0], item[1] or ""))
    )
    closing = " /" if tag.lower() in VOID_TAGS else ""
    return f"<{tag}{canonical_attributes}{closing}>"


def normalize_html_fragment(value: str, semantic: bool) -> str:
    value = value.replace("\r\n", "\n").replace("\r", "\n")
    value = value.replace("&#39;", "'").replace("&#x27;", "'")
    value = value.replace("<hr>", "<hr />")
    value = value.replace("<br>", "<br />")
    value = re.sub(r"<img([^>/]*)>", r"<img\1 />", value)

    if semantic:
        value = RHOE_SECTION_OPEN.sub("", value)
        value = value.replace("</section>", "")
        value = DATA_RHOE_ATTR.sub("", value)
        value = HEADING_ID_ATTR.sub(r"\1", value)
        value = CLASS_ATTR.sub(clean_class_attr, value)
        value = TABLE_EXTRA_ATTRS.sub("", value)
        value = value.replace(" checked disabled", " checked=\"\" disabled=\"\"")
        value = value.replace(" disabled>", " disabled=\"\">")
        value = re.sub(r"\s+>", ">", value)

    value = HTML_OPEN_TAG.sub(canonicalize_open_tag, value)

    value = re.sub(
        r">(?=<(?:/?(?:blockquote|caption|dd|dl|dt|figcaption|figure|h[1-6]|hr|li|ol|p|pre|table|tbody|td|tfoot|th|thead|tr|ul)\b))",
        ">\n",
        value,
    )
    lines = [line.rstrip() for line in value.strip().split("\n")]
    return "\n".join(lines).strip() + ("\n" if lines else "")


def render_example(binary: Path, flavor: str, markdown: str, timeout: float) -> tuple[int, str, str]:
    with tempfile.TemporaryDirectory(prefix="rhoemd-conformance-") as tmp:
        input_path = Path(tmp) / "input.md"
        input_path.write_text(markdown, encoding="utf-8")
        completed = subprocess.run(
            [str(binary), str(input_path), "--format", "html", "--flavor", flavor],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
        )
        return completed.returncode, completed.stdout, completed.stderr


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--suite", required=True, choices=["commonmark", "gfm"])
    parser.add_argument("--fixtures", required=True, type=Path)
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--flavor", required=True, choices=["strict", "github"])
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--normalization", choices=["raw", "semantic"], default="semantic")
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--failure-budget", type=int, default=0)
    args = parser.parse_args()

    payload = json.loads(args.fixtures.read_text(encoding="utf-8"))
    examples = payload["examples"]
    if args.limit > 0:
        examples = examples[: args.limit]

    semantic = args.normalization == "semantic"
    failures: list[dict[str, object]] = []
    passed = 0

    for example in examples:
        code, stdout, stderr = render_example(
            args.binary,
            flavor=args.flavor,
            markdown=example["markdown"],
            timeout=args.timeout,
        )
        expected = normalize_html_fragment(example["html"], semantic=semantic)
        actual = normalize_html_fragment(stdout, semantic=semantic)
        if code == 0 and actual == expected:
            passed += 1
            continue

        failures.append(
            {
                "number": example["number"],
                "section": example["section"],
                "startLine": example["startLine"],
                "exitCode": code,
                "markdown": example["markdown"],
                "expected": example["html"],
                "actual": stdout,
                "normalizedExpected": expected,
                "normalizedActual": actual,
                "stderr": stderr,
            }
        )

    total = len(examples)
    report = {
        "suite": args.suite,
        "flavor": args.flavor,
        "normalization": args.normalization,
        "upstreamRef": payload.get("upstreamRef"),
        "upstreamURL": payload.get("upstreamURL"),
        "total": total,
        "passed": passed,
        "failed": len(failures),
        "passRate": round(passed / total, 4) if total else 1,
        "failures": failures,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print(
        f"{args.suite}: {passed}/{total} passed "
        f"({report['passRate']:.2%}) with {args.normalization} normalization"
    )
    for failure in failures[:10]:
        print(f"  FAIL #{failure['number']} {failure['section']} line {failure['startLine']}")

    if len(failures) > args.failure_budget:
        print(
            f"{args.suite}: failure budget exceeded "
            f"({len(failures)} > {args.failure_budget}); report: {args.report}"
        )
        return 1

    print(f"{args.suite}: report written to {args.report}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.TimeoutExpired as error:
        print(f"external conformance runner timed out: {error}", file=os.sys.stderr)
        raise SystemExit(124)
