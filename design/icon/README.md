# App icon sources

`icon.svg` is the composed icon on a 1024 canvas; `layers/` holds the same three elements one
per file (halo, beam, dot, back to front) for the Icon Composer bundle at `MorseLamp/AppIcon.icon`.
After editing any SVG here run `scripts/render-icon.sh`, which re-renders the layer PNGs into the
bundle and `icon-1024.png` next to this file. The PNGs are build artefacts: never edit them by hand.
Open `MorseLamp/AppIcon.icon` in Icon Composer (ships with Xcode 26) to tune glass, shadow and
translucency per layer; the beam has glass off because an alpha gradient under glass draws a seam.
