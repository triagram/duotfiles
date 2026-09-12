#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Toggle cursor trail
# @raycast.mode compact
# @raycast.icon 🌠
# @raycast.packageName Ghostty
# @raycast.description Turn Ghostty's cursor-trail shader on or off

# Toggle Ghostty's cursor-trail shader on or off, with no daemon involved.
#
# Ghostty has 85 keybind actions and none of them run an external command, so
# a hotkey has to come from outside Ghostty. The Raycast metadata above makes
# this file usable as a Raycast script command; it is plain shell otherwise.

set -u
FRAGMENT="$HOME/.config/ghostty/shader.conf"
SHADER="$HOME/.config/ghostty/shaders/cursor_tail.glsl"

[ -f "$SHADER" ] || { echo "shader missing: $SHADER"; exit 1; }
[ -f "$FRAGMENT" ] || : > "$FRAGMENT"

# Only ever signal real Ghostty processes. An unhandled SIGUSR2 kills a
# process, so a stale or recycled pid is not something to be casual about.
ghostty_pids() { ps -Axo pid,comm | awk '/\/Ghostty\.app\/Contents\/MacOS\/ghostty/ {print $1}'; }

if [ -s "$FRAGMENT" ]; then
  : > "$FRAGMENT"
  state="off"
else
  printf 'custom-shader = %s\ncustom-shader-animation = true\n' "$SHADER" > "$FRAGMENT"
  state="on"
fi

pids="$(ghostty_pids)"
[ -n "$pids" ] || { echo "cursor trail $state (no Ghostty running to reload)"; exit 0; }
for pid in $pids; do kill -USR2 "$pid"; done

# Measured at 0.81% -> 8.18% CPU on an idle focused window, so say something
# when it is switched on without mains power. Warning only; the point of the
# manual toggle is that it does what it is told.
if [ "$state" = on ] && ! pmset -g batt | grep -q "'AC Power'"; then
  echo "cursor trail on — on battery, ~10x idle CPU"
else
  echo "cursor trail $state"
fi
