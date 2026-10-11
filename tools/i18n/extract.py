"""Collects the player-facing English strings of CALMQUEST and checks a catalog.

Sources:
  - GDScript string literals that look like player-facing text (words and
    spaces), skipping comments, log calls, file paths and node/class names;
  - every literal passed straight to L.t("..."), and every literal on a line
    marked with a trailing "# i18n" comment (tables translated where used);
  - the text fields of every JSON file in game/data/ (plus crafting station
    names, fish waters and creature weather, which are shown translated).

    python tools/i18n/extract.py            # coverage report for game/data/i18n/id/
    python tools/i18n/extract.py --missing  # print untranslated strings as JSON

Translations live in game/data/i18n/<locale>/*.json as {"English": "translation"}
(split into several files only to keep them readable; they are merged).
English is the source language: strings without a translation stay English.
"""
import argparse
import glob
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PLACEHOLDER = re.compile(r"%(?:[-+ 0#]*\d*(?:\.\d+)?[sdif]|%)")
TEXT_FIELDS = {
    "name", "title", "desc", "text", "uses", "intro", "prompt", "hints", "lines", "arrival_text",
    "personality", "subtitle", "done_text", "complete_text", "needs_text", "description", "greet",
    "morning", "evening", "night", "loved", "liked", "neutral", "lore", "invite", "waters", "weather",
}
# Keys of JSON objects whose string values are never player-facing.
SKIP_KEYS = {"id", "icon", "shape", "color", "accent", "glow", "body", "leaf", "fruit", "item", "grows",
             "rows", "legend", "region", "kind", "style", "site", "cave", "from", "villager", "opens",
             "needs", "hearthstone", "seed", "requires", "unlock", "condition", "target", "flag", "counter"}
# Developer-only literals inside GDScript that look like sentences.
SKIP_LINE = ("push_warning", "push_error", "print(", "printerr", "assert(", "load_errors", "last_error =",
             "load_error =", "autosave(", "save_slot(", "get_node(", "has_node(", "find_child(", "set_meta(", "get_meta(",
             ".name = ", "add_to_group(", "is_in_group(")
# Capitalised identifiers (node, class and theme type names) that are not text.
IGNORE = {
    "CALMQUEST", "Walls", "HiddenBridge", "Smoke", "Label", "RichTextLabel", "PanelContainer", "Panel",
    "Button", "CheckBox", "HSlider", "HSeparator", "VSeparator", "VBoxContainer", "HBoxContainer",
    "TabContainer", "ScrollContainer", "MarginContainer", "CenterContainer", "LineEdit", "TextEdit",
    "PondCollision", "GuidanceArrow", "GloomLayer", "Atmosphere", "Wildlife", "Ground", "GroundFeatures",
    "TerrainCollision", "Chunk_%d_%d", "SFX", "UI", "TooltipPanel",
    "TooltipLabel", "ProgressBar", "OptionButton", "ItemList", "Tree", "PopupMenu", "Window",
}
FORCE_MARK = "# i18n"


