images for the main README, already dropped into the Bezel iPhone Duo frame.

- `framed/*.png`: inner-display captures from the demo app (`xcrun simctl io booted screenshot --display=<inner id>`),
  framed with `tools/frame.sh image in.png out.png` (`outer` mode for the folded shot).
- `framed/unfold-3d.gif`: rendered with the Duo Studio project (`dev/crackgate.html` there), outer screen = folded
  capture, inner screen = a short video that is clean while opening and cracks once open.

the demo accepts `SIMCTL_CHILD_CRACKGATE_DEMO_CLEAN=1` (no crack, no panel) and
`SIMCTL_CHILD_CRACKGATE_DEMO_HIDE_CONTROLS=1` (crack, no panel) on `xcrun simctl launch` for clean captures.
