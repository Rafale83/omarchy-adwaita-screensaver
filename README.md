# Omarchy Adwaita hires screensaver · v0.2

<p align="center">
  <img src="preview.gif" width="400" height="300" alt="Hires Screensaver — blackhole, 60s">
  <img src="preview-burn.gif" width="400" height="300" alt="Hires Screensaver — burn, 60s">
</p>

High-resolution `█▄▀` mosaic screensaver for [Omarchy](https://omarchy.org), drawn from **Adwaita Mono**.  
Économiseur d’écran mosaïque haute résolution pour Omarchy, tracé en **Adwaita Mono**.

---

## Français

L’économiseur d’écran d’Omarchy est juste magnifique mais :

- Sa résolution est ridicule
- La police d’origine est juste moche. Originale, certes, mais, disons-le, moche.
- Le texte mériterait d’être modifiable.

Ce module s’attaque à ces trois points. Il **n’embarque aucune charte personnelle** : tu fournis les mots ; il les rasterise en mosaïque dense de blocs et les joue avec `ttfx` sur la vraie grille plein écran (pas le pty 80×24 que le lanceur d’origine capture trop souvent).

**v0.2** — widget de réglages.

### Ce que ça fait

- Lance l’économiseur dans Foot en **cellules de 8 px** (~480×141 sur un 3840×2400 @ 1.6)
- Attend que le terminal ait vraiment été redimensionné, puis calque le canvas `ttfx` dessus
- Rasterise ton message en Adwaita Mono Bold, en caractères demi-blocs
- Intercepte la config Foot packagée (qui force JetBrains Mono)
- Cadence d’animation par défaut : 260 i/s (`SS_FRAME_RATE` pour changer)
- Widget barre : texte, logo IA, photo, délais d’inactivité/verrouillage Omarchy, exclusion d’effets moches

Le verrouillage reste celui d’Omarchy (mot de passe, empreinte, FIDO2 — ce que tu as déjà configuré). Le panneau ne change que les délais `idle.screensaver` et `idle.lock`.

Les photos (JPEG de téléphone compris) sont bornées : 25 Mo, orientation EXIF, réduction auto, étirement de contraste, mosaïque demi-blocs ~400 colonnes.

### Prérequis

- Omarchy (Hyprland + Foot + `ttfx`)
- Adwaita Mono (fourni avec Omarchy)
- `python-cairo`
- ImageMagick (`magick`) pour logos et photos

### Installation

```bash
git clone https://github.com/Rafale83/omarchy-adwaita-screensaver.git
cd omarchy-adwaita-screensaver
./install.sh
```

Le widget **Hires screensaver** apparaît à droite de la barre (icône écran). Clique pour ouvrir le panneau.

Ou génère une mosaïque en ligne de commande :

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
BarWidget.qml / Panel.qml / Model.js / manifest.json
overlay/generate-branding.py
overlay/convert-image.py
overlay/apply-settings.py
overlay/logos/*.svg
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

**v0.2** — settings widget.

### What it does

- Runs the screensaver in Foot at **8px cells** (~480×141 on a 3840×2400 @ 1.6 display)
- Waits until the terminal has actually resized, then sizes the `ttfx` canvas to match
- Rasterizes your message with Adwaita Mono Bold into half-block characters
- Intercepts the packaged Foot screensaver config (which hardcodes JetBrains Mono)
- Default animation rate: 260 fps (`SS_FRAME_RATE` overrides)
- Bar widget: text, AI logo, photo, Omarchy idle/lock delays, exclude ugly effects

Locking stays Omarchy's lock screen (password, fingerprint, FIDO2 — whatever you already set up). The panel only edits `idle.screensaver` and `idle.lock`.

Photos (including phone JPEGs) are gated: 25 MB cap, EXIF orientation, auto-downscale, contrast stretch, ~400-column half-block mosaic.

### Requirements

- Omarchy (Hyprland + Foot + `ttfx`)
- Adwaita Mono (ships with Omarchy)
- `python-cairo`
- ImageMagick (`magick`) for logos and photos

### Install

```bash
git clone https://github.com/Rafale83/omarchy-adwaita-screensaver.git
cd omarchy-adwaita-screensaver
./install.sh
```

The **Hires screensaver** widget lands on the right of the bar. Click it to open the panel.

Or generate a mosaic from the CLI:

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
BarWidget.qml / Panel.qml / Model.js / manifest.json
overlay/generate-branding.py
overlay/convert-image.py
overlay/apply-settings.py
overlay/logos/*.svg
overlay/run-foot.sh
overlay/fonts.conf
overlay/default/foot/screensaver.ini
```

### License

MIT
