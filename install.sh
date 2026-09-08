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
need magick
python3 -c "import cairo" >/dev/null || {
  echo "missing python cairo (Arch: pacman -S python-cairo)" >&2
  exit 1
}

mkdir -p "$OVERLAY/default/foot" "$OVERLAY/logos" "$BIN"

install -m 755 "$ROOT/overlay/run-foot.sh" "$OVERLAY/run-foot.sh"
install -m 755 "$ROOT/overlay/generate-branding.py" "$OVERLAY/generate-branding.py"
install -m 755 "$ROOT/overlay/convert-image.py" "$OVERLAY/convert-image.py"
install -m 755 "$ROOT/overlay/apply-settings.py" "$OVERLAY/apply-settings.py"
install -m 644 "$ROOT/overlay/fonts.conf" "$OVERLAY/fonts.conf"
install -m 644 "$ROOT/overlay/default/foot/screensaver.ini" "$OVERLAY/default/foot/screensaver.ini"
install -m 644 "$ROOT/overlay/logos/"*.svg "$OVERLAY/logos/"

install -m 755 "$ROOT/bin/omarchy-launch-screensaver" "$BIN/omarchy-launch-screensaver"
install -m 755 "$ROOT/bin/omarchy-screensaver" "$BIN/omarchy-screensaver"
install -m 755 "$ROOT/bin/omarchy-adwaita-screensaver-generate" "$BIN/omarchy-adwaita-screensaver-generate"

# v0.2 shipped a PATH shim at ~/.local/bin/foot that shadowed the real terminal.
# It is gone: our own omarchy-launch-screensaver calls run-foot.sh directly, and
# run-foot.sh execs /usr/bin/foot by absolute path, so nothing needs the shim.
# Remove a leftover only when it is byte-for-byte the wrapper this project
# shipped -- never a regular file, symlink, or wrapper we do not own.
remove_legacy_foot_shim() {
  local shim="$HOME/.local/bin/foot"
  [[ -f $shim && ! -L $shim ]] || return 0
  grep -qF 'Intercept the packaged screensaver launcher, which hardcodes JetBrains Mono.' "$shim" || return 0
  grep -qF 'exec "$HOME/.config/omarchy/screensaver-overlay/run-foot.sh"' "$shim" || return 0
  rm -f "$shim"
  echo "Removed the obsolete ~/.local/bin/foot shim left by v0.2."
}

remove_legacy_foot_shim

PLUGIN_ID="rafale83.hires-screensaver"
PLUGIN_DST="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
mkdir -p "$PLUGIN_DST"
# Running from inside the installed plugin folder (the route the README
# documents after `omarchy plugin add`) makes ROOT and PLUGIN_DST the same
# directory, and `install` fails on copying a file onto itself.
if [[ ! $ROOT -ef $PLUGIN_DST ]]; then
  install -m 644 "$ROOT/manifest.json" "$ROOT/BarWidget.qml" "$ROOT/Panel.qml" "$ROOT/Model.js" "$PLUGIN_DST/"
fi

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

omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
if omarchy plugin enable rafale83.hires-screensaver --section right >/dev/null 2>&1; then
  echo "Enabled bar widget rafale83.hires-screensaver on the right."
else
  echo "Copied the widget. Enable it with: omarchy plugin enable rafale83.hires-screensaver --section right"
fi

echo "Installed Adwaita hires screensaver v$(cat "$ROOT/VERSION")."
echo "Open the bar widget to edit text, lock delays, effects, AI logos, or a photo."
echo "CLI: omarchy-adwaita-screensaver-generate your text here"
echo "Preview: omarchy-launch-screensaver force"
