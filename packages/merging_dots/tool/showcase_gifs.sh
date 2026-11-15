#!/usr/bin/env bash
# Turns the showcase videos in doc/ into GIFs for the README.
#
# Record them first, from example/:
#   flutter test --run-skipped -t showcase test/showcase
set -euo pipefail
cd "$(dirname "$0")/../doc"

gif() {
  local name=$1 width=$2 fps=$3
  ffmpeg -loglevel error -y -i "$name.mp4" -vf \
    "fps=$fps,scale=$width:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=64:stats_mode=diff[p];[b][p]paletteuse=dither=none" \
    "$name.gif"
  echo "doc/$name.gif: $(du -h "$name.gif" | cut -f1)"
}

gif morph 360 30
gif loaders 960 30
gif editor 960 20
