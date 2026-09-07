#!/usr/bin/env python3
"""Apply screensaver overlay settings: artwork, idle/lock timings, effects."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
OVERLAY = HOME / ".config/omarchy/screensaver-overlay"
SETTINGS = OVERLAY / "settings.json"
SHELL = HOME / ".config/omarchy/shell.json"
MESSAGE = HOME / ".config/omarchy/branding/screensaver-message"
GENERATE = OVERLAY / "generate-branding.py"
CONVERT = OVERLAY / "convert-image.py"
LOGOS = OVERLAY / "logos"

DEFAULTS = {
    "version": 1,
    "source": "text",
    "text": "",
    "logo": "grok",
    "photo": "",
    "excludeEffects": [
        "matrix",
        "decrypt",
        "vhstape",
        "thunderstorm",
        "overflow",
        "print",
        "binarypath",
        "synthgrid",
        "errorcorrect",
        "orbittingvolley",
    ],
    "screensaverSeconds": 150,
    "lockSeconds": 300,
}


def load_settings() -> dict:
    data = dict(DEFAULTS)
    if SETTINGS.is_file():
        try:
            data.update(json.loads(SETTINGS.read_text()))
        except json.JSONDecodeError:
            pass
    return data


def atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(text)
    tmp.replace(path)


def save_settings(data: dict) -> None:
    atomic_write(SETTINGS, json.dumps(data, indent=2) + "\n")


def patch_idle(screensaver: int, lock: int) -> None:
    if not SHELL.is_file():
        return
    try:
        doc = json.loads(SHELL.read_text())
    except json.JSONDecodeError:
        return
    idle = doc.setdefault("idle", {})
    idle["screensaver"] = int(screensaver)
    idle["lock"] = int(lock)
    atomic_write(SHELL, json.dumps(doc, indent=2) + "\n")


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def apply_artwork(data: dict) -> None:
    source = data.get("source") or "text"
    if source == "logo":
        logo = str(data.get("logo") or "grok")
        svg = LOGOS / f"{logo}.svg"
        if not svg.is_file():
            raise SystemExit(f"unknown logo: {logo}")
        run([sys.executable, str(CONVERT), str(svg), "--cols", "240", "--max-rows", "70"])
        return
    if source == "photo":
        photo = Path(str(data.get("photo") or "")).expanduser()
        if not photo.is_file():
            raise SystemExit("no photo selected")
        run([sys.executable, str(CONVERT), str(photo), "--photo"])
        return
    text = str(data.get("text") or "").strip()
    if not text and MESSAGE.is_file():
        text = MESSAGE.read_text()
    lines = [ln for ln in text.splitlines() if ln.strip()]
    if not lines:
        raise SystemExit("no text to render")
    MESSAGE.parent.mkdir(parents=True, exist_ok=True)
    MESSAGE.write_text("\n".join(lines) + "\n")
    run([sys.executable, str(GENERATE), *lines])


def bounce_screensaver() -> None:
    subprocess.run(["pkill", "-x", "ttfx"], check=False)
    subprocess.run(
        ["bash", "-c", "ps -C foot -o pid=,args= | awk '/screensaver.ini/{print $1}' | xargs -r kill"],
        check=False,
    )


def main() -> None:
    incoming = {}
    if sys.argv[1:] and sys.argv[1] == "--json":
        incoming = json.loads(sys.argv[2])
    elif sys.argv[1:] and sys.argv[1] == "--file":
        incoming = json.loads(Path(sys.argv[2]).read_text())
    elif not sys.stdin.isatty():
        incoming = json.loads(sys.stdin.read() or "{}")
    data = load_settings()
    data.update(incoming)
    save_settings(data)
    patch_idle(data.get("screensaverSeconds", 150), data.get("lockSeconds", 300))
    try:
        apply_artwork(data)
    except SystemExit as exc:
        if data.get("source") == "text" and not str(data.get("text") or "").strip():
            print("saved timings only")
            bounce_screensaver()
            return
        raise exc
    bounce_screensaver()
    subprocess.run(["omarchy-notification-send", "-g", "Hires screensaver updated"], check=False)
    print("ok")


if __name__ == "__main__":
    main()
