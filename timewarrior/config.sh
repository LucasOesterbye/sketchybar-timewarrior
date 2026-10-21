#!/usr/bin/env bash
# sketchybar-timewarrior settings. Reload SketchyBar after editing.

# Categories in the menu, separated by ';' (so names can contain spaces)
TW_TAGS="Work;School;Coding;Projects;Reading"

# Bar position: left, right or center
TW_POSITION=right

# The timer turns orange when one session runs longer than this many hours (0 = off)
TW_WARN_HOURS=3

# Pause automatically when the screen locks or the Mac sleeps (1 = on, 0 = off)
TW_AUTO_PAUSE=1

# Back after an auto-pause: 1 = ask "Resume?" in a dialog, 0 = only a notification
TW_RESUME_PROMPT=1

# Nerd Font for icons and text (its "Mono" variant keeps the ticking timer from jiggling)
TW_FONT="Hack Nerd Font"

# Colours (0xAARRGGBB). Defaults: Catppuccin Mocha
TW_ACTIVE=0xffa6e3a1        # tracking
TW_PAUSED=0xfff9e2af        # paused
TW_WARN=0xfffab387          # long session
TW_DIM=0xff6c7086           # idle and secondary text
TW_TEXT=0xffcdd6f4          # menu text
TW_STOP=0xfff38ba8          # stop button
TW_ACCENT=0xff89b4fa        # headers and today in the chart
TW_HOVER=0xff313244         # menu row under the mouse
TW_POPUP_BG=0xff1e1e2e
TW_POPUP_BORDER=0xff45475a
