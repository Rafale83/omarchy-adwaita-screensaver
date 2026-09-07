#!/usr/bin/env python3
"""Turn a photo or logo into a high-res ▄█▀ mosaic for the Omarchy screensaver.

Smartphone JPEGs are accepted: EXIF orientation is honoured, huge files are
downscaled before decode, and contrast is stretched so mixed lighting still
reads. Logos skip the stretch so edges stay crisp.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import cairo

MAX_BYTES = 25 * 1024 * 1024
MAX_MEGAPIXELS = 80
MIN_EDGE = 64
PREVIEW_EDGE = 1600
DEFAULT_COLS = int(os.environ.get("SS_COLS", "400"))
DEFAULT_MAX_ROWS = int(os.environ.get("SS_MAX_ROWS", "90"))
OUT = Path(os.environ.get("SS_OUT", Path.home() / ".config/omarchy/branding/screensaver.txt"))
ALLOWED = {".jpg", ".jpeg", ".png", ".webp", ".svg"}


def fail(msg: str, code: int = 1) -> None:
    sys.stderr.write(msg + "\n")
    sys.exit(code)


def magick(*args: str) -> None:
    cmd = ["magick", *args]
    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True, timeout=60)
    except FileNotFoundError:
        fail("ImageMagick magick is required")
    except subprocess.TimeoutExpired:
        fail("image conversion timed out")
    except subprocess.CalledProcessError as exc:
        err = (exc.stderr or exc.stdout or "").strip()
        fail(f"could not read image: {err or 'unknown magick error'}")


def identify(path: Path) -> tuple[int, int]:
    try:
        out = subprocess.run(
            ["magick", "identify", "-format", "%w %h", str(path)],
            check=True,
            capture_output=True,
            text=True,
            timeout=20,
        ).stdout.strip()
    except Exception:
        fail("could not identify image")
    parts = out.split()
    if len(parts) != 2:
        fail("could not identify image")
    w, h = int(parts[0]), int(parts[1])
    if w < MIN_EDGE or h < MIN_EDGE:
        fail(f"image too small ({w}x{h}); need at least {MIN_EDGE}px")
    if w * h > MAX_MEGAPIXELS * 1_000_000:
        fail(f"image too large ({w}x{h} px)")
    return w, h


def to_png(src: Path, dest: Path) -> None:
    magick(
        str(src),
        "-auto-orient",
        "-colorspace",
        "sRGB",
        "-resize",
        f"{PREVIEW_EDGE}x{PREVIEW_EDGE}>",
        "-strip",
        str(dest),
    )


def load_gray(png: Path) -> list[list[float]]:
    surf = cairo.ImageSurface.create_from_png(str(png))
    w, h = surf.get_width(), surf.get_height()
    buf = surf.get_data()
    stride = surf.get_stride()
    fmt = surf.get_format()
    pixels = []
    for y in range(h):
        row = []
        for x in range(w):
            i = y * stride + x * 4
            if fmt == cairo.FORMAT_ARGB32:
                b, g, r, a = buf[i], buf[i + 1], buf[i + 2], buf[i + 3]
                if a == 0:
                    lum = 1.0
                else:
                    lum = (r + g + b) / (3 * 255.0)
            else:
                b, g, r = buf[i], buf[i + 1], buf[i + 2]
                lum = (r + g + b) / (3 * 255.0)
            row.append(lum)
        pixels.append(row)
    return pixels


def percentile(values: list[float], p: float) -> float:
    if not values:
        return 0.0
    s = sorted(values)
    i = min(len(s) - 1, max(0, int(round((p / 100.0) * (len(s) - 1)))))
    return s[i]


def stretch(pixels: list[list[float]]) -> list[list[float]]:
    flat = [v for row in pixels for v in row]
    lo, hi = percentile(flat, 2), percentile(flat, 98)
    if hi - lo < 0.05:
        lo, hi = 0.0, 1.0
    scale = 1.0 / (hi - lo)
    return [[min(1.0, max(0.0, (v - lo) * scale)) for v in row] for row in pixels]


def maybe_invert(pixels: list[list[float]]) -> list[list[float]]:
    flat = [v for row in pixels for v in row]
    if percentile(flat, 50) > 0.62:
        return [[1.0 - v for v in row] for row in pixels]
    return pixels


def scale(pixels: list[list[float]], tw: int, th: int) -> list[list[float]]:
    h, w = len(pixels), len(pixels[0])
    out = []
    for y in range(th):
        sy = min(h - 1, int(y * h / th))
        row = []
        for x in range(tw):
            sx = min(w - 1, int(x * w / tw))
            row.append(pixels[sy][sx])
        out.append(row)
    return out


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
    return "\n".join(lines).rstrip() + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image")
    parser.add_argument("--photo", action="store_true", help="phone-photo heuristics")
    parser.add_argument("--cols", type=int, default=DEFAULT_COLS)
    parser.add_argument("--max-rows", type=int, default=DEFAULT_MAX_ROWS)
    parser.add_argument("--threshold", type=float, default=0.5)
    args = parser.parse_args()

    src = Path(args.image).expanduser()
    if not src.is_file():
        fail(f"not a file: {src}")
    if src.suffix.lower() not in ALLOWED:
        fail(f"unsupported type {src.suffix}; use jpg, png, webp or svg")
    size = src.stat().st_size
    if size > MAX_BYTES:
        fail(f"file too large ({size} bytes); max {MAX_BYTES}")
    identify(src)

    with tempfile.TemporaryDirectory() as tmp:
        png = Path(tmp) / "in.png"
        to_png(src, png)
        gray = load_gray(png)

    if args.photo:
        gray = maybe_invert(stretch(gray))
        on = lambda v: v < args.threshold
    else:
        on = lambda v: v < args.threshold

    h, w = len(gray), len(gray[0])
    cols = max(8, args.cols)
    rows_px = max(2, int(round(h * (cols / w))))
    max_px = args.max_rows * 2
    if rows_px > max_px:
        rows_px = max_px - (max_px % 2)
        cols = max(8, int(round(w * (rows_px / h))))
    if rows_px % 2:
        rows_px += 1
    scaled = scale(gray, cols, rows_px)
    bits = [[on(v) for v in row] for row in scaled]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(to_halfblocks(bits))
    print(f"Wrote {OUT} ({cols} cols, {rows_px // 2} rows)")


if __name__ == "__main__":
    main()
