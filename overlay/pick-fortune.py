#!/usr/bin/env python3
"""Pick one short fortune and print it, one mosaic line per output line.

The mosaic rasterizes each line separately and only stays legible at a few
words per line, so everything here is filtered on length. The bundled corpora
are written to that constraint; the system `fortune` is used opportunistically
when it happens to produce something short enough.
"""
from __future__ import annotations

import argparse
import json
import os
import random
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CORPORA = HERE / "fortunes"
# User databases win: `fortune` itself does not look here, but people drop
# language packs into the XDG data dir rather than touching /usr/share.
FORTUNE_DIRS = (
    Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "fortune",
    Path("/usr/share/fortune"),
    Path("/usr/share/games/fortune"),
)

# `fortune` ships English by default; other languages come from separate
# packages that install into a locale subdirectory.
FORTUNE_SUBDIR = {"en": "", "fr": "fr", "es": "es", "de": "de", "zh": "zh"}

# Some language packs (the Debian zh ones, for instance) embed terminal colour
# codes. They would be rasterized as literal garbage.
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")

# CJK has no spaces, so word wrapping cannot split it, and a CJK glyph carries
# far more ink than a latin letter -- far fewer per mosaic line stay legible.
CJK_MAX_LINE = 8
CJK_RANGES = ((0x3000, 0x9fff), (0xf900, 0xfaff), (0xff00, 0xffef))


def strip_attribution(text: str) -> str:
    """Drop a trailing "-- Source". Two mosaic lines have no room for a citation."""
    head = re.split(r"\s*(?:-\+-|--+)\s*", text)[0].strip()
    return head if len(head) >= 4 else text.strip()


def is_cjk(text: str) -> bool:
    return any(any(lo <= ord(ch) <= hi for lo, hi in CJK_RANGES) for ch in text)


def wrap_cjk(text: str, max_line: int, max_lines: int) -> list[str] | None:
    body = text.strip()
    if not body or len(body) > max_line * max_lines:
        return None
    return [body[i:i + max_line] for i in range(0, len(body), max_line)]


def bundled(lang: str) -> list[list[str]]:
    path = CORPORA / f"{lang}.json"
    if not path.is_file():
        path = CORPORA / "en.json"
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return []
    out = []
    for entry in doc.get("fortunes") or []:
        if isinstance(entry, str):
            out.append([entry])
        elif isinstance(entry, list) and entry:
            out.append([str(line) for line in entry])
    return out


def fortune_dir(lang: str) -> Path | None:
    sub = FORTUNE_SUBDIR.get(lang)
    if sub is None:
        return None
    for base in FORTUNE_DIRS:
        cand = base / sub if sub else base
        # A directory that merely exists is not enough: the XDG root holds only
        # per-language subdirectories, and `fortune` on it finds nothing. Require
        # a built index at the top level.
        if cand.is_dir() and any(cand.glob("*.dat")):
            return cand
    return None


def wrap(words: list[str], max_line: int, max_lines: int) -> list[str] | None:
    """Greedy wrap. Returns None when it cannot fit the budget."""
    lines: list[str] = []
    current = ""
    for word in words:
        if len(word) > max_line:
            return None
        candidate = f"{current} {word}".strip()
        if len(candidate) <= max_line:
            current = candidate
        else:
            lines.append(current)
            current = word
            if len(lines) > max_lines:
                return None
    if current:
        lines.append(current)
    return lines if 0 < len(lines) <= max_lines else None


def from_system(lang: str, max_line: int, max_lines: int, tries: int = 12) -> list[str] | None:
    if not shutil.which("fortune"):
        return None
    directory = fortune_dir(lang)
    if directory is None:
        return None
    budget = max_line * max_lines
    for _ in range(tries):
        try:
            proc = subprocess.run(
                ["fortune", "-s", "-n", str(budget), str(directory)],
                capture_output=True,
                text=True,
                timeout=5,
            )
        except (OSError, subprocess.SubprocessError):
            return None
        if proc.returncode != 0:
            return None
        text = strip_attribution(" ".join(ANSI.sub("", proc.stdout).split()))
        if not text:
            continue
        if is_cjk(text):
            lines = wrap_cjk(text, CJK_MAX_LINE, max_lines)
        elif len(text) > budget:
            continue
        else:
            lines = wrap(text.split(" "), max_line, max_lines)
        if lines:
            return lines
    return None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lang", default="en")
    parser.add_argument("--max-line", type=int, default=22)
    parser.add_argument("--max-lines", type=int, default=3)
    parser.add_argument(
        "--no-system",
        action="store_true",
        help="Ignore the system fortune command and use only the bundled corpora",
    )
    parser.add_argument("--list-langs", action="store_true")
    args = parser.parse_args()

    if args.list_langs:
        for path in sorted(CORPORA.glob("*.json")):
            try:
                doc = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            print(f"{doc.get('lang', path.stem)}\t{doc.get('name', path.stem)}")
        return

    # When both sources are available, alternate at random: the system corpus is
    # vast but generic, the bundled one is short and written for this screensaver.
    if not args.no_system and random.random() < 0.5:
        lines = from_system(args.lang, args.max_line, args.max_lines)
        if lines:
            print("\n".join(lines))
            return

    pool = bundled(args.lang)
    if not pool:
        sys.stderr.write(f"no fortunes for {args.lang}\n")
        sys.exit(1)
    print("\n".join(random.choice(pool)))


if __name__ == "__main__":
    main()
