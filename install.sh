#!/bin/bash
# Install the Adwaita hires Omarchy screensaver (no branding text).
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY="$HOME/.config/omarchy/screensaver-overlay"
BIN="$HOME/.local/bin"
BASHRC="$HOME/.bashrc"
HYPR="$HOME/.config/hypr/hyprland.lua"
BEGIN="# omarchy-adwaita-screensaver begin"
END="# omarchy-adwaita-screensaver end"
LUA_BEGIN="-- omarchy-adwaita-screensaver begin"
LUA_END="-- omarchy-adwaita-screensaver end"

need() {
  command -v "$1" >/dev/null || {
    echo "missing dependency: $1" >&2
    exit 1
  }
}

need python3
need ttfx
need foot
python3 -c "import cairo" >/dev/null || {
  echo "missing python cairo (Arch: pacman -S python-cairo)" >&2
  exit 1
}

mkdir -p "$OVERLAY/default/foot" "$BIN"

install -m 755 "$ROOT/overlay/run-foot.sh" "$OVERLAY/run-foot.sh"
install -m 755 "$ROOT/overlay/generate-branding.py" "$OVERLAY/generate-branding.py"
install -m 644 "$ROOT/overlay/fonts.conf" "$OVERLAY/fonts.conf"
install -m 644 "$ROOT/overlay/default/foot/screensaver.ini" "$OVERLAY/default/foot/screensaver.ini"

install -m 755 "$ROOT/bin/foot" "$BIN/foot"
install -m 755 "$ROOT/bin/omarchy-launch-screensaver" "$BIN/omarchy-launch-screensaver"
install -m 755 "$ROOT/bin/omarchy-screensaver" "$BIN/omarchy-screensaver"
install -m 755 "$ROOT/bin/omarchy-adwaita-screensaver-generate" "$BIN/omarchy-adwaita-screensaver-generate"

strip_block() {
  local file="$1" begin="$2" end="$3"
  [[ -f $file ]] || return 0
  local tmp
  tmp="$(mktemp)"
  awk -v begin="$begin" -v end="$end" '
    $0 == begin {skip=1; next}
    $0 == end {skip=0; next}
    skip {next}
    {print}
  ' "$file" >"$tmp"
  mv "$tmp" "$file"
}

insert_before_interactive_return() {
  python3 - "$BASHRC" "$BEGIN" "$END" <<'PY'
from pathlib import Path
import sys

path, begin, end = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
body = """export PATH="$HOME/.local/bin:$PATH"
omarchy-launch-screensaver() {
  "$HOME/.local/bin/omarchy-launch-screensaver" "$@"
}
"""
block = f"{begin}\n{body.rstrip()}\n{end}\n"
text = path.read_text() if path.exists() else ""
needle = "[[ $- != *i* ]] && return"
if needle in text:
    text = text.replace(needle, block + "\n" + needle, 1)
else:
    text = text.rstrip() + "\n\n" + block + "\n"
path.write_text(text)
PY
}

strip_block "$BASHRC" "$BEGIN" "$END"
insert_before_interactive_return

lua_body=$(
  cat <<'EOF'
do
  local home = os.getenv("HOME") or ""
  local local_bin = home .. "/.local/bin"
  local path = os.getenv("PATH") or "/usr/bin"
  if path:sub(1, #local_bin + 1) ~= local_bin .. ":" then
    path = local_bin .. ":" .. path
  end
  hl.env("PATH", path)
end
EOF
)

if [[ -f $HYPR ]]; then
  strip_block "$HYPR" "$LUA_BEGIN" "$LUA_END"
  printf '\n%s\n%s\n%s\n' "$LUA_BEGIN" "$lua_body" "$LUA_END" >>"$HYPR"
  hyprctl reload >/dev/null 2>&1 || true
fi

echo "Installed Adwaita hires screensaver."
echo "It does not change your branding text. Generate a mosaic with:"
echo "  omarchy-adwaita-screensaver-generate your text here"
echo "or write ~/.config/omarchy/branding/screensaver-message then rerun that command."
echo "Preview: omarchy-launch-screensaver force"