def unescape(s):
    return bytes(s, "utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


def looks_player_facing(t):
    if not t or t in IGNORE or "res://" in t or "user://" in t or t.startswith("%s_") or "/" in t and " " not in t:
        return False
    if re.fullmatch(r"[a-z0-9_:.%,\- ]+", t) and " " not in t:
        return False
    if re.fullmatch(r"[A-Za-z]+_[A-Za-z0-9_]+", t) or re.fullmatch(r"#[0-9a-fA-F]{3,8}", t):
        return False
    words = re.findall(r"[A-Za-z]{2,}", t)
    if not words:
        return False
    return " " in t.strip() or t[0].isupper()


def literals(src):
    """Yields (text, start_index, is_string_name) for each string literal, skipping comments."""
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "#":
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        if c in "\"'":
            triple = src.startswith(c * 3, i)
            q = c * 3 if triple else c
            j = i + len(q)
            buf = []
            while j < n and not src.startswith(q, j):
                if src[j] == "\\" and j + 1 < n:
                    buf.append(src[j:j + 2])
                    j += 2
                    continue
                buf.append(src[j])
                j += 1
            prefix = src[i - 1] if i > 0 else ""
            yield "".join(buf), i, prefix in "&^$"
            i = j + len(q)
            continue
        i += 1


def from_scripts():
    out = {}
    for f in sorted(glob.glob(os.path.join(ROOT, "game", "scripts", "**", "*.gd"), recursive=True)):
        src = open(f, encoding="utf-8").read()
        rel = os.path.relpath(f, ROOT).replace("\\", "/")
        for raw, start, is_name in literals(src):
            if is_name:
                continue
            line_start = src.rfind("\n", 0, start) + 1
            line_end = src.find("\n", start)
            line = src[line_start: line_end if line_end >= 0 else len(src)]
            n = src.count("\n", 0, start) + 1
            try:
                t = unescape(raw)
            except Exception:
                t = raw
            wrapped = src[max(0, start - 4): start] == "L.t("
            forced = line.rstrip().endswith(FORCE_MARK)
            if not (wrapped or forced):
                if any(k in line for k in SKIP_LINE):
                    continue
                after = src[start + len(raw) + 2: start + len(raw) + 4]
                if after.startswith(":") and " " not in t:
                    continue
                if not looks_player_facing(t):
                    continue
            if t.strip():
                out.setdefault(t, "%s:%d" % (rel, n))
    return out


def from_data():
    out = {}

    def walk(o, key, path):
        if isinstance(o, dict):
            for k, v in o.items():
                if k == "station" and isinstance(v, str):
                    out.setdefault(v.replace("_", " "), path)
                    out.setdefault(v.replace("_2", " (cottage)").replace("_", " "), path)
                    continue
                if k in SKIP_KEYS:
                    continue
                walk(v, k, path)
        elif isinstance(o, list):
            for v in o:
                walk(v, key, path)
        elif isinstance(o, str) and key in TEXT_FIELDS and o.strip():
            out.setdefault(o, path)

    for f in sorted(glob.glob(os.path.join(ROOT, "game", "data", "**", "*.json"), recursive=True)):
        if os.sep + "i18n" + os.sep in f:
            continue
        walk(json.load(open(f, encoding="utf-8")), None, os.path.relpath(f, ROOT).replace("\\", "/"))
    return out


def all_strings():
    s = from_data()
    for k, v in from_scripts().items():
        s.setdefault(k, v)
    return s


def placeholders(t):
    """Placeholders in order (GDScript's % fills them by position), plus the line count."""
    return PLACEHOLDER.findall(t) + ["lines:%d" % t.count("\n")]


def load_catalog(locale):
    out = {}
    for f in sorted(glob.glob(os.path.join(ROOT, "game", "data", "i18n", locale, "*.json"))):
        out.update(json.load(open(f, encoding="utf-8")))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--locale", default="id")
    ap.add_argument("--missing", action="store_true")
    ap.add_argument("--unused", action="store_true")
    args = ap.parse_args()
    strings = all_strings()
    catalog = load_catalog(args.locale)
    missing = {k: v for k, v in strings.items() if not catalog.get(k)}
    bad = [k for k, v in catalog.items() if v and placeholders(k) != placeholders(v)]
    if args.missing:
        json.dump({k: "" for k in missing}, sys.stdout, ensure_ascii=False, indent=1)
        return
    if args.unused:
        json.dump(sorted(set(catalog) - set(strings)), sys.stdout, ensure_ascii=False, indent=1)
        return
    print(f"strings found: {len(strings)}  translated: {len(strings) - len(missing)}  missing: {len(missing)}  placeholder mismatches: {len(bad)}  unused entries: {len(set(catalog) - set(strings))}")
    for k in bad:
        print("  placeholder mismatch:", repr(k))
    sys.exit(1 if missing or bad else 0)


if __name__ == "__main__":
    main()
