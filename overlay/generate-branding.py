#!/usr/bin/env python3
"""Rasterize Adwaita Mono into a high-res ▄█▀ mosaic for the Omarchy screensaver.

Does not ship any personal branding. Pass text on the command line or put it in
~/.config/omarchy/branding/screensaver-message (one mosaic line per text line).
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

import cairo

FONT = os.environ.get("SS_FONT", "Adwaita Mono")
DEFAULT_FONT = "Adwaita Mono"
# Cairo's toy font API silently substitutes when a family is missing or lacks a
# glyph, so an unreadable mosaic is the only symptom. Ask fontconfig first.
CJK_FALLBACKS = ("Noto Sans CJK SC", "Noto Sans CJK TC", "Noto Sans CJK HK", "Noto Sans CJK JP")


def family_exists(name: str) -> bool:
    if not shutil.which("fc-list"):
        return True
    try:
        out = subprocess.run(
            ["fc-list", f":family={name}", "family"],
            capture_output=True, text=True, timeout=5,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return True
    return bool(out.strip())


def covers_lang(name: str, lang: str) -> bool:
    if not shutil.which("fc-list"):
        return True
    try:
        out = subprocess.run(
            ["fc-list", f":lang={lang}:family={name}", "family"],
            capture_output=True, text=True, timeout=5,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return True
    return bool(out.strip())


def needs_cjk(texts: list[str]) -> bool:
    return any(
        "\u3000" <= ch <= "\u9fff" or "\uf900" <= ch <= "\ufaff"
        for text in texts for ch in text
    )


def resolve_font(name: str, texts: list[str]) -> str:
    """Pick a family that actually exists and can draw this text."""
    font = (name or "").strip() or DEFAULT_FONT
    if not family_exists(font):
        sys.stderr.write(f"font not installed: {font!r}, falling back to {DEFAULT_FONT!r}\n")
        font = DEFAULT_FONT
    if needs_cjk(texts) and not covers_lang(font, "zh-cn"):
        for candidate in CJK_FALLBACKS:
            if family_exists(candidate):
                sys.stderr.write(f"{font!r} has no CJK coverage, using {candidate!r}\n")
                return candidate
        sys.stderr.write("no CJK font found; the mosaic will show blanks\n")
    return font
OUT = Path(os.environ.get("SS_OUT", Path.home() / ".config/omarchy/branding/screensaver.txt"))
MESSAGE_FILE = Path.home() / ".config/omarchy/branding/screensaver-message"
TARGET_COLS = int(os.environ.get("SS_COLS", "400"))
RENDER_SIZE = float(os.environ.get("SS_RENDER_SIZE", "400"))


def rasterize(text: str, font_size: float, font: str) -> list[list[bool]]:
    dummy = cairo.ImageSurface(cairo.FORMAT_ARGB32, 1, 1)
    ctx = cairo.Context(dummy)
    ctx.select_font_face(font, cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
    ctx.set_font_size(font_size)
    xb, yb, tw, th, xa, ya = ctx.text_extents(text)
    pad = 4
    w = max(1, int(tw + abs(xb) + pad * 2) + 2)
    h = max(1, int(th + abs(yb) + pad * 2) + 2)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
    ctx = cairo.Context(surf)
    ctx.set_source_rgb(0, 0, 0)
    ctx.paint()
    ctx.set_source_rgb(1, 1, 1)
    ctx.select_font_face(font, cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
    ctx.set_font_size(font_size)
    ctx.move_to(pad - xb, pad - yb)
    ctx.show_text(text)
    surf.flush()
    buf = surf.get_data()
    stride = surf.get_stride()
    pixels = []
    for y in range(h):
        row = []
        for x in range(w):
            i = y * stride + x * 4
            b, g, r = buf[i], buf[i + 1], buf[i + 2]
            row.append((r + g + b) / 3 > 80)
        pixels.append(row)
    return pixels


def trim(pixels: list[list[bool]]) -> list[list[bool]]:
    rows_used = [i for i, row in enumerate(pixels) if any(row)]
    if not rows_used:
        return [[False]]
    cols_used = [x for x in range(len(pixels[0])) if any(pixels[y][x] for y in rows_used)]
    y0, y1 = rows_used[0], rows_used[-1] + 1
    x0, x1 = cols_used[0], cols_used[-1] + 1
    return [row[x0:x1] for row in pixels[y0:y1]]


def scale_wh(pixels: list[list[bool]], tw: int, th: int) -> list[list[bool]]:
    h, w = len(pixels), len(pixels[0])
    out = []
    for y in range(th):
        sy = min(h - 1, int(y * h / th))
        out.append([pixels[sy][min(w - 1, int(x * w / tw))] for x in range(tw)])
    return out


def even(n: int) -> int:
    n = max(2, n)
    return n + (n % 2)


def to_halfblocks(pixels: list[list[bool]]) -> str:
    h, w = len(pixels), len(pixels[0])
    lines = []
    for y in range(0, h, 2):
        top = pixels[y]
        bot = pixels[y + 1] if y + 1 < h else [False] * w
        chars = []
        for t, b in zip(top, bot):
            if t and b:
                chars.append("█")
            elif t:
                chars.append("▀")
            elif b:
                chars.append("▄")
            else:
                chars.append(" ")
        lines.append("".join(chars).rstrip())
    return "\n".join(lines)


def center(pixels: list[list[bool]], width: int) -> list[list[bool]]:
    w = len(pixels[0])
    if w >= width:
        return [row[:width] for row in pixels]
    pad = (width - w) // 2
    right = width - pad - w
    return [[False] * pad + row + [False] * right for row in pixels]


def load_lines(args: argparse.Namespace) -> list[str]:
    if args.lines:
        return [line for line in args.lines if line.strip()]
    path = Path(args.file) if args.file else MESSAGE_FILE
    if path.is_file():
        return [line for line in path.read_text().splitlines() if line.strip()]
    sys.stderr.write(
        f"No text given. Pass lines as arguments, or write {MESSAGE_FILE}\n"
        f"Example: {Path(sys.argv[0]).name} hello world\n"
    )
    sys.exit(2)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lines", nargs="*", help="One mosaic row per argument")
    parser.add_argument("-f", "--file", help="Plain-text message file")
    parser.add_argument("-c", "--cols", type=int, default=TARGET_COLS)
    parser.add_argument("--font", default=FONT, help="Font family used to draw the letters")
    args = parser.parse_args()

    texts = load_lines(args)
    font = resolve_font(args.font, texts)
    raw = [trim(rasterize(text, RENDER_SIZE, font)) for text in texts]
    widest = max(len(p[0]) for p in raw)
    scale = args.cols / widest
    mosaic_rows = []
    for pixels in raw:
        tw = max(8, int(round(len(pixels[0]) * scale)))
        th = even(int(round(len(pixels) * scale)))
        mosaic_rows.append(center(scale_wh(pixels, tw, th), args.cols))

    art = "\n\n".join(to_halfblocks(row) for row in mosaic_rows) + "\n"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(art)
    print(f"Wrote {OUT} ({args.cols} cols, {len(texts)} line(s), font {font!r})")


if __name__ == "__main__":
    main()
