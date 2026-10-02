"""Validate a release tag and extract its dated changelog section (stdlib only)."""

import argparse
from datetime import date
from pathlib import Path
import re


def release_notes(tag: str, pubspec: str, changelog: str) -> str:
    match = re.fullmatch(r"v((?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*))", tag)
    if not match:
        raise ValueError("Expected a version tag such as v0.1.0")
    version = match[1]
    versions = re.findall(r"^version:\s*(\S+)\s*$", pubspec, re.MULTILINE)
    if len(versions) != 1 or not re.fullmatch(re.escape(version) + r"\+[1-9]\d*", versions[0]):
        raise ValueError("Tag must match pubspec.yaml version with a positive +build number")

    sections = re.split(r"^(## .*)$", changelog, flags=re.MULTILINE)
    entries = [(sections[i].strip(), sections[i + 1].strip()) for i in range(1, len(sections), 2)]
    if sum(heading == "## [Unreleased]" for heading, _ in entries) != 1 or entries[0][0] != "## [Unreleased]":
        raise ValueError("Changelog must start with exactly one Unreleased section")
    selected = [(heading, body) for heading, body in entries if heading.startswith(f"## [{version}]")]
    if len(selected) != 1:
        raise ValueError(f"Expected exactly one changelog section for {version}")
    heading, body = selected[0]
    dated = re.fullmatch(r"## \[" + re.escape(version) + r"\] - (\d{4}-\d{2}-\d{2})", heading)
    if not dated:
        raise ValueError("Release heading must include a YYYY-MM-DD preparation date")
    date.fromisoformat(dated[1])
    if not re.search(r"^- \S", body, re.MULTILINE):
        raise ValueError("Release notes must contain at least one change")
    return body + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag")
    parser.add_argument("--pubspec", type=Path, default=Path("pubspec.yaml"))
    parser.add_argument("--changelog", type=Path, default=Path("CHANGELOG.md"))
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        notes = release_notes(args.tag, args.pubspec.read_text(encoding="utf-8"), args.changelog.read_text(encoding="utf-8"))
    except (ValueError, OSError) as error:
        parser.exit(1, f"Release validation failed: {error}\n")
    if args.output:
        args.output.write_text(notes, encoding="utf-8")
    else:
        print(notes, end="")


if __name__ == "__main__":
    main()
