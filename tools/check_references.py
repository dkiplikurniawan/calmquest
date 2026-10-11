"""Static check: every res:// path referenced by the project must exist.

Scans project.godot, *.tscn, *.tres and *.gd files for res:// paths and
reports any that do not resolve to a file in the repository.

Usage (from the repository root):
    python tools/check_references.py
Exit code 0 = all references resolve, 1 = missing references found.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATTERN = re.compile(r'res://[A-Za-z0-9_./\-]+')
SCAN_SUFFIXES = {".godot", ".tscn", ".tres", ".gd"}
SKIP_DIRS = {".godot", ".git", "analysis", "data", "docs"}
# Files the game reads only when they exist (documented fallbacks). They are
# listed here explicitly so every other reference is still required.
OPTIONAL = {
    "res://build_commit.txt",  # written by a build script; Study Mode leaves git_commit empty without it
    # An OFL font the developer adds (assets/fonts/README.md); the default font is used without it.
    "res://assets/fonts/Nunito-VariableFont_wght.ttf",
    "res://assets/fonts/Nunito-Regular.ttf",
    "res://assets/fonts/Quicksand-VariableFont_wght.ttf",
    "res://assets/fonts/Quicksand-Regular.ttf",
    # Optional character sprite sheets (assets/sprites/README.md); the procedural art is used without them.
    "res://assets/sprites/traveler.png",
    "res://assets/sprites/lumi.png",
}


def main() -> int:
    missing: list[tuple[str, str]] = []
    optional_absent: set[str] = set()
    checked = 0
    for path in sorted(ROOT.rglob("*")):
        if path.suffix not in SCAN_SUFFIXES or any(part in SKIP_DIRS for part in path.relative_to(ROOT).parts):
            continue
        text = path.read_text(encoding="utf-8")
        for ref in sorted(set(PATTERN.findall(text))):
            ref = ref.rstrip(".")
            checked += 1
            target = ROOT / ref[len("res://"):]
            if not target.exists():
                if ref in OPTIONAL:
                    optional_absent.add(ref)
                else:
                    missing.append((str(path.relative_to(ROOT)), ref))
    for source, ref in missing:
        print(f"MISSING  {ref}  (referenced in {source})")
    for ref in sorted(optional_absent):
        print(f"optional, not present  {ref}")
    print(f"Checked {checked} res:// references: {len(missing)} missing")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
