#!/usr/bin/env python3
"""Turn a photo or logo into a high-res mosaic for the Omarchy screensaver.

Photos become truecolor ▀ half-blocks (ANSI 24-bit fg+bg), not a 2-tone
silhouette. Logos stay crisp black-on-white ▄█▀. Smartphone JPEGs: EXIF
orientation, size caps, downscale, mild luma stretch.
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
    png24 = f"PNG24:{dest}"
    if src.suffix.lower() == ".svg":
        # Logos are 24x24 viewBox marks: rasterize large, then scale to the
        # mosaic source size. The trailing '>' on photos must not apply here
        # or a 64px rsvg output stays tiny. Force 8-bit RGB: cairo cannot
        # read ImageMagick's 16-bit gray PNGs.
        magick(
            "-density",
            "512",
            "-background",
            "white",
            str(src),
            "-alpha",
            "remove",
            "-colorspace",
            "sRGB",
            "-depth",
            "8",
            "-type",
            "TrueColor",
            "-resize",
            f"{PREVIEW_EDGE}x{PREVIEW_EDGE}",
            "-strip",
            png24,
        )
        return
    magick(
        str(src),
        "-auto-orient",
        "-colorspace",
        "sRGB",
        "-depth",
        "8",
        "-type",
        "TrueColor",
        "-resize",
        f"{PREVIEW_EDGE}x{PREVIEW_EDGE}>",
        "-strip",
        png24,
    )


def _surface_rgb(png: Path):
    surf = cairo.ImageSurface.create_from_png(str(png))
    w, h = surf.get_width(), surf.get_height()
    buf = surf.get_data()
    stride = surf.get_stride()
    fmt = surf.get_format()
    if fmt not in (cairo.FORMAT_ARGB32, cairo.FORMAT_RGB24):
        fail(f"unsupported png format {fmt}; need 8-bit rgb")
    return surf, w, h, buf, stride, fmt


def _pixel_rgb(buf, stride: int, fmt: int, x: int, y: int) -> tuple[int, int, int]:
    i = y * stride + x * 4
    b, g, r, a = buf[i], buf[i + 1], buf[i + 2], buf[i + 3]
    if fmt == cairo.FORMAT_ARGB32:
        if a == 0:
            return 0, 0, 0
        if a != 255:
            r = min(255, r * 255 // a)
            g = min(255, g * 255 // a)
            b = min(255, b * 255 // a)
    return r, g, b


def load_gray(png: Path) -> list[list[float]]:
    _surf, w, h, buf, stride, fmt = _surface_rgb(png)
    pixels = []
    for y in range(h):
        row = []
        for x in range(w):
            r, g, b = _pixel_rgb(buf, stride, fmt, x, y)
            row.append((r + g + b) / (3 * 255.0))
        pixels.append(row)
    return pixels


def load_rgb(png: Path) -> list[list[tuple[int, int, int]]]:
    _surf, w, h, buf, stride, fmt = _surface_rgb(png)
    pixels = []
    for y in range(h):
        row = []
        for x in range(w):
            row.append(_pixel_rgb(buf, stride, fmt, x, y))
        pixels.append(row)
    return pixels


def percentile(values: list[float], p: float) -> float:
    if not values:
        return 0.0
    s = sorted(values)
    i = min(len(s) - 1, max(0, int(round((p / 100.0) * (len(s) - 1)))))
    return s[i]


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


def luma(p: tuple[int, int, int]) -> float:
    r, g, b = p
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def stretch_luma(pixels: list[list[tuple[int, int, int]]]) -> list[list[tuple[int, int, int]]]:
    flat = [luma(p) for row in pixels for p in row]
    lo, hi = percentile(flat, 2), percentile(flat, 98)
    if hi - lo < 8:
        return pixels
    scale = 255.0 / (hi - lo)
    out = []
    for row in pixels:
        nr = []
        for r, g, b in row:
            y = luma((r, g, b))
            if y < 1.0:
                nr.append((r, g, b))
                continue
            y2 = min(255.0, max(0.0, (y - lo) * scale))
            f = y2 / y
            nr.append(
                (
                    min(255, max(0, int(round(r * f)))),
                    min(255, max(0, int(round(g * f)))),
                    min(255, max(0, int(round(b * f)))),
                )
            )
        out.append(nr)
    return out


def scale_rgb(
    pixels: list[list[tuple[int, int, int]]], tw: int, th: int
) -> list[list[tuple[int, int, int]]]:
    h, w = len(pixels), len(pixels[0])
    out = []
    for y in range(th):
        y0 = y * h // th
        y1 = max(y0 + 1, (y + 1) * h // th)
        row = []
        for x in range(tw):
            x0 = x * w // tw
            x1 = max(x0 + 1, (x + 1) * w // tw)
            rs = gs = bs = n = 0
            for yy in range(y0, y1):
                prow = pixels[yy]
                for xx in range(x0, x1):
                    r, g, b = prow[xx]
                    rs += r
                    gs += g
                    bs += b
                    n += 1
            row.append((rs // n, gs // n, bs // n))
        out.append(row)
    return out


def fit_grid(h: int, w: int, cols: int, max_rows: int) -> tuple[int, int]:
    cols = max(8, cols)
    rows_px = max(2, int(round(h * (cols / w))))
    max_px = max_rows * 2
    if rows_px > max_px:
        rows_px = max_px - (max_px % 2)
        cols = max(8, int(round(w * (rows_px / h))))
    if rows_px % 2:
        rows_px += 1
    return cols, rows_px


def to_color_halfblocks(pixels: list[list[tuple[int, int, int]]]) -> str:
    """Truecolor ▀ cells: fg = top pixel, bg = bottom. Sticky SGR for ttfx."""
    h, w = len(pixels), len(pixels[0])
    lines = []
    black = (0, 0, 0)
    for y in range(0, h, 2):
        top = pixels[y]
        bot = pixels[y + 1] if y + 1 < h else [black] * w
        parts: list[str] = []
        prev: tuple[tuple[int, int, int], tuple[int, int, int]] | None = None
        for t, b in zip(top, bot):
            key = (t, b)
            if key != prev:
                tr, tg, tb = t
                br, bg, bb = b
                parts.append(f"\x1b[38;2;{tr};{tg};{tb};48;2;{br};{bg};{bb}m")
                prev = key
            parts.append("▀")
        parts.append("\x1b[0m")
        lines.append("".join(parts))
    return "\n".join(lines) + "\n"


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
    parser.add_argument("--photo", action="store_true", help="truecolor photo mosaic")
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
    if src.suffix.lower() != ".svg":
        identify(src)

    with tempfile.TemporaryDirectory() as tmp:
        png = Path(tmp) / "in.png"
        to_png(src, png)
        if args.photo:
            rgb = stretch_luma(load_rgb(png))
        else:
            gray = load_gray(png)

    if args.photo:
        h, w = len(rgb), len(rgb[0])
        cols, rows_px = fit_grid(h, w, args.cols, args.max_rows)
        scaled = scale_rgb(rgb, cols, rows_px)
        art = to_color_halfblocks(scaled)
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(art)
        print(f"Wrote {OUT} ({cols} cols, {rows_px // 2} rows, truecolor)")
        return

    on = lambda v: v < args.threshold
    h, w = len(gray), len(gray[0])
    cols, rows_px = fit_grid(h, w, args.cols, args.max_rows)
    scaled = scale(gray, cols, rows_px)
    bits = [[on(v) for v in row] for row in scaled]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(to_halfblocks(bits))
    print(f"Wrote {OUT} ({cols} cols, {rows_px // 2} rows)")


if __name__ == "__main__":
    main()
