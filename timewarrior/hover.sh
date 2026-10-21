#!/usr/bin/env bash
# Highlights the menu row under the mouse
case "$SENDER" in
  mouse.entered) sketchybar --set "$NAME" background.drawing=on ;;
  mouse.exited)  sketchybar --set "$NAME" background.drawing=off ;;
esac
