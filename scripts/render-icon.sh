#!/usr/bin/env bash
# Renders the app icon layers and the composed icon from the SVG sources in design/icon/.
# Run after editing any SVG there; never edit the PNGs by hand.
set -euo pipefail
cd "$(dirname "$0")/.."

for layer in halo beam dot; do
  rsvg-convert --width 1024 --height 1024 \
    --output "MorseLamp/AppIcon.icon/Assets/$layer.png" "design/icon/layers/$layer.svg"
done
rsvg-convert --width 1024 --height 1024 --output design/icon/icon-1024.png design/icon/icon.svg
