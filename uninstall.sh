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

rm -f "$HOME/.local/bin/omarchy-launch-screensaver"
rm -f "$HOME/.local/bin/omarchy-screensaver"
rm -f "$HOME/.local/bin/omarchy-adwaita-screensaver-generate"
rm -f "$HOME/.local/bin/omarchy-adwaita-screensaver-fortunes"
rm -rf "$HOME/.config/omarchy/screensaver-overlay"
omarchy plugin disable rafale83.hires-screensaver >/dev/null 2>&1 || true
rm -rf "$HOME/.config/omarchy/plugins/rafale83.hires-screensaver"

hyprctl reload >/dev/null 2>&1 || true
echo "Removed Adwaita hires screensaver wrappers."
echo "Left ~/.config/omarchy/branding/screensaver.txt untouched."
