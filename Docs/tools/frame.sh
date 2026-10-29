#!/bin/zsh
# Drop an inner-display capture into the Bezel "iPhone Duo - Inner Open Landscape" frame.
#   frame.sh image  in.png  out.png          inner display, open landscape
#   frame.sh outer  in.png  out.png          outer display, closed portrait
#   frame.sh video  in.mov  out.mp4 [out.gif]
# Inner bezel: transparent 2853x2007 screen hole at (120,120) on a 3093x2247 canvas.
# Outer bezel: transparent 1398x2034 screen hole at (88,80) on a 1574x2194 canvas.
set -euo pipefail
BEZEL="${BEZEL:-/Volumes/Bezel-iPhone-Duo/PNG/iPhone Duo - Night Sky - Inner Open Landscape.png}"
OUTER_BEZEL="${OUTER_BEZEL:-/Volumes/Bezel-iPhone-Duo/PNG/iPhone Duo - Night Sky - Outer Closed Portrait.png}"
# simctl sometimes writes the inner display sideways without a rotation flag; fix that here.
orient_filter() {
  local f="$1"
  local rot; rot=$(ffprobe -v error -select_streams v:0 -show_entries stream_side_data=rotation -of default=nw=1:nk=1 "$f" | head -1)
  local w h
  w=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 "$f" | head -1)
  h=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 "$f" | head -1)
  if [ -z "$rot" ] && [ "$w" -lt "$h" ]; then echo "transpose=1,"; else echo ""; fi
}
mode="$1"; in="$2"; out="$3"
case "$mode" in
  image)
    magick -size 3093x2247 xc:none \
      \( "$in" -resize '2853x2007!' \) -geometry +120+120 -composite \
      "$BEZEL" -composite \
      -trim +repage -resize 1800x -depth 8 "$out"
    ;;
  outer)
    magick -size 1574x2194 xc:none \
      \( "$in" -resize '1398x2034!' \) -geometry +88+80 -composite \
      "$OUTER_BEZEL" -composite \
      -trim +repage -resize 1000x -depth 8 "$out"
    ;;
  video)
    pre=$(orient_filter "$in")
    ffmpeg -v error -y -i "$in" -i "$BEZEL" -filter_complex \
      "[0:v]${pre}fps=30,scale=2853:2007:flags=lanczos,setsar=1,pad=3093:2247:120:120:color=white[s];[s][1:v]overlay=0:0:format=auto,crop=2985:2139:58:50,scale=1600:-2[v]" \
      -map "[v]" -c:v libx264 -pix_fmt yuv420p -crf 20 -movflags +faststart "$out"
    if [ "${4:-}" != "" ]; then
      ffmpeg -v error -y -i "$out" -vf "fps=15,scale=1000:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=192[p];[b][p]paletteuse=dither=sierra2_4a" "$4"
    fi
    ;;
esac
