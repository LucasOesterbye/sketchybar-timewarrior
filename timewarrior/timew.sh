#!/usr/bin/env bash
# The bar item. Tracking: live session time. Paused: frozen time. Idle: today's total.
# Left-click opens the menu, right-click pauses / resumes.
# Ticks every second while tracking, but only asks Timewarrior every 10 seconds
# (every second while the menu is open).
source "$CONFIG_DIR/plugins/timewarrior/lib.sh"

case "$SENDER" in
  timew_screen_locked)
    exec "$TW_DIR/away.sh" away ;;
  timew_screen_unlocked)
    "$TW_DIR/away.sh" back >/dev/null 2>&1 &
    exit 0 ;;
  mouse.exited.global)
    sketchybar --set "$NAME" popup.drawing=off
    rm -f "$TW_POPUP"
    exit 0 ;;
  mouse.clicked)
    [ "$BUTTON" = "right" ] && exec "$TW_DIR/action.sh" toggle
    if [ -f "$TW_POPUP" ]; then
      sketchybar --set "$NAME" popup.drawing=off
      rm -f "$TW_POPUP"
    else
      "$TW_DIR/menu.sh"
      sketchybar --set "$NAME" popup.drawing=on
      date +%s > "$TW_POPUP"
    fi
    exit 0 ;;
esac

NOW=$(date +%s)

# Asleep: while tracking the bar ticks every second, so a gap of over 90 s means the Mac slept.
# Only routine ticks check this, so restarting SketchyBar never cuts your time.
if [ "$SENDER" = "routine" ] && [ "$TW_AUTO_PAUSE" = 1 ] && [ -f "$TW_LAST_TICK" ]; then
  read -r LAST < "$TW_LAST_TICK"
  if [ $((NOW - ${LAST:-$NOW})) -gt 90 ]; then
    rm -f "$TW_LAST_TICK"
    "$TW_DIR/away.sh" gap "$LAST" >/dev/null 2>&1 &
    exit 0
  fi
fi

if [ "$SENDER" = "routine" ]; then tw_state; else tw_check_now; fi

case "$TW_STATUS" in
  tracking)
    echo "$NOW" > "$TW_LAST_TICK"
    COLOR=$TW_ACTIVE
    if [ "$TW_WARN_HOURS" -gt 0 ] && [ "$TW_SECS" -ge $((TW_WARN_HOURS * 3600)) ]; then
      COLOR=$TW_WARN
    fi
    sketchybar --set "$NAME" update_freq=1 icon= icon.color=$COLOR icon.padding_right=4 \
               label="${TW_TAG:0:12} $(tw_hms "$TW_SECS")" label.drawing=on \
               background.border_width=2 background.border_color=$COLOR ;;
  paused)
    rm -f "$TW_LAST_TICK"
    sketchybar --set "$NAME" update_freq=30 icon= icon.color=$TW_PAUSED icon.padding_right=4 \
               label="${TW_TAG:0:12} $(tw_hms "$TW_SECS")" label.drawing=on \
               background.border_width=2 background.border_color=$TW_PAUSED ;;
  *)
    rm -f "$TW_LAST_TICK"
    TOTAL="$("$TW_PY" "$TW_STATS" today 2>/dev/null)"
    if [ "${TOTAL:-0}" -gt 0 ]; then
      sketchybar --set "$NAME" update_freq=30 icon= icon.color=$TW_DIM icon.padding_right=4 \
                 label="$(tw_hms "$TOTAL")" label.drawing=on background.border_width=0
    else
      # Icon only: equal padding on both sides keeps it centred
      sketchybar --set "$NAME" update_freq=30 icon= icon.color=$TW_DIM icon.padding_right=8 \
                 label.drawing=off background.border_width=0
    fi ;;
esac

# Keep an open menu live; close it after 2 minutes so it never refreshes forever
if [ -f "$TW_POPUP" ]; then
  read -r OPENED < "$TW_POPUP"
  if [ $((NOW - ${OPENED:-0})) -gt 120 ]; then
    sketchybar --set "$NAME" popup.drawing=off
    rm -f "$TW_POPUP"
  else
    "$TW_DIR/menu.sh"
  fi
fi
exit 0
