#!/bin/bash
set -euo pipefail

BEGIN="# omarchy-adwaita-screensaver begin"
END="# omarchy-adwaita-screensaver end"
LUA_BEGIN="-- omarchy-adwaita-screensaver begin"
LUA_END="-- omarchy-adwaita-screensaver end"

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

strip_block "$HOME/.bashrc" "$BEGIN" "$END"
strip_block "$HOME/.config/hypr/hyprland.lua" "$LUA_BEGIN" "$LUA_END"

rm -f "$HOME/.local/bin/foot"
rm -f "$HOME/.local/bin/omarchy-launch-screensaver"
rm -f "$HOME/.local/bin/omarchy-screensaver"
rm -f "$HOME/.local/bin/omarchy-adwaita-screensaver-generate"
rm -rf "$HOME/.config/omarchy/screensaver-overlay"

hyprctl reload >/dev/null 2>&1 || true
echo "Removed Adwaita hires screensaver wrappers."
echo "Left ~/.config/omarchy/branding/screensaver.txt untouched."
