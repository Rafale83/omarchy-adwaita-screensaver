#!/bin/bash
# Launch Foot for the Omarchy screensaver with the Adwaita hires overlay.
export FONTCONFIG_FILE="${FONTCONFIG_FILE:-$HOME/.config/omarchy/screensaver-overlay/fonts.conf}"
exec /usr/bin/foot \
  --app-id=org.omarchy.screensaver \
  --config="$HOME/.config/omarchy/screensaver-overlay/default/foot/screensaver.ini" \
  -e omarchy-screensaver
