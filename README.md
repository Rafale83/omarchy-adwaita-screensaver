# Omarchy Adwaita hires screensaver · v0.1

High-resolution `█▄▀` mosaic screensaver for [Omarchy](https://omarchy.org), drawn from **Adwaita Mono**.  
Économiseur d’écran mosaïque haute résolution pour Omarchy, tracé en **Adwaita Mono**.

---

## Français

L’économiseur d’écran d’Omarchy est juste magnifique mais :

- Sa résolution est ridicule
- La police d’origine est juste moche. Originale, certes, mais, disons-le, moche.
- Le texte mériterait d’être modifiable.

Ce module s’attaque à ces trois points. Il **n’embarque aucune charte personnelle** : tu fournis les mots ; il les rasterise en mosaïque dense de blocs et les joue avec `ttfx` sur la vraie grille plein écran (pas le pty 80×24 que le lanceur d’origine capture trop souvent).

**v0.1** — première version publiée. D’autres fonctions arriveront.

### Ce que ça fait

- Lance l’économiseur dans Foot en **cellules de 8 px** (~480×141 sur un 3840×2400 @ 1.6)
- Attend que le terminal ait vraiment été redimensionné, puis calque le canvas `ttfx` dessus
- Rasterise ton message en Adwaita Mono Bold, en caractères demi-blocs
- Intercepte la config Foot packagée (qui force JetBrains Mono)
- Cadence d’animation par défaut : 260 i/s (`SS_FRAME_RATE` pour changer)

### Prérequis

- Omarchy (Hyprland + Foot + `ttfx`)
- Adwaita Mono (fourni avec Omarchy)
- `python-cairo`

### Installation

```bash
git clone https://github.com/Rafale83/omarchy-adwaita-screensaver.git
cd omarchy-adwaita-screensaver
./install.sh
```

Puis génère une mosaïque à partir de **ton** texte (non inclus) :

```bash
omarchy-adwaita-screensaver-generate hello
# ou plusieurs lignes :
omarchy-adwaita-screensaver-generate 'ligne un' 'ligne deux'
```

Ou écris `~/.config/omarchy/branding/screensaver-message` et relance la commande sans argument.

Aperçu :

```bash
omarchy-launch-screensaver force
```

Une touche ou un mouvement de souris le ferme. L’inactivité Omarchy le lance toujours.

### Désinstallation

```bash
./uninstall.sh
```

Ne touche pas à `~/.config/omarchy/branding/screensaver.txt`.

### Fichiers

```
install.sh
uninstall.sh
VERSION
bin/foot                              wrapper Foot, économiseur uniquement
bin/omarchy-launch-screensaver
bin/omarchy-screensaver               attend la grille plein écran, puis ttfx
bin/omarchy-adwaita-screensaver-generate
overlay/generate-branding.py
overlay/run-foot.sh
overlay/fonts.conf
overlay/default/foot/screensaver.ini
```

### Licence

MIT

---

## English

Omarchy’s screensaver is genuinely magnificent, but:

- Its resolution is ridiculous
- The original font is just ugly. Original, sure — but let’s say it: ugly.
- The text deserves to be editable.

This module addresses those three points. It does **not** ship any personal branding. You supply the words; it rasterizes them into a dense block mosaic and plays them with `ttfx` on the real fullscreen grid (not the 80×24 pty that the stock launcher often captures).

**v0.1** — first public release. More features will follow.

### What it does

- Runs the screensaver in Foot at **8px cells** (~480×141 on a 3840×2400 @ 1.6 display)
- Waits until the terminal has actually resized, then sizes the `ttfx` canvas to match
- Rasterizes your message with Adwaita Mono Bold into half-block characters
- Intercepts the packaged Foot screensaver config (which hardcodes JetBrains Mono)
- Default animation rate: 260 fps (`SS_FRAME_RATE` overrides)

### Requirements

- Omarchy (Hyprland + Foot + `ttfx`)
- Adwaita Mono (ships with Omarchy)
- `python-cairo`

### Install

```bash
git clone https://github.com/Rafale83/omarchy-adwaita-screensaver.git
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

### Uninstall

```bash
./uninstall.sh
```

Leaves `~/.config/omarchy/branding/screensaver.txt` alone.

### Layout

```
install.sh
uninstall.sh
VERSION
bin/foot                              screensaver-only Foot wrapper
bin/omarchy-launch-screensaver
bin/omarchy-screensaver               wait for fullscreen grid, then ttfx
bin/omarchy-adwaita-screensaver-generate
overlay/generate-branding.py
overlay/run-foot.sh
overlay/fonts.conf
overlay/default/foot/screensaver.ini
```

### License

MIT
