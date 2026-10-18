#!/usr/bin/env bash
# Renders the app icon layers and the composed icon from the SVG sources in design/icon/,
# plus the web page's favicon, touch icon and og logo. Run after editing any SVG there;
# never edit the PNGs by hand.
set -euo pipefail
cd "$(dirname "$0")/.."

for layer in halo beam dot; do
  rsvg-convert --width 1024 --height 1024 \
    --output "MorseLamp/AppIcon.icon/Assets/$layer.png" "design/icon/layers/$layer.svg"
done
rsvg-convert --width 1024 --height 1024 --output design/icon/icon-1024.png design/icon/icon.svg

# Web copies. The Docker build context is web/, so the files live there, not as symlinks.
mkdir -p web/public web/src/assets
cp design/icon/icon.svg web/public/favicon.svg
cp design/icon/icon-1024.png web/src/assets/icon-1024.png
rsvg-convert --width 96 --height 96 --output web/public/favicon-96.png design/icon/icon.svg
rsvg-convert --width 180 --height 180 --output web/public/apple-touch-icon.png design/icon/icon.svg
