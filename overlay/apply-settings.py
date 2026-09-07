#!/usr/bin/env python3
"""Apply screensaver overlay settings: artwork, idle/lock timings, effects."""
from __future__ import annotations

import json
import subprocess
import sys
import time
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


def patch_idle(screensaver: int, lock: int) -> bool:
    """Write idle.screensaver / idle.lock. Returns True if the file changed."""
    screensaver = int(screensaver)
    lock = int(lock)
    if not SHELL.is_file():
        return False
    try:
        doc = json.loads(SHELL.read_text())
    except json.JSONDecodeError:
        return False
    idle = doc.setdefault("idle", {})
    if idle.get("screensaver") == screensaver and idle.get("lock") == lock:
        return False
    idle["screensaver"] = screensaver
    idle["lock"] = lock
    atomic_write(SHELL, json.dumps(doc, indent=2, ensure_ascii=False) + "\n")
    return True


def confirm_idle(screensaver: int, lock: int, timeout: float = 1.5) -> str:
    """Wait until omarchy-shell reports the new delays, or say it did not."""
    screensaver = int(screensaver)
    lock = int(lock)
    deadline = time.time() + timeout
    last = "unavailable"
    while time.time() < deadline:
        try:
            out = subprocess.run(
                ["omarchy-shell", "idle", "status"],
                check=True,
                capture_output=True,
                text=True,
                timeout=2,
            ).stdout
            st = json.loads(out)
            live_s = int(st.get("screensaver"))
            live_l = int(st.get("lock"))
            last = f"{live_s}/{live_l}"
            if live_s == screensaver and live_l == lock:
                return f"idle live {live_s}s screensaver, {live_l}s lock"
        except Exception as exc:
            last = str(exc)
        time.sleep(0.1)
    return f"idle written {screensaver}/{lock}s but shell still {last}"


def artwork_changed(old: dict, new: dict) -> bool:
    keys = ("source", "text", "logo", "photo")
    return any((old.get(k) or "") != (new.get(k) or "") for k in keys)


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
        run(
            [
                sys.executable,
                str(CONVERT),
                str(photo),
                "--photo",
                "--cols",
                "360",
                "--max-rows",
                "130",
            ]
        )
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
    previous = load_settings()
    data = dict(previous)
    data.update(incoming)
    save_settings(data)
    ss = data.get("screensaverSeconds", 150)
    lk = data.get("lockSeconds", 300)
    patch_idle(ss, lk)
    idle_msg = confirm_idle(ss, lk)
    rebuilt = False
    if artwork_changed(previous, data):
        try:
            apply_artwork(data)
            rebuilt = True
        except SystemExit as exc:
            if data.get("source") == "text" and not str(data.get("text") or "").strip():
                print(idle_msg)
                return
            raise exc
        bounce_screensaver()
        subprocess.run(["omarchy-notification-send", "-g", "Hires screensaver updated"], check=False)
    print(idle_msg + (" · artwork updated" if rebuilt else ""))


if __name__ == "__main__":
    main()
