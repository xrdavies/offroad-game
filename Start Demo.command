#!/bin/zsh
set -eu
cd -- "${0:A:h}"
demo_engine="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$demo_engine" ]]; then
  demo_engine="/Applications/Godot.app/Contents/MacOS/Godot"
fi
if [[ ! -x "$demo_engine" ]]; then
  demo_engine="$(command -v godot || true)"
fi
if [[ ! -x "$demo_engine" ]]; then
  print 'Godot was not found. Set GODOT_BIN to the Godot executable and try again.'
  read '?Press Return to close.'
  exit 1
fi
"$demo_engine" --headless --path "$PWD" --editor --import --quit
exec "$demo_engine" --path "$PWD" --fullscreen -- --demo
