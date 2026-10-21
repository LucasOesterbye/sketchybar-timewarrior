#!/usr/bin/env bash
# Menu and keyboard actions: start <n> | pause | toggle | stop | range | chart
source "$CONFIG_DIR/plugins/timewarrior/lib.sh"

CLOSE=0
tw_lock
case "$1" in
  start)
    tw_load_tags
    T="${TW_TAG_LIST[$(( ${2:-1} - 1 ))]}"
    [ -n "$T" ] || { tw_unlock; exit 0; }
    tw_check
    if [ "$TW_STATUS" != "tracking" ] || [ "$TW_TAG" != "$T" ]; then
      rm -f "$TW_LAST_TICK" "$TW_PAUSED_FLAG"
      "$TIMEW" start "$T" >/dev/null 2>&1          # also stops whatever was running
      tw_session_write "$T" 0
    fi
    CLOSE=1 ;;
  pause|toggle)
    tw_check
    case "$TW_STATUS" in
      tracking)
        tw_stop
        tw_session_write "$TW_TAG" "$TW_SECS"      # bank the time so far
        touch "$TW_PAUSED_FLAG" ;;
      paused)
        rm -f "$TW_LAST_TICK" "$TW_PAUSED_FLAG"
        "$TIMEW" continue >/dev/null 2>&1 ;;       # same category, new interval
      *)
        # toggle while idle (e.g. from a keyboard shortcut): open the menu
        if [ "$1" = "toggle" ]; then
          tw_unlock
          exec env SENDER=mouse.clicked BUTTON=left NAME=timew "$TW_DIR/timew.sh"
        fi ;;
    esac ;;
  stop)
    tw_check
    [ "$TW_STATUS" = "tracking" ] && tw_stop
    rm -f "$TW_PAUSED_FLAG" "$TW_SESSION" ;;
  range)
    [ -f "$TW_POPUP" ] && date +%s > "$TW_POPUP"   # still using the menu: keep it open
    case "$(cat "$TW_RANGE" 2>/dev/null)" in
      week)  echo month > "$TW_RANGE" ;;
      month) echo day   > "$TW_RANGE" ;;
      *)     echo week  > "$TW_RANGE" ;;
    esac ;;
  chart)
    [ -f "$TW_POPUP" ] && date +%s > "$TW_POPUP"
    if [ "$(cat "$TW_CHART" 2>/dev/null)" = "hidden" ]; then echo shown > "$TW_CHART"; else echo hidden > "$TW_CHART"; fi ;;
esac
tw_unlock

if [ "$CLOSE" = 1 ]; then
  sketchybar --set timew popup.drawing=off
  rm -f "$TW_POPUP"
fi
NAME=timew SENDER=refresh "$TW_DIR/timew.sh"
