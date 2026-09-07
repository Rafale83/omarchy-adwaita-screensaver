# Omarchy Adwaita hires screensaver

High-resolution `█▄▀` mosaic screensaver for [Omarchy](https://omarchy.org), drawn from **Adwaita Mono** instead of the stock JetBrains Mono terminal font.

The module does **not** ship any personal branding. You supply the words; it rasterizes them into a dense block mosaic and plays them with `ttfx` on the real fullscreen grid (not the 80×24 pty that the stock launcher often captures).

## What it does

- Runs the screensaver in Foot at **8px cells** (~480×141 on a 3840×2400 @ 1.6 display)
- Waits until the terminal has actually resized, then sizes the `ttfx` canvas to match
- Rasterizes your message with Adwaita Mono Bold into half-block characters
- Intercepts the packaged Foot screensaver config (which hardcodes JetBrains Mono)
- Default animation rate: 260 fps (`SS_FRAME_RATE` overrides)

## Requirements

- Omarchy (Hyprland + Foot + `ttfx`)
- Adwaita Mono (ships with Omarchy)
- `python-cairo`

## Install

```bash
git clone https://github.com/<you>/omarchy-adwaita-screensaver.git
cd omarchy-adwaita-screensaver
./install.sh
```

Then generate a mosaic from **your** text (not included):

```bash
omarchy-adwaita-screensaver-generate hello
# or several lines:
omarchy-adwaita-screensaver-generate 'line one' 'line two'
```

Or write `~/.config/omarchy/branding/screensaver-message` and run the generator with no arguments.

Preview:

```bash
omarchy-launch-screensaver force
```

A key or mouse movement dismisses it. Idle still launches it through Omarchy.

## Uninstall

```bash
./uninstall.sh
```

Leaves `~/.config/omarchy/branding/screensaver.txt` alone.

## Layout

```
install.sh
uninstall.sh
bin/foot                              screensaver-only Foot wrapper
bin/omarchy-launch-screensaver
bin/omarchy-screensaver               wait for fullscreen grid, then ttfx
bin/omarchy-adwaita-screensaver-generate
overlay/generate-branding.py
overlay/run-foot.sh
overlay/fonts.conf
overlay/default/foot/screensaver.ini
```

## License

MIT
